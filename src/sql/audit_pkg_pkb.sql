create or replace PACKAGE BODY audit_pkg IS

    FUNCTION log_transaction
        ( p_table_name IN varchar2
        , p_table_key IN varchar2
        , p_dml IN varchar2
        ) return AUD_TRANSACTIONS.id%TYPE IS
        
        l_id AUD_TRANSACTIONS.id%TYPE;
        l_client_identifier AUD_TRANSACTIONS.client_identifier%TYPE;
    BEGIN
        l_client_identifier := sys_context('APEX$SESSION', 'APP_USER');
        if l_client_identifier is null then
            -- We are not in APEX
            l_client_identifier := sys_context('userenv','client_identifier');
        end if;
        if l_client_identifier is null then
            l_client_identifier := USER;
        end if;
        
        insert into aud_transactions
        ( tstamp
        , table_name
        , table_key
        , dml
        , client_identifier
        ) values
        ( systimestamp
        , p_table_name
        , p_table_key
        , p_dml
        , l_client_identifier
        ) returning id into l_id;
        return l_id;
    END;
    
    PROCEDURE insert_transaction_data
        ( p_trx_id varchar2
        , p_column_name varchar2
        , p_old_value clob
        , p_new_value clob
        , p_old_num_value number := null
        , p_new_num_value number := null
        ) IS
    BEGIN
        insert into aud_transaction_data
        ( trx_id
        , column_name
        , old_value
        , new_value
        , old_num_value
        , new_num_value
        ) values
        ( p_trx_id
        , p_column_name
        , p_old_value
        , p_new_value
        , p_old_num_value
        , p_new_num_value);
    END;
    
    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value varchar2
        , p_new_value varchar2
        ) IS
    BEGIN
        if (p_new_value <> p_old_value) OR (p_new_value is NULL and p_old_value is not NULL) OR (p_new_value is not NULL and p_old_value is NULL) then
            insert_transaction_data(p_trx_id, p_column_name, p_old_value, p_new_value);
        end if;    
    END;

    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value date
        , p_new_value date
        ) IS
    BEGIN
        if (p_new_value <> p_old_value) OR (p_new_value is NULL and p_old_value is not NULL) OR (p_new_value is not NULL and p_old_value is NULL) then
            insert_transaction_data(p_trx_id, p_column_name
                                   , to_char(p_old_value, 'YYYY-MM-DD HH24:MI:SS')
                                   , to_char(p_new_value, 'YYYY-MM-DD HH24:MI:SS'));
        end if;    
    END;

    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value timestamp
        , p_new_value timestamp
        ) IS
    BEGIN
        if (p_new_value <> p_old_value) OR (p_new_value is NULL and p_old_value is not NULL) OR (p_new_value is not NULL and p_old_value is NULL) then
            insert_transaction_data(p_trx_id, p_column_name
                                   , to_char(p_old_value, 'YYYY-MM-DD HH24:MI:SS')
                                   , to_char(p_new_value, 'YYYY-MM-DD HH24:MI:SS'));
        end if;    
    END;

    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value number
        , p_new_value number
        ) IS
    BEGIN
        if (p_new_value <> p_old_value) OR (p_new_value is NULL and p_old_value is not NULL) OR (p_new_value is not NULL and p_old_value is NULL) then
            insert_transaction_data(p_trx_id, p_column_name
                                   , to_clob(p_old_value)
                                   , to_clob(p_new_value)
                                   , p_old_value
                                   , p_new_value);
        end if;    
    END;

    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value clob
        , p_new_value clob
        ) IS
    BEGIN
        if (p_new_value <> p_old_value) OR (p_new_value is NULL and p_old_value is not NULL) OR (p_new_value is not NULL and p_old_value is NULL) then
            insert_transaction_data(p_trx_id, p_column_name, p_old_value, p_new_value);
        end if;    
    END;

    -- This is a procedure rather than a function so that is can be easily invoked from the Apex SQL command facility.
    -- In Apex it is cumbersome to see dbms_output (only from the SQL script window, and then navigating to script results
    -- So error messages are provided via  exceptions
    PROCEDURE generate_trigger (p_table_name        USER_TABLES.table_name%TYPE) IS
        cursor c_table_columns (p_table_name USER_TABLES.table_name%TYPE) is
         select atc.column_name
           , case when atc.column_name in ('CREATION_DATE', 'CREATED_BY', 'LAST_UPDATED_DATE', 'LAST_UPDATED_BY')
             then '--    '
             else '      '
             end as indentation
           from USER_TABLES      ata,
                all_tab_columns atc
          where ata.table_name  = p_table_name
            and ata.table_name  = atc.table_name
            and atc.data_type  != 'BLOB' -- BLOB columns will not be audited
          order by atc.column_name;

        r_table_columns c_table_columns%ROWTYPE;
        p_column_name   user_CONS_COLUMNS.column_name%TYPE := NULL;
        p_data_type     user_TAB_COLUMNS.data_type%TYPE    := NULL;
        p_trigger_text  clob          := NULL;
        p_exists        integer       := NULL;
        p_field_length  integer       := 37;
        p_newline       varchar2(5)   := chr(13) || chr(10);
        p_suffix        varchar2(10)  := 'TRG_AUD_';
        p_trigger_name  varchar2(30)  := substr (p_suffix || p_table_name, 1, 30);
        p_prc_name      varchar2(200) := p_pck_name || 'generate_trigger ('|| p_table_name || '): ';
        l_table_name    varchar2(200) := trim (upper (p_table_name));

    BEGIN
        if l_table_name is NULL then
            raise_application_error(-20000, 'Table name must be provided');
        end if;

        BEGIN
            select 1
              into p_exists
              from USER_TABLES ata
             where ata.table_name = l_table_name;
        EXCEPTION
        when no_data_found then
            raise_application_error(-20000, 'Table ' || l_table_name || ' does not exist');
        END;

        -- Finf primary ley column
        BEGIN
            select lower (acc.column_name) as column_name,
                   atc.data_type
              into p_column_name,
                   p_data_type
              from user_constraints  ac,
                   user_cons_columns acc,
                   user_tab_columns  atc
             where ac.table_name       = l_table_name
               and ac.constraint_type  = 'P' -- Retrieved column is primary key
               and atc.data_type       in ('INTEGER', 'NUMBER', 'VARCHAR2')
               and acc.table_name      = ac.table_name
               and acc.constraint_name = ac.constraint_name
               and atc.table_name      = acc.table_name
               and atc.column_name     = acc.column_name;
        EXCEPTION
        when no_data_found then
            raise_application_error(-20000, 'Table "' || l_table_name || '" does not have a primary key, or it is not INTEGER/NUMBER/VARCHAR2.');
        when too_many_rows then
            raise_application_error(-20000, 'Table "' || l_table_name || '" has more than one column as primary key.');
        END;

        -- MAX COLUMN LENGTH for indenting purposes
        select max (length (atc.column_name)) as column_max_length
        into p_field_length
        from USER_TABLES      ata,
             user_tab_columns atc
        where ata.table_name  = l_table_name
        and ata.table_name  = atc.table_name;

        DBMS_LOB.createtemporary (p_trigger_text, TRUE);

        DBMS_LOB.append (p_trigger_text, 'CREATE OR REPLACE TRIGGER ' || lower (p_trigger_name) || p_newline);
        DBMS_LOB.append (p_trigger_text, 'AFTER INSERT OR UPDATE OR DELETE ON ' || lower (p_table_name) || p_newline);
        DBMS_LOB.append (p_trigger_text, 'FOR EACH ROW' || p_newline);
        DBMS_LOB.append (p_trigger_text, '--' || p_newline);
        DBMS_LOB.append (p_trigger_text, '-- This trigger was generated by running audit_pkg.generate_trigger(''' || l_table_name || ''');' || p_newline);
        DBMS_LOB.append (p_trigger_text, '--' || p_newline);
        DBMS_LOB.append (p_trigger_text, 'DECLARE' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   l_dml        varchar2(1) := case when updating then ''U'' when inserting then ''I'' else ''D'' end;' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   l_trx_id     AUD_TRANSACTIONS.id%TYPE;' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   l_table_key  AUD_TRANSACTIONS.table_key%TYPE;' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   l_prc_name   varchar2(50) := ''' || p_trigger_name || ': '';' || p_newline);
        DBMS_LOB.append (p_trigger_text, p_newline);
        DBMS_LOB.append (p_trigger_text, 'BEGIN' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   if l_dml = ''D'' then' || p_newline);
        DBMS_LOB.append (p_trigger_text, '       l_table_key := to_char(:OLD.' || p_column_name || ');' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   else' || p_newline);
        DBMS_LOB.append (p_trigger_text, '       l_table_key := to_char(:NEW.' || p_column_name || ');' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   end if;' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   l_trx_id := audit_pkg.log_transaction(''' || l_table_name || ''', l_table_key, l_dml);' || p_newline);
        DBMS_LOB.append (p_trigger_text, p_newline);
        DBMS_LOB.append (p_trigger_text, '   if deleting then' || p_newline);

        for r_table_columns in c_table_columns (l_table_name) loop
            DBMS_LOB.append( p_trigger_text
                           , r_table_columns.indentation
                             || 'audit_pkg.log_column_change(l_trx_id, '''
                             || r_table_columns.column_name || ''', '
                             || rpad (' ', p_field_length - length (r_table_columns.column_name), ' ')
                             || rpad (':OLD.' || lower (r_table_columns.column_name) || ', ', p_field_length + 7, ' ')
                             || 'NULL);'
                             || p_newline);
        end loop;
        
        DBMS_LOB.append (p_trigger_text, '   else' || p_newline);

        for r_table_columns in c_table_columns (l_table_name) loop
            DBMS_LOB.append( p_trigger_text
                           , r_table_columns.indentation
                             || 'audit_pkg.log_column_change(l_trx_id, '''
                             || r_table_columns.column_name || ''', '
                             || rpad (' ', p_field_length - length (r_table_columns.column_name), ' ')
                             || rpad (':OLD.' || lower (r_table_columns.column_name) || ', ', p_field_length + 7, ' ')
                             || ':NEW.' || lower (r_table_columns.column_name) || ');'
                             || p_newline);
        end loop;
       
        DBMS_LOB.append (p_trigger_text, '   end if;' || p_newline);
        DBMS_LOB.append (p_trigger_text, p_newline);
        DBMS_LOB.append (p_trigger_text, 'EXCEPTION' || p_newline);
        DBMS_LOB.append (p_trigger_text, '   when others then' || p_newline);
        DBMS_LOB.append (p_trigger_text, '      raise_application_error (-20000, ''Error '' || l_prc_name || to_char (sqlcode) || '' - '' ||' ||
                                         ' sqlerrm);' || p_newline);
        DBMS_LOB.append (p_trigger_text, 'END ' || lower (p_trigger_name) || ';' || p_newline);

        execute immediate p_trigger_text;
        DBMS_LOB.freetemporary (p_trigger_text);
    END generate_trigger;
END audit_pkg;