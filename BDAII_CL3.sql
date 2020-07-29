
-- Esquema BDHR

--1

create or replace package PK_DEPARTMENS
is
    procedure SP_INSERT_DEPART(p_depa_name departments.department_name%type,p_depa_manag departments.manager_id%type,p_depa_loc departments.location_id%type,p_mensaje out varchar2);
    procedure SP_UPDATE_DEPART(p_depa_id departments.department_id%type,p_depa_name departments.department_name%type,p_depa_manag departments.manager_id%type,p_depa_loc departments.location_id%type,p_mensaje out varchar2);
    procedure SP_DEL_DEPART(p_department_id departments.department_id%type,p_mensaje out varchar2);
    
end;

create or replace package body PK_DEPARTMENS
is
    --Insertar nuevo departamento
    procedure SP_INSERT_DEPART(p_depa_name departments.department_name%type,p_depa_manag departments.manager_id%type,p_depa_loc departments.location_id%type,p_mensaje out varchar2)
    is
        v_department_id departments.department_id%type;
        v_department_dup exception;
        v_existe int;
    begin
        
        select count(1)
        into v_existe
        from departments
        where upper (department_name, manager_id, location_id) = upper (p_depa_name,p_depa_manag,p_depa_loc);
        
        if v_existe >= 1 then
            raise v_department_dup;
        else
            
            select max(department_id)+1 into v_department_id from departments;
            
            insert into departments values(v_department_id,p_depa_name,p_depa_manag,p_depa_loc);
            commit;
            p_mensaje := 'El departamento se ingresó de forma exitosa. ID: '||v_department_id;
        end if;
    exception
        when v_depa_dup then
            p_mensaje := ('El Departamento ingresado ya existe: '||p_depa_name);
        when DUP_VAL_ON_INDEX then
            p_mensaje := ('ERROR - Primary key repetido');
        when others then
            p_mensaje := ('Se ha encontrado un error: '||SQLCODE||' Mensaje: '||SQLERRM);    
    end;
    
    /*Actualizar los datos del departamento*/
    procedure SP_UPDATE_DEPART(p_depa_id departments.department_id%type,p_depa_name departments.department_name%type,p_depa_manag departments.manager_id%type,p_depa_loc departments.location_id%type,p_mensaje out varchar2)
    as
        v_err_nombre exception;
        v_err_manag exception;
        v_err_loc exception;
        v_num_depa int;
    begin
        
        select count(*) into v_num_depa from departments where upper(department_name,manager_id,location_id) = upper(p_depa_name,p_depa_manag,p_depa_loc);
        
        if v_num_depa > 0 then
            raise v_err_nombre;  
            raise v_err_manag ;
            raise v_err_loc;
        end if;
        
        update departments
        set department_name = initcap(p_depa_name), manager_id = p_depa_manag, location_id = p_depa_loc
        where department_id = p_depa_id;
        commit;
        p_mensaje := 'El departamento se actualizó correctamente: '||p_depa_id||'-'||initcap(p_depa_name)||'-'||p_depa_manag||'-'||p_depa_loc;
    exception
        when NO_DATA_FOUND then
            p_mensaje := ('Ese departamento no existe.');
        when v_err_nombre then
            p_mensaje := ('El nombre del Departamento ya existe');
        when v_err_manag then
            p_mensaje := ('La ID del manager ya existe');
        when v_err_loc then
            p_mensaje := ('La ID de la locación ya existe');
        when others then
            p_mensaje := ('Se ha encontrado un error: '||SQLCODE||' Mensaje: '||SQLERRM);
    end;
    
    /*Eliminar un departamento*/
    procedure SP_DEL_DEPART(p_department_id departments.department_id%type,p_mensaje out varchar2)
    as
        v_exs_locations exception;
        v_num_locations number;
    begin
    
        select count(*) into v_num_locations from locations where department_id = p_department_id;
        
        if v_num_locations > 0 then
            raise v_exs_locations;
        end if;
        
        delete from departments
        where department_id = p_department_id;
        
        if sql%notfound then
            p_mensaje := 'El código solicitado no existe: '||p_department_id;
        else
            commit;
            p_mensaje := 'El departamento se eliminó corectamente: '||p_department_id;
        end if;
    exception
        when v_exs_locations then
            p_mensaje := 'Hay una locación con la cual se impide ejecutar la eliminación.';
        when others then
            p_mensaje := 'Se ha encontrado un error: '||SQLCODE||' Mensaje: '||SQLERRM;
    end;
end;

--2
create or replace package PKG_CALCULO
is
    function fn_obtener_fecha(p_fecha_cont employees.hire_date%type)return varchar2;
    function fn_bono(p_codemp employees.employee_id%type)return numeric;
    function fn_dscto(p_codjob jobs.job_id%type) return numeric;
end;

create or replace package body PKG_CALCULO
as

    --	Función que calcule la cantidad de años, enviando como parámetro una fecha.
    function fn_obtener_fecha(p_fecha_cont employees.hire_date%type)return varchar2
    is
        id_emp employees.employee_id%type;
        v_en_texto varchar2(100);
    begin
        select trunc(years_between(sysdate,hire_date)/12) 
        from employees
        where employee_id = id_emp;
    exception
        when others then
            v_en_texto := ('Ha ocurrido un error: '||SQLERRM);
            return v_en_texto;
    end;
    
    -- Función que calcule un bono enviando como parámetro el salario. La formula es la siguiente: 
    -- BONO_UTIL = (((SALARIO*7) + 15% SALARIO)/5 )+ 35 SOLES POR CADA AÑO TRABAJADO(use la función creada anteriormente)
    function fn_bono(p_codemp employees.employee_id%type)return numeric
    is
        sal employees.salary%type;
        bono employees.salary%type;
    begin 
        select salary
        into sal
        from employees
        where employee_id = p_codemp;
        
        bono := (((sal*7)+0.15*sal)/5)+35*(fn_obtener_fecha);
        return bono;
    exception
        when others then
        return -1;
    end;
    
    -- Función que calcule un descuento en base al JOB_ID y SALARIO enviados como parámetros:
    -- DESCUENTO = (SALARIO – (SALARIO MINIMO DEL JOB_ID))
    function fn_dscto(p_codjob jobs.job_id%type) return numeric
    is
        sal employees.salary%type;
        dscto employees.salary%type;
    begin
        select e.salary, j.min_salary 
        into sal
        from employees e
        inner join jobs j on j.job_id = e.job_id
        where j.job_id = p_codjob;
    
        dscto := (sal - (j.min_salary));
        return dscto;
    exception
        when others then
            return -1;
    end;
end;

procedure sp_reporte(p_id_emp employees.employee_id%type)
is
    cursor c_empleado is (SELECT e.employee_id,e.first_name,e.last_name,e.hire_date,e.salary, j.job_title FROM employees e 
    inner join jobs j on j.job_id = e.job_id where department_id = p_id_emp);
begin
    
    DBMS_OUTPUT.PUT_LINE('REPORTE-DEPARTAMENTO: TI');
    DBMS_OUTPUT.PUT_LINE('====================================');
    for reg_emp in c_empleado loop
    DBMS_OUTPUT.PUT_LINE('Empleado: '||reg_emp.first_name||' '||reg_emp.last_name);
    DBMS_OUTPUT.PUT_LINE('Fecha de contrato: '||reg_emp.hire_date);
    DBMS_OUTPUT.PUT_LINE('Trabajo: '||reg_emp.job_id||'-'||reg_emp.job_title);
    DBMS_OUTPUT.PUT_LINE('Salario: '||to_char(salary,'L999,999.99'));
    DBMS_OUTPUT.PUT_LINE('************************************');
    DBMS_OUTPUT.PUT_LINE('BONO UTIL         '||fn_bono(reg_emp.employee_id));
    DBMS_OUTPUT.PUT_LINE('DESCUENTO         '||fn_dscto(reg_emp.employee_id));
    DBMS_OUTPUT.PUT_LINE('************************************');
    end loop;
end;
    
