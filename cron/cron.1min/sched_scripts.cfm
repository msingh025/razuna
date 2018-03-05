<cfabort>
<!---
*
* Copyright (C) 2005-2008 Razuna
*
* This file is part of Razuna - Enterprise Digital Asset Management.
*
* Razuna is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Razuna is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero Public License for more details.
*
* You should have received a copy of the GNU Affero Public License
* along with Razuna. If not, see <http://www.gnu.org/licenses/>.
*
* You may restribute this Program with a special exception to the terms
* and conditions of version 3.0 of the AGPL as described in Razuna's
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->

<!---

TODO:

- Get selected renditions

 --->


<cftry>

	<cfset _script_time = "1min">

	<cfset console("#now()# --- Executing script cron job #_script_time#")>

	<!--- Path --->
	<cfset _path = expandPath("../..")>

	<!--- Get database --->
	<cfquery datasource="razuna_default" name="_config">
	SELECT conf_database, conf_datasource, conf_storage, conf_aws_access_key, conf_aws_secret_access_key, conf_aws_location, conf_aws_tenant_in_one_bucket_name, conf_aws_tenant_in_one_bucket_enable
	FROM razuna_config
	</cfquery>

	<!--- Set DB --->
	<cfset _struct = structNew()>
	<cfset _struct.from_cron = true>
	<cfset _struct.fa = "">
	<cfset _struct.razuna.application.datasource = _config.conf_datasource>
	<cfset _struct.razuna.application.storage = _config.conf_storage>
	<cfset _struct.razuna.application.thedatabase = _config.conf_database>

	<!--- Get tools --->
	<cfquery datasource="#_struct.razuna.application.datasource#" name="qry_tools">
	SELECT thetool, thepath
	FROM tools
	</cfquery>

	<cfset console("qry_tools : ", qry_tools)>

	<cfloop query="qry_tools">
		<cfif thetool EQ "imagemagick">
			<cfset _im_path = thepath>
		<cfelseif thetool EQ "exiftool">
			<cfset _ex_path = thepath>
		</cfif>
	</cfloop>

	<!--- Check the platform and then decide on the ImageMagick tag --->
	<cfif FindNoCase("Windows", server.os.name)>
		<cfset _convert = """#_im_path#/convert.exe""">
		<cfset _exiftool = """#_ex_path#/exiftool.exe""">
	<cfelse>
		<cfset _convert = "#_im_path#/convert">
		<cfset _exiftool = "#_ex_path#/exiftool">
	</cfif>

	<!--- Prefix into session --->
	<cfset _struct.razuna.session.hostdbprefix = "raz1_">
	<cfset _struct.razuna.session.thelangid = 1>

	<!--- Check in script table for scripts that need to execute within this time --->
	<cfinvoke component="global.cfc.scheduler" method="getScriptTime" script_interval="#_script_time#" thestruct="#_struct#" returnvariable="qry_scripts" />

	<!--- Create lock file for this script --->
	<cfinvoke component="global.cfc.global" method="_lockFile" qry="#qry_scripts#" type="script_#_script_time#" returnvariable="_hosts" />

	<!--- SFTP --->
	<cfinvoke component="global.cfc.sftp" method="init" returnvariable="sftp">

	<!--- START --->

	<!--- Loop over hosts --->
	<cfloop query="qry_scripts">

		<!--- Prefix into session --->
		<cfset _struct.razuna.session.hostid = host_id>

		<!--- Grab all values of script --->
		<cfinvoke component="global.cfc.scheduler" method="getScript" id="#sched_id#" thestruct="#_struct#" returnvariable="qry_script" />
		<!--- <cfset console("SCRIPT : ", qry_script)> --->

		<!--- If this is a new record just continue --->
		<cfif qry_script.new_record>
			<cfcontinue>
		</cfif>

		<!--- If this record is not active just continue --->
		<cfif ! qry_script.sched_script_active>
			<cfcontinue>
		</cfif>

		<!--- CONTINUE --->

		<!--- Grab all matching files --->
		<cfset _struct.filename = qry_script.SCHED_SCRIPT_FILES_FILENAME>
		<cfset _struct.folderid = Serializejson([ qry_script.SCHED_SCRIPT_FILES_FOLDER ])>
		<cfset _struct.labels = Serializejson([ qry_script.SCHED_SCRIPT_FILES_LABEL ])>
		<cfinvoke component="global.cfc.scheduler" method="scriptFileSearch" thestruct="#_struct#" files_since="#qry_script.SCHED_SCRIPT_FILES_TIME#" files_since_unit="#qry_script.SCHED_SCRIPT_FILES_TIME_UNIT#" returnvariable="qry_files" />

		<!--- If no files found continue --->
		<cfif ! qry_files.recordcount>
			<cfcontinue>
		</cfif>

		<cfset console("FILES : ", qry_files)>

		<!--- Unique id for this script --->
		<cfset _uuid = createuuid('')>
		<cfset _file_file_name = "">
		<cfset _zip_file = "">
		<!--- Path to temp directory --->
		<cfset _path_temp = GetTempdirectory() & "/" & _uuid>
		<cfset _zip_file_name = "Omnipix.zip">
		<cfset _zip_file = GetTempdirectory() & _zip_file_name>

		<!--- Check what files we need to grab (Originals and renditions) Guess we could pass this in the search above --->

		<!--- Collect files here --->
		<cfset list_files = _collectFiles( files=qry_files, path_temp=_path_temp, thestruct=_struct )>

		<!--- Check if we have to transform any files --->
		<cfset _transcodeFiles( files=qry_files, script=qry_script, path_temp=_path_temp, thestruct=_struct )>

		<!--- Check if we have to create a metadata file --->
		<cfset _metaFile( files=qry_files, script=qry_script, path_temp=_path_temp, thestruct=_struct )>

		<!--- Create a ZIP file --->
		<cfthread name="zip_#_uuid#" file="#_zip_file#" source="#_path_temp#">
			<cfzip action="create" zipfile="#attributes.file#" source="#attributes.source#" overwrite="true" />
		</cfthread>
		<!--- Only release when thread is done --->
		<cfthread action="join" name="zip_#_uuid#" />

		<!--- Finally connect to FTP site and transfer all files --->
		<!--- <cfset _connection = sftp.connect( host=qry_script.SCHED_SCRIPT_FTP_HOST, port=qry_script.SCHED_SCRIPT_FTP_PORT, user=qry_script.SCHED_SCRIPT_FTP_USER, pass=qry_script.SCHED_SCRIPT_FTP_PASS )>
		<cfset put = sftp.put(file_local=_zip_file, file_remote="/#_zip_file_name#")>
		<cfset sftp.disconnect()> --->

		<!--- Check if file could be transfered --->
		<!--- <cfset console("sFTP PUT STATUS : ", put)> --->

		<!--- Delete temp dir and zip file --->
		<cfset DirectoryDelete( _path_temp, true )>
		<cfset fileDelete( _zip_file )>

	</cfloop>

	<!--- END --->

	<!--- Remove lock files --->
	<cfinvoke component="global.cfc.global" method="_removeLockFile" qry_remove_lock="#qry_scripts#" type="script_#_script_time#"/>

	<cfset console("#now()# --- Finished script cron job #_script_time#")>

	<cfcatch type="any">
		<cfset console("#now()# ---------------------- Error script cron job #_script_time#")>
		<cfset console(cfcatch)>
	</cfcatch>
</cftry>


<!--- Collect files --->
<cffunction name="_collectFiles">
	<cfargument name="files" required="yes" type="query">
	<cfargument name="path_temp" required="yes" type="string">
	<cfargument name="thestruct" required="yes" type="struct">

	<!--- Create temp dir --->
	<cfdirectory action="create" directory="#arguments.path_temp#" mode="775" />

	<!--- Name for thread --->
	<cfset var _tn = createuuid('')>

	<!--- LOCAL --->
	<cfif arguments.thestruct.razuna.application.storage EQ "local">

	<cfelseif arguments.thestruct.razuna.application.storage EQ "amazon">
		<!--- Download files to temp diretory --->
		<cfthread name="#_tn#" intstruct="#arguments#">
			<cfloop query=attributes.intstruct.files>
				<cfhttp url="#cloud_url#" file="thumb_#filename#" path="#attributes.intstruct.path_temp#" />
				<cfhttp url="#cloud_url_org#" file="#filename#" path="#attributes.intstruct.path_temp#" />
			</cfloop>
		</cfthread>
	</cfif>

	<!--- Only release when thread is done --->
	<cfthread action="join" name="#_tn#" />

	<!--- We got all the files. List them in case some files could not be put in here --->
	<cfdirectory action="list" directory="#arguments.path_temp#" type="file" listinfo="name" name="list_files" />

	<cfreturn list_files />
</cffunction>

<!--- Transcode files --->
<cffunction name="_transcodeFiles">
	<cfargument name="files" required="yes" type="query">
	<cfargument name="script" required="yes" type="struct">
	<cfargument name="path_temp" required="yes" type="string">
	<cfargument name="thestruct" required="yes" type="struct">

	<!--- If img params not empty --->
	<cfif arguments.script.SCHED_SCRIPT_IMG_CANVAS_WIDTH NEQ "" AND arguments.script.SCHED_SCRIPT_IMG_CANVAS_HEIGTH>

		<cfset arguments.convert = _convert>
		<cfset arguments.exiftool = _exiftool>

		<!--- Name for thread --->
		<cfset var _tn = createuuid('')>

		<!--- Loop over files but only images --->
		<cfthread name="#_tn#" intstruct="#arguments#">
			<cfloop query=attributes.intstruct.files>
				<!--- Path to file --->
				<cfset _path_to_file = "#attributes.intstruct.path_temp#/#filename#">
				<!--- Check type and exists --->
				<cfif type EQ "img" AND FileExists( _path_to_file )>
					<cfset _w = "">
					<cfset _h = "">
					<cfset _d = "72">
					<cfset _ext = listlast(filename, ".")>
					<cfset _filename_no_ext = replacenocase( filename, ".#_ext#", "" )>
					<!--- Get sizes of image --->
					<cfexecute name="#attributes.intstruct.exiftool#" arguments="-S -s -ImageHeight #_path_to_file#" timeout="60" variable="theheight" />
					<cfexecute name="#attributes.intstruct.exiftool#" arguments="-S -s -ImageWidth #_path_to_file#" timeout="60" variable="thewidth" />
					<!--- If with is bigger than wanted canvas --->
					<cfif thewidth GT attributes.intstruct.script.SCHED_SCRIPT_IMG_CANVAS_WIDTH>
						<cfset _w = attributes.intstruct.script.SCHED_SCRIPT_IMG_CANVAS_WIDTH>
					</cfif>
					<!--- If height is bigger than wanted canvas --->
					<cfif theheight GT attributes.intstruct.script.SCHED_SCRIPT_IMG_CANVAS_HEIGTH>
						<cfset _h = attributes.intstruct.script.SCHED_SCRIPT_IMG_CANVAS_HEIGTH>
					</cfif>
					<cfif attributes.intstruct.script.SCHED_SCRIPT_IMG_DPI NEQ "">
						<cfset _d = attributes.intstruct.script.SCHED_SCRIPT_IMG_DPI>
					</cfif>
					<!--- Create canvas with file --->
					<cfexecute name="#attributes.intstruct.convert#" arguments="convert #_path_to_file# -resize #_w#x#_h# -gravity center -background white -extent #attributes.intstruct.script.SCHED_SCRIPT_IMG_CANVAS_WIDTH#x#attributes.intstruct.script.SCHED_SCRIPT_IMG_CANVAS_HEIGTH# -density #_d# #attributes.intstruct.path_temp#/#_filename_no_ext#_extended.jpg" timeout="120" />
				</cfif>
			</cfloop>
		</cfthread>

		<!--- Only release when thread is done --->
		<cfthread action="join" name="#_tn#" />

	</cfif>

	<cfreturn />
</cffunction>

<!--- Metadata file --->
<cffunction name="_metaFile">
	<cfargument name="files" required="yes" type="query">
	<cfargument name="script" required="yes" type="struct">
	<cfargument name="path_temp" required="yes" type="string">
	<cfargument name="thestruct" required="yes" type="struct">

	<!--- If metadata not empty --->
	<!--- <cfif arguments.script.sched_script_files_include_metadata> --->

		<cfset arguments.thestruct.folder_id = "">
		<cfset arguments.thestruct.what = "">
		<cfset arguments.thestruct.thepath = GetTempdirectory()>
		<cfset arguments.thestruct.format = "xls">
		<cfset arguments.thestruct.include_renditions = false>
		<cfset arguments.thestruct.razuna.session.file_id = valueList(arguments.files.file_id)>

		<cfinvoke component="global.cfc.settings" method="get_export_template_details" thestruct="#arguments.thestruct#" returnvariable="arguments.thestruct.export_template" />

		<cfinvoke component="global.cfc.xmp" method="meta_export" thestruct="#arguments.thestruct#" returnvariable="export" />

		<!--- Export contains the full path to the exported file --->
		<cfset consoleoutput(true, true)>
		<cfset console("export", export)>
		<cffile action="move" source="#export#" destination="#arguments.path_temp#/metadata.xls" />


	<!--- </cfif> --->

	<!--- Return --->
	<cfreturn />
</cffunction>




























