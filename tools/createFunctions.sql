/***************************************************************************
Functions and init for the Postgres Versioning System
----------------------------------------------------------------------------
begin		: 2010-07-31
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch

		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
create schema versions;  


CREATE OR REPLACE FUNCTION versions._pgvscreateversiontable()
  RETURNS void AS
$BODY$    
  
  BEGIN
    execute 'CREATE TABLE versions.version_tables
           (
              version_table_id serial,
              version_table_schema character varying,
              version_table_name character varying,
              version_view_schema character varying,
              version_view_name character varying,
              version_view_pkey character varying,
              version_view_geometry_column character varying,
              CONSTRAINT version_table_pkey PRIMARY KEY (version_table_id)
            )';
    execute 'GRANT SELECT ON TABLE versions.version_tables TO public';

    EXCEPTION when others then
  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;  
  
  
CREATE OR REPLACE FUNCTION versions._pgvscreateconflicttype()
  RETURNS void AS
$BODY$    
  
  BEGIN
    execute 'create type versions.conflicts as (objectkey int, myproject text, mysystime bigint, project text, systime bigint)';
    EXCEPTION when others then
  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;  

CREATE OR REPLACE FUNCTION versions._pgvscreatelogviewtype()
  RETURNS void AS
$BODY$    
  
  BEGIN
    execute 'create type versions.logview as (revision integer, datum timestamp, project text, logmsg text)';
    EXCEPTION when others then
  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;    

CREATE OR REPLACE FUNCTION versions._pgvsdifftype()
  RETURNS void AS
$BODY$    
  
  BEGIN
    execute 'create type versions.diffrecord as (mykey int, action varchar, revision int, systime bigint, logmsg varchar)';
    EXCEPTION when others then
  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;      

  select versions._pgvscreateversiontable();
  select versions._pgvscreateconflicttype();
  select versions._pgvscreatelogviewtype();
  select versions._pgvscheckouttype();
  select versions._pgvsdifftype();


  
/***************************************************************************
Function to get the pgvs Version Number
----------------------------------------------------------------------------
begin		: 2010-11.13
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

CREATE OR REPLACE FUNCTION versions.pgvsrevision()
  RETURNS TEXT AS
$BODY$    
DECLARE
  revision TEXT;
  BEGIN	
    revision := '1.8.4';
  RETURN revision ;                             

  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;  
/***************************************************************************
Function to commit changes to the database
----------------------------------------------------------------------------
begin		: 2010-07-31
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
DROP FUNCTION IF EXISTS versions.pgvscommit(character varying, TEXT);
CREATE OR REPLACE FUNCTION versions.pgvscommit(character varying, TEXT) RETURNS setof versions.conflicts AS
$BODY$

  DECLARE
    inTable ALIAS FOR $1;
    logMessage ALIAS FOR $2;
    mySchema TEXT;
    myTable TEXT;
    myPkey TEXT;
    fields TEXT;
    insFields TEXT;
    message TEXT;
    myDebug TEXT;
    commitQuery TEXT;
    checkQuery TEXT;
    myPkeyRec record;
    attributes record;
    testRec record;
    conflict BOOLEAN;
    conflictCheck versions.conflicts%rowtype;
    pos integer;
    versionLogTable TEXT;
    revision integer;

  BEGIN	
    pos := strpos(inTable,'.');
    fields := '';
    insFields := '';
    conflict := False;
  
    if pos=0 then 
        mySchema := 'public';
  	    myTable := inTable; 
    else 
        mySchema := substr(inTable,0,pos);
        pos := pos + 1; 
        myTable := substr(inTable,pos);
    END IF;  
    
    versionLogTable := 'versions.'||mySchema||'_'||myTable||'_version_log';   

  -- Pruefen ob und welche Spalte der Primarykey der Tabelle ist 
    select into myPkeyRec col.column_name 
    from information_schema.table_constraints as key,
         information_schema.key_column_usage as col
    where key.table_schema = mySchema::name
      and key.table_name = myTable::name
      and key.constraint_type='PRIMARY KEY'
      and key.constraint_name = col.constraint_name
      and key.table_catalog = col.table_catalog
      and key.table_schema = col.table_schema
      and key.table_name = col.table_name;	
  
    IF FOUND THEN
       myPkey := myPkeyRec.column_name;
    else
        RAISE EXCEPTION 'Table % does not have Primarykey defined', mySchema||'.'||myTable;
    END IF;    
    
/*
Check for conflicts before committing. When conflicts are existing stop the commit process 
with a listing of the conflicting objects.
*/    

    message := '';
            
  myDebug := ' select a.'||myPkey||', myproject, mysystime, project, systime 
                         from ( 
                              select '||myPkey||', project as myproject, max(systime) as mysystime
                              from '||versionLogTable||'
                              where not commit 
                                and project = current_user
                              group by '||myPkey||', project
                             ) as a,
                             (
                              select '||myPkey||', project, systime 
                              from '||versionLogTable||'
                              where commit and project <> current_user
                             ) as b
                         where b.systime > a.mysystime
                             and a.'||myPkey||' = b.'||myPkey;

--RAISE EXCEPTION '%',myDebug;                                    
                                    
    for conflictCheck IN  EXECUTE myDebug
    LOOP

      return next conflictCheck;
      conflict := True;
      message := message||E'\n'||'WARNING! The object with '||myPkey||'='||conflictCheck.objectkey||' is also changed by user '||conflictCheck.project||'.';
    END LOOP;    
              
    message := message||E'\n\n';
    message := message||'Changes are not committed!'||E'\n\n';
    IF conflict THEN
       RAISE NOTICE '%', message;
    ELSE    
    
         execute 'create temp table tmp_tab as 
       select project
       from '||versionLogTable||'
       where not commit ';

         select into testRec project from tmp_tab;

        IF NOT FOUND THEN
          execute 'drop table tmp_tab';
          RETURN;
        ELSE  
          execute 'drop table tmp_tab';
          for attributes in select *
                                     from  information_schema.columns
                                     where table_schema=mySchema::name
                                          and table_name = myTable::name

              LOOP
                
                if attributes.column_name <> 'OID' 
                  and attributes.column_name <> 'versionarchive' 
                  and attributes.column_name <> 'new_date' 
                  and  attributes.column_name <> 'archive_date' 
                  and  attributes.column_name <> 'archive' then
                    fields := fields||',log."'||attributes.column_name||'"';
                    insFields := insFields||',"'||attributes.column_name||'"';
                END IF;
              END LOOP;    
            
              fields := substring(fields,2);
              insFields := substring(insFields,2);     
            
          revision := nextval(''||versionLogTable||'_seq');
         
          commitQuery := '
                delete from '||versionLogTable||'
                using (
                    select log.* from '||versionLogTable||' as log,
                       ( 
                    select '||myPkey||', max(systime) as systime
                    from '||versionLogTable||'
                    where not commit and project = current_user
                    group by '||myPkey||') as foo
                    where log.project = current_user
                      and foo.'||myPkey||' = log.'||myPkey||'
                      and foo.systime <> log.systime
                      and not commit) as foo
                where '||versionLogTable||'.'||myPkey||' = foo.'||myPkey||'
                  and '||versionLogTable||'.systime = foo.systime
                  and '||versionLogTable||'.project = foo.project; 
                  
                delete from '||inTable||' where '||myPkey||' in 
                   (select '||myPkey||'
                    from  '||versionLogTable||'
                             where not commit
                               and project = current_user
                             group by '||myPkey||', project);
   
                    insert into '||inTable||' ('||insFields||') 
                    select '||fields||' from '||versionLogTable||' as log,
                       (
                        select '||myPKey||', max(systime) as systime
                        from '||versionLogTable||'
                        where project = current_user
                          and not commit
                          and action <> ''delete''
                        group by '||myPKey||'
                       ) as foo
                    where log.'||myPkey||'= foo.'||myPkey||'
                      and log.systime = foo.systime
                      and log.action <> ''delete'';                    
                      
                    update '||versionLogTable||' set 
                         commit = True, 
                         revision = '||revision||', 
                         logmsg = '''||logMessage ||''',    
                         systime = ' || EXTRACT(EPOCH FROM now()::TIMESTAMP)*1000 || '
                    where not commit
                      and project = current_user;';

     execute 'INSERT INTO versions.version_tables_logmsg(
                version_table_id, revision, logmsg) 
              SELECT version_table_id, '||revision||', '''||logMessage||''' as logmsg FROM versions.version_tables where version_table_schema = '''||mySchema||''' and version_table_name = '''|| myTable||''''; 
                      
--RAISE EXCEPTION '%',commitQuery;
        execute commitQuery;              
     END IF;
  END IF;    

  RETURN;                             

  END;


$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;
/***************************************************************************
Function to initialize the pgvs-environment
table are still persisting of course.
----------------------------------------------------------------------------
begin		: 2010-07-31
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

CREATE OR REPLACE FUNCTION versions.pgvsinit(character varying)
  RETURNS boolean AS
$BODY$
  DECLARE
    inTable ALIAS FOR $1;
    pos INTEGER;
    mySchema TEXT;
    myTable TEXT;
    versionTable TEXT;
    versionView TEXT;
    versionLogTable TEXT;
    versionLogTableSeq TEXT;
    versionLogTableTmp TEXT;
    geomCol TEXT;
    geomType TEXT;
    geomDIM INTEGER;
    geomSRID INTEGER;
    attributes record;
    testRec record;
    testPKey record;
    fields TEXT;
    newFields TEXT;
    oldFields TEXT;
    updateFields TEXT;
    mySequence TEXT;
    myPkey TEXT;
    myPkeyRec record;
    testTab TEXT;
    archiveWhere TEXT;
    

  BEGIN	
    pos := strpos(inTable,'.');
    fields := '';
    newFields := '';
    oldFields := '';
    updateFields := '';
    geomCol := '';
    geomDIM := 2;
    geomSRID := -1;
    geomType := '';
    mySequence := '';
    archiveWhere := '';

    if pos=0 then 
        mySchema := 'public';
  	    myTable := inTable; 
    else 
        mySchema = substr(inTable,0,pos);
        pos := pos + 1; 
        myTable = substr(inTable,pos);
    END IF;  

    versionTable := mySchema||'.'||myTable||'_version_t';
    versionView := '"'||mySchema||'"."'||myTable||'_version"';
    versionLogTable := '"versions"."'||mySchema||'_'||myTable||'_version_log"';
    versionLogTableSeq := '"versions"."'||mySchema||'_'||myTable||'_version_log_seq"';
    versionLogTableTmp := '"versions"."'||mySchema||'_'||myTable||'_version_log_tmp"';

-- Feststellen ob die Tabelle oder der View existiert
     select into testRec table_name
     from information_schema.tables
     where table_schema = mySchema::name
          and table_name = myTable::name;

     IF NOT FOUND THEN
       select into testRec table_name
       from information_schema.views
       where table_schema = mySchema::name
            and table_name = myTable::name;     
       IF NOT FOUND THEN
         RAISE EXCEPTION 'Table %.% does not exist', mySchema,myTable;
         RETURN False;
       END IF;
     END IF;    
 
 
-- Die grundlegenden Geometrieparameter des Ausgangslayers ermitteln
     select into testRec f_geometry_column, coord_dimension, srid, type
     from geometry_columns
     where f_table_schema = mySchema::name
       and f_table_name = myTable::name;

     IF NOT FOUND THEN
       RAISE EXCEPTION 'Table %.% is not registered in geometry_columns', mySchema, myTable;
       RETURN False;
     END IF;

     geomCol := testRec.f_geometry_column;
     geomDIM := testRec.coord_dimension;
     geomSRID := testRec.srid;
     geomType := testRec.type;

     
-- Pruefen ob und welche Spalte der Primarykey der Tabelle old_layer ist 
    select into testPKey col.column_name 
    from information_schema.table_constraints as key,
         information_schema.key_column_usage as col
    where key.table_schema = mySchema::name
      and key.table_name = myTable::name
      and key.constraint_type='PRIMARY KEY'
      and key.constraint_name = col.constraint_name
      and key.table_catalog = col.table_catalog
      and key.table_schema = col.table_schema
      and key.table_name = col.table_name;	
  
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Table %.% has no Primarykey', mySchema, myTable;
        RETURN False;
    END IF;			
       
-- Feststellen ob die Tabelle bereits besteht
     testTab := '"versions"."'||myTable||'_version_log"';
     select into testRec table_name
     from information_schema.tables
     where table_schema = mySchema::name
          and table_name = testTab::name;

     IF FOUND THEN
       RAISE NOTICE 'Table %.% has been deleted', mySchema,testTab;
       execute 'drop table "'||mySchema||'"."'||testTab||'" cascade';
     END IF;    
  
-- Feststellen ob die Log-Tabelle bereits in geometry_columns registriert ist
     select into testRec f_table_name
     from geometry_columns
     where f_table_schema = mySchema::name
          and f_table_name = testTab::name;
          
     IF FOUND THEN
       execute 'delete from geometry_columns where f_table_schema='''||mySchema||''' and f_table_name='''||myTable||'_version_log''';
     END IF;    

-- Feststellen ob der View bereits in geometry_columns registriert ist
     testTab := '"'||mySchema||'"."'||myTable||'_version"';
     select into testRec f_table_name
     from geometry_columns
     where f_table_schema = mySchema::name
          and f_table_name = testTab::name;

     IF FOUND THEN
       execute 'delete from geometry_columns where f_table_schema='''||mySchema||''' and f_table_name='''||myTable||'_version''';
     END IF;    
     
     
  -- Pruefen ob und welche Spalte der Primarykey der Tabelle ist 
    select into myPkeyRec col.column_name 
    from information_schema.table_constraints as key,
         information_schema.key_column_usage as col
    where key.table_schema = mySchema::name
      and key.table_name = myTable::name
      and key.constraint_type='PRIMARY KEY'
      and key.constraint_name = col.constraint_name
      and key.table_catalog = col.table_catalog
      and key.table_schema = col.table_schema
      and key.table_name = col.table_name;	
  
    IF FOUND THEN
       myPkey := myPkeyRec.column_name;
    else
        RAISE EXCEPTION 'Table % has no Primarykey', mySchema||'.'||myTable;
        RETURN False;
    END IF;

    execute 'create table '||versionLogTable||' (LIKE "'||mySchema||'"."'||myTable||'");
             CREATE SEQUENCE '||versionLogTableSeq||' INCREMENT 1 START 1;
             GRANT ALL ON TABLE '||versionLogTable||' TO public;
             GRANT ALL ON TABLE '||versionLogTableSeq||' TO public;
             alter table '||versionLogTable||' add column action character varying;
             alter table '||versionLogTable||' add column project character varying default current_user;     
             alter table '||versionLogTable||' add column systime bigint default (EXTRACT(EPOCH FROM now()::TIMESTAMP)*1000);    
             alter table '||versionLogTable||' add column revision bigint;
             alter table '||versionLogTable||' add column logmsg text;        
             alter table '||versionLogTable||' add column commit boolean DEFAULT False;
             create index '||myTable||'_version_geo_idx on '||versionLogTable||' USING GIST ('||geomCol||');     
             create table '||versionLogTableTmp||' (LIKE '||versionLogTable||');
             alter table '||versionLogTableTmp||' alter project set default current_user;     
             alter table '||versionLogTableTmp||' alter systime set default (EXTRACT(EPOCH FROM now()::TIMESTAMP)*1000);    
             alter table '||versionLogTableTmp||' alter commit set DEFAULT False;
             insert into versions.version_tables (version_table_schema,version_table_name,version_view_schema,version_view_name,version_view_pkey,version_view_geometry_column) 
                 values('''||mySchema||''','''||myTable||''','''||mySchema||''','''||myTable||'_version'','''||testPKey.column_name||''','''||geomCol||''');
             insert into public.geometry_columns (f_table_catalog, f_table_schema,f_table_name,f_geometry_column,coord_dimension,srid,type)
                 values ('''',''versions'','''||myTable||'_version_log'','''||geomCol||''','||geomDIM||','||geomSRID||','''||geomTYPE||''');
             insert into public.geometry_columns (f_table_catalog, f_table_schema,f_table_name,f_geometry_column,coord_dimension,srid,type)
               values ('''','''||mySchema||''','''||myTable||'_version'','''||geomCol||''','||geomDIM||','||geomSRID||','''||geomTYPE||''');';
    
    for attributes in select *
                               from  information_schema.columns
                               where table_schema=mySchema::name
                                    and table_name = myTable::name

        LOOP
          
          if attributes.column_default LIKE 'nextval%' then
             execute 'alter table '||versionLogTable||' alter column '||attributes.column_name||' drop not null';
             mySequence := attributes.column_default;
          ELSE
            if myPkey <> attributes.column_name then
              fields := fields||',"'||attributes.column_name||'"';
              newFields := newFields||',new."'||attributes.column_name||'"';
              oldFields := oldFields||',old."'||attributes.column_name||'"';
              updateFields := updateFields||',"'||attributes.column_name||'"=new."'||attributes.column_name||'"';
            END IF;
          END IF;
          IF attributes.column_name = 'archive' THEN
            archiveWhere := 'and archive=0';           
          END IF;  
        END LOOP;

-- Das erste Komma  aus dem String entfernen
        fields := substring(fields,2);
        newFields := substring(newFields,2);
        oldFields := substring(oldFields,2);
        updateFields := substring(updateFields,2);
        
        IF length(mySequence)=0 THEN
          RAISE EXCEPTION 'No Sequence defined for Table %.%', mySchema,myTable;
          RETURN False;
        END IF;

     execute 'alter table '||versionLogTable||' add constraint '||myTable||'_pkey primary key ('||myPkey||',project,systime,action) ';  

     execute 'create or replace view '||versionView||' as 
             select * from (
               select '||myPkey||','||fields||' from "'||mySchema||'"."'||myTable||'" where '||myPkey||' not in (select '||myPkey||' from '||versionLogTable||' where project = current_user and not commit) '||archiveWhere||' 
               union 
               select '||myPkey||','||fields||' from '||versionLogTable||' where project = current_user and action <> ''delete'' and systime||''-''||'||myPkey||' in (
                  select max(systime||''-''||'||myPkey||') 
                  from '||versionLogTable||' 
                  where project=current_user 
                    and not commit
                    group by '||myPkey||')
             )as foo;
             GRANT ALL ON TABLE '||versionView||' TO public;';
            
             
    execute 'CREATE OR REPLACE RULE delete AS
                ON DELETE TO '||versionView||' DO INSTEAD  
                INSERT INTO '||versionLogTable||' ('||myPkey||','||fields||',action) VALUES (old.'||myPkey||','||oldFields||',''delete'')';                

       
    execute 'CREATE OR REPLACE RULE insert AS
                ON INSERT TO '||versionView||' DO INSTEAD  
                INSERT INTO '||versionLogTable||' ('||myPkey||','||fields||',action) VALUES ('||mySequence||','||newFields||',''insert'')';
          
     execute 'CREATE OR REPLACE RULE update AS
                ON UPDATE TO '||versionView||' DO INSTEAD  
                (INSERT INTO '||versionLogTableTmp||' ('||myPkey||','||fields||',action) VALUES (old.'||myPkey||','||oldFields||',''delete'');               
                 INSERT INTO '||versionLogTableTmp||' ('||myPkey||','||fields||',action) VALUES (old.'||myPkey||','||newFields||',''insert'');
                 insert into '||versionLogTable||'('||myPkey||','||fields||',action) select '||myPkey||','||fields||',action from '||versionLogTableTmp||';
                 delete from '||versionLogTableTmp||')';         

     execute 'INSERT INTO versions.version_tables_logmsg(
                version_table_id, revision, logmsg) 
              SELECT version_table_id, 1 as revision, ''initial commit revision 1'' as logmsg FROM versions.version_tables where version_table_schema = '''||mySchema||''' and version_table_name = '''|| myTable||''''; 
                
  RETURN true ;                             

  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;

/***************************************************************************
Function to check conflicts
----------------------------------------------------------------------------
begin		: 2010-09-07
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
DROP FUNCTION IF EXISTS versions.pgvscheck(character varying);
CREATE OR REPLACE FUNCTION versions.pgvscheck(character varying) RETURNS setof versions.conflicts AS
$BODY$

  DECLARE
    inTable ALIAS FOR $1;
    mySchema TEXT;
    myTable TEXT;
    myPkey TEXT;
    message TEXT;
    myDebug TEXT;
    myPkeyRec record;
    conflict BOOLEAN;
    conflictCheck versions.conflicts%rowtype;
    pos integer;
    versionLogTable TEXT;

  BEGIN	
    pos := strpos(inTable,'.');
    conflict := False;
  
    if pos=0 then 
        mySchema := 'public';
  	    myTable := inTable; 
    else 
        mySchema := substr(inTable,0,pos);
        pos := pos + 1; 
        myTable := substr(inTable,pos);
    END IF;  
    
    versionLogTable := 'versions.'||mySchema||'_'||myTable||'_version_log';   

  -- Pruefen ob und welche Spalte der Primarykey der Tabelle ist 
    select into myPkeyRec col.column_name 
    from information_schema.table_constraints as key,
         information_schema.key_column_usage as col
    where key.table_schema = mySchema::name
      and key.table_name = myTable::name
      and key.constraint_type='PRIMARY KEY'
      and key.constraint_name = col.constraint_name
      and key.table_catalog = col.table_catalog
      and key.table_schema = col.table_schema
      and key.table_name = col.table_name;	
  
    IF FOUND THEN
       myPkey := myPkeyRec.column_name;
    else
        RAISE EXCEPTION 'Table % does not have Primarykey defined', mySchema||'.'||myTable;
    END IF;    
    
/*
Check for conflicts before committing. When conflicts are existing stop the commit process 
with a listing of the conflicting objects.
*/    

    message := '';
            
  myDebug := ' select a.'||myPkey||', myproject, mysystime, project, systime 
                         from ( 
                              select '||myPkey||', project as myproject, max(systime) as mysystime
                              from '||versionLogTable||'
                              where not commit 
                                and project = current_user
                              group by '||myPkey||', project
                             ) as a,
                             (
                              select '||myPkey||', project, max(systime) as systime 
                              from '||versionLogTable||'
                              where commit and project <> current_user
                              group by '||myPkey||', project
                             ) as b
                         where b.systime > a.mysystime
                             and a.'||myPkey||' = b.'||myPkey;

--RAISE EXCEPTION '%',myDebug;                                    
                                    
    for conflictCheck IN  EXECUTE myDebug
    LOOP

      return next conflictCheck;
      conflict := True;
      message := message||E'\n'||'WARNING! The object with '||myPkey||'='||conflictCheck.objectkey||' is also changed by user '||conflictCheck.project||'.';
    END LOOP;    
              
    message := message||E'\n\n';
    message := message||'Changes are not committed!'||E'\n\n';
    IF conflict THEN
       RAISE NOTICE '%', message;
    ELSE    
       return;    
  END IF;    

  END;


$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;

/**************************************************************************
Function to resolve conflicts between objects
----------------------------------------------------------------------------
begin		: 2010-08-17
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
CREATE OR REPLACE FUNCTION versions.pgvsmerge("inTable" character varying, "targetGid" integer, "targetProject" character varying)
  RETURNS boolean AS
$BODY$  DECLARE
    inTable ALIAS FOR $1;
    targetGid ALIAS FOR $2;
    targetProject ALIAS FOR $3;
    mySchema TEXT;
    myTable TEXT;
    myPkey TEXT;
    myDebug TEXT;
    myPkeyRec record;
    conflict BOOLEAN;
    conflictCheck record;
    pos integer;
    versionLogTable TEXT;

  BEGIN	
    pos := strpos(inTable,'.');
    conflict := False;
  
    if pos=0 then 
        mySchema := 'public';
  	    myTable := inTable; 
    else 
        mySchema := substr(inTable,0,pos);
        pos := pos + 1; 
        myTable := substr(inTable,pos);
    END IF;  
    
    versionLogTable := 'versions.'||mySchema||'_'||myTable||'_version_log';   

  -- Pruefen ob und welche Spalte der Primarykey der Tabelle ist 
    select into myPkeyRec col.column_name 
    from information_schema.table_constraints as key,
         information_schema.key_column_usage as col
    where key.table_schema = mySchema::name
      and key.table_name = myTable::name
      and key.constraint_type='PRIMARY KEY'
      and key.constraint_name = col.constraint_name
      and key.table_catalog = col.table_catalog
      and key.table_schema = col.table_schema
      and key.table_name = col.table_name;	
  
    IF FOUND THEN
       myPkey := myPkeyRec.column_name;
    else
        RAISE EXCEPTION 'Table % does not have Primarykey defined', mySchema||'.'||myTable;
        RETURN False;
    END IF;    
        

        
myDebug := 'select a.'||myPkey||' as objectkey, b.systime, b.project as myuser
                                  from '||versionLogTable||' as a,
                                       (
                                         select '||myPkey||', systime, project
                                         from '||versionLogTable||'
                                         where commit
                                           and project <> '''||targetProject||''') as b
                                  where not commit
                                    and a.systime < b.systime
                                    and a.'||myPkey||' = b.'||myPkey||'
                                    and a.'||myPkey||' = '||targetGid||'
                                  union
                                  select '||myPkey||',systime, project
                                  from '||versionLogTable||' as a
                                  where not commit 
                                    and project <> '''||targetProject||'''
                                    and '||myPkey||' = '||targetGid||''; 
                                                                 
-- RAISE EXCEPTION '%',myDebug;    
    
    for conflictCheck IN EXECUTE myDebug
    LOOP
       RAISE NOTICE '%  %',conflictCheck.objectkey,conflictCheck.systime;

      myDebug := 'delete from '||versionLogTable||' 
                     where '||myPkey||' = '||conflictCheck.objectkey||' 
                        and project = '''||conflictCheck.myuser||'''
                        and systime = '||conflictCheck.systime||' ';
-- RAISE EXCEPTION '%', myDebug;                        
      execute myDebug;
                      
    END LOOP; 
  
  RETURN True;
  
  END;$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;
/***************************************************************************
Function to drop an existing pgvs environment. The data from the main 
table are still persisting of course.
----------------------------------------------------------------------------
begin		: 2010-07-31
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

CREATE OR REPLACE FUNCTION versions.pgvsdrop(character varying)
  RETURNS boolean AS
$BODY$
  DECLARE
    inTable ALIAS FOR $1;
    pos INTEGER;
    mySchema TEXT;
    myTable TEXT;
    versionTableRec record;
    versionTable TEXT;
    versionView TEXT;
    versionLogTable TEXT;
    geomCol TEXT;
    geomType TEXT;
    geomDIM INTEGER;
    geomSRID INTEGER;
    testRec record;
    testTab TEXT;
    

  BEGIN	
    pos := strpos(inTable,'.');
    geomCol := '';
    geomDIM := 2;
    geomSRID := -1;
    geomType := '';

    if pos=0 then 
        mySchema := 'public';
  	    myTable := inTable; 
    else 
        mySchema = substr(inTable,0,pos);
        pos := pos + 1; 
        myTable = substr(inTable,pos);
    END IF;  

    versionView := mySchema||'.'||myTable||'_version';
    versionLogTable := 'versions.'||mySchema||'_'||myTable||'_version_log';

-- Feststellen ob die Tabelle existiert
     select into testRec table_name
     from information_schema.tables
     where table_schema = mySchema::name
          and table_name = myTable::name;

     IF NOT FOUND THEN
       RAISE EXCEPTION 'Table %.% does not exist', mySchema,myTable;
       RETURN False;
     END IF;    
     
-- Feststellen ob die Log-Tabelle existiert
     testTab := mySchema||'_'||myTable||'_version_log';
     
     select into testRec table_name
     from information_schema.tables
     where table_schema = 'versions'
          and table_name = testTab::name;

     IF NOT FOUND THEN
       RAISE EXCEPTION 'Log Table %.% does not exist', mySchema,myTable;
       RETURN False;
     END IF;        
 
     
-- Die grundlegenden Geometrieparameter des Ausgangslayers ermitteln
     select into testRec f_geometry_column, coord_dimension, srid, type
     from geometry_columns
     where f_table_schema = mySchema::name
       and f_table_name = myTable::name;

     geomCol := testRec.f_geometry_column;
     geomDIM := testRec.coord_dimension;
     geomSRID := testRec.srid;
     geomType := testRec.type;
     
     execute 'create temp table tmp_tab as 
       select project
       from '||versionLogTable||'
       where not commit ';

     select into testRec project
     from tmp_tab;

     IF FOUND THEN
       RAISE EXCEPTION 'Uncommitted Records are existing. Please commit all changes before use pgvsdrop()';
       RETURN False;
     END IF;  

     select into versionTableRec version_table_id as vtid
     from versions.version_tables as vt
     where version_table_schema = mySchema::name
       and version_table_name = myTable::name;

     

    execute 'DROP SEQUENCE if exists '||versionLogTable||'_seq';
    execute 'drop table if exists '||versionLogTable||' cascade;';
    execute 'drop table if exists '||versionLogTable||'_tmp cascade;';
    
    execute 'delete from versions.version_tables 
               where version_table_id = '''||versionTableRec.vtid||''';';

    execute 'delete from versions.version_tables_logmsg 
               where version_table_id = '''||versionTableRec.vtid||''';';


    execute 'delete from public.geometry_columns 
              where f_table_schema = ''versions''
                and f_table_name = '''||myTable||'_version_log''
                and f_geometry_column = '''||geomCol||'''
                and coord_dimension = '||geomDIM||'
                and srid = '||geomSRID||'
                and type = '''||geomTYPE||''';';
                
    execute 'delete from public.geometry_columns 
               where f_table_schema = '''||mySchema||'''
                 and f_table_name = '''||myTable||'_version''
                 and f_geometry_column = '''||geomCol||'''
                 and coord_dimension = '||geomDIM||'
                 and srid = '||geomSRID||'
                 and type = '''||geomTYPE||''';';

  RETURN true ;                             

  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;  
/***************************************************************************
Function to reverse all current editings to the users last commit.
----------------------------------------------------------------------------
begin		: 2010-11.13
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
DROP FUNCTION IF EXISTS versions.pgvsreverse(character varying);
CREATE OR REPLACE FUNCTION versions.pgvsrevert(character varying)
  RETURNS INTEGER AS
$BODY$
  DECLARE
    inTable ALIAS FOR $1;
    pos INTEGER;
    mySchema TEXT;
    myTable TEXT;
    versionTable TEXT;
    versionView TEXT;
    versionLogTable TEXT;
    geomCol TEXT;
    geomType TEXT;
    geomDIM INTEGER;
    geomSRID INTEGER;
    revision INTEGER;
    testRec record;
    testTab TEXT;
    

  BEGIN	
    pos := strpos(inTable,'.');
    geomCol := '';
    geomDIM := 2;
    geomSRID := -1;
    geomType := '';

    if pos=0 then 
        mySchema := 'public';
  	    myTable := inTable; 
    else 
        mySchema = substr(inTable,0,pos);
        pos := pos + 1; 
        myTable = substr(inTable,pos);
    END IF;  

    versionView := mySchema||'.'||myTable||'_version';
    versionLogTable := 'versions.'||mySchema||'_'||myTable||'_version_log';

-- Feststellen ob die Tabelle existiert
     select into testRec table_name
     from information_schema.tables
     where table_schema = mySchema::name
          and table_name = myTable::name;

     IF NOT FOUND THEN
       RAISE EXCEPTION 'Table %.% does not exist', mySchema,myTable;
       RETURN False;
     END IF;    
     
-- Feststellen ob die Log-Tabelle existiert
     testTab := mySchema||'_'||myTable||'_version_log';
     
     select into testRec table_name
     from information_schema.tables
     where table_schema = 'versions'
          and table_name = testTab::name;

     IF NOT FOUND THEN
       RAISE EXCEPTION 'Log Table %.% does not exist', mySchema,myTable;
       RETURN False;
     END IF;        
 
     execute 'select max(revision) from '||versionLogTable into revision;
     
     execute 'delete from '||versionLogTable||' 
                    where project = current_user
                      and not commit';
                    
  RETURN revision ;                             

  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;  
/***************************************************************************
Function shows an overview over all logs
----------------------------------------------------------------------------
begin		: 2011-07-20
copyright	: (C) 2010 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

CREATE OR REPLACE FUNCTION versions.pgvslogview(character varying) RETURNS setof versions.logview AS
$BODY$    
  DECLARE
    inTable ALIAS FOR $1;
    mySchema TEXT;
    myTable TEXT;
    logViewQry TEXT;
    versionLogTable TEXT;
    pos integer;
    logs versions.logview%rowtype;


  BEGIN	
    pos := strpos(inTable,'.');
  
    if pos=0 then 
        mySchema := 'public';
  	    myTable := inTable; 
    else 
        mySchema := substr(inTable,0,pos);
        pos := pos + 1; 
        myTable := substr(inTable,pos);
    END IF;  
    
    versionLogTable := 'versions.'||mySchema||'_'||myTable||'_version_log';       

    logViewQry := 'select logt.revision, to_timestamp(logt.systime/1000), logt.project,  logt.logmsg
                           from  versions.version_tables as vt, versions.version_tables_logmsg as logt
                           where vt.version_table_id = logt.version_table_id
                             and vt.version_table_schema = '''||mySchema||'''
                             and vt.version_table_name = '''||myTable||''' 
                           order by revision desc';
                           
    for logs IN  EXECUTE logViewQry
    LOOP

      return next logs;    
    end loop;                       
  
  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;  


/***************************************************************************
Function to rollback to a specific pgvs revision
table are still persisting of course.
----------------------------------------------------------------------------
begin		: 2011-07-22
copyright	: (C) 2011 by Dr. Horst Duester
email		: horst.duester@kappasys.ch
		  		
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

CREATE OR REPLACE FUNCTION versions.pgvsrollback(character varying, integer)
  RETURNS boolean AS
$BODY$
  DECLARE
    inTable ALIAS FOR $1;
    myRevision ALIAS FOR $2;
    pos INTEGER;
    mySchema TEXT;
    myTable TEXT;
    versionTable TEXT;
    versionView TEXT;
    versionLogTable TEXT;
    attributes record;
    fields TEXT;
    archiveWhere TEXT;
    myPKeyRec Record;
    myPkey Text;
    deleteQry Text;
    insertQry Text;
    myInsertFields Text;
    

  BEGIN	
    pos := strpos(inTable,'.');
    fields := '';
    myInsertFields := '';
    archiveWhere := '';


    if pos=0 then 
        mySchema := 'public';
  	    myTable := inTable; 
    else 
        mySchema = substr(inTable,0,pos);
        pos := pos + 1; 
        myTable = substr(inTable,pos);
    END IF;  
    
  -- Pruefen ob und welche Spalte der Primarykey der Tabelle ist 
    select into myPkeyRec col.column_name 
    from information_schema.table_constraints as key,
         information_schema.key_column_usage as col
    where key.table_schema = mySchema::name
      and key.table_name = myTable::name
      and key.constraint_type='PRIMARY KEY'
      and key.constraint_name = col.constraint_name
      and key.table_catalog = col.table_catalog
      and key.table_schema = col.table_schema
      and key.table_name = col.table_name;	
  
    myPkey := myPkeyRec.column_name;

    versionTable := mySchema||'.'||myTable||'_version_t';
    versionView := mySchema||'.'||myTable||'_version';
    versionLogTable := 'versions.'||mySchema||'_'||myTable||'_version_log';
    
    for attributes in select *
                               from  information_schema.columns
                               where table_schema=mySchema::name
                                    and table_name = myTable::name

        LOOP
          
          if attributes.column_name not in ('action','project','systime','revision','logmsg','commit') then
            fields := fields||',a."'||attributes.column_name||'"';
            myInsertFields := myInsertFields||',"'||attributes.column_name||'"';
          END IF;

          END LOOP;

-- Das erste Komma  aus dem String entfernen
        fields := substring(fields,2);
        myInsertFields := substring(myInsertFields,2);

        
     deleteQry := 'insert into versions.'||mySchema||'_'||myTable||'_version_log ('||myInsertFields||', action)
                    select '||fields||',''delete'' as action
                    from versions.'||mySchema||'_'||myTable||'_version_log as a inner join 
                      (select '||myPkey||', max(systime) as systime
                                              from versions.'||mySchema||'_'||myTable||'_version_log 
                                              where revision > '||myRevision||'  
                                                 and action = ''insert''
                                                 and commit
                                              group by '||myPkey||') as b 
                       on a.'||myPkey||'=b.'||myPkey||' and a.systime = b.systime
                      where action = ''insert''';        

--RAISE EXCEPTION '%', deleteQry;

      execute deleteQry;
      
     insertQry := 'insert into versions.'||mySchema||'_'||myTable||'_version_log ('||myInsertFields||', action)
                    select '||fields||',''insert'' as action
                    from versions.'||mySchema||'_'||myTable||'_version_log as a inner join 
                      (select '||myPkey||', max(systime) as systime
                                              from versions.'||mySchema||'_'||myTable||'_version_log 
                                              where revision > '||myRevision||'  
                                                 and action = ''delete''
                                                 and commit
                                              group by '||myPkey||') as b 
                       on a.'||myPkey||'=b.'||myPkey||' and a.systime = b.systime
                      where action = ''delete''';    

      execute insertQry;
                  
      execute 'select * from versions.pgvscommit('''||mySchema||'.'||myTable||''',''Rollback to Revision '||myRevision||''')';

  RETURN true ;                             

  END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100;


