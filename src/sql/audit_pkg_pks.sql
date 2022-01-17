create or replace PACKAGE audit_pkg IS
    p_pck_name varchar2(50) := 'AUDIT_PKG.';

    PROCEDURE generate_trigger (p_table_name USER_TABLES.table_name%TYPE);
   
    FUNCTION log_transaction
        ( p_table_name IN varchar2
        , p_table_key IN varchar2
        , p_dml IN varchar2
        ) return AUD_TRANSACTIONS.id%TYPE;

    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value varchar2
        , p_new_value varchar2);
        
    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value date
        , p_new_value date);

    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value timestamp
        , p_new_value timestamp);

    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value number
        , p_new_value number);

    PROCEDURE log_column_change
        ( p_trx_id number
        , p_column_name varchar2
        , p_old_value clob
        , p_new_value clob);
END audit_pkg;