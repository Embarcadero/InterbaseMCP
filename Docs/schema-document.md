# InterBase Schema Document

Source: current InterBase catalog for this project.

## COUNTRY

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| COUNTRY | CHAR(52) | No |  |
| CURRENCY | CHAR(50) | No |  |

- Primary key: `COUNTRY`
- Foreign keys: none
- Indexes:
  - `RDB$PRIMARY1` on `COUNTRY` `UNIQUE`

## CUSTOMER

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| CUST_NO | INTEGER | No |  |
| CUSTOMER | VARCHAR(25) | No |  |
| CONTACT_FIRST | VARCHAR(15) | Yes |  |
| CONTACT_LAST | VARCHAR(20) | Yes |  |
| PHONE_NO | VARCHAR(20) | Yes |  |
| ADDRESS_LINE1 | VARCHAR(30) | Yes |  |
| ADDRESS_LINE2 | VARCHAR(30) | Yes |  |
| CITY | VARCHAR(25) | Yes |  |
| STATE_PROVINCE | VARCHAR(15) | Yes |  |
| COUNTRY | VARCHAR(15) | Yes |  |
| POSTAL_CODE | VARCHAR(12) | Yes |  |
| ON_HOLD | CHAR(1) | Yes | `NULL` |

- Primary key: `CUST_NO`
- Foreign keys:
  - `INTEG_61` via `RDB$FOREIGN23` -> `COUNTRY(COUNTRY)`
- Indexes:
  - `CUSTNAMEX` on `CUSTOMER`
  - `CUSTREGION` on `COUNTRY, CITY`
  - `RDB$FOREIGN23` on `COUNTRY`
  - `RDB$PRIMARY22` on `CUST_NO` `UNIQUE`

## DEPARTMENT

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| DEPT_NO | CHAR(3) | No |  |
| DEPARTMENT | VARCHAR(25) | No |  |
| HEAD_DEPT | CHAR(3) | Yes |  |
| MNGR_NO | SMALLINT | Yes |  |
| BUDGET | DECIMAL(12,2) | Yes |  |
| LOCATION | VARCHAR(15) | Yes |  |
| PHONE_NO | VARCHAR(20) | Yes | `555-1234` |

- Primary key: `DEPT_NO`
- Foreign keys:
  - `INTEG_17` via `RDB$FOREIGN6` -> `DEPARTMENT(DEPT_NO)`
  - `INTEG_31` via `RDB$FOREIGN10` -> `EMPLOYEE(EMP_NO)`
- Indexes:
  - `BUDGETX` on `BUDGET`
  - `IDX_DEPARTMENT_LOCATION` on `LOCATION`
  - `RDB$4` on `DEPARTMENT` `UNIQUE`
  - `RDB$FOREIGN10` on `MNGR_NO`
  - `RDB$FOREIGN6` on `HEAD_DEPT`
  - `RDB$PRIMARY5` on `DEPT_NO` `UNIQUE`

## EMPLOYEE

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| EMP_NO | SMALLINT | No |  |
| FIRST_NAME | VARCHAR(15) | No |  |
| LAST_NAME | VARCHAR(20) | No |  |
| PHONE_EXT | VARCHAR(4) | Yes |  |
| HIRE_DATE | TIMESTAMP | No | `CURRENT_TIMESTAMP` |
| DEPT_NO | CHAR(3) | No |  |
| JOB_CODE | VARCHAR(5) | No |  |
| JOB_GRADE | SMALLINT | No |  |
| JOB_COUNTRY | VARCHAR(15) | No |  |
| SALARY | DECIMAL(10,2) | No |  |
| FULL_NAME | VARCHAR(37) | Yes |  |

- Primary key: `EMP_NO`
- Foreign keys:
  - `INTEG_28` via `RDB$FOREIGN8` -> `DEPARTMENT(DEPT_NO)`
  - `INTEG_29` via `RDB$FOREIGN9` -> `JOB(JOB_CODE, JOB_GRADE, JOB_COUNTRY)`
- Indexes:
  - `NAMEX` on `LAST_NAME, FIRST_NAME`
  - `RDB$FOREIGN8` on `DEPT_NO`
  - `RDB$FOREIGN9` on `JOB_CODE, JOB_GRADE, JOB_COUNTRY`
  - `RDB$PRIMARY7` on `EMP_NO` `UNIQUE`

## EMPLOYEE_PROJECT

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| EMP_NO | SMALLINT | No |  |
| PROJ_ID | CHAR(5) | No |  |

- Primary key: `EMP_NO, PROJ_ID`
- Foreign keys:
  - `INTEG_40` via `RDB$FOREIGN15` -> `EMPLOYEE(EMP_NO)`
  - `INTEG_41` via `RDB$FOREIGN16` -> `PROJECT(PROJ_ID)`
- Indexes:
  - `RDB$FOREIGN15` on `EMP_NO`
  - `RDB$FOREIGN16` on `PROJ_ID`
  - `RDB$PRIMARY14` on `EMP_NO, PROJ_ID` `UNIQUE`

## JOB

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| JOB_CODE | VARCHAR(5) | No |  |
| JOB_GRADE | SMALLINT | No |  |
| JOB_COUNTRY | VARCHAR(15) | No |  |
| JOB_TITLE | VARCHAR(25) | No |  |
| MIN_SALARY | DECIMAL(10,2) | No |  |
| MAX_SALARY | DECIMAL(10,2) | No |  |
| JOB_REQUIREMENT | BLOB | Yes |  |
| LANGUAGE_REQ | VARCHAR(15) | Yes |  |

- Primary key: `JOB_CODE, JOB_GRADE, JOB_COUNTRY`
- Foreign keys:
  - `INTEG_11` via `RDB$FOREIGN3` -> `COUNTRY(COUNTRY)`
- Indexes:
  - `MAXSALX` on `JOB_COUNTRY, MAX_SALARY`
  - `MINSALX` on `JOB_COUNTRY, MIN_SALARY`
  - `RDB$FOREIGN3` on `JOB_COUNTRY`
  - `RDB$PRIMARY2` on `JOB_CODE, JOB_GRADE, JOB_COUNTRY` `UNIQUE`

## PROJECT

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| PROJ_ID | CHAR(5) | No |  |
| PROJ_NAME | VARCHAR(20) | No |  |
| PROJ_DESC | BLOB | Yes |  |
| TEAM_LEADER | SMALLINT | Yes |  |
| PRODUCT | VARCHAR(12) | Yes |  |

- Primary key: `PROJ_ID`
- Foreign keys:
  - `INTEG_36` via `RDB$FOREIGN13` -> `EMPLOYEE(EMP_NO)`
- Indexes:
  - `PRODTYPEX` on `PRODUCT, PROJ_NAME` `UNIQUE`
  - `RDB$11` on `PROJ_NAME` `UNIQUE`
  - `RDB$FOREIGN13` on `TEAM_LEADER`
  - `RDB$PRIMARY12` on `PROJ_ID` `UNIQUE`

## PROJ_DEPT_BUDGET

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| FISCAL_YEAR | INTEGER | No |  |
| PROJ_ID | CHAR(5) | No |  |
| DEPT_NO | CHAR(3) | No |  |
| QUART_HEAD_CNT | INTEGER | Yes |  |
| PROJECTED_BUDGET | DECIMAL(12,2) | Yes |  |

- Primary key: `FISCAL_YEAR, PROJ_ID, DEPT_NO`
- Foreign keys:
  - `INTEG_47` via `RDB$FOREIGN18` -> `DEPARTMENT(DEPT_NO)`
  - `INTEG_48` via `RDB$FOREIGN19` -> `PROJECT(PROJ_ID)`
- Indexes:
  - `RDB$FOREIGN18` on `DEPT_NO`
  - `RDB$FOREIGN19` on `PROJ_ID`
  - `RDB$PRIMARY17` on `FISCAL_YEAR, PROJ_ID, DEPT_NO` `UNIQUE`

## SALARY_HISTORY

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| EMP_NO | SMALLINT | No |  |
| CHANGE_DATE | TIMESTAMP | No | `CURRENT_TIMESTAMP` |
| UPDATER_ID | VARCHAR(20) | No |  |
| OLD_SALARY | DECIMAL(10,2) | No |  |
| PERCENT_CHANGE | DOUBLE PRECISION | No | `0` |
| NEW_SALARY | INTEGER | Yes |  |

- Primary key: `EMP_NO, CHANGE_DATE, UPDATER_ID`
- Foreign keys:
  - `INTEG_56` via `RDB$FOREIGN21` -> `EMPLOYEE(EMP_NO)`
- Indexes:
  - `CHANGEX` on `CHANGE_DATE`
  - `RDB$FOREIGN21` on `EMP_NO`
  - `RDB$PRIMARY20` on `EMP_NO, CHANGE_DATE, UPDATER_ID` `UNIQUE`
  - `UPDATERX` on `UPDATER_ID`

## SALES

| Column | Data type | Null | Default |
| --- | --- | --- | --- |
| PO_NUMBER | CHAR(8) | No |  |
| CUST_NO | INTEGER | No |  |
| SALES_REP | SMALLINT | Yes |  |
| ORDER_STATUS | CHAR(7) | No | `new` |
| ORDER_DATE | TIMESTAMP | No | `CURRENT_TIMESTAMP` |
| SHIP_DATE | TIMESTAMP | Yes |  |
| DATE_NEEDED | TIMESTAMP | Yes |  |
| PAID | CHAR(1) | Yes | `n` |
| QTY_ORDERED | INTEGER | No | `1` |
| TOTAL_VALUE | NUMERIC(9,2) | No |  |
| DISCOUNT | SMALLINT | No | `0` |
| ITEM_TYPE | VARCHAR(12) | Yes |  |
| AGED | NUMERIC(18,9) | Yes |  |

- Primary key: `PO_NUMBER`
- Foreign keys:
  - `INTEG_77` via `RDB$FOREIGN25` -> `CUSTOMER(CUST_NO)`
  - `INTEG_78` via `RDB$FOREIGN26` -> `EMPLOYEE(EMP_NO)`
- Indexes:
  - `NEEDX` on `DATE_NEEDED`
  - `QTYX` on `ITEM_TYPE, QTY_ORDERED`
  - `RDB$FOREIGN25` on `CUST_NO`
  - `RDB$FOREIGN26` on `SALES_REP`
  - `RDB$PRIMARY24` on `PO_NUMBER` `UNIQUE`
  - `SALESTATX` on `ORDER_STATUS, PAID`

## Relationship Summary

- `CUSTOMER.COUNTRY` references `COUNTRY.COUNTRY`
- `DEPARTMENT.HEAD_DEPT` references `DEPARTMENT.DEPT_NO`
- `DEPARTMENT.MNGR_NO` references `EMPLOYEE.EMP_NO`
- `EMPLOYEE.DEPT_NO` references `DEPARTMENT.DEPT_NO`
- `EMPLOYEE.JOB_CODE, EMPLOYEE.JOB_GRADE, EMPLOYEE.JOB_COUNTRY` references `JOB.JOB_CODE, JOB.JOB_GRADE, JOB.JOB_COUNTRY`
- `EMPLOYEE_PROJECT.EMP_NO` references `EMPLOYEE.EMP_NO`
- `EMPLOYEE_PROJECT.PROJ_ID` references `PROJECT.PROJ_ID`
- `PROJECT.TEAM_LEADER` references `EMPLOYEE.EMP_NO`
- `PROJ_DEPT_BUDGET.DEPT_NO` references `DEPARTMENT.DEPT_NO`
- `PROJ_DEPT_BUDGET.PROJ_ID` references `PROJECT.PROJ_ID`
- `SALARY_HISTORY.EMP_NO` references `EMPLOYEE.EMP_NO`
- `SALES.CUST_NO` references `CUSTOMER.CUST_NO`
- `SALES.SALES_REP` references `EMPLOYEE.EMP_NO`

