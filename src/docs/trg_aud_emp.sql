create or replace TRIGGER trg_aud_emp
AFTER INSERT OR UPDATE OR DELETE ON emp
FOR EACH ROW
--
-- This trigger was generated by running audit_pkg.generate_trigger('EMP');
--
DECLARE
   l_dml        varchar2(1) := case when updating then 'U' when inserting then 'I' else 'D' end;
   l_trx_id     AUD_TRANSACTIONS.id%TYPE;
   l_table_key  AUD_TRANSACTIONS.table_key%TYPE;
   l_prc_name   varchar2(50) := 'TRG_AUD_emp: ';

BEGIN
   if l_dml = 'D' then
       l_table_key := to_char(:OLD.empno);
   else
       l_table_key := to_char(:NEW.empno);
   end if;
   l_trx_id := audit_pkg.log_transaction('EMP', l_table_key, l_dml);

   if deleting then
      audit_pkg.log_column_change(l_trx_id, 'COMM',     :OLD.comm,     NULL);
      audit_pkg.log_column_change(l_trx_id, 'DEPTNO',   :OLD.deptno,   NULL);
      audit_pkg.log_column_change(l_trx_id, 'EMPNO',    :OLD.empno,    NULL);
      audit_pkg.log_column_change(l_trx_id, 'ENAME',    :OLD.ename,    NULL);
      audit_pkg.log_column_change(l_trx_id, 'HIREDATE', :OLD.hiredate, NULL);
      audit_pkg.log_column_change(l_trx_id, 'JOB',      :OLD.job,      NULL);
      audit_pkg.log_column_change(l_trx_id, 'MGR',      :OLD.mgr,      NULL);
      audit_pkg.log_column_change(l_trx_id, 'SAL',      :OLD.sal,      NULL);
   else
      audit_pkg.log_column_change(l_trx_id, 'COMM',     :OLD.comm,     :NEW.comm);
      audit_pkg.log_column_change(l_trx_id, 'DEPTNO',   :OLD.deptno,   :NEW.deptno);
      audit_pkg.log_column_change(l_trx_id, 'EMPNO',    :OLD.empno,    :NEW.empno);
      audit_pkg.log_column_change(l_trx_id, 'ENAME',    :OLD.ename,    :NEW.ename);
      audit_pkg.log_column_change(l_trx_id, 'HIREDATE', :OLD.hiredate, :NEW.hiredate);
      audit_pkg.log_column_change(l_trx_id, 'JOB',      :OLD.job,      :NEW.job);
      audit_pkg.log_column_change(l_trx_id, 'MGR',      :OLD.mgr,      :NEW.mgr);
      audit_pkg.log_column_change(l_trx_id, 'SAL',      :OLD.sal,      :NEW.sal);
   end if;

EXCEPTION
   when others then
      raise_application_error (-20000, 'Error ' || l_prc_name || to_char (sqlcode) || ' - ' || sqlerrm);
END trg_aud_emp;
