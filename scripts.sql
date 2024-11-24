--TASK1: In this exercise, create a procedure to add a new job into the JOBS table.
-- a) Create a stored procedure called NEW_JOB to enter a new order into the JOBS table.
CREATE OR REPLACE PROCEDURE new_job(job_id TEXT, job_title TEXT, min_salary NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO jobs (job_id, job_title, min_salary, max_salary)
    VALUES (job_id, job_title, min_salary, min_salary * 2);
END;
$$;

-- b) Invoke the procedure
CALL new_job('SY_ANAL', 'System Analyst', 6000);


--TASK2: In this exercise, create a program to add a new row to the JOB_HISTORY table for an existing employee.
--a. Create a stored procedure called ADD_JOB_HIST to add a new row into the JOB_HISTORY table for an employee who is changing his job to the new job ID ('SY_ANAL') that you created in exercise 1b.
CREATE OR REPLACE PROCEDURE add_job_hist(emp_id INT, new_job_id TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    hire_date DATE;
    min_salary NUMERIC;
BEGIN
    SELECT hire_date INTO hire_date FROM employees WHERE employee_id = emp_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee with ID % does not exist', emp_id;
    END IF;

    INSERT INTO job_history (employee_id, start_date, end_date, job_id, department_id)
    SELECT emp_id, hire_date, CURRENT_DATE, job_id, department_id
    FROM employees
    WHERE employee_id = emp_id;

    SELECT min_salary INTO min_salary FROM jobs WHERE job_id = new_job_id;

    UPDATE employees
    SET hire_date = CURRENT_DATE, job_id = new_job_id, salary = min_salary + 500
    WHERE employee_id = emp_id;
END;
$$;

-- Отключим триггеры
ALTER TABLE employees DISABLE TRIGGER ALL;
ALTER TABLE jobs DISABLE TRIGGER ALL;
ALTER TABLE job_history DISABLE TRIGGER ALL;

CALL add_job_hist(106, 'SY_ANAL');

-- Заново подключим триггеры
ALTER TABLE employees ENABLE TRIGGER ALL;
ALTER TABLE jobs ENABLE TRIGGER ALL;
ALTER TABLE job_history ENABLE TRIGGER ALL;

-- Проверка изменений
SELECT * FROM job_history WHERE employee_id = 106;
SELECT * FROM employees WHERE employee_id = 106;
-- Отключение триггеров для предотвращения автоматических изменений, вызов процедуры с параметрами (emp_id = 106, new_job_id = 'SY_ANAL').
-- После выполнения проверяются изменения в таблицах job_history и employees для этого сотрудника, что верно работает в базе данных


-- TASK3: In this exercise, create a program to update the minimum and maximum salaries for a job in the JOBS table.
CREATE OR REPLACE PROCEDURE upd_jobsal(job_id TEXT, new_min_salary NUMERIC, new_max_salary NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM jobs WHERE job_id = job_id) THEN
        RAISE EXCEPTION 'Job ID % does not exist', job_id;
    END IF;

    IF new_max_salary < new_min_salary THEN
        RAISE EXCEPTION 'Maximum salary is not greater than or equal to minimum salary';
    END IF;

    UPDATE jobs
    SET min_salary = new_min_salary, max_salary = new_max_salary
    WHERE job_id = job_id;
END;
$$;

-- Отключаем триггеры
ALTER TABLE employees DISABLE TRIGGER ALL;
ALTER TABLE jobs DISABLE TRIGGER ALL;

-- Вызов процедуры
CALL upd_jobsal('SY_ANAL', 7000, 14000);

-- Возвращаем триггеры
ALTER TABLE employees ENABLE TRIGGER ALL;
ALTER TABLE jobs ENABLE TRIGGER ALL;

-- Проверка корректности
SELECT * FROM jobs WHERE job_id = 'SY_ANAL';
-- Процедура обновляет минимальную и максимальную зарплату для указанной должности в таблице JOBS. 
-- Включает проверку на существование должности, корректность значений зарплат и обработку ошибок при блокировке строки.


-- TASK4: Create a subprogram to retrieve the number of years of service for a specific employee.
CREATE OR REPLACE FUNCTION get_years_service(emp_id INT) RETURNS NUMERIC
LANGUAGE plpgsql AS $$
DECLARE
    hire_date DATE;
BEGIN
    SELECT hire_date INTO hire_date FROM employees WHERE employee_id = emp_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee with ID % does not exist', emp_id;
    END IF;

    RETURN EXTRACT(YEAR FROM AGE(CURRENT_DATE, hire_date));
END;
$$;

SELECT get_years_service(106);
-- Функция для получения количества лет службы сотрудника на основе его даты найма. 
-- Включает обработку ошибок для несуществующего сотрудника. Возвращает количество лет, прошедших с даты найма до текущей даты.


-- TASK5: In this exercise, create a program to retrieve the number of different jobs that an employee worked on during his or her service.
CREATE OR REPLACE FUNCTION get_job_count(emp_id INT) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    job_cnt INT;
BEGIN
    SELECT COUNT(DISTINCT job_id)
    INTO job_cnt
    FROM (
        SELECT job_id FROM job_history WHERE employee_id = emp_id
        UNION
        SELECT job_id FROM employees WHERE employee_id = emp_id
    ) AS unique_jobs;

    IF job_cnt IS NULL THEN
        RAISE EXCEPTION 'Employee with ID % does not exist', emp_id;
    END IF;

    RETURN job_cnt;
END;
$$;

SELECT get_job_count(176);
-- Функция для подсчета количества должностей по id, на которых работал сотрудник, включая текущую.
-- Использует уникальные идентификаторы должностей из таблиц job_history и employees, с обработкой ошибок для несуществующего сотрудника.


-- TASK6: In this exercise, create a trigger to ensure that the minimum and maximum salaries of a job are never modified such that the salary of an existing employee with that job ID is outside the new range specified for the job.
CREATE OR REPLACE FUNCTION check_sal_range()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM employees
        WHERE job_id = NEW.job_id
          AND (salary < NEW.min_salary OR salary > NEW.max_salary)
    ) THEN
        RAISE EXCEPTION 'Salary range update existing';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_sal_range
BEFORE UPDATE OF min_salary, max_salary ON jobs
FOR EACH ROW
EXECUTE FUNCTION check_sal_range();

-- Тесты
UPDATE jobs SET min_salary = 5000, max_salary = 7000 WHERE job_id = 'SY_ANAL';
UPDATE jobs SET min_salary = 7000, max_salary = 18000 WHERE job_id = 'SY_ANAL';
-- check_sal_range - nриггер для проверки изменений диапазона зарплат в таблице JOBS.
-- При обновлении min_salary или max_salary проверяется, не выходят ли зарплаты сотрудников за новый диапазон.
-- Если это так, выбрасывается исключение. Выполняется до изменения строк в таблице.


