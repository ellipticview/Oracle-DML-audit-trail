create or replace view emp_aud_vw as
select trx.table_key
, trx.client_identifier as changed_by
, trx.tstamp as changed

-- Map column names to field names
, decode( trd.column_name
        , 'DEPTNO', 'Department'
        , 'ENAME', 'Name'
        , 'JOB', 'Job'
        , 'MGR', 'Manager'
        , 'SAL', 'Salary'
        , trd.column_name) as field

-- Display OLD values
, CASE trd.column_name
    WHEN 'DEPTNO' THEN dpt_old.dname
    WHEN 'MGR' THEN emp_old.ename
    ELSE to_char(trd.old_value)
  END as old_value

-- Display NEW values
, CASE trd.column_name
    WHEN 'DEPTNO' THEN dpt_new.dname
    WHEN 'MGR' THEN emp_new.ename
    ELSE to_char(trd.new_value)
  END as new_value

FROM aud_transaction_data trd
INNER JOIN aud_transactions trx ON trd.trx_id = trx.id

-- Foreign key to Department
LEFT JOIN dept dpt_old ON trd.column_name='DEPTNO' and trd.old_num_value = dpt_old.deptno
LEFT JOIN dept dpt_new ON trd.column_name='DEPTNO' and trd.new_num_value = dpt_new.deptno

-- Foreign key to Employees
LEFT JOIN emp emp_old ON trd.column_name='MGR' and trd.old_num_value = emp_old.empno
LEFT JOIN emp emp_new ON trd.column_name='MGR' and trd.new_num_value = emp_new.empno

WHERE  trx.table_name = 'EMP'
and trx.dml='U'
