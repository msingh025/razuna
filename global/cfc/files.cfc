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
<cfcomponent output="false" extends="extQueryCaching">

	<!--- COUNT ALL FILES IN A FOLDER --->
	<cffunction name="getFolderCount" description="COUNT ALL FILES IN A FOLDER" output="false" access="public" returntype="numeric">
		<cfargument name="folder_id" required="true" type="string">
		<cfargument name="file_extension" required="false" type="string" default="">
		<cfargument name="thestruct" type="struct" required="true" />
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- init local vars --->
		<cfset var qLocal = 0>
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qLocal" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#getFolderCountfiles */ COUNT(*) AS folderCount
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files
		WHERE folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Arguments.folder_id#">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		<cfif Len(Arguments.file_extension)>
			AND
			<!--- if doc or xls also add office 2007 format to query --->
			<cfif Arguments.file_extension EQ "doc" OR Arguments.file_extension EQ "xls">
				(
				<cfif arguments.thestruct.razuna.application.thedatabase EQ "oracle" OR arguments.thestruct.razuna.application.thedatabase EQ "h2" OR arguments.thestruct.razuna.application.thedatabase EQ "db2">NVL<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mysql">ifnull<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">isnull</cfif>(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
				OR <cfif arguments.thestruct.razuna.application.thedatabase EQ "oracle" OR arguments.thestruct.razuna.application.thedatabase EQ "h2" OR arguments.thestruct.razuna.application.thedatabase EQ "db2">NVL<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mysql">ifnull<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">isnull</cfif>(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#x">
				)
			<!--- query all formats if not other --->
			<cfelseif Arguments.file_extension neq "other">
				<cfif arguments.thestruct.razuna.application.thedatabase EQ "oracle" OR arguments.thestruct.razuna.application.thedatabase EQ "h2" OR arguments.thestruct.razuna.application.thedatabase EQ "db2">NVL<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mysql">ifnull<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">isnull</cfif>(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
			<cfelse>
				<cfif arguments.thestruct.razuna.application.thedatabase EQ "oracle" OR arguments.thestruct.razuna.application.thedatabase EQ "h2" OR arguments.thestruct.razuna.application.thedatabase EQ "db2">NVL<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mysql">ifnull<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">isnull</cfif>(file_extension, '') NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="doc,xls,docx,xlsx,pdf" list="true">)
			</cfif>
		</cfif>
		</cfquery>
		<cfreturn qLocal.folderCount />
	</cffunction>

	<!--- GET ALL RECORDS OF THIS TYPE IN A FOLDER --->
	<cffunction name="getFolderAssets" access="public" description="GET ALL RECORDS OF THIS TYPE IN A FOLDER" output="false" returntype="query">
		<cfargument name="folder_id" type="string" required="true">
		<cfargument name="ColumnList" required="false" type="string"  default="file_id">
		<cfargument name="file_extension" required="false" type="string" default="">
		<cfargument name="offset" type="numeric" required="false" default="0">
		<cfargument name="rowmaxpage" type="numeric" required="false" default="0">
		<cfargument name="thestruct" type="struct" required="false" default="">
		<!--- init local vars --->
		<cfset var qLocal = 0>
		<!--- Set pages var --->
		<cfparam name="arguments.thestruct.pages" default="">
		<cfparam name="arguments.thestruct.thisview" default="">
		<cfparam name="arguments.thestruct.folderaccess" default="">
		<!--- Get cachetoken --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- If we need to show subfolders --->
		<cfif arguments.thestruct.razuna.session.showsubfolders EQ "T">
			<cfinvoke component="folders" method="getfoldersinlist" dsn="#arguments.thestruct.razuna.application.datasource#" folder_id="#arguments.folder_id#" hostid="#arguments.thestruct.razuna.session.hostid#" database="#arguments.thestruct.razuna.application.thedatabase#" thestruct="#arguments.thestruct#" returnvariable="thefolders">
			<cfset var thefolderlist = arguments.folder_id & "," & ValueList(thefolders.folder_id)>
		<cfelse>
			<cfset var thefolderlist = arguments.folder_id & ",">
		</cfif>
		<!--- Set the session for offset correctly if the total count of assets in lower the the total rowmaxpage --->
		<cfif arguments.thestruct.qry_filecount LTE arguments.thestruct.razuna.session.rowmaxpage>
			<cfset arguments.thestruct.razuna.session.offset = 0>
		</cfif>
		<!---
		This is for Oracle and MSQL
		Calculate the offset .Show the limit only if pages is null or current (from print)
		--->
		<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
			<cfif arguments.thestruct.razuna.session.offset EQ 0>
				<cfset var min = 0>
				<cfset var max = arguments.thestruct.razuna.session.rowmaxpage>
			<cfelse>
				<cfset var min = arguments.thestruct.razuna.session.offset * arguments.thestruct.razuna.session.rowmaxpage>
				<cfset var max = (arguments.thestruct.razuna.session.offset + 1) * arguments.thestruct.razuna.session.rowmaxpage>
				<cfif arguments.thestruct.razuna.application.thedatabase EQ "db2">
					<cfset min = min + 1>
				</cfif>
			</cfif>
		<cfelse>
			<cfset var min = 0>
			<cfset var max = 1000>
		</cfif>
		<!--- Set sortby variable --->
		<cfset var sortby = arguments.thestruct.razuna.session.sortby>
		<!--- Set the order by --->
		<cfif arguments.thestruct.razuna.session.sortby EQ "name" OR arguments.thestruct.razuna.session.sortby EQ "kind">
			<cfset var sortby = "filename_forsort">
		<cfelseif arguments.thestruct.razuna.session.sortby EQ "sizedesc">
			<cfset var sortby = "size DESC">
		<cfelseif arguments.thestruct.razuna.session.sortby EQ "sizeasc">
			<cfset var sortby = "size ASC">
		<cfelseif arguments.thestruct.razuna.session.sortby EQ "dateadd">
			<cfset var sortby = "date_create DESC">
		<cfelseif arguments.thestruct.razuna.session.sortby EQ "datechanged">
			<cfset var sortby = "date_change DESC">
		</cfif>
		<!--- Oracle --->
		<cfif arguments.thestruct.razuna.application.thedatabase EQ "oracle">
			<!--- Clean columnlist --->
			<cfset var thecolumnlist = replacenocase(arguments.columnlist,"f.","","all")>
			<!--- Query --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qLocal" cachedwithin="1" region="razcache">
			SELECT /* #cachetoken#getFolderAssetsfiles */ rn, #thecolumnlist#, keywords, description, labels,
			filename_forsort, size, hashtag, date_create, date_change
			FROM (
				SELECT ROWNUM AS rn, #thecolumnlist#, keywords, description, labels,
				filename_forsort, size, hashtag, date_create, date_change
				FROM (
					SELECT #Arguments.ColumnList#, ft.file_keywords keywords, ft.file_desc description, '' as labels, file_name filename_forsort, file_size size, hashtag, file_create_time date_create, file_change_date date_change
					FROM #arguments.thestruct.razuna.session.hostdbprefix#files LEFT JOIN #arguments.thestruct.razuna.session.hostdbprefix#files_desc ft ON file_id = ft.file_id_r AND ft.lang_id_r = 1
					WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
					<cfif Len(Arguments.file_extension)>
						AND
						<!--- if doc or xls also add office 2007 format to query --->
						<cfif Arguments.file_extension EQ "doc" OR Arguments.file_extension EQ "xls">
							(
							NVL(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
							OR NVL(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#x">
							)
						<!--- query all formats if not other --->
						<cfelseif Arguments.file_extension neq "other">
							NVL(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
						<!--- query all files except the ones in the list --->
						<cfelse>
							(
							NVL(file_extension, '') NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="doc,xls,docx,xlsx,pdf" list="true">)
							OR (file_extension IS NULL OR file_extension = '')
							)
						</cfif>
					</cfif>
					AND in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="F">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
					ORDER BY #sortby#
					)
				WHERE ROWNUM <= <cfqueryparam cfsqltype="cf_sql_numeric" value="#max#">
				)
			WHERE rn > <cfqueryparam cfsqltype="cf_sql_numeric" value="#min#">
			</cfquery>
		<!--- DB2 --->
		<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "db2">
			<!--- Clean columnlist --->
			<cfset var thecolumnlist = replacenocase(arguments.columnlist,"f.","","all")>
			<!--- Query --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qLocal" cachedwithin="1" region="razcache">
			SELECT /* #cachetoken#getFolderAssetsfiles */ #thecolumnlist#, ft.file_keywords keywords, ft.file_desc description, '' as labels, filename_forsort, size, hashtag, date_create, date_change
			FROM (
				SELECT row_number() over() as rownr, #arguments.thestruct.razuna.session.hostdbprefix#files.*, ft.*, file_name filename_forsort, file_size size, hashtag, file_create_time date_create, file_change_date date_change
				FROM #arguments.thestruct.razuna.session.hostdbprefix#files LEFT JOIN #arguments.thestruct.razuna.session.hostdbprefix#files_desc ft ON file_id = ft.file_id_r AND ft.lang_id_r = 1
				WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				<cfif Len(Arguments.file_extension)>
					AND
					<!--- if doc or xls also add office 2007 format to query --->
					<cfif Arguments.file_extension EQ "doc" OR Arguments.file_extension EQ "xls">
						(
						file_extension = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
						OR file_extension = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#x">
						)
					<!--- query all formats if not other --->
					<cfelseif Arguments.file_extension neq "other">
						file_extension = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
					<!--- query all files except the ones in the list --->
					<cfelse>
						(
						file_extension NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="doc,xls,docx,xlsx,pdf" list="true">)
						OR (file_extension IS NULL OR file_extension = '')
						)
					</cfif>
				</cfif>
				AND in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="F">
				AND #arguments.thestruct.razuna.session.hostdbprefix#files.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				ORDER BY #sortby#
			)
			<!--- Show the limit only if pages is null or current (from print) --->
			<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
				WHERE rownr between #min# AND #max#
			</cfif>
			</cfquery>
		<!--- Other DB's --->
		<cfelse>
			<!--- MySQL Offset --->
			<cfset var mysqloffset = arguments.thestruct.razuna.session.offset * arguments.thestruct.razuna.session.rowmaxpage>
			<!--- For aliases --->
			<cfset var alias = '0,'>
			<!--- Query Aliases --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qry_aliases" cachedwithin="1" region="razcache">
			SELECT /* #cachetoken#getallaliases */ asset_id_r, type
			FROM ct_aliases c, #arguments.thestruct.razuna.session.hostdbprefix#files f
			WHERE c.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
			AND c.type = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="doc">
			AND c.asset_id_r = f.file_id
			AND f.in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="f">
			<cfif Len(Arguments.file_extension)>
				AND
				<!--- if doc or xls also add office 2007 format to query --->
				<cfif Arguments.file_extension EQ "doc" OR Arguments.file_extension EQ "xls">
					(
					file_extension = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
					OR file_extension = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#x">
					)
				<!--- query all formats if not other --->
				<cfelseif Arguments.file_extension neq "other">
					file_extension = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
				<!--- query all files except the ones in the list --->
				<cfelse>
					(
					file_extension NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="doc,xls,docx,xlsx,pdf" list="true">)
					OR (file_extension IS NULL OR file_extension = '')
					)
				</cfif>
			</cfif>
			</cfquery>
			<cfif qry_aliases.recordcount NEQ 0>
				<cfset var alias = valueList(qry_aliases.asset_id_r)>
			</cfif>
			<!--- Query --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qLocal" cachedwithin="1" region="razcache">
			<!--- MSSQL --->
			<cfif arguments.thestruct.razuna.application.thedatabase EQ "mssql">
				SELECT * FROM (
				SELECT ROW_NUMBER() OVER ( ORDER BY #sortby# ) AS RowNum,sorted_inline_view.* FROM (
			</cfif>

			SELECT /* #cachetoken#getFolderAssetsfiles */ #Arguments.ColumnList#, ft.file_keywords keywords, ft.file_desc description, '' as labels, file_name filename_forsort, cast(f.file_size as decimal(12,0)) size, hashtag,
			file_create_time date_create, file_change_date date_change, f.expiry_date, 'null' as customfields<cfif arguments.columnlist does not contain ' id'>, f.file_id id</cfif><cfif arguments.columnlist does not contain ' kind'>,'doc' kind</cfif>
			<!--- custom metadata fields to show --->
			<cfif arguments.thestruct.cs.files_metadata NEQ "">
				<cfloop list="#arguments.thestruct.cs.files_metadata#" index="m" delimiters=",">
					,<cfif m CONTAINS "keywords" OR m CONTAINS "description">ft
					<cfelseif m CONTAINS "_id" OR m CONTAINS "_time" OR m CONTAINS "_size" OR m CONTAINS "_filename" OR m CONTAINS "_number" OR m CONTAINS "expiry_date">f
					<cfelse>x
					</cfif>.#m#
				</cfloop>
			</cfif>
			FROM #arguments.thestruct.razuna.session.hostdbprefix#files f LEFT JOIN #arguments.thestruct.razuna.session.hostdbprefix#files_desc ft ON f.file_id = ft.file_id_r AND ft.lang_id_r = 1 AND f.host_id = ft.host_id LEFT JOIN #arguments.thestruct.razuna.session.hostdbprefix#files_xmp x ON x.asset_id_r = f.file_id AND f.host_id = x.host_id
			WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
			<cfif Len(Arguments.file_extension)>
				AND
				<!--- if doc or xls also add office 2007 format to query --->
				<cfif Arguments.file_extension EQ "doc" OR Arguments.file_extension EQ "xls">
					(
					<cfif arguments.thestruct.razuna.application.thedatabase EQ "h2">NVL<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mysql">ifnull<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">isnull</cfif>(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
					OR <cfif arguments.thestruct.razuna.application.thedatabase EQ "h2">NVL<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mysql">ifnull<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">isnull</cfif>(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#x">
					)
				<!--- query all formats if not other --->
				<cfelseif Arguments.file_extension neq "other">
					<cfif arguments.thestruct.razuna.application.thedatabase EQ "h2">NVL<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mysql">ifnull<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">isnull</cfif>(file_extension, '') = <cfqueryparam cfsqltype="cf_sql_varchar" value="#Arguments.file_extension#">
				<!--- query all files except the ones in the list --->
				<cfelse>
					(
					<cfif arguments.thestruct.razuna.application.thedatabase EQ "h2">NVL<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mysql">ifnull<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">isnull</cfif>(file_extension, '') NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="doc,xls,docx,xlsx,pdf" list="true">)
					OR (file_extension IS NULL OR file_extension = '')
					)
				</cfif>
			</cfif>
			AND in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="F">
			AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			AND f.is_available <cfif arguments.thestruct.razuna.application.thedatabase EQ "mysql"><><cfelse>!=</cfif> <cfqueryparam cfsqltype="cf_sql_varchar" value="2">
			<cfif arguments.thestruct.folderaccess EQ 'R'>
				AND (f.expiry_date >=<cfqueryparam cfsqltype="cf_sql_date" value="#now()#"> OR f.expiry_date is null)
			</cfif>
			OR f.file_id IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#alias#" list="true">)
			<!--- MySQL --->
			<cfif arguments.thestruct.razuna.application.thedatabase EQ "mysql" OR arguments.thestruct.razuna.application.thedatabase EQ "h2">
				ORDER BY #sortby#
				<!--- Show the limit only if pages is null or current (from print) --->
				<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
					LIMIT #mysqloffset#, #arguments.thestruct.razuna.session.rowmaxpage#
				</cfif>
			<!--- MSSQL --->
			<cfelseif arguments.thestruct.razuna.application.thedatabase EQ "mssql">
					) sorted_inline_view
				 ) resultSet
			 	 WHERE RowNum > #mysqloffset# AND RowNum <= #mysqloffset+arguments.thestruct.razuna.session.rowmaxpage#
			</cfif>
			</cfquery>
		</cfif>
		<!--- If coming from custom view and the arguments.thestruct.razuna.session.customfileid is not empty --->
		<cfif arguments.thestruct.razuna.session.customfileid NEQ "">
			<cfquery dbtype="query" name="qLocal">
			SELECT *
			FROM qLocal
			WHERE file_id IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.razuna.session.customfileid#" list="true">)
			</cfquery>
		</cfif>
		<!--- Only get the labels if in the combinded view --->
		<cfif arguments.thestruct.razuna.session.view EQ "combined">
			<!--- Get the cachetoken for here --->
			<cfset var cachetoken = getcachetoken(type="labels", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<!--- Loop over files and get labels and add to qry --->
			<cfloop query="qLocal">
				<!--- Query labels --->
				<cfquery name="qry_l" datasource="#arguments.thestruct.razuna.application.datasource#" cachedwithin="1" region="razcache">
				SELECT /* #cachetoken#getallassetslabels */ ct_label_id
				FROM ct_labels
				WHERE ct_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#file_id#">
				</cfquery>
				<!--- Add labels query --->
				<cfif qry_l.recordcount NEQ 0>
					<cfset QuerySetCell(qLocal, "labels", valueList(qry_l.ct_label_id), currentRow)>
				</cfif>
			</cfloop>
		</cfif>
		<!--- Add the custom fields to query --->
		<cfinvoke component="folders" method="addCustomFieldsToQuery" theqry="#qLocal#" thestruct="#arguments.thestruct#" returnvariable="qLocal" />
		<!--- Return --->
		<cfreturn qLocal />
	</cffunction>

	<!--- GET ALL RECORD-DETAILS OF THIS TYPE IN A FOLDER --->
	<cffunction name="getFolderAssetDetails" access="public" description="GET ALL RECORD-DETAILS OF THIS TYPE IN A FOLDER" output="false" returntype="query">
		<cfargument name="folder_id" type="string" required="true">
		<cfargument name="ColumnList" required="false" type="string"  default="file_id, folder_id_r, file_extension, file_type, file_create_date, file_create_time, file_change_date, file_change_time, file_owner, file_name, file_remarks, path_to_asset, cloud_url">
		<cfargument name="file_extension" type="string" required="false" default="">
		<cfargument name="offset" type="numeric" required="false" default="0">
		<cfargument name="rowmaxpage" type="numeric" required="false" default="0">
		<cfargument name="thestruct" type="struct" required="false" default="">
		<cfreturn getFolderAssets(folder_id=arguments.folder_id, columnlist=arguments.columnlist, file_extension=arguments.file_extension, offset=arguments.thestruct.razuna.session.offset, rowmaxpage=arguments.thestruct.razuna.session.rowmaxpage, thestruct=arguments.thestruct)>
	</cffunction>

	<!--- REMOVE THE FILE --->
	<cffunction  name="removefile" output="false">
		<cfargument name="thestruct" type="struct">
		<!--- Get file detail for log --->
		<cfinvoke method="filedetail" theid="#arguments.thestruct.id#" thecolumn="file_name, folder_id_r, file_name_org filenameorg, lucene_key, link_kind, link_path_url, path_to_asset" returnvariable="thedetail" thestruct="#arguments.thestruct#">
		<cfif thedetail.recordcount NEQ 0>
			<!--- Execute workflow --->
			<cfset arguments.thestruct.fileid = arguments.thestruct.id>
			<cfset arguments.thestruct.file_name = thedetail.file_name>
			<cfset arguments.thestruct.thefiletype = "doc">
			<cfset arguments.thestruct.folder_id = thedetail.folder_id_r>
			<cfset arguments.thestruct.folder_action = false>
			<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
			<cfset arguments.thestruct.folder_action = true>
			<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
			<!--- Log --->
			<cfinvoke component="defaults" method="trans" transid="deleted" returnvariable="deleted" />
			<cfinvoke component="extQueryCaching" method="log_assets">
				<cfinvokeargument name="theuserid" value="#arguments.thestruct.razuna.session.theuserid#">
				<cfinvokeargument name="logaction" value="Delete">
				<cfinvokeargument name="logdesc" value="#deleted#: #thedetail.file_name#">
				<cfinvokeargument name="logfiletype" value="doc">
				<cfinvokeargument name="assetid" value="#arguments.thestruct.id#">
				<cfinvokeargument name="folderid" value="#arguments.thestruct.folder_id#">
				<cfinvokeargument name="hostid" value="#arguments.thestruct.razuna.session.hostid#">
				<cfinvokeargument name="thestruct" value="#arguments.thestruct#">
			</cfinvoke>
			<!--- Delete from files DB (including referenced data)--->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
			DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#files
			WHERE file_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>
			<!--- Delete from collection --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
			DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#collections_ct_files
			WHERE file_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
			AND col_file_type = <cfqueryparam value="doc" cfsqltype="cf_sql_varchar">
			</cfquery>
			<!--- Delete from favorites --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
			DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#users_favorites
			WHERE fav_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
			AND fav_kind = <cfqueryparam value="doc" cfsqltype="cf_sql_varchar">
			AND user_id_r = <cfqueryparam value="#arguments.thestruct.razuna.session.theuserid#" cfsqltype="CF_SQL_VARCHAR">
			</cfquery>
			<!--- Delete from Versions --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
			DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#versions
			WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
			AND ver_type = <cfqueryparam value="doc" cfsqltype="cf_sql_varchar">
			</cfquery>
			<!--- Delete from Share Options --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
			DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#share_options
			WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
			</cfquery>
			<!--- Delete aliases --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
			DELETE FROM ct_aliases
			WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
			</cfquery>
			<!--- Delete labels --->
			<cfinvoke component="labels" method="label_ct_remove" id="#arguments.thestruct.id#" thestruct="#arguments.thestruct#" />
			<!--- Custom field values --->
			<cfinvoke component="custom_fields" method="delete_values" fileid="#arguments.thestruct.id#" thestruct="#arguments.thestruct#" />
			<!--- Delete from file system --->
			<cfset arguments.thestruct.folder_id_r = thedetail.folder_id_r>
			<cfset arguments.thestruct.qrydetail = thedetail>
			<cfset arguments.thestruct.link_kind = thedetail.link_kind>
			<cfset arguments.thestruct.filenameorg = thedetail.filenameorg>
			<cfthread intstruct="#arguments.thestruct#">
				<cfinvoke method="deletefromfilesystem" thestruct="#attributes.intstruct#">
			</cfthread>
			<!--- Flush Cache --->
			<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<cfset resetcachetoken(type="folders", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<cfset resetcachetoken(type="search", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<cfset resetcachetoken(type="labels", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		</cfif>
		<cfreturn />
	</cffunction>

	<!--- TRASH THE FILE --->
	<cffunction name="trashfile" output="false">
		<cfargument name="thestruct" type="struct">
		<!--- Update in_trash --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
		UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files
		SET
		in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.trash#">,
		file_change_time = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
		WHERE file_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<!--- Execute workflow --->
		<cfset arguments.thestruct.fileid = arguments.thestruct.id>
		<!--- <cfset arguments.thestruct.file_name = thedetail.img_filename> --->
		<cfset arguments.thestruct.thefiletype = "doc">
		<!--- <cfset arguments.thestruct.folder_id = arguments.thestruct.folder_id> --->
		<cfset arguments.thestruct.folder_action = false>
		<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
		<cfset arguments.thestruct.folder_action = true>
		<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
		<!--- Remove item from basket and favorites --->
		<cfinvoke component="favorites" method="removeitem" favid="#arguments.thestruct.id#" thestruct="#arguments.thestruct#" />
		<cfinvoke component="basket" method="removeitem" thefileid="#arguments.thestruct.id#" thestruct="#arguments.thestruct#" />
		<!--- Flush Cache --->
		<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="folders", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="search", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="labels", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- return --->
		<cfreturn />
	</cffunction>

	<!--- TRASH MANY FILE --->
	<cffunction name="trashfilemany" output="true">
		<cfargument name="thestruct" type="struct">
		<cfif arguments.thestruct.razuna.session.file_id EQ "all">
			<!--- As we have all get all IDS from this search --->
			<cfinvoke component="search" method="getAllIdsMain" thestruct="#arguments.thestruct#" searchupc="#arguments.thestruct.razuna.session.search.searchupc#" searchtext="#arguments.thestruct.razuna.session.search.searchtext#" searchtype="doc" searchrenditions="#arguments.thestruct.razuna.session.search.searchrenditions#" searchfolderid="#arguments.thestruct.razuna.session.search.searchfolderid#" hostid="#arguments.thestruct.razuna.session.hostid#" returnvariable="ids">
				<!--- Set the fileid --->
				<cfset arguments.thestruct.razuna.session.file_id = ids>
		</cfif>
		<!--- Loop --->
		<cfset var i = "">
		<cfloop list="#arguments.thestruct.razuna.session.file_id#" index="i" delimiters=",">
			<cfset i = listfirst(i,"-")>
			<!--- Update in_trash --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
			UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files
			SET
			in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.trash#">,
			file_change_time = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">
			WHERE file_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>
			<!--- Execute workflow --->
			<cfset arguments.thestruct.fileid = i>
			<!--- <cfset arguments.thestruct.file_name = thedetail.img_filename> --->
			<cfset arguments.thestruct.thefiletype = listlast(i,"-")>
			<cfset arguments.thestruct.folder_id = arguments.thestruct.folder_id>
			<cfset arguments.thestruct.folder_action = false>
			<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
			<cfset arguments.thestruct.folder_action = true>
			<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
			<!--- Remove item from basket and favorites --->
			<cfinvoke component="favorites" method="removeitem" favid="#i#" thestruct="#arguments.thestruct#" />
			<cfinvoke component="basket" method="removeitem" thefileid="#i#" thestruct="#arguments.thestruct#" />
		</cfloop>
		<!--- Flush Cache --->
		<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="folders", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="search", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="labels", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfreturn />
	</cffunction>

	<!--- Get files from trash --->
	<cffunction name="gettrashfile" output="false" returntype="Query">
		<cfargument name="noread" required="false" default="false">
		<cfargument name="nocount" required="false" default="false">
		<cfargument name="thestruct" type="struct" required="true" />
		<!--- Param --->
		<cfset var qry_file = "">
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- Query --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qry_file" cachedwithin="#CreateTimeSpan(0,0,5,0)#" region="razcache">
				SELECT /* #cachetoken#gettrashfile */
				f.file_id AS id,
				f.file_name AS filename,
				f.folder_id_r,
				f.file_extension AS ext,
				f.file_name_org AS filename_org,
				'doc' AS kind,
				f.link_kind,
				f.path_to_asset,
				f.cloud_url,
				f.cloud_url_org,
				f.hashtag,
				'false' AS in_collection,
				'files' as what,
				'' AS folder_main_id_r,
				<cfif arguments.thestruct.razuna.application.thedatabase EQ "mssql">f.file_id + '-doc'<cfelse>concat(f.file_id,'-doc')</cfif> as listid
					<!--- Permfolder --->
					<cfif arguments.thestruct.razuna.session.is_system_admin OR arguments.thestruct.razuna.session.is_administrator>
						, 'X' as permfolder
					<cfelse>
						,
						CASE
							WHEN (
								SELECT DISTINCT max(fg5.grp_permission)
								FROM #arguments.thestruct.razuna.session.hostdbprefix#folders_groups fg5
								WHERE fg5.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
								AND fg5.folder_id_r = f.folder_id_r
								AND (
									fg5.grp_id_r = '0'
									OR fg5.grp_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.razuna.session.thegroupofuser#" list="true">)
								)
							) = 'R' THEN 'R'
							WHEN (
								SELECT DISTINCT max(fg5.grp_permission)
								FROM #arguments.thestruct.razuna.session.hostdbprefix#folders_groups fg5
								WHERE fg5.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
								AND fg5.folder_id_r = f.folder_id_r
								AND (
									fg5.grp_id_r = '0'
									OR fg5.grp_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.razuna.session.thegroupofuser#" list="true">)
								)
							) = 'W' THEN 'W'
							WHEN (
								SELECT DISTINCT max(fg5.grp_permission)
								FROM #arguments.thestruct.razuna.session.hostdbprefix#folders_groups fg5
								WHERE fg5.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
								AND fg5.folder_id_r = f.folder_id_r
								AND (
									fg5.grp_id_r = '0'
									OR fg5.grp_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.razuna.session.thegroupofuser#" list="true">)
								)
							) = 'X' THEN 'X'
							WHEN (
								SELECT folder_owner
								FROM #arguments.thestruct.razuna.session.hostdbprefix#folders fo
								WHERE fo.folder_id = f.folder_id_r
							) = '#arguments.thestruct.razuna.session.theUserID#' THEN 'X'
						END as permfolder
					</cfif>
				FROM
					#arguments.thestruct.razuna.session.hostdbprefix#files f
				WHERE
					f.in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="T">
				AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				<cfif !nocount>
					LIMIT 500
				</cfif>
			</cfquery>
			<cfif qry_file.RecordCount NEQ 0>
				<cfset var myArray = arrayNew( 1 )>
				<cfset var temp= ArraySet(myArray, 1, qry_file.RecordCount, "False")>
				<cfloop query="qry_file">
					<cfquery name="alert_col" datasource="#arguments.thestruct.razuna.application.datasource#">
					SELECT file_id_r
					FROM #arguments.thestruct.razuna.session.hostdbprefix#collections_ct_files
					WHERE file_id_r = <cfqueryparam value="#qry_file.id#" cfsqltype="CF_SQL_VARCHAR">
					</cfquery>
					<cfif alert_col.RecordCount NEQ 0>
						<cfset temp = QuerySetCell(qry_file, "in_collection", "True", currentRow  )>
					</cfif>
				</cfloop>
				<cfquery name="qry_file" dbtype="query">
					SELECT *
					FROM qry_file
					WHERE permfolder != <cfqueryparam value="" cfsqltype="CF_SQL_VARCHAR">
					<cfif noread>
						AND permfolder != <cfqueryparam value="r" cfsqltype="CF_SQL_VARCHAR">
					</cfif>
				</cfquery>
			</cfif>
			<cfreturn qry_file />
	</cffunction>

	<!--- Get trash files form trash directory --->
	<cffunction name="thetrashfiles" output="false">
		<cfargument name="thestruct" type="struct">
		<cfif directoryExists('#arguments.thestruct.thepathup#global/host/#arguments.thestruct.thetrash#/#arguments.thestruct.razuna.session.hostid#/file/')>
			<cfdirectory action="list" directory="#arguments.thestruct.thepathup#global/host/#arguments.thestruct.thetrash#/#arguments.thestruct.razuna.session.hostid#/file/" name="getfilestrash">
		<cfelse>
			<cfdirectory action="create" directory="#arguments.thestruct.thepathup#global/host/#arguments.thestruct.thetrash#/#arguments.thestruct.razuna.session.hostid#/file/">
			<cfdirectory action="list" directory="#arguments.thestruct.thepathup#global/host/#arguments.thestruct.thetrash#/#arguments.thestruct.razuna.session.hostid#/file/" name="getfilestrash">
		</cfif>
		<cfreturn getfilestrash />
	</cffunction>

	<!--- RESTORE THE FILE --->
	<cffunction name="restorefile" output="false">
		<cfargument name="thestruct" type="struct">
		<!--- Param --->
		<cfset var local = structNew()>
		<cfset var thedetail = "">
		<cfset var dir_parent_id = "">
		<cfset var get_qry = "">
		<!--- check the parent folder is exist --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="thedetail">
		SELECT folder_main_id_r,folder_id_r FROM #arguments.thestruct.razuna.session.hostdbprefix#folders
		WHERE folder_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.folder_id#">
		AND in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="F">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>

		<cfif thedetail.RecordCount EQ 0>
			<cfset local.istrash = "trash">
		<cfelse>
			<!---<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="theparentdetail">
				SELECT folder_id,folder_id_r,in_trash FROM #arguments.thestruct.razuna.session.hostdbprefix#folders
				WHERE folder_main_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#thedetail.folder_main_id_r#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>--->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="dir_parent_id">
			SELECT folder_id,folder_id_r,in_trash FROM #arguments.thestruct.razuna.session.hostdbprefix#folders
			WHERE folder_main_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#thedetail.folder_main_id_r#">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>
			<cfloop query="dir_parent_id">
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="get_qry">
				SELECT folder_id,in_trash FROM #arguments.thestruct.razuna.session.hostdbprefix#folders
				WHERE folder_id = <cfqueryparam cfsqltype="cf_sql_varchar" value="#dir_parent_id.folder_id_r#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				</cfquery>
				<cfif get_qry.in_trash EQ 'T'>
					<cfset local.istrash = "trash">
				<cfelseif get_qry.folder_id EQ dir_parent_id.folder_id_r AND get_qry.in_trash EQ 'F'>
					<cfset local.root = "yes">
					<!--- Update in_trash --->
					<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
					UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files
					SET
					in_trash = <cfqueryparam cfsqltype="cf_sql_varchar" value="F">,
					is_indexed = <cfqueryparam cfsqltype="cf_sql_varchar" value="0">
					WHERE file_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
					</cfquery>
				</cfif>
			</cfloop>
			<!--- Flush Cache --->
			<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<cfset resetcachetoken(type="folders", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<cfset resetcachetoken(type="search", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<cfset resetcachetoken(type="labels", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		</cfif>
		<cfif isDefined('local.istrash') AND  local.istrash EQ "trash">
			<cfset var is_trash = "intrash">
		<cfelse>
			<cfset var is_trash = "notrash">
		</cfif>
		<cfreturn is_trash />
	</cffunction>

	<cffunction name="removefilemany" output="true">
		<cfargument name="thestruct" type="struct">
		<cfinvoke method="removefilemanythread" thestruct="#arguments.thestruct#" />
		<cfreturn />
	</cffunction>

	<!--- REMOVE MANY FILES --->
	<cffunction name="removefilemanythread" output="true">
		<cfargument name="thestruct" type="struct">
		<cfparam name="arguments.thestruct.fromfolderremove" default="false" />
		<!--- Get storage --->
		<cfset var qry_storage = "">
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qry_storage" cachedwithin="#CreateTimeSpan(0,1,0,0)#" region="razcache">
		SELECT set2_aws_bucket
		FROM #arguments.thestruct.razuna.session.hostdbprefix#settings_2
		WHERE host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<cfset arguments.thestruct.awsbucket = qry_storage.set2_aws_bucket>
		<!--- Loop --->
		<!--- Delete from files DB (including referenced data)--->
		<cfset var i = "">
		<cfloop list="#arguments.thestruct.id#" index="i" delimiters=",">
			<cfset i = listfirst(i,"-")>
			<!--- Get file detail for log --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="thedetail">
			SELECT file_name, folder_id_r, file_name_org filenameorg, lucene_key, link_kind, link_path_url, path_to_asset
			FROM #arguments.thestruct.razuna.session.hostdbprefix#files
			WHERE file_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>
			<cfif thedetail.recordcount NEQ 0>
				<!--- Execute workflow --->
				<cfif !arguments.thestruct.fromfolderremove>
					<cfset arguments.thestruct.fileid = i>
					<cfset arguments.thestruct.file_name = thedetail.file_name>
					<cfset arguments.thestruct.thefiletype = "doc">
					<cfset arguments.thestruct.folder_id = thedetail.folder_id_r>
					<cfset arguments.thestruct.folder_action = false>
					<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
					<cfset arguments.thestruct.folder_action = true>
					<cfinvoke component="plugins" method="getactions" theaction="on_file_remove" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
				</cfif>
				<!--- Log --->
				<cfinvoke component="defaults" method="trans" transid="deleted" returnvariable="deleted" />
				<cfinvoke component="extQueryCaching" method="log_assets">
					<cfinvokeargument name="theuserid" value="#arguments.thestruct.razuna.session.theuserid#">
					<cfinvokeargument name="logaction" value="Delete">
					<cfinvokeargument name="logdesc" value="#deleted#: #thedetail.file_name#">
					<cfinvokeargument name="logfiletype" value="doc">
					<cfinvokeargument name="assetid" value="#i#">
					<cfinvokeargument name="folderid" value="#arguments.thestruct.folder_id#">
					<cfinvokeargument name="hostid" value="#arguments.thestruct.razuna.session.hostid#">
					<cfinvokeargument name="thestruct" value="#arguments.thestruct#">
				</cfinvoke>
				<!--- Remove --->
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
				DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#files
				WHERE file_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				</cfquery>
				<!--- Delete from collection --->
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
				DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#collections_ct_files
				WHERE file_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
				AND col_file_type = <cfqueryparam value="doc" cfsqltype="cf_sql_varchar">
				</cfquery>
				<!--- Delete from favorites --->
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
				DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#users_favorites
				WHERE fav_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
				AND fav_kind = <cfqueryparam value="doc" cfsqltype="cf_sql_varchar">
				AND user_id_r = <cfqueryparam value="#arguments.thestruct.razuna.session.theuserid#" cfsqltype="CF_SQL_VARCHAR">
				</cfquery>
				<!--- Delete from Versions --->
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
				DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#versions
				WHERE asset_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
				AND ver_type = <cfqueryparam value="doc" cfsqltype="cf_sql_varchar">
				</cfquery>
				<!--- Delete from Share Options --->
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
				DELETE FROM #arguments.thestruct.razuna.session.hostdbprefix#share_options
				WHERE asset_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
				</cfquery>
				<!--- Delete aliases --->
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
				DELETE FROM ct_aliases
				WHERE asset_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
				</cfquery>
				<!--- Delete labels --->
				<cfinvoke component="labels" method="label_ct_remove" id="#i#" thestruct="#arguments.thestruct#" />
				<!--- Custom field values --->
				<cfinvoke component="custom_fields" method="delete_values" fileid="#i#" thestruct="#arguments.thestruct#" />
				<!--- Delete from file system --->
				<cfset arguments.thestruct.id = i>
				<cfset arguments.thestruct.folder_id_r = thedetail.folder_id_r>
				<cfset arguments.thestruct.qrydetail = thedetail>
				<cfset arguments.thestruct.link_kind = thedetail.link_kind>
				<cfset arguments.thestruct.filenameorg = thedetail.filenameorg>
				<cfset arguments.thestruct.assetpath = thedetail.path_to_asset>
				<cfthread intstruct="#arguments.thestruct#" priority="low">
					<cfinvoke method="deletefromfilesystem" thestruct="#attributes.intstruct#">
				</cfthread>
			</cfif>
		</cfloop>
		<!--- Flush Cache --->
		<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="folders", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="search", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfreturn />
	</cffunction>

	<!--- SubFunction called from deletion above --->
	<cffunction name="deletefromfilesystem" output="false">
		<cfargument name="thestruct" type="struct">
		<cftry>
			<!--- Delete in Lucene --->
			<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.id#" category="doc">
			<cfif arguments.thestruct.razuna.application.storage EQ "local">
				<!--- File --->
				<cfif DirectoryExists("#arguments.thestruct.assetpath#/#arguments.thestruct.razuna.session.hostid#/#arguments.thestruct.qrydetail.path_to_asset#") AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
					<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#arguments.thestruct.razuna.session.hostid#/#arguments.thestruct.qrydetail.path_to_asset#" recurse="true">
				</cfif>
				<!--- Versions --->
				<cfif DirectoryExists("#arguments.thestruct.assetpath#/#arguments.thestruct.razuna.session.hostid#/versions/doc/#arguments.thestruct.id#") AND arguments.thestruct.id NEQ "">
					<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#arguments.thestruct.razuna.session.hostid#/versions/doc/#arguments.thestruct.id#" recurse="true">
				</cfif>
			<cfelseif arguments.thestruct.razuna.application.storage EQ "nirvanix" AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
				<!--- File --->
				<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/#arguments.thestruct.qrydetail.path_to_asset#">
				<!--- Versions --->
				<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/versions/doc/#arguments.thestruct.id#">
			<!--- Amazon --->
			<cfelseif arguments.thestruct.razuna.application.storage EQ "amazon" AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
				<cfinvoke component="amazon" method="deletefolder" folderpath="#arguments.thestruct.qrydetail.path_to_asset#" awsbucket="#arguments.thestruct.awsbucket#" thestruct="#arguments.thestruct#" />
				<!--- Versions --->
				<cfinvoke component="amazon" method="deletefolder" folderpath="versions/doc/#arguments.thestruct.id#" awsbucket="#arguments.thestruct.awsbucket#" thestruct="#arguments.thestruct#" />
			<!--- Akamai --->
			<cfelseif arguments.thestruct.razuna.application.storage EQ "akamai" AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
				<cfinvoke component="akamai" method="Delete">
					<cfinvokeargument name="theasset" value="">
					<cfinvokeargument name="thetype" value="#arguments.thestruct.akadoc#">
					<cfinvokeargument name="theurl" value="#arguments.thestruct.akaurl#">
					<cfinvokeargument name="thefilename" value="#arguments.thestruct.qrydetail.filenameorg#">
				</cfinvoke>
			</cfif>
			<cfcatch type="any">
				<cfset console("#now()# ---------------- Error")>
				<cfset consoleoutput(true, true)>
				<cfset console(cfcatch)>
			</cfcatch>
		</cftry>
		<cfreturn />
	</cffunction>

	<!--- GET DETAIL BY COLUMN ONLY --->
	<cffunction name="filedetail" output="false">
		<cfargument name="theid" type="string">
		<cfargument name="thecolumn" type="string">
		<cfargument name="thestruct" type="struct" required="true" />
		<cfset var qry = "">
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qry" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#filedetailfiles */ #arguments.thecolumn#
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files
		WHERE file_id = <cfqueryparam value="#arguments.theid#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<cfreturn qry>
	</cffunction>

	<!--- GET THE FILES DETAILS --->
	<cffunction name="detail" output="false">
		<cfargument name="thestruct" type="struct">
		<!--- Params --->
		<cfset var theassetsize = "">
		<cfset var qry = structnew()>
		<cfset var details = "">
		<cfparam default="0" name="arguments.thestruct.razuna.session.thegroupofuser">
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- Get details --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="details" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#detailfiles */ f.file_id, f.folder_id_r, f.file_extension, f.file_type, f.file_create_date, f.file_create_time, f.file_change_date, f.file_change_time, f.file_owner, f.file_name, f.file_remarks, f.file_name_org, f.file_name_org filenameorg, f.shared, f.link_path_url, f.link_kind, f.file_size, f.file_meta, f.path_to_asset, f.cloud_url, f.cloud_url_org, f.file_upc_number, f.expiry_date, s.set2_doc_download, s.set2_intranet_gen_download, s.set2_url_website, s.set2_path_to_assets, u.user_first_name, u.user_last_name, fo.folder_name,
		'' as perm
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files f
		LEFT JOIN #arguments.thestruct.razuna.session.hostdbprefix#settings_2 s ON s.set2_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.application.setid#"> AND s.host_id = f.host_id
		LEFT JOIN users u ON u.user_id = f.file_owner
		LEFT JOIN #arguments.thestruct.razuna.session.hostdbprefix#folders fo ON fo.folder_id = f.folder_id_r AND fo.host_id = f.host_id
		WHERE f.file_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<cfif details.recordcount NEQ 0>
			<!--- Get proper folderaccess --->
			<cfinvoke component="folders" method="setaccess" returnvariable="theaccess" thestruct="#arguments.thestruct#" folder_id="#details.folder_id_r#"  />
			<!--- Add labels query --->
			<cfif theaccess NEQ "">
				<cfset QuerySetCell(details, "perm", theaccess)>
			</cfif>
		</cfif>
		<!--- Get descriptions and keywords --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="desc" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#detaildescfiles */ lang_id_r, file_keywords, file_desc, file_desc as thedesc, file_keywords as thekeys
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files_desc
		WHERE file_id_r = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<!--- Get PDF XMP values--->
		<cfif details.file_extension EQ "pdf">
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="pdfxmp" cachedwithin="1" region="razcache">
			SELECT /* #cachetoken#detailxmpfiles */ author, rights, authorsposition, captionwriter, webstatement, rightsmarked
			FROM #arguments.thestruct.razuna.session.hostdbprefix#files_xmp
			WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>
			<!--- Put into struct --->
			<cfset qry.pdfxmp = pdfxmp>
		</cfif>
		<!--- Get file size on file system --->
		<cfif (arguments.thestruct.razuna.application.storage NEQ "nirvanix" OR arguments.thestruct.razuna.application.storage NEQ "amazon" OR arguments.thestruct.razuna.application.storage NEQ "akamai") AND (details.file_size EQ "0" OR details.file_size EQ "0" AND details.link_kind NEQ "url")>
			<cfset var thefilepath = "#details.set2_path_to_assets#/#arguments.thestruct.razuna.session.hostid#/#details.path_to_asset#/#details.file_name_org#">
			<cfinvoke component="global" method="getfilesize" filepath="#thefilepath#" returnvariable="theassetsize">
		<cfelse>
			<cfset var theassetsize = details.file_size>
		</cfif>
		<!--- Convert the size --->
		<cfif isnumeric(theassetsize)>
			<cfinvoke component="global" method="converttomb" returnvariable="qry.thesize" thesize="#theassetsize#">
		<cfelse>
			<cfset qry.thesize = 0>
		</cfif>
		<!--- Put into struct --->
		<cfset qry.detail = details>
		<cfset qry.desc = desc>
		<!--- Return --->
		<cfreturn qry>
	</cffunction>

	<!--- UPDATE FILES IN THREAD --->
	<cffunction name="update" output="false">
		<cfargument name="thestruct" type="struct">
		<!--- Start the thread for updating --->
		<cfthread intstruct="#arguments.thestruct#">
			<cfinvoke method="updatethread" thestruct="#attributes.intstruct#" />
		</cfthread>
		<cfset resetcachetoken(type="general", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
	</cffunction>

	<!--- SAVE THE FILES DETAILS --->
	<cffunction name="updatethread" output="false">
		<cfargument name="thestruct" type="struct">
		<cfparam name="arguments.thestruct.shared" default="F">
		<cfparam name="arguments.thestruct.what" default="">
		<cfparam name="arguments.thestruct.frombatch" default="F">
		<cfparam name="arguments.thestruct.batch_replace" default="true">
		<cfset var renlist ="-1">
		<!--- If this is from search the file_id should be all --->
		<cfif arguments.thestruct.file_id EQ "all">
			<!--- As we have all get all IDS from this search --->
			<cfinvoke component="search" method="getAllIdsMain" thestruct="#arguments.thestruct#" searchupc="#arguments.thestruct.razuna.session.search.searchupc#" searchtext="#arguments.thestruct.razuna.session.search.searchtext#" searchtype="doc" searchrenditions="#arguments.thestruct.razuna.session.search.searchrenditions#" searchfolderid="#arguments.thestruct.razuna.session.search.searchfolderid#" hostid="#arguments.thestruct.razuna.session.hostid#" returnvariable="ids">
				<!--- Set the fileid --->
				<cfset arguments.thestruct.file_id = ids>
		</cfif>
		<!--- RAZ-2837 :: Update Metadata when renditions exists and rendition's metadata option is True --->
		<cfif (structKeyExists(arguments.thestruct,'qry_related') AND arguments.thestruct.qry_related.recordcount NEQ 0) AND (structKeyExists(arguments.thestruct,'option_rendition_meta') AND arguments.thestruct.option_rendition_meta EQ 'true')>
			<!--- Get additional renditions --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="getaddver">
			SELECT av_id FROM #arguments.thestruct.razuna.session.hostdbprefix#additional_versions
			WHERE asset_id_r in (<cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR" list="true">)
			</cfquery>
			<!--- Append additional renditions --->
			<cfset renlist = listappend(renlist,'#valuelist(getaddver.av_id)#',',')>
			<!--- Append  renditions --->
			<cfset renlist = listappend(renlist,'#valuelist(arguments.thestruct.qry_related.aud_id)#',',')>
			<!--- Append to file_id list --->
			<cfset arguments.thestruct.file_id = listappend(arguments.thestruct.file_id,renlist,',')>
		</cfif>
		<!--- Loop over the file_id (important when working on more then one image) --->
		<cfloop list="#arguments.thestruct.file_id#" delimiters="," index="i">
			<cfset var i = listfirst(i,"-")>
			<cfset arguments.thestruct.file_id = i>
			<!--- Save the desc and keywords --->
			<cfloop list="#arguments.thestruct.langcount#" index="langindex">
				<!--- If we come from all we need to change the desc and keywords arguments name --->
				<cfif arguments.thestruct.what EQ "all">
					<cfset var alldesc = "all_desc_#langindex#">
					<cfset var allkeywords = "all_keywords_#langindex#">
					<cfset var thisdesc = "arguments.thestruct.file_desc_#langindex#">
					<cfset var thiskeywords = "arguments.thestruct.file_keywords_#langindex#">
					<cfset "#thisdesc#" =  evaluate(alldesc)>
					<cfset "#thiskeywords#" =  evaluate(allkeywords)>
				<cfelse>
					<!--- <cfif langindex EQ 1>
						<cfset thisdesc = "desc_#langindex#">
						<cfset thiskeywords = "keywords_#langindex#">
					<cfelse> --->
						<cfset var thisdesc = "file_desc_#langindex#">
						<cfset var thiskeywords = "file_keywords_#langindex#">
					<!--- </cfif> --->
				</cfif>
				<cfset var l = langindex>
				<cfif thisdesc CONTAINS l OR thiskeywords CONTAINS l>
					<cfloop list="#arguments.thestruct.file_id#" delimiters="," index="f">
						<!--- Query excisting --->
						<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="ishere">
						SELECT file_id_r, file_desc, file_keywords
						FROM #arguments.thestruct.razuna.session.hostdbprefix#files_desc
						WHERE file_id_r = <cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">
						AND lang_id_r = <cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">
						AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
						</cfquery>
						<cfif ishere.recordcount NEQ 0>
							<cfset var tdesc = evaluate(thisdesc)>
							<cfset var tkeywords = evaluate(thiskeywords)>
							<!--- If the first character is a comma remove it --->
							<cfset var _first = left(tkeywords, 1)>
							<cfif _first EQ ",">
								<cfset var _len = len(tkeywords)>
								<cfset var _len_new = _len - 1>
								<cfset tkeywords = mid(tkeywords, 2, _len_new)>
							</cfif>
							<!--- If users chooses to append values --->
							<cfif !arguments.thestruct.batch_replace>
								<cfif ishere.file_desc NEQ "">
									<cfset tdesc = ishere.file_desc & " " & tdesc>
								</cfif>
								<cfif ishere.file_keywords NEQ "">
									<cfset tkeywords = ishere.file_keywords & "," & tkeywords>
								</cfif>
							</cfif>
							<!--- De-duplicate the list --->
							<cfset tkeywords = ListRemoveduplicates(tkeywords, ",")>
							<!--- Update DB --->
							<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
							UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files_desc
							SET
							file_desc = <cfqueryparam value="#ltrim(tdesc)#" cfsqltype="cf_sql_varchar">,
							file_keywords = <cfqueryparam value="#ltrim(tkeywords)#" cfsqltype="cf_sql_varchar">
							WHERE file_id_r = <cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">
							AND lang_id_r = <cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">
							AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
							</cfquery>
						<cfelse>
							<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
							INSERT INTO #arguments.thestruct.razuna.session.hostdbprefix#files_desc
							(id_inc, file_id_r, lang_id_r, file_desc, file_keywords, host_id)
							VALUES(
							<cfqueryparam value="#createuuid()#" cfsqltype="CF_SQL_VARCHAR">,
							<cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">,
							<cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">,
							<cfqueryparam value="#ltrim(evaluate(thisdesc))#" cfsqltype="cf_sql_varchar">,
							<cfqueryparam value="#ltrim(evaluate(thiskeywords))#" cfsqltype="cf_sql_varchar">,
							<cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
							)
							</cfquery>
						</cfif>
					</cfloop>
				</cfif>
			</cfloop>

			<cfif isdefined("arguments.thestruct.expiry_date")>
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
					UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files
					SET
					<cfif expiry_date EQ '00/00/0000'>
					expiry_date = null
					<cfelseif isdate(arguments.thestruct.expiry_date)>
						expiry_date= <cfqueryparam value="#arguments.thestruct.expiry_date#" cfsqltype="cf_sql_date">
					<cfelse>
						expiry_date = expiry_date
					</cfif>
					WHERE file_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
					<!--- Filter out renditions --->
					AND file_id  NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#renlist#" list="true">)
				</cfquery>
			</cfif>

			<!--- Only if not from batch function --->
			<cfif arguments.thestruct.frombatch NEQ "T">
				<!--- If PDF save XMP data --->
				<cfif isdefined("arguments.thestruct.file_extension") AND arguments.thestruct.file_extension EQ "pdf" AND arguments.thestruct.link_kind NEQ "url">
					<!--- Check if info is in DB --->
					<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qryfilesxmp">
					SELECT asset_id_r
					FROM #arguments.thestruct.razuna.session.hostdbprefix#files_xmp
					WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
					</cfquery>
					<!--- If record is here do a update else a insert --->
					<cfif qryfilesxmp.recordcount EQ 1>
						<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
						UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files_xmp
						SET
						author = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.author#">,
						rights = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.rights#">,
						authorsposition = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.authorsposition#">,
						captionwriter = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.captionwriter#">,
						webstatement = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.webstatement#">,
						rightsmarked = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.rightsmarked#">
						WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
						AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
						<!--- Filter out renditions --->
						AND asset_id_r NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#renlist#" list="true">)
						</cfquery>
					<cfelse>
						<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
						INSERT INTO #arguments.thestruct.razuna.session.hostdbprefix#files_xmp
						(asset_id_r, author, rights, authorsposition, captionwriter, webstatement, rightsmarked, host_id)
						VALUES(
							<cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">,
							<cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.author#">,
							<cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.rights#">,
							<cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.AuthorsPosition#">,
							<cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.CaptionWriter#">,
							<cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.WebStatement#">,
							<cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.rightsmarked#">,
							<cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
						)
						</cfquery>
					</cfif>
				</cfif>
				<!--- Save to the files table --->
				<cfif structkeyexists(arguments.thestruct,"fname") AND arguments.thestruct.frombatch NEQ "T">
					<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
					UPDATE #arguments.thestruct.razuna.session.hostdbprefix#additional_versions
					SET
					av_link_title = <cfqueryparam value="#arguments.thestruct.fname#" cfsqltype="cf_sql_varchar">
					WHERE av_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
					AND av_id  NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#renlist#" list="true">)
					</cfquery>
					<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
					UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files
					SET
					file_name = <cfqueryparam value="#arguments.thestruct.fname#" cfsqltype="cf_sql_varchar">,
					<cfif isdefined("arguments.thestruct.file_upc")>
						file_upc_number = <cfqueryparam value="#arguments.thestruct.file_upc#" cfsqltype="cf_sql_varchar">,
					</cfif>
					shared = <cfqueryparam value="#arguments.thestruct.shared#" cfsqltype="cf_sql_varchar">
					<!--- <cfif isdefined("remarks")>, file_remarks = <cfqueryparam value="#remarks#" cfsqltype="cf_sql_varchar"></cfif> --->
					WHERE file_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
					<!--- Filter out renditions --->
					AND file_id  NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="#renlist#" list="true">)
					</cfquery>
				</cfif>
			</cfif>
			<!--- Set for indexing --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
			UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files
			SET
			is_indexed = <cfqueryparam cfsqltype="cf_sql_varchar" value="0">
			WHERE file_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>
			<!--- Update main record with dates --->
			<cfinvoke component="global" method="update_dates" type="doc" fileid="#arguments.thestruct.file_id#" thestruct="#arguments.thestruct#" />
			<!--- Query --->
			<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qryfileupdate">
			SELECT file_name_org, file_name, path_to_asset, folder_id_r
			FROM #arguments.thestruct.razuna.session.hostdbprefix#files
			WHERE file_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>
			<cfif qryfileupdate.recordcount neq 0>
				<!--- Select the record to get the original filename or assign if one is there --->
				<cfif NOT structkeyexists(arguments.thestruct,"filenameorg") OR arguments.thestruct.filenameorg EQ "">
					<cfset arguments.thestruct.qrydetail.filenameorg = qryfileupdate.file_name_org>
					<cfset arguments.thestruct.filenameorg = qryfileupdate.file_name_org>
					<cfset arguments.thestruct.file_name = qryfileupdate.file_name>
				<cfelse>
					<cfset arguments.thestruct.qrydetail.filenameorg = arguments.thestruct.filenameorg>
				</cfif>
				<!--- Log --->
				<cfinvoke component="defaults" method="trans" transid="updated" returnvariable="updated" />
				<cfset log_assets(theuserid=arguments.thestruct.razuna.session.theuserid,logaction='Update',logdesc='#updated#: #qryfileupdate.file_name#',logfiletype='doc',assetid='#arguments.thestruct.file_id#',folderid='#arguments.thestruct.folder_id#', hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<cfelse>
				<!--- If updating additional version then get info and log change--->
				<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qryaddver">
				SELECT av_link_title, folder_id_r, asset_id_r
				FROM #arguments.thestruct.razuna.session.hostdbprefix#additional_versions
				WHERE av_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				</cfquery>
				<cfif qryaddver.recordcount neq 0>
					<cfinvoke component="defaults" method="trans" transid="updated" returnvariable="updated" />
					<cfinvoke component="defaults" method="trans" transid="additional_rendition" returnvariable="additional_rendition" />
					<cfset log_assets(theuserid=arguments.thestruct.razuna.session.theuserid,logaction='Update',logdesc='#updated# #additional_rendition#: #qryaddver.av_link_title#',logfiletype='img',assetid='#qryaddver.asset_id_r#',folderid='#qryaddver.folder_id_r#', hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
				</cfif>
			</cfif>

			<!--- Execute workflow --->
			<cfset arguments.thestruct.fileid = arguments.thestruct.file_id>
			<cfset arguments.thestruct.file_name = qryfileupdate.file_name>
			<cfset arguments.thestruct.thefiletype = "doc">
			<cfset arguments.thestruct.folder_id = qryfileupdate.folder_id_r>
			<cfset arguments.thestruct.folder_action = false>
			<cfinvoke component="plugins" method="getactions" theaction="on_file_edit" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
			<cfset arguments.thestruct.folder_action = true>
			<cfinvoke component="plugins" method="getactions" theaction="on_file_edit" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />

		</cfloop>
		<!--- Flush Cache --->
		<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="folders", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="search", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="labels", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
	</cffunction>

	<!--- SERVE THE FILE TO THE BROWSER --->
	<cffunction name="servefile" output="true">
		<cfargument name="thestruct" type="struct">
		<!--- Params --->
		<cfparam name="arguments.thestruct.zipit" default="T">
		<cfparam name="arguments.thestruct.v" default="o">
		<cfparam name="arguments.thestruct.av" default="false">
		<cfset var qry = structnew()>
		<cfset qry.thefilename = "">
		<cfset qry.av = false>
		<!--- RAZ-2906 : Get the dam settings --->
		<cfinvoke component="global.cfc.settings"  method="getsettingsfromdam" returnvariable="arguments.thestruct.getsettings" thestruct="#arguments.thestruct#" />
		<!--- If this is for additional renditions --->
		<cfif arguments.thestruct.av>
			<!--- Query version --->
			<cfquery name="qFile" datasource="#arguments.thestruct.razuna.application.datasource#">
			SELECT av_link_url AS path_to_asset, av_link_url AS cloud_url, av_link_url AS cloud_url_org,
			'' AS link_kind, av_link_title AS filenameorg, av_link_title AS thefilename, thesize
			FROM #arguments.thestruct.razuna.session.hostdbprefix#additional_versions
			WHERE av_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
			</cfquery>
			<!--- Set filename --->
			<cfset qry.thefilename = qFile.thefilename>
			<!--- Correct download URL --->
			<cfif qFile.path_to_asset DOES NOT CONTAIN "http" OR qFile.path_to_asset DOES NOT CONTAIN "https">
				<cfset qry.theurl = "#arguments.thestruct.razuna.session.thehttp##cgi.http_host#/#arguments.thestruct.dynpath#/assets/#arguments.thestruct.razuna.session.hostid##qFile.path_to_asset#">
			<cfelse>
				<cfset qry.theurl = qFile.cloud_url_org>
			</cfif>
			<!--- Set av value --->
			<cfset qry.av = true>
		<cfelse>
			<!--- Images --->
			<cfif arguments.thestruct.type EQ "img">
				<cfquery name="qFile" datasource="#arguments.thestruct.razuna.application.datasource#">
				SELECT  img_id, img_filename, img_extension as extension,
				thumb_extension, img_filename_org filenameorg, folder_id_r, link_kind, link_path_url, path_to_asset,
				cloud_url, cloud_url_org, img_size as thesize, CASE WHEN NOT(i.img_group ='' OR i.img_group is null) THEN (SELECT expiry_date FROM #arguments.thestruct.razuna.session.hostdbprefix#images WHERE img_id = i.img_group) ELSE expiry_date END expiry_date_actual
				FROM #arguments.thestruct.razuna.session.hostdbprefix#images i
				WHERE img_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				</cfquery>
				<!--- RAZ-2906: Check the settings for download assets with ext or not  --->
				<cfset var name = qFile.img_filename>
				<cfset var orgname = listfirst(qFile.filenameorg,".")>
				<cfif structKeyExists(arguments.thestruct.getsettings,"set2_custom_file_ext") AND arguments.thestruct.getsettings.set2_custom_file_ext EQ "false">
					<cfif name EQ orgname>
						<cfset var thumbnailname = "thumb_" & qfile.img_id >
						<cfset var originalfilename = qFile.img_filename >
					<cfelse>
						<cfset var thumbnailname = "thumb_" & qfile.img_id & "." & qfile.thumb_extension >
						<cfset var originalfilename = qFile.img_filename >
					</cfif>
				<cfelse>
					<cfif arguments.thestruct.v EQ "o">
						<cfset var originalfilename =  replacenocase(qFile.img_filename, ".#qFile.extension#","","ALL")& "." & qfile.extension>
					<cfelse>
						<cfset var thumbnailname = "thumb_" & qfile.img_id & "." & qfile.thumb_extension>
					</cfif>
				</cfif>
				<!--- Correct filename for thumbnail or original --->
				<cfif arguments.thestruct.v EQ "o">
					<cfset qry.thefilename =  originalfilename>
					<cfset qry.dlname =  qFile.filenameorg>
				<cfelse>
					<cfset qry.thefilename = thumbnailname>
					<cfset qry.dlname =  thumbnailname>
				</cfif>
			<!--- Videos --->
			<cfelseif arguments.thestruct.type EQ "vid">
				<cfquery name="qFile" datasource="#arguments.thestruct.razuna.application.datasource#">
				SELECT vid_filename, vid_extension as extension, vid_name_org filenameorg,
				folder_id_r, link_kind, link_path_url, path_to_asset, cloud_url, cloud_url_org, vid_size as thesize, CASE WHEN NOT(v.vid_group ='' OR v.vid_group is null) THEN (SELECT expiry_date FROM #arguments.thestruct.razuna.session.hostdbprefix#videos WHERE vid_id = v.vid_group) ELSE expiry_date END expiry_date_actual
				FROM #arguments.thestruct.razuna.session.hostdbprefix#videos v
				WHERE vid_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				</cfquery>
				<!--- RAZ-2906: Check the settings for download assets with ext or not  --->
				<cfset var name = qFile.vid_filename>
				<cfset var orgname = listfirst(qFile.filenameorg,".")>
				<cfif structKeyExists(arguments.thestruct.getsettings,"set2_custom_file_ext") AND arguments.thestruct.getsettings.set2_custom_file_ext EQ "false">
					<cfif name EQ orgname>
						<cfset var originalfilename = qFile.vid_filename >
					<cfelse>
						<cfset var originalfilename = qFile.vid_filename >
					</cfif>
				<cfelse>
					<cfset originalfilename =  replacenocase(qFile.vid_filename, ".#qFile.extension#","","ALL") & "." & qfile.extension>
				</cfif>
				<!--- Correct filename --->
				<cfset qry.thefilename =  originalfilename >
				<cfset qry.dlname =  qFile.filenameorg>
			<!--- Audios --->
			<cfelseif arguments.thestruct.type EQ "aud">
				<cfquery name="qFile" datasource="#arguments.thestruct.razuna.application.datasource#">
				SELECT  aud_name, aud_extension as extension, aud_name_org filenameorg,
				folder_id_r, link_kind, link_path_url, path_to_asset, cloud_url, cloud_url_org, aud_size as thesize, CASE WHEN NOT(a.aud_group ='' OR a.aud_group is null) THEN (SELECT expiry_date FROM #arguments.thestruct.razuna.session.hostdbprefix#audios WHERE aud_id = a.aud_group) ELSE expiry_date END expiry_date_actual
				FROM #arguments.thestruct.razuna.session.hostdbprefix#audios a
				WHERE aud_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				</cfquery>
				<!--- RAZ-2906: Check the settings for download assets with ext or not  --->
				<cfset var name = qFile.aud_name>
				<cfset var orgname = listfirst(qFile.filenameorg,".")>
				<cfif structKeyExists(arguments.thestruct.getsettings,"set2_custom_file_ext") AND arguments.thestruct.getsettings.set2_custom_file_ext EQ "false">
					<cfif name EQ orgname>
						<cfset var originalfilename = qFile.aud_name >
					<cfelse>
						<cfset var originalfilename = qFile.aud_name >
					</cfif>
				<cfelse>
					<cfset var originalfilename =  replacenocase(qFile.aud_name, ".#qFile.extension#","","ALL") & "." & qfile.extension>
				</cfif>
				<!--- Correct filename --->
				<cfset qry.thefilename = originalfilename >
				<cfset qry.dlname =  qFile.filenameorg>
			<!--- Documents --->
			<cfelse>
				<cfquery name="qFile" datasource="#arguments.thestruct.razuna.application.datasource#">
				SELECT file_name, file_extension as extension, file_name_org filenameorg,
				folder_id_r, link_path_url, link_kind, link_path_url, path_to_asset, cloud_url, cloud_url_org,
				file_size as thesize, expiry_date expiry_date_actual
				FROM #arguments.thestruct.razuna.session.hostdbprefix#files f
				WHERE file_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				</cfquery>
				<!--- RAZ-2906: Check the settings for download assets with ext or not  --->
				<cfset var name = qFile.file_name>
				<cfset var orgname = listfirst(qFile.filenameorg,".")>
				<cfif structKeyExists(arguments.thestruct.getsettings,"set2_custom_file_ext") AND arguments.thestruct.getsettings.set2_custom_file_ext EQ "false">
					<cfif name EQ orgname>
						<cfset var originalfilename = qFile.file_name >
					<cfelse>
						<cfset var originalfilename = qFile.file_name >
					</cfif>
				<cfelse>
					<cfset var originalfilename =  replacenocase(qFile.file_name, ".#qFile.extension#","","ALL") & "." & qfile.extension>
				</cfif>
				<!--- Correct filename --->
				<cfset qry.thefilename =  originalfilename >
				<cfset qry.dlname =  qFile.filenameorg>
			</cfif>
			<!--- Create the URL --->
			<cfif arguments.thestruct.razuna.application.storage EQ "local">
				<cfset qry.theurl = "#arguments.thestruct.razuna.session.thehttp##cgi.http_host#/#arguments.thestruct.dynpath#/assets/#arguments.thestruct.razuna.session.hostid#/#qFile.path_to_asset#/#qry.dlname#">
			<cfelse>
				<cfset qry.theurl = qFile.cloud_url_org>
			</cfif>
		</cfif>
		<!--- If name contains spaces then convert them to _ or else an incorrect name is being shown during download --->
		<cfset qry.thefilename = replacenocase(qry.thefilename," ","_","all")>
		<!--- Set variables --->
		<!--- <cfset qry.direct = "T"> --->
		<cfset qry.qFile = qFile>
		<cfreturn qry>
	</cffunction>

	<!--- WRITE FILE TO SYSTEM --->
	<cffunction name="writefile" output="true">
		<cfargument name="thestruct" type="struct">
		<cfparam name="arguments.thestruct.sendaszip" default="F">
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- Create an Outgoing folder if it doesn't exists --->
		<cfif !directoryExists("#arguments.thestruct.thepath#/outgoing/")>
			<cfdirectory action="create" directory="#arguments.thestruct.thepath#/outgoing/" mode="775">
		</cfif>
		<!--- The tool paths --->
		<cfinvoke component="settings" method="get_tools" thestruct="#arguments.thestruct#" returnVariable="arguments.thestruct.thetools" />
		<!--- Go grab the platform --->
		<cfinvoke component="assets" method="iswindows" returnvariable="arguments.thestruct.iswindows">
		<!--- Query --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="getbin" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#writefilefile */ file_extension, folder_id_r, file_name_org, link_kind, link_path_url, path_to_asset, cloud_url_org
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files
		WHERE file_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<!--- Rename --->
		<!--- If filename contains /\ --->
		<cfset var newname = replace(arguments.thestruct.zipname,"/","-","all")>
		<cfset newname = replace(newname,"\","-","all")>
		<cfset newname = replacenocase(newname, " ", "_", "All")>
		<cfset newname = replacenocase(newname, ".#getbin.file_extension#", "", "ALL")>
		<cfset newnamenoext = newname>
		<cfset newname = "#newname#" & ".#getbin.file_extension#">
		<!--- Put variables into struct for threads --->
		<cfset arguments.thestruct.getbin = getbin>
		<cfset arguments.thestruct.newname = newname>
		<!--- Decide which path to zip --->
		<cfif arguments.thestruct.razuna.application.storage EQ "local" AND getbin.link_kind EQ "">
			<!--- Copy file to the outgoing folder --->
			<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
				<cffile action="copy" source="#attributes.intstruct.assetpath#/#attributes.intstruct.razuna.session.hostid#/#attributes.intstruct.getbin.path_to_asset#/#attributes.intstruct.getbin.file_name_org#" destination="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.newname#" mode="775">
			</cfthread>
		<!--- Nirvanix --->
		<cfelseif arguments.thestruct.razuna.application.storage EQ "nirvanix" AND getbin.link_kind EQ "">
			<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
				<cfhttp url="#attributes.intstruct.getbin.cloud_url_org#" file="#attributes.intstruct.getbin.file_name_org#" path="#attributes.intstruct.thepath#/outgoing"></cfhttp>
			</cfthread>
		<!--- Amazon --->
		<cfelseif arguments.thestruct.razuna.application.storage EQ "amazon" AND getbin.link_kind EQ "">
			<!--- Download file --->
			<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
				<cfinvoke component="amazon" method="Download">
					<cfinvokeargument name="key" value="/#attributes.intstruct.getbin.path_to_asset#/#attributes.intstruct.getbin.file_name_org#">
					<cfinvokeargument name="theasset" value="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.getbin.file_name_org#">
					<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
					<cfinvokeargument name="thestruct" value="#attributes.intstruct#">
				</cfinvoke>
				<!--- Rename the file --->
				<cffile action="rename" source="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.getbin.file_name_org#" destination="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.newname#" >
			</cfthread>
		<!--- Akamai --->
		<cfelseif arguments.thestruct.razuna.application.storage EQ "akamai" AND getbin.link_kind EQ "">
			<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
				<cfhttp url="#attributes.intstruct.akaurl##attributes.intstruct.akadoc#/#attributes.intstruct.getbin.file_name_org#" file="#attributes.intstruct.getbin.file_name_org#" path="#attributes.intstruct.thepath#/outgoing"></cfhttp>
			</cfthread>
		<!--- If this is a linked asset --->
		<cfelseif getbin.link_kind EQ "lan">
			<!--- Copy file to the outgoing folder --->
			<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
				<cffile action="copy" source="#attributes.intstruct.getbin.link_path_url#" destination="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.newname#" mode="775">
			</cfthread>
		</cfif>
		<!--- Check that the zip name contains no spaces --->
		<cfset var zipname = replace(arguments.thestruct.zipname,"/","-","all")>
		<cfset zipname = replace(zipname,"\","-","all")>
		<cfset zipname = replace(zipname, " ", "_", "All")>
		<!--- Wait for the thread above until the file is downloaded fully --->
		<cfthread action="join" name="download#arguments.thestruct.file_id#" />
		<!--- Remove any file with the same name in this directory. Wrap in a cftry so if the file does not exist we don't have a error --->
		<cftry>
			<!--- Remove the Zip file of the (.doc, .pdf, .xls etc)file formats other than (.zip) file format --->
			<cfif getbin.file_extension NEQ 'zip'>
				<cffile action="delete" file="#arguments.thestruct.thepath#/outgoing/#newnamenoext#.zip">
			</cfif>
			<cfcatch type="any"></cfcatch>
		</cftry>
		<cfif structKeyExists(arguments.thestruct.razuna.session,"createzip") AND arguments.thestruct.razuna.session.createzip EQ 'no'>
			<!--- Delete if any folder exists in same name and create the new directory --->
			<cfif directoryExists("#arguments.thestruct.thepath#/outgoing/#zipname#")>
				<cfdirectory action="delete" directory="#arguments.thestruct.thepath#/outgoing/#zipname#" recurse="true">
			</cfif>
			<cfdirectory action="create" directory="#arguments.thestruct.thepath#/outgoing/#zipname#">
			<cffile action="move" destination="#arguments.thestruct.thepath#/outgoing/#zipname#" source="#arguments.thestruct.thepath#/outgoing/#newname#" >
		<cfelse>
			<cfif listLast(arguments.thestruct.newname,'.') NEQ "zip">
				<!--- Zip the file --->
				<cfzip action="create" ZIPFILE="#arguments.thestruct.thepath#/outgoing/#newnamenoext#.zip" source="#arguments.thestruct.thepath#/outgoing/#newname#" recurse="true" timeout="300" />
				<!--- Remove the file --->
				<cffile action="delete" file="#arguments.thestruct.thepath#/outgoing/#newname#">
			</cfif>
		</cfif>
		<cfif structKeyExists(arguments.thestruct.razuna.session,"createzip") AND arguments.thestruct.razuna.session.createzip EQ 'no'>
			<cfset var newname="#newnamenoext#">
		<cfelse>
			<cfset var newname="#newnamenoext#.zip">
		</cfif>
		<!--- Return --->
		<cfreturn newname>
	</cffunction>

	<!--- MOVE FILE IN THREADS --->
	<cffunction name="movethread" output="true">
		<cfargument name="thestruct" type="struct">
		<!--- Loop over files --->
		<cfthread intstruct="#arguments.thestruct#">
			<!--- If this is from search the file_id should be all --->
			<cfif attributes.intstruct.file_id EQ "all">
				<!--- As we have all get all IDS from this search --->
				<cfinvoke component="search" method="getAllIdsMain" thestruct="#arguments.thestruct#" searchupc="#attributes.intstruct.razuna.session.search.searchupc#" searchtext="#attributes.intstruct.razuna.session.search.searchtext#" searchtype="doc" searchrenditions="#attributes.intstruct.razuna.session.search.searchrenditions#" searchfolderid="#attributes.intstruct.razuna.session.search.searchfolderid#" hostid="#attributes.intstruct.razuna.session.hostid#" returnvariable="ids">
					<!--- Set the fileid --->
					<cfset attributes.intstruct.file_id = ids>
			</cfif>

			<cfloop list="#attributes.intstruct.file_id#" delimiters="," index="fileid">
				<cfset attributes.intstruct.doc_id = "">
				<cfset attributes.intstruct.doc_id = listfirst(fileid,"-")>
				<cfif attributes.intstruct.doc_id NEQ "">
					<cfinvoke method="move" thestruct="#attributes.intstruct#" />
				</cfif>
			</cfloop>
		</cfthread>
		<!--- Flush Cache --->
		<cfset resetcachetoken(type="folders", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
	</cffunction>

	<!--- MOVE FILE --->
	<cffunction name="move" output="false">
		<cfargument name="thestruct" type="struct">
			<cfset arguments.thestruct.qrydoc = "">
			<!--- Get file details --->
			<cfinvoke method="filedetail" theid="#arguments.thestruct.doc_id#" thecolumn="file_name, folder_id_r, file_name_org filenameorg, lucene_key, link_kind, path_to_asset" returnvariable="arguments.thestruct.qrydoc" thestruct="#arguments.thestruct#">
			<!--- If no records found then return --->
			<cfif arguments.thestruct.qrydoc.recordcount EQ 0>
				<cfreturn>
			</cfif>
			<cfset var qry_alias="">
			<!--- Check if this is an alias --->
			<cfinvoke component="global" method="getAlias" asset_id_r="#arguments.thestruct.doc_id#" folder_id_r="#arguments.thestruct.razuna.session.thefolderorg#" thestruct="#arguments.thestruct#" returnvariable="qry_alias"/>
			<!--- If this is an alias --->
			<cfif qry_alias>
				<!--- Move alias --->
				<cfinvoke component="global" method="moveAlias" asset_id_r="#arguments.thestruct.doc_id#" new_folder_id_r="#arguments.thestruct.folder_id#" pre_folder_id_r="#arguments.thestruct.razuna.session.thefolderorg#" thestruct="#arguments.thestruct#" />
			<cfelse>
				<!--- Ignore if the folder id is the same --->
				<cfif arguments.thestruct.qrydoc.recordcount NEQ 0 AND arguments.thestruct.folder_id NEQ arguments.thestruct.qrydoc.folder_id_r>
					<!--- Update DB --->
					<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
					UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files
					SET
					folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">,
					in_trash = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="F">,
					is_indexed = <cfqueryparam cfsqltype="cf_sql_varchar" value="0">
					WHERE file_id = <cfqueryparam value="#arguments.thestruct.doc_id#" cfsqltype="CF_SQL_VARCHAR">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
					</cfquery>
					<!--- <cfthread intstruct="#arguments.thestruct#"> --->
						<!--- Update Dates --->
						<cfinvoke component="global" method="update_dates" type="doc" fileid="#arguments.thestruct.doc_id#" thestruct="#arguments.thestruct#" />
						<!--- Execute workflow --->
						<cfset arguments.thestruct.fileid = arguments.thestruct.doc_id>
						<cfset arguments.thestruct.file_name = arguments.thestruct.qrydoc.file_name>
						<cfset arguments.thestruct.thefiletype = "doc">
						<cfset arguments.thestruct.folder_id = arguments.thestruct.folder_id>
						<cfset arguments.thestruct.folder_action = false>
						<cfinvoke component="plugins" method="getactions" theaction="on_file_move" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
						<cfset arguments.thestruct.folder_action = true>
						<cfinvoke component="plugins" method="getactions" theaction="on_file_move" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
						<cfinvoke component="plugins" method="getactions" theaction="on_file_add" args="#arguments.thestruct#" thestruct="#arguments.thestruct#" />
					<!--- </cfthread> --->
					<!--- Delete any aliases of the file in the folder if present --->
					<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
					DELETE  FROM ct_aliases
					WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.doc_id#" cfsqltype="CF_SQL_VARCHAR">
					AND folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
					</cfquery>
					<!--- Log --->
					<cfinvoke component="defaults" method="trans" transid="moved" returnvariable="moved" />
					<cfset log_assets(theuserid=arguments.thestruct.razuna.session.theuserid,logaction='Move',logdesc='#moved#: #arguments.thestruct.qrydoc.file_name#',logfiletype='doc',assetid=arguments.thestruct.doc_id,folderid='#arguments.thestruct.folder_id#', hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
				</cfif>
			</cfif>
			<!--- Flush Cache --->
			<cfset resetcachetoken(type="folders", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
			<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfreturn />
	</cffunction>

	<!--- List the PDF image files to be shown to the browser --->
	<cffunction name="pdfjpgs" output="true">
		<cfargument name="thestruct" type="struct">
		<cfset var lqry = structnew()>
		<cfset lqry.thepdfjpgslist = "">
		<cfset var qry_thefile = "">
		<!--- Get some file details --->
		<cfinvoke method="filedetail" theid="#arguments.thestruct.file_id#" thecolumn="folder_id_r, path_to_asset" returnvariable="qry_thefile" thestruct="#arguments.thestruct#">
		<!--- Local --->
		<cfif arguments.thestruct.razuna.application.storage EQ "local">
			<!--- Get the directory list --->
			<cfdirectory action="list" directory="#arguments.thestruct.assetpath#/#arguments.thestruct.razuna.session.hostid#/#qry_thefile.path_to_asset#/razuna_pdf_images/" name="lqry.qry_pdfjpgs" filter="*.jpg" sort="name">
			<cfset var numbr = ArrayNew(1)>

			<cfset var tmp = queryAddColumn(lqry.qry_pdfjpgs, "numbering","integer",numbr)>

			<cfloop query="lqry.qry_pdfjpgs">
				<cfset tmp = querySetCell(lqry.qry_pdfjpgs, "numbering", replacenocase(listlast(name,'-'),'.jpg','' ,'ALL'), currentrow)>
			</cfloop>
			<!--- Order by page numbering --->
			<cfquery name="lqry.qry_pdfjpgs" dbtype="query">
				SELECT * FROM lqry.qry_pdfjpgs ORDER BY numbering ASC
			</cfquery>
			<cfset lqry.thepdfjpgslist = valuelist(lqry.qry_pdfjpgs.name)>
		</cfif>
		<!--- Return --->
		<cfreturn lqry>
	</cffunction>

	<cffunction name="genpdfjpgs"  returntype="void" >
		<cfargument name="path2pdf" required="true" >
		<cfargument name="path2jpgs" required="true" >
		<cfargument name="thestruct" type="struct" required="true" />
		<cfinvoke component="settings" method="get_tools" thestruct="#arguments.thestruct#" returnVariable="thetools" />
		<cfset var gettemp = GetTempDirectory()>
	 	<cfset var ttpdf = Createuuid("")>
		<cfset var theorgfile = arguments.path2pdf>
	 	<cfset var thepdfimage = replacenocase(listlast(theorgfile,"/"),".pdf",".jpg","all")>
	 	<cfif FindNoCase("Windows", server.os.name)>
			<cfset theimconvert = """#thetools.imagemagick#/convert.exe""">
			<cfset args.thesht = "#gettemp#/#ttpdf#t.bat">
			<cfset theorgfile = theorgfile>
		<cfelse>
			<cfset theimconvert = "#thetools.imagemagick#/convert">
			<!--- Set non windows scripts --->
			<cfset args.thesht = "#gettemp#/#ttpdf#t.sh">
			<cfset theorgfile = replace(theorgfile," ","\ ","all")>
			<cfset theorgfile = replace(theorgfile,"&","\&","all")>
			<cfset theorgfile = replace(theorgfile,"'","\'","all")>
		</cfif>
	 	<cfset var thejpgdirectory = arguments.path2jpgs>
		<!--- Write out script file--->
		<cffile action="write" file="#args.thesht#" output="#theimconvert# #theorgfile# #thejpgdirectory#/#thepdfimage#" mode="777">
		<!--- Execute script file in thread--->
		<cfthread name="#ttpdf#" action="run" pdfintstruct="#args#">
			<cfexecute name="#attributes.pdfintstruct.thesht#" timeout="900" />
		</cfthread>
		<!--- Wait for thread to finish --->
		<cfthread action="join" name="#ttpdf#" />
		<!--- Delete script file --->
		<cffile action="delete" file="#args.thesht#">
		<cfreturn>
	</cffunction>

	<!--- GET THE DETAILS FOR BASKET --->
	<cffunction name="detailforbasket" output="false">
		<cfargument name="thestruct" type="struct">
		<!--- Param --->
		<cfparam default="0" name="arguments.thestruct.razuna.session.thegroupofuser">
		<cfset var qry = "">
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- Qry. We take the query and do a IN --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qry" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#detailforbasketfile */ f.file_id, f.file_extension, f.file_extension, f.file_size, f.folder_id_r, f.file_name_org,
		f.link_kind, f.link_path_url, f.path_to_asset, f.cloud_url, f.file_name filename, f.file_name_org filename_org, fo.share_dl_org, fo.share_dl_thumb,
		'' as perm
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files f, #arguments.thestruct.razuna.session.hostdbprefix#folders fo
		WHERE f.folder_id_r = fo.folder_id AND
		f.file_id
		<cfif arguments.thestruct.qrybasket.recordcount EQ 0>
		= '0'
		<cfelse>
		IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ValueList(arguments.thestruct.qrybasket.cart_product_id)#" list="true">)
		</cfif>
		</cfquery>
		<!--- Get proper folderaccess --->
		<cfif arguments.thestruct.fa NEQ "c.basket" AND arguments.thestruct.fa NEQ "c.basket_put">
			<cfloop query="qry">
				<cfinvoke component="folders" method="setaccess" returnvariable="theaccess" thestruct="#arguments.thestruct#" folder_id="#folder_id_r#"  />
				<!--- Add labels query --->
				<cfif theaccess NEQ "">
					<cfset QuerySetCell(qry, "perm", theaccess, currentRow)>
				</cfif>
			</cfloop>
		</cfif>
		<cfreturn qry>
	</cffunction>

	<!--- Get description and keywords for print --->
	<cffunction name="gettext" output="false">
		<cfargument name="qry" type="query">
		<cfargument name="thestruct" type="struct" required="true" />
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- Get how many loop --->
		<cfset var howmanyloop = ceiling(arguments.qry.recordcount / 990)>
		<!--- Set outer loop --->
		<cfset var pos_start = 1>
		<cfset var pos_end = howmanyloop>
		<!--- Set inner loop --->
		<cfset var q_start = 1>
		<cfset var q_end = 990>
		<!--- Var --->
		<cfset var qryintern = "">
		<!--- Query --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qryintern" cachedwithin="1" region="razcache">
			<cfloop from="#pos_start#" to="#pos_end#" index="i">
				<cfif q_start NEQ 1>
					UNION ALL
				</cfif>
				SELECT /* #cachetoken#gettextfile */ file_id_r tid, file_desc description, file_keywords keywords
				FROM #arguments.thestruct.razuna.session.hostdbprefix#files_desc
				WHERE file_id_r IN ('0'<cfloop query="arguments.qry" startrow="#q_start#" endrow="#q_end#">,'#id#'</cfloop>)
				AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				<cfset q_start = q_end + 1>
		    	<cfset q_end = q_end + 990>
		    </cfloop>
		</cfquery>
		<!--- Return --->
		<cfreturn qryintern>
	</cffunction>

	<!--- Get description and keywords for print --->
	<cffunction name="gettextforexport" output="false">
		<cfargument name="theid" type="string">
		<cfargument name="thestruct" type="struct" required="true" />
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- Var --->
		<cfset var qryintern = "">
		<!--- Query --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qryintern" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#gettextfile */ file_id_r tid, file_desc description, file_keywords keywords
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files_desc
		WHERE file_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.theid#">
		AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<!--- Return --->
		<cfreturn qryintern>
	</cffunction>

	<!--- Get rawmetadata --->
	<cffunction name="getrawmetadata" output="false">
		<cfargument name="qry" type="query">
		<cfargument name="thestruct" type="struct" required="true" />
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- Get how many loop --->
		<cfset var howmanyloop = ceiling(arguments.qry.recordcount / 990)>
		<!--- Set outer loop --->
		<cfset var pos_start = 1>
		<cfset var pos_end = howmanyloop>
		<!--- Set inner loop --->
		<cfset var q_start = 1>
		<cfset var q_end = 990>
		<!--- Query --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qryintern" cachedwithin="1" region="razcache">
			<cfloop from="#pos_start#" to="#pos_end#" index="i">
				<cfif q_start NEQ 1>
					UNION ALL
				</cfif>
				SELECT /* #cachetoken#gettextrm */ file_meta rawmetadata
				FROM #arguments.thestruct.razuna.session.hostdbprefix#files
				WHERE file_id IN ('0'<cfloop query="arguments.qry" startrow="#q_start#" endrow="#q_end#">,'#id#'</cfloop>)
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
				<cfset q_start = q_end + 1>
		    	<cfset q_end = q_end + 990>
		    </cfloop>
		</cfquery>
		<!--- Return --->
		<cfreturn qryintern>
	</cffunction>

	<!--- GET RECORDS WITH EMTPY VALUES --->
	<cffunction name="getempty" output="false">
		<cfargument name="thestruct" type="struct">
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset var qry = "">
		<!--- Query --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qry" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#getemptyfile */
		file_id id, file_name, folder_id_r, path_to_asset, cloud_url, cloud_url_org, link_kind, link_path_url,
		path_to_asset, lucene_key, file_name_org filenameorg
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files
		WHERE (folder_id_r IS NULL OR folder_id_r = '')
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<!--- Return --->
		<cfreturn qry>
	</cffunction>

	<!--- GET PDF XMP --->
	<cffunction name="getpdfxmp" output="false">
		<cfargument name="thestruct" type="struct">
		<cfargument name="checkinfolder" type="string" required="false" default = "" >
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<!--- Query --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="pdfxmp" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#getpdfxmp */ asset_id_r AS id_r, author, rights, authorsposition, captionwriter, webstatement, rightsmarked
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files_xmp
		WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<!--- Return --->
		<cfreturn pdfxmp>
	</cffunction>

	<!--- Check for existing MD5 mash records --->
	<cffunction name="checkmd5" output="false">
		<cfargument name="md5hash" type="string">
		<cfargument name="thestruct" type="struct" required="true" />
		<!--- Get the cachetoken for here --->
		<cfset var cachetoken = getcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
		<cfset var qry = "">
		<!--- Query --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qry" cachedwithin="1" region="razcache">
		SELECT /* #cachetoken#checkmd5 */ hashtag
		FROM #arguments.thestruct.razuna.session.hostdbprefix#files
		WHERE hashtag = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.md5hash#">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		AND in_trash = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="F">
		<cfif arguments.checkinfolder NEQ "">
			AND folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.checkinfolder#">
		</cfif>
		</cfquery>
		<cfreturn qry />
	</cffunction>

	<!--- Update all copy Metadata --->
	<cffunction name="copymetadataupdate" output="false">
		<cfargument name="thestruct" type="struct">
		<!--- select file detail --->
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="thefiletext">
			SELECT file_desc,file_keywords, lang_id_r
			FROM #arguments.thestruct.razuna.session.hostdbprefix#files_desc
			WHERE file_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.file_id#">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<cfif arguments.thestruct.insert_type EQ 'replace'>
			<cfloop list="#arguments.thestruct.idlist#" index="i">
				<cfloop query="thefiletext">
					<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="checkid">
						SELECT file_id_r
						FROM #arguments.thestruct.razuna.session.hostdbprefix#files_desc
						WHERE file_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#i#">
						AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
						AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="#thefiletext.lang_id_r#">
					</cfquery>
					<cfif checkid.RecordCount>
						<!--- update file detail --->
						<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="updatefiletext">
							UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files_desc
							SET file_desc = <cfqueryparam cfsqltype="cf_sql_varchar" value="#thefiletext.file_desc#">,
							file_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="#thefiletext.file_keywords#">
							WHERE file_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#i#">
							AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
							AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="#thefiletext.lang_id_r#">
						</cfquery>
					<cfelse>
						<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
							INSERT INTO #arguments.thestruct.razuna.session.hostdbprefix#files_desc
							(id_inc, file_id_r, file_desc, file_keywords, host_id, lang_id_r)
							VALUES(
							<cfqueryparam value="#createuuid()#" cfsqltype="CF_SQL_VARCHAR">,
							<cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">,
							<cfqueryparam value="#thefiletext.file_desc#" cfsqltype="cf_sql_varchar">,
							<cfqueryparam value="#thefiletext.file_keywords#" cfsqltype="cf_sql_varchar">,
							<cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">,
							<cfqueryparam cfsqltype="cf_sql_numeric" value="#thefiletext.lang_id_r#">
							)
						</cfquery>
					</cfif>
				</cfloop>
			</cfloop>
		<cfelse>
			<cfloop list="#arguments.thestruct.idlist#" index="i">
				<cfloop query="thefiletext">
					<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="thefiletextdetail">
						SELECT file_desc,file_keywords
						FROM #arguments.thestruct.razuna.session.hostdbprefix#files_desc
						WHERE file_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#i#">
						AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
						AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="#thefiletext.lang_id_r#">
					</cfquery>
					<cfif thefiletextdetail.RecordCount>
						<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="updatefiletext">
							UPDATE #arguments.thestruct.razuna.session.hostdbprefix#files_desc
							SET file_desc = <cfqueryparam cfsqltype="cf_sql_varchar" value="#thefiletextdetail.file_desc# #thefiletext.file_desc#">,
							file_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="#thefiletextdetail.file_keywords# #thefiletext.file_keywords#">
							WHERE file_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#i#">
							AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
							AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="#thefiletext.lang_id_r#">
						</cfquery>
					<cfelse>
						<cfquery datasource="#arguments.thestruct.razuna.application.datasource#">
							INSERT INTO #arguments.thestruct.razuna.session.hostdbprefix#files_desc
							(id_inc, file_id_r, file_desc, file_keywords, host_id, lang_id_r)
							VALUES(
							<cfqueryparam value="#createuuid()#" cfsqltype="CF_SQL_VARCHAR">,
							<cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">,
							<cfqueryparam value="#thefiletext.file_desc#" cfsqltype="cf_sql_varchar">,
							<cfqueryparam value="#thefiletext.file_keywords#" cfsqltype="cf_sql_varchar">,
							<cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">,
							<cfqueryparam cfsqltype="cf_sql_numeric" value="#thefiletext.lang_id_r#">
							)
						</cfquery>
					</cfif>
				</cfloop>
			</cfloop>
		</cfif>
		<cfset resetcachetoken(type="files", hostid=arguments.thestruct.razuna.session.hostid, thestruct=arguments.thestruct)>
	</cffunction>

	<!--- Get all asset from folder --->
	<cffunction name="getAllFolderAsset" output="false">
		<cfargument name="thestruct" type="struct">
		<cfquery datasource="#arguments.thestruct.razuna.application.datasource#" name="qry_data">
			SELECT file_id AS id,file_name AS filename
			FROM #arguments.thestruct.razuna.session.hostdbprefix#files
			WHERE folder_id_r = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.folder_id#">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.razuna.session.hostid#">
		</cfquery>
		<cfreturn qry_data>
	</cffunction>

	<!--- Create renditions --->
	<cffunction name="createRenditions" output="true" access="public">
		<cfargument name="thestruct" type="struct">
		<!--- <cfset consoleoutput(true, true)>
		<cfset console(arguments.thestruct)> --->

		<cfparam name="arguments.thestruct.convert_img" default="">
		<cfparam name="arguments.thestruct.convert_vid" default="">
		<cfparam name="arguments.thestruct.convert_aud" default="">
		<cfparam name="arguments.thestruct.renditions_on_the_fly" default="true">
		<cfparam name="arguments.thestruct.renditions_on_the_fly_id" default="#createuuid()#">
		<cfparam name="arguments.thestruct.renditions_on_the_fly_folder" default="#arguments.thestruct.thepath#/incoming/#arguments.thestruct.renditions_on_the_fly_id#">

		<!--- Create folder for ZIP --->
		<!--- Create the temp folder in the incoming dir --->
		<cfdirectory action="create" directory="#arguments.thestruct.renditions_on_the_fly_folder#" mode="775">

		<!--- Feedback --->
		<cfoutput><h2>Creating your renditions now</h2><br></cfoutput>
		<cfflush>

		<!--- Current date for query of log --->
		<cfset var _date_now = now()>

		<!--- Images --->
		<cfif ListContains(arguments.thestruct.razuna.session.file_id, '-img', ',')>
			<!--- Feedback --->
			<cfoutput><h3>Doing images</h3></cfoutput>
			<cfflush>
			<!--- Loop over the file_ids --->
			<cfloop list="#arguments.thestruct.razuna.session.file_id#" delimiters="," index="id">
				<!--- Feedback --->
				<cfoutput>.</cfoutput>
				<cfflush>
				<cfif listlast(id,"-") == 'img'>
					<!--- Store file_id --->
					<cfset arguments.thestruct.file_id = listfirst(id,"-")>
					<!--- Check if we have a upload template --->
					<cfif arguments.thestruct.template_img NEQ "0">
						<cfset arguments.thestruct.upl_template = arguments.thestruct.template_img>
						<!--- Query template formats --->
						<cfinvoke component="global.cfc.global" method="upl_template_detail" upl_temp_id="#arguments.thestruct.upl_template#" upl_temp_type="img" only_first_format="true" returnvariable="qry_template" thestruct="#arguments.thestruct#">
						<!--- We just need the format --->
						<cfset arguments.thestruct.convert_to = valuelist(qry_template.uplval.upl_temp_value)>
					<cfelse>
						<!--- To field --->
						<cfset arguments.thestruct.convert_to = arguments.thestruct.convert_img>
					</cfif>
					<!--- Call function to convert --->
					<cfset var _t_name = "rend_#arguments.thestruct.file_id#">
					<cfthread name="#_t_name#" intstruct="#arguments.thestruct#">
						<cfinvoke component="global.cfc.images" method="convertImagethread" thestruct="#attributes.intstruct#" returnvariable="the_rendition">
					</cfthread>
					<!--- Join --->
					<cfthread action="join" name="#_t_name#" />
					<!--- Here we should query the logs --->
					<cfinvoke component="global.cfc.log" method="getLogSpecific" file_id="#arguments.thestruct.file_id#" timestamp="#_date_now#" log_action="convert" fields="log_desc" returnvariable="qry_log" thestruct="#arguments.thestruct#">
					<!--- <cfdump var="#qry_log#"> --->
					<!--- Loop over log result and print --->
					<cfloop query="qry_log">
						<!--- Feedback --->
						<cfset _color = ! FindNocase('error', log_desc) ? 'green' : 'red'>
						<!--- <cfset _color = 'green'> --->
						<cfoutput><br><span style="color:#_color#">#log_desc#</span><br></cfoutput>
						<cfflush>
					</cfloop>
				</cfif>
			</cfloop>

		<!--- Videos --->
		<cfelseif ListContains(arguments.thestruct.razuna.session.file_id, '-vid', ',') AND arguments.thestruct.convert_vid NEQ "">
			<!--- Feedback --->
			<cfoutput><h3>Doing videos</h3></cfoutput>
			<cfflush>
			<!--- Loop over the file_ids --->
			<cfloop list="#arguments.thestruct.razuna.session.file_id#" delimiters="," index="id">
				<!--- Feedback --->
				<cfoutput>.</cfoutput>
				<cfflush>
				<cfif listlast(id,"-") == 'vid'>
					<!--- Store file_id --->
					<cfset arguments.thestruct.file_id = listfirst(id,"-")>
					<!--- Check if we have a upload template --->
					<cfif arguments.thestruct.template_vid NEQ "0">
						<cfset arguments.thestruct.upl_template = arguments.thestruct.template_vid>
						<!--- Query template formats --->
						<cfinvoke component="global.cfc.global" method="upl_template_detail" upl_temp_id="#arguments.thestruct.upl_template#" upl_temp_type="vid" only_first_format="true" returnvariable="qry_template" thestruct="#arguments.thestruct#">
						<!--- We just need the format --->
						<cfset arguments.thestruct.convert_to = valuelist(qry_template.uplval.upl_temp_value)>
						<cfset console(arguments.thestruct.convert_to)>
					<cfelse>
						<!--- To field --->
						<cfset arguments.thestruct.convert_to = arguments.thestruct.convert_vid>
					</cfif>
					<!--- Call function to convert --->
					<!--- Call function to convert --->
					<cfset var _t_name = "rend_#arguments.thestruct.file_id#">
					<cfthread name="#_t_name#" intstruct="#arguments.thestruct#">
						<cfinvoke component="global.cfc.videos" method="convertvideo" thestruct="#attributes.intstruct#" returnvariable="the_rendition">
					</cfthread>
					<!--- Join --->
					<cfthread action="join" name="#_t_name#" />
					<!--- Here we should query the logs --->
					<cfinvoke component="global.cfc.log" method="getLogSpecific" file_id="#arguments.thestruct.file_id#" timestamp="#_date_now#" log_action="convert" fields="log_desc" returnvariable="qry_log" thestruct="#arguments.thestruct#">
					<!--- <cfdump var="#qry_log#"> --->
					<!--- Loop over log result and print --->
					<cfloop query="qry_log">
						<!--- Feedback --->
						<cfset _color = ! FindNocase('error', log_desc) ? 'green' : 'red'>
						<!--- <cfset _color = 'green'> --->
						<cfoutput><br><span style="color:#_color#">#log_desc#</span><br></cfoutput>
						<cfflush>
					</cfloop>
				</cfif>
			</cfloop>

		<!--- Audios --->
		<cfelseif ListContains(arguments.thestruct.razuna.session.file_id, '-aud', ',') AND arguments.thestruct.convert_aud NEQ "">
			<!--- Feedback --->
			<cfoutput><h3>Doing audios</h3></cfoutput>
			<cfflush>
			<!--- Loop over the file_ids --->
			<cfloop list="#arguments.thestruct.razuna.session.file_id#" delimiters="," index="id">
				<!--- Feedback --->
				<cfoutput>.</cfoutput>
				<cfflush>
				<cfif listlast(id,"-") == 'aud'>
					<!--- Store file_id --->
					<cfset arguments.thestruct.file_id = listfirst(id,"-")>
					<!--- Check if we have a upload template --->
					<cfif arguments.thestruct.template_aud NEQ "0">
						<cfset arguments.thestruct.upl_template = arguments.thestruct.template_aud>
						<!--- Query template formats --->
						<cfinvoke component="global.cfc.global" method="upl_template_detail" upl_temp_id="#arguments.thestruct.upl_template#" upl_temp_type="aud" only_first_format="true" returnvariable="qry_template" thestruct="#arguments.thestruct#">
						<!--- We just need the format --->
						<cfset arguments.thestruct.convert_to = valuelist(qry_template.uplval.upl_temp_value)>
					<cfelse>
						<!--- To field --->
						<cfset arguments.thestruct.convert_to = arguments.thestruct.convert_aud>
					</cfif>
					<!--- Call function to convert --->
					<cfset var _t_name = "rend_#arguments.thestruct.file_id#">
					<cfthread name="#_t_name#" intstruct="#arguments.thestruct#">
						<cfinvoke component="global.cfc.audios" method="convertaudiothread" thestruct="#attributes.intstruct#" returnvariable="the_rendition">
					</cfthread>
					<!--- Join --->
					<cfthread action="join" name="#_t_name#" />
					<!--- Here we should query the logs --->
					<cfinvoke component="global.cfc.log" method="getLogSpecific" file_id="#arguments.thestruct.file_id#" timestamp="#_date_now#" log_action="convert" fields="log_desc" returnvariable="qry_log" thestruct="#arguments.thestruct#">
					<!--- <cfdump var="#qry_log#"> --->
					<!--- Loop over log result and print --->
					<cfloop query="qry_log">
						<!--- Feedback --->
						<cfset _color = ! FindNocase('error', log_desc) ? 'green' : 'red'>
						<!--- <cfset _color = 'green'> --->
						<cfoutput><br><span style="color:#_color#">#log_desc#</span><br></cfoutput>
						<cfflush>
					</cfloop>
				</cfif>
			</cfloop>

		</cfif>

		<!--- Feedback --->
		<cfif arguments.thestruct.convert_img EQ "" AND arguments.thestruct.convert_vid EQ "" AND arguments.thestruct.convert_aud EQ "" AND arguments.thestruct.template_img EQ "0" AND arguments.thestruct.template_vid EQ "0" AND arguments.thestruct.template_aud EQ "0">
			<cfoutput><h2 style="color:red;">I did not receive any formats to convert!</h2><br></cfoutput>
			<cfflush>
		<cfelse>

			<!--- Create a ZIP for downloading --->
			<cfoutput><h3>Creating a ZIP for downloading...</h3></cfoutput>
			<cfflush>

			<cfset var _date = DateTimeFormat( now(), "YMMdd-hhmmss" )>
			<cfset arguments.thestruct.zipname = "Omnipix_#_date#.zip">

			<!--- Zip the folder --->
			<cfthread name="#arguments.thestruct.renditions_on_the_fly_id#" intstruct="#arguments.thestruct#">
				<cfzip action="create" ZIPFILE="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.zipname#" source="#attributes.intstruct.renditions_on_the_fly_folder#" recurse="true" timeout="300" />
			</cfthread>
			<!--- Get thread status --->
			<cfset var thethread=cfthread["#arguments.thestruct.renditions_on_the_fly_id#"]>
			<!--- Output to page to prevent it from timing out while thread is running --->
			<cfloop condition="#thethread.status# EQ 'RUNNING' OR thethread.Status EQ 'NOT_STARTED' "> <!--- Wait till thread is finished --->
				<cfoutput> . </cfoutput>
				<cfset sleep(3000)>
				<cfflush>
			</cfloop>
			<cfthread action="join" name="#arguments.thestruct.renditions_on_the_fly_id#" />
			<!--- Remove the temp folder --->
			<cfdirectory action="delete" directory="#arguments.thestruct.renditions_on_the_fly_folder#" recurse="yes">
			<cfset var sn = replacenocase(cgi.script_name,"/index.cfm","","one")>
			<!--- Output --->
			<cfoutput><h2 style="color:green;">Renditions are <a href="#arguments.thestruct.razuna.session.thehttp##cgi.HTTP_HOST##sn#/outgoing/#arguments.thestruct.zipname#" style="color:green;">now ready for download</a></h2></cfoutput>
			<cfflush>
		</cfif>

		<cfreturn true>
	</cffunction>

</cfcomponent>