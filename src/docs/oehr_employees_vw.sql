create or replace view oehr_employees_aud_vw as
select trx.table_key
, trx.client_identifier as changed_by
, trx.tstamp as changed

-- Map column names to field names
, decode( trd.column_name
        , 'DEPARTMENT_ID', 'Department'
        , 'JOB_ID', 'Job'
        , 'MANAGER_ID', 'Manager'
        , 'SAL', 'Salary'
        , trd.column_name) as field

-- Display OLD values
, CASE trd.column_name
    WHEN 'DEPARTMENT_ID' THEN dpt_old.department_name
    WHEN 'MANAGER_ID' THEN emp_old.first_name || ' ' || emp_old.last_name
    WHEN 'JOB_ID' THEN job_old.job_title
    ELSE to_char(trd.old_value)
  END as old_value

-- Display NEW values
, CASE trd.column_name
    WHEN 'DEPARTMENT_ID' THEN dpt_new.department_name
    WHEN 'MANAGER_ID' THEN emp_new.first_name || ' ' || emp_new.last_name
    WHEN 'JOB_ID' THEN job_new.job_title
    ELSE to_char(trd.new_value)
  END as new_value

FROM aud_transaction_data trd
INNER JOIN aud_transactions trx ON trd.trx_id = trx.id

-- Foreign key to OEHR_DEPARTMENTS
LEFT JOIN OEHR_DEPARTMENTS dpt_old ON trd.column_name='DEPARTMENT_ID' and trd.old_num_value = dpt_old.department_id
LEFT JOIN OEHR_DEPARTMENTS dpt_new ON trd.column_name='DEPARTMENT_ID' and trd.new_num_value = dpt_new.department_id

-- Foreign key to OEHR_JOBS, note that this is a varchar FK
LEFT JOIN OEHR_JOBS job_old ON trd.column_name='JOB_ID' and to_char(trd.old_value) = job_old.job_id
LEFT JOIN OEHR_JOBS job_new ON trd.column_name='JOB_ID' and to_char(trd.new_value) = job_new.job_id

-- Foreign key to OEHR_EMPLOYEES
LEFT JOIN OEHR_EMPLOYEES emp_old ON trd.column_name='MANAGER_ID' and trd.old_num_value = emp_old.employee_id
LEFT JOIN OEHR_EMPLOYEES emp_new ON trd.column_name='MANAGER_ID' and trd.new_num_value = emp_new.employee_id

WHERE  trx.table_name = 'OEHR_EMPLOYEES'
and trx.dml='U'
