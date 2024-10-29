-- AdventureWorks for Postgres
--  by Lorin Thwaits

-- How to use this script:

-- Download "Adventure Works 2014 OLTP Script" from:
--   https://msftdbprodsamples.codeplex.com/downloads/get/880662

-- Extract the .zip and copy all of the CSV files into the same folder containing
-- this install.sql file and the update_csvs.rb file.

-- Modify the CSVs to work with Postgres by running:
--   ruby update_csvs.rb

-- Create the database and tables, import the data, and set up the views and keys with:
--   psql -c "CREATE DATABASE adventure_works;"
--   psql -d adventure_works < install.sql

-- All 68 tables are properly set up.
-- All 20 views are established.
-- 68 additional convenience views are added which:
--   * Provide a shorthand to refer to tables.
--   * Add an "id" column to a primary key or primary-ish key if it makes sense.
--
--   For example, with the convenience views you can simply do:
--       SELECT pe.p.first_name, hr.e.job_title
--       FROM pe.p
--         INNER JOIN hr.e ON pe.p.id = hr.e.id;
--   Instead of:
--       SELECT p.first_name, e.job_title
--       FROM person.person AS p
--         INNER JOIN human_resources.employee AS e ON p.business_entity_id = e.business_entity_id;
--
-- Schemas for these views:
--   pe = person
--   hr = human_resources
--   pr = production
--   pu = purchasing
--   sa = sales
-- Easily get a list of all of these with:  \dv (pe|hr|pr|pu|sa).*

-- Enjoy!


-- -- Disconnect all other existing connections
-- SELECT pg_terminate_backend(pid)
--   FROM pg_stat_activity
--   WHERE pid <> pg_backend_pid() AND datname='adventure_works';

\cd data

\pset tuples_only on

-- Support to auto-generate UUIDs (aka GUIDs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Support crosstab function to do PIVOT thing for sales.v_sales_person_sales_by_fiscal_years
CREATE EXTENSION tablefunc;

-------------------------------------
-- Custom data types
-------------------------------------

CREATE DOMAIN "order_number" varchar(25) NULL;
CREATE DOMAIN "account_number" varchar(15) NULL;

CREATE DOMAIN "flag" boolean NOT NULL;
CREATE DOMAIN "name_style" boolean NOT NULL;
CREATE DOMAIN "name" varchar(50) NULL;
CREATE DOMAIN "phone" varchar(25) NULL;


-------------------------------------
-- Five schemas, with tables and data
-------------------------------------

CREATE SCHEMA person
  CREATE TABLE business_entity(
    business_entity_id SERIAL, --  NOT FOR REPLICATION
    row_guid uuid NOT NULL CONSTRAINT "DF_BusinessEntity_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_BusinessEntity_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE person(
    business_entity_id INT NOT NULL,
    person_type char(2) NOT NULL,
    name_style "name_style" NOT NULL CONSTRAINT "DF_Person_NameStyle" DEFAULT (false),
    title varchar(8) NULL,
    first_name "name" NOT NULL,
    middle_name "name" NULL,
    last_name "name" NOT NULL,
    suffix varchar(10) NULL,
    email_promotion INT NOT NULL CONSTRAINT "DF_Person_EmailPromotion" DEFAULT (0),
    additional_contact_info XML NULL, -- XML("AdditionalContactInfoSchemaCollection"),
    demographics XML NULL, -- XML("IndividualSurveySchemaCollection"),
    row_guid uuid NOT NULL CONSTRAINT "DF_Person_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Person_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Person_EmailPromotion" CHECK (email_promotion BETWEEN 0 AND 2),
    CONSTRAINT "CK_Person_PersonType" CHECK (person_type IS NULL OR UPPER(person_type) IN ('SC', 'VC', 'IN', 'EM', 'SP', 'GC'))
  )
  CREATE TABLE state_province(
    state_province_id SERIAL,
    state_province_code char(3) NOT NULL,
    country_region_code varchar(3) NOT NULL,
    is_only_state_province_flag "flag" NOT NULL CONSTRAINT "DF_StateProvince_IsOnlyStateProvinceFlag" DEFAULT (true),
    name "name" NOT NULL,
    territory_id INT NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_StateProvince_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_StateProvince_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE address(
    address_id SERIAL, --  NOT FOR REPLICATION
    address_line_1 varchar(60) NOT NULL,
    address_line_2 varchar(60) NULL,
    city varchar(30) NOT NULL,
    state_province_id INT NOT NULL,
    postal_code varchar(15) NOT NULL,
    spatial_location bytea NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_Address_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Address_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE address_type(
    address_type_id SERIAL,
    name "name" NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_AddressType_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_AddressType_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE business_entity_address(
    business_entity_id INT NOT NULL,
    address_id INT NOT NULL,
    address_type_id INT NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_BusinessEntityAddress_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_BusinessEntityAddress_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE contact_type(
    contact_type_id SERIAL,
    name "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ContactType_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE business_entity_contact(
    business_entity_id INT NOT NULL,
    person_id INT NOT NULL,
    contact_type_id INT NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_BusinessEntityContact_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_BusinessEntityContact_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE email_address(
    business_entity_id INT NOT NULL,
    email_address_id SERIAL,
    email_address varchar(50) NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_EmailAddress_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_EmailAddress_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE password(
    business_entity_id INT NOT NULL,
    password_hash VARCHAR(128) NOT NULL,
    password_salt VARCHAR(10) NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_Password_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Password_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE phone_number_type(
    phone_number_type_id SERIAL,
    name "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_PhoneNumberType_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE person_phone(
    business_entity_id INT NOT NULL,
    phone_number "phone" NOT NULL,
    phone_number_type_id INT NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_PersonPhone_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE country_region(
    country_region_code varchar(3) NOT NULL,
    name "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_CountryRegion_ModifiedDate" DEFAULT (NOW())
  );

COMMENT ON SCHEMA person IS 'Contains objects related to names and addresses of customers, vendors, and employees';

SELECT 'Copying data into person.business_entity';
\copy person.business_entity FROM 'business_entity.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.person';
\copy person.person FROM 'person.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.state_province';
\copy person.state_province FROM 'state_province.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.address';
\copy person.address FROM 'address.csv' DELIMITER E'\t' CSV ENCODING 'latin1';
SELECT 'Copying data into person.address_type';
\copy person.address_type FROM 'address_type.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.business_entity_address';
\copy person.business_entity_address FROM 'business_entity_address.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.contact_type';
\copy person.contact_type FROM 'contact_type.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.business_entity_contact';
\copy person.business_entity_contact FROM 'business_entity_contact.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.email_address';
\copy person.email_address FROM 'email_address.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.password';
\copy person.password FROM 'password.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.phone_number_type';
\copy person.phone_number_type FROM 'phone_number_type.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.person_phone';
\copy person.person_phone FROM 'person_phone.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into person.country_region';
\copy person.country_region FROM 'country_region.csv' DELIMITER E'\t' CSV;


CREATE SCHEMA human_resources
  CREATE TABLE department(
    department_id SERIAL NOT NULL, -- smallint
    name "name" NOT NULL,
    group_name "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Department_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE employee(
    business_entity_id INT NOT NULL,
    national_id_number varchar(15) NOT NULL,
    login_id varchar(256) NOT NULL,    
    org varchar NULL,-- hierarchyid, will become organization_node
    organization_level INT NULL, -- AS organization_node.GetLevel(),
    job_title varchar(50) NOT NULL,
    birth_date DATE NOT NULL,
    martial_status char(1) NOT NULL,
    gender char(1) NOT NULL,
    hire_date DATE NOT NULL,
    salaried_flag "flag" NOT NULL CONSTRAINT "DF_Employee_SalariedFlag" DEFAULT (true),
    vacation_hours smallint NOT NULL CONSTRAINT "DF_Employee_VacationHours" DEFAULT (0),
    sick_leave_hours smallint NOT NULL CONSTRAINT "DF_Employee_SickLeaveHours" DEFAULT (0),
    current_flag "flag" NOT NULL CONSTRAINT "DF_Employee_CurrentFlag" DEFAULT (true),
    row_guid uuid NOT NULL CONSTRAINT "DF_Employee_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Employee_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Employee_BirthDate" CHECK (birth_date BETWEEN '1930-01-01' AND NOW() - INTERVAL '18 years'),
    CONSTRAINT "CK_Employee_MaritalStatus" CHECK (UPPER(martial_status) IN ('M', 'S')), -- Married or Single
    CONSTRAINT "CK_Employee_HireDate" CHECK (hire_date BETWEEN '1996-07-01' AND NOW() + INTERVAL '1 day'),
    CONSTRAINT "CK_Employee_Gender" CHECK (UPPER(gender) IN ('M', 'F')), -- Male or Female
    CONSTRAINT "CK_Employee_VacationHours" CHECK (vacation_hours BETWEEN -40 AND 240),
    CONSTRAINT "CK_Employee_SickLeaveHours" CHECK (sick_leave_hours BETWEEN 0 AND 120)
  )
  CREATE TABLE employee_department_history(
    business_entity_id INT NOT NULL,
    department_id smallint NOT NULL,
    shift_id smallint NOT NULL, -- tinyint
    start_date DATE NOT NULL,
    end_date DATE NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_EmployeeDepartmentHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_EmployeeDepartmentHistory_EndDate" CHECK ((end_date >= start_date) OR (end_date IS NULL))
  )
  CREATE TABLE employee_pay_history(
    business_entity_id INT NOT NULL,
    rate_change_date TIMESTAMP NOT NULL,
    rate numeric NOT NULL, -- money
    pay_frequency smallint NOT NULL,  -- tinyint
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_EmployeePayHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_EmployeePayHistory_PayFrequency" CHECK (pay_frequency IN (1, 2)), -- 1 = monthly salary, 2 = biweekly salary
    CONSTRAINT "CK_EmployeePayHistory_Rate" CHECK (rate BETWEEN 6.50 AND 200.00)
  )
  CREATE TABLE job_candidate(
    job_candidate_id SERIAL NOT NULL, -- int
    business_entity_id INT NULL,
    resume XML NULL, -- XML(HRResumeSchemaCollection)
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_JobCandidate_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE shift(
    shift_id SERIAL NOT NULL, -- tinyint
    name "name" NOT NULL,
    start_time time NOT NULL,
    end_time time NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Shift_ModifiedDate" DEFAULT (NOW())
  );

COMMENT ON SCHEMA human_resources IS 'Contains objects related to employees and departments.';

SELECT 'Copying data into human_resources.department';
\copy human_resources.department FROM 'department.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into human_resources.employee';
\copy human_resources.employee FROM 'employee.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into human_resources.employee_department_history';
\copy human_resources.employee_department_history FROM 'employee_department_history.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into human_resources.employee_pay_history';
\copy human_resources.employee_pay_history FROM 'employee_pay_history.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into human_resources.job_candidate';
\copy human_resources.job_candidate FROM 'job_candidate.csv' DELIMITER E'\t' CSV ENCODING 'latin1';
SELECT 'Copying data into human_resources.shift';
\copy human_resources.shift FROM 'shift.csv' DELIMITER E'\t' CSV;

-- Calculated column that needed to be there just for the CSV import
ALTER TABLE human_resources.employee DROP COLUMN organization_level;

-- employee HierarchyID column
ALTER TABLE human_resources.employee ADD organization_node VARCHAR DEFAULT '/';
-- Convert from all the hex to a stream of hierarchyid bits
WITH RECURSIVE hier AS (
  SELECT business_entity_id, org, get_byte(decode(substring(org, 1, 2), 'hex'), 0)::bit(8)::varchar AS bits, 2 AS i
    FROM human_resources.employee
  UNION ALL
  SELECT e.business_entity_id, e.org, hier.bits || get_byte(decode(substring(e.org, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 AS i
    FROM human_resources.employee AS e INNER JOIN
      hier ON e.business_entity_id = hier.business_entity_id AND i < LENGTH(e.org)
)
UPDATE human_resources.employee AS emp
  SET org = COALESCE(trim(trailing '0' FROM hier.bits::TEXT), '')
  FROM hier
  WHERE emp.business_entity_id = hier.business_entity_id
    AND (hier.org IS NULL OR i = LENGTH(hier.org));

-- Convert bits to the real hieararchy paths
CREATE OR REPLACE FUNCTION f_ConvertOrgNodes()
  RETURNS void AS
$func$
DECLARE
  got_none BOOLEAN;
BEGIN
  LOOP
  got_none := true;
  -- 01 = 0-3
  UPDATE human_resources.employee
   SET organization_node = organization_node || SUBSTRING(org, 3,2)::bit(2)::INTEGER::VARCHAR || CASE SUBSTRING(org, 5, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 6, 9999)
    WHERE org LIKE '01%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 100 = 4-7
  UPDATE human_resources.employee
   SET organization_node = organization_node || (SUBSTRING(org, 4,2)::bit(2)::INTEGER + 4)::VARCHAR || CASE SUBSTRING(org, 6, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 7, 9999)
    WHERE org LIKE '100%';
  IF FOUND THEN
    got_none := false;
  END IF;
  
  -- 101 = 8-15
  UPDATE human_resources.employee
   SET organization_node = organization_node || (SUBSTRING(org, 4,3)::bit(3)::INTEGER + 8)::VARCHAR || CASE SUBSTRING(org, 7, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 8, 9999)
    WHERE org LIKE '101%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 110 = 16-79
  UPDATE human_resources.employee
   SET organization_node = organization_node || ((SUBSTRING(org, 4,2)||SUBSTRING(org, 7,1)||SUBSTRING(org, 9,3))::bit(6)::INTEGER + 16)::VARCHAR || CASE SUBSTRING(org, 12, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 13, 9999)
    WHERE org LIKE '110%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 1110 = 80-1103
  UPDATE human_resources.employee
   SET organization_node = organization_node || ((SUBSTRING(org, 5,3)||SUBSTRING(org, 9,3)||SUBSTRING(org, 13,1)||SUBSTRING(org, 15,3))::bit(10)::INTEGER + 80)::VARCHAR || CASE SUBSTRING(org, 18, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 19, 9999)
    WHERE org LIKE '1110%';
  IF FOUND THEN
    got_none := false;
  END IF;
  EXIT WHEN got_none;
  END LOOP;
END
$func$ LANGUAGE plpgsql;

SELECT f_ConvertOrgNodes();
-- Drop the original binary hierarchyid column
ALTER TABLE human_resources.employee DROP COLUMN org;
DROP FUNCTION f_ConvertOrgNodes();




CREATE SCHEMA production
  CREATE TABLE bill_of_materials(
    bill_of_materials_id SERIAL NOT NULL, -- int
    product_assembly_id INT NULL,
    component_id INT NOT NULL,
    start_date TIMESTAMP NOT NULL CONSTRAINT "DF_BillOfMaterials_StartDate" DEFAULT (NOW()),
    end_date TIMESTAMP NULL,
    unit_measure_code char(3) NOT NULL,
    bom_level smallint NOT NULL,
    per_assembly_qty decimal(8, 2) NOT NULL CONSTRAINT "DF_BillOfMaterials_PerAssemblyQty" DEFAULT (1.00),
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_BillOfMaterials_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_BillOfMaterials_EndDate" CHECK ((end_date > start_date) OR (end_date IS NULL)),
    CONSTRAINT "CK_BillOfMaterials_ProductAssemblyID" CHECK (product_assembly_id <> component_id),
    CONSTRAINT "CK_BillOfMaterials_BOMLevel" CHECK (((product_assembly_id IS NULL)
        AND (bom_level = 0) AND (per_assembly_qty = 1.00))
        OR ((product_assembly_id IS NOT NULL) AND (bom_level >= 1))),
    CONSTRAINT "CK_BillOfMaterials_PerAssemblyQty" CHECK (per_assembly_qty >= 1.00)
  )
  CREATE TABLE culture(
    culture_id char(6) NOT NULL,
    name "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Culture_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE document(
    doc varchar NULL,-- hierarchyid, will become document_node
    document_level INTEGER, -- AS document_node.GetLevel(),
    title varchar(50) NOT NULL,
    owner INT NOT NULL,
    folder_flag "flag" NOT NULL CONSTRAINT "DF_Document_FolderFlag" DEFAULT (false),
    file_name varchar(400) NOT NULL,
    file_extension varchar(8) NULL,
    revision char(5) NOT NULL,
    change_number INT NOT NULL CONSTRAINT "DF_Document_ChangeNumber" DEFAULT (0),
    status smallint NOT NULL, -- tinyint
    document_summary text NULL,
    document bytea  NULL, -- varbinary
    row_guid uuid NOT NULL UNIQUE CONSTRAINT "DF_Document_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Document_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Document_Status" CHECK (status BETWEEN 1 AND 3)
  )
  CREATE TABLE product_category(
    product_category_id SERIAL NOT NULL, -- int
    name "name" NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_ProductCategory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductCategory_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product_subcategory(
    product_subcategory_id SERIAL NOT NULL, -- int
    product_category_id INT NOT NULL,
    name "name" NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_ProductSubcategory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductSubcategory_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product_model(
    product_model_id SERIAL NOT NULL, -- int
    name "name" NOT NULL,
    catalog_description XML NULL, -- XML(Production.ProductDescriptionSchemaCollection)
    instructions XML NULL, -- XML(Production.ManuInstructionsSchemaCollection)
    row_guid uuid NOT NULL CONSTRAINT "DF_ProductModel_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductModel_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product(
    product_id SERIAL NOT NULL, -- int
    name "name" NOT NULL,
    product_number varchar(25) NOT NULL,
    make_flag "flag" NOT NULL CONSTRAINT "DF_Product_MakeFlag" DEFAULT (true),
    finished_goods_flag "flag" NOT NULL CONSTRAINT "DF_Product_FinishedGoodsFlag" DEFAULT (true),
    color varchar(15) NULL,
    safety_stock_level smallint NOT NULL,
    reorder_point smallint NOT NULL,
    standard_cost numeric NOT NULL, -- money
    list_price numeric NOT NULL, -- money
    size varchar(5) NULL,
    size_unit_measure_code char(3) NULL,
    weight_unit_measure_code char(3) NULL,
    weight decimal(8, 2) NULL,
    days_to_manufacture INT NOT NULL,
    product_line char(2) NULL,
    class char(2) NULL,
    style char(2) NULL,
    product_subcategory_id INT NULL,
    product_model_id INT NULL,
    sell_start_date TIMESTAMP NOT NULL,
    sell_end_date TIMESTAMP NULL,
    discontinued_date TIMESTAMP NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_Product_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Product_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Product_SafetyStockLevel" CHECK (safety_stock_level > 0),
    CONSTRAINT "CK_Product_ReorderPoint" CHECK (reorder_point > 0),
    CONSTRAINT "CK_Product_StandardCost" CHECK (standard_cost >= 0.00),
    CONSTRAINT "CK_Product_ListPrice" CHECK (list_price >= 0.00),
    CONSTRAINT "CK_Product_Weight" CHECK (weight > 0.00),
    CONSTRAINT "CK_Product_DaysToManufacture" CHECK (days_to_manufacture >= 0),
    CONSTRAINT "CK_Product_ProductLine" CHECK (UPPER(product_line) IN ('S', 'T', 'M', 'R') OR product_line IS NULL),
    CONSTRAINT "CK_Product_Class" CHECK (UPPER(class) IN ('L', 'M', 'H') OR class IS NULL),
    CONSTRAINT "CK_Product_Style" CHECK (UPPER(style) IN ('W', 'M', 'U') OR style IS NULL),
    CONSTRAINT "CK_Product_SellEndDate" CHECK ((sell_end_date >= sell_start_date) OR (sell_end_date IS NULL))
  )
  CREATE TABLE product_cost_history(
    product_id INT NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NULL,
    standard_cost numeric NOT NULL,  -- money
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductCostHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ProductCostHistory_EndDate" CHECK ((end_date >= start_date) OR (end_date IS NULL)),
    CONSTRAINT "CK_ProductCostHistory_StandardCost" CHECK (standard_cost >= 0.00)
  )
  CREATE TABLE product_description(
    product_description_id SERIAL NOT NULL, -- int
    description varchar(400) NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_ProductDescription_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductDescription_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product_document(
    product_id INT NOT NULL,
    doc varchar NOT NULL, -- hierarchyid, will become document_node
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductDocument_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE location(
    location_id SERIAL NOT NULL, -- smallint
    name "name" NOT NULL,
    cost_rate numeric NOT NULL CONSTRAINT "DF_Location_CostRate" DEFAULT (0.00), -- smallmoney -- money
    availability decimal(8, 2) NOT NULL CONSTRAINT "DF_Location_Availability" DEFAULT (0.00),
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Location_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Location_CostRate" CHECK (cost_rate >= 0.00),
    CONSTRAINT "CK_Location_Availability" CHECK (availability >= 0.00)
  )
  CREATE TABLE product_inventory(
    product_id INT NOT NULL,
    location_id smallint NOT NULL,
    shelf varchar(10) NOT NULL,
    bin smallint NOT NULL, -- tinyint
    quantity smallint NOT NULL CONSTRAINT "DF_ProductInventory_Quantity" DEFAULT (0),
    row_guid uuid NOT NULL CONSTRAINT "DF_ProductInventory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductInventory_ModifiedDate" DEFAULT (NOW()),
--    CONSTRAINT "CK_ProductInventory_Shelf" CHECK ((shelf LIKE 'AZa-z]') OR (shelf = 'N/A')),
    CONSTRAINT "CK_ProductInventory_Bin" CHECK (bin BETWEEN 0 AND 100)
  )
  CREATE TABLE product_list_price_history(
    product_id INT NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NULL,
    list_price numeric NOT NULL,  -- money
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductListPriceHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ProductListPriceHistory_EndDate" CHECK ((end_date >= start_date) OR (end_date IS NULL)),
    CONSTRAINT "CK_ProductListPriceHistory_ListPrice" CHECK (list_price > 0.00)
  )
  CREATE TABLE illustration(
    illustration_id SERIAL NOT NULL, -- int
    diagram XML NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Illustration_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product_model_illustration(
    product_model_id INT NOT NULL,
    illustration_id INT NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductModelIllustration_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product_model_product_description_culture(
    product_model_id INT NOT NULL,
    product_description_id INT NOT NULL,
    culture_id char(6) NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductModelProductDescriptionCulture_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product_photo(
    product_photo_id SERIAL NOT NULL, -- int
    thumbnail_photo bytea NULL,-- varbinary
    thumbnail_photo_file_name varchar(50) NULL,
    large_photo bytea NULL,-- varbinary
    large_photo_file_name varchar(50) NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductPhoto_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product_product_photo(
    product_id INT NOT NULL,
    product_photo_id INT NOT NULL,
    "primary" "flag" NOT NULL CONSTRAINT "DF_ProductProductPhoto_Primary" DEFAULT (false),
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductProductPhoto_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE product_review(
    product_review_id SERIAL NOT NULL, -- int
    product_id INT NOT NULL,
    reviewer_name "name" NOT NULL,
    review_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductReview_ReviewDate" DEFAULT (NOW()),
    email_address varchar(50) NOT NULL,
    rating INT NOT NULL,
    comments varchar(3850),
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductReview_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ProductReview_Rating" CHECK (rating BETWEEN 1 AND 5)
  )
  CREATE TABLE scrap_reason(
    scrap_reason_id SERIAL NOT NULL, -- smallint
    name "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ScrapReason_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE transaction_history(
    transaction_id SERIAL NOT NULL, -- INT IDENTITY (100000, 1)
    product_id INT NOT NULL,
    reference_order_id INT NOT NULL,
    reference_order_line_id INT NOT NULL CONSTRAINT "DF_TransactionHistory_ReferenceOrderLineID" DEFAULT (0),
    transaction_date TIMESTAMP NOT NULL CONSTRAINT "DF_TransactionHistory_TransactionDate" DEFAULT (NOW()),
    transaction_type char(1) NOT NULL,
    quantity INT NOT NULL,
    actual_cost numeric NOT NULL,  -- money
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_TransactionHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_TransactionHistory_TransactionType" CHECK (UPPER(transaction_type) IN ('W', 'S', 'P'))
  )
  CREATE TABLE transaction_history_archive(
    transaction_id INT NOT NULL,
    product_id INT NOT NULL,
    reference_order_id INT NOT NULL,
    reference_order_line_id INT NOT NULL CONSTRAINT "DF_TransactionHistoryArchive_ReferenceOrderLineID" DEFAULT (0),
    transaction_date TIMESTAMP NOT NULL CONSTRAINT "DF_TransactionHistoryArchive_TransactionDate" DEFAULT (NOW()),
    transaction_type char(1) NOT NULL,
    quantity INT NOT NULL,
    actual_cost numeric NOT NULL,  -- money
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_TransactionHistoryArchive_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_TransactionHistoryArchive_TransactionType" CHECK (UPPER(transaction_type) IN ('W', 'S', 'P'))
  )
  CREATE TABLE unit_measure(
    unit_measure_code char(3) NOT NULL,
    name "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_UnitMeasure_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE work_order(
    work_order_id SERIAL NOT NULL, -- int
    product_id INT NOT NULL,
    order_qty INT NOT NULL,
    stocked_qty INT, -- AS ISNULL(order_qty - scrapped_qty, 0),
    scrapped_qty smallint NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NULL,
    due_date TIMESTAMP NOT NULL,
    scrap_reason_id smallint NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_WorkOrder_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_WorkOrder_OrderQty" CHECK (order_qty > 0),
    CONSTRAINT "CK_WorkOrder_ScrappedQty" CHECK (scrapped_qty >= 0),
    CONSTRAINT "CK_WorkOrder_EndDate" CHECK ((end_date >= start_date) OR (end_date IS NULL))
  )
  CREATE TABLE work_order_routing(
    work_order_id INT NOT NULL,
    product_id INT NOT NULL,
    operation_sequence smallint NOT NULL,
    location_id smallint NOT NULL,
    scheduled_start_date TIMESTAMP NOT NULL,
    scheduled_end_date TIMESTAMP NOT NULL,
    actual_start_date TIMESTAMP NULL,
    actual_end_date TIMESTAMP NULL,
    actual_resource_hrs decimal(9, 4) NULL,
    planned_cost numeric NOT NULL, -- money
    actual_cost numeric NULL,  -- money
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_WorkOrderRouting_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_WorkOrderRouting_ScheduledEndDate" CHECK (scheduled_end_date >= scheduled_start_date),
    CONSTRAINT "CK_WorkOrderRouting_ActualEndDate" CHECK ((actual_end_date >= actual_start_date)
        OR (actual_end_date IS NULL) OR (actual_start_date IS NULL)),
    CONSTRAINT "CK_WorkOrderRouting_ActualResourceHrs" CHECK (actual_resource_hrs >= 0.0000),
    CONSTRAINT "CK_WorkOrderRouting_PlannedCost" CHECK (planned_cost > 0.00),
    CONSTRAINT "CK_WorkOrderRouting_ActualCost" CHECK (actual_cost > 0.00)
  );

COMMENT ON SCHEMA production IS 'Contains objects related to products, inventory, and manufacturing.';

SELECT 'Copying data into production.bill_of_materials';
\copy production.bill_of_materials FROM 'bill_of_materials.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.culture';
\copy production.culture FROM 'culture.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.document';
\copy production.document FROM 'document.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_category';
\copy production.product_category FROM 'product_category.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_subcategory';
\copy production.product_subcategory FROM 'product_subcategory.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_model';
\copy production.product_model FROM 'product_model.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product';
\copy production.product FROM 'product.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_cost_history';
\copy production.product_cost_history FROM 'product_cost_history.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_description';
\copy production.product_description FROM 'product_description.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_document';
\copy production.product_document FROM 'product_document.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.location';
\copy production.location FROM 'location.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_inventory';
\copy production.product_inventory FROM 'product_inventory.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_list_price_history';
\copy production.product_list_price_history FROM 'product_list_price_history.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.illustration';
\copy production.illustration FROM 'illustration.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_model_illustration';
\copy production.product_model_illustration FROM 'product_model_illustration.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_model_product_description_culture';
\copy production.product_model_product_description_culture FROM 'product_model_product_description_culture.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_photo';
\copy production.product_photo FROM 'product_photo.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.product_product_photo';
\copy production.product_product_photo FROM 'product_product_photo.csv' DELIMITER E'\t' CSV;

-- This doesn't work:
-- SELECT 'Copying data into production.product_review';
-- \copy production.product_review FROM 'product_review.csv' DELIMITER '  ' CSV;

-- so instead ...
INSERT INTO production.product_review (product_review_id, product_id, reviewer_name, review_date, email_address, rating, comments, modified_date) VALUES
 (1, 709, 'John Smith', '2013-09-18 00:00:00', 'john@fourthcoffee.com', 5, 'I can''t believe I''m singing the praises of a pair of socks, but I just came back from a grueling
3-day ride and these socks really helped make the trip a blast. They''re lightweight yet really cushioned my feet all day. 
The reinforced toe is nearly bullet-proof and I didn''t experience any problems with rubbing or blisters like I have with
other brands. I know it sounds silly, but it''s always the little stuff (like comfortable feet) that makes or breaks a long trip.
I won''t go on another trip without them!', '2013-09-18 00:00:00'),

 (2, 937, 'David', '2013-11-13 00:00:00', 'david@graphicdesigninstitute.com', 4, 'A little on the heavy side, but overall the entry/exit is easy in all conditions. I''ve used these pedals for 
more than 3 years and I''ve never had a problem. Cleanup is easy. Mud and sand don''t get trapped. I would like 
them even better if there was a weight reduction. Maybe in the next design. Still, I would recommend them to a friend.', '2013-11-13 00:00:00'),

 (3, 937, 'Jill', '2013-11-15 00:00:00', 'jill@margiestravel.com', 2, 'Maybe it''s just because I''m new to mountain biking, but I had a terrible time getting use
to these pedals. In my first outing, I wiped out trying to release my foot. Any suggestions on
ways I can adjust the pedals, or is it just a learning curve thing?', '2013-11-15 00:00:00'),

 (4, 798, 'Laura Norman', '2013-11-15 00:00:00', 'laura@treyresearch.net', 5, 'The Road-550-W from Adventure Works Cycles is everything it''s advertised to be. Finally, a quality bike that
is actually built for a woman and provides control and comfort in one neat package. The top tube is shorter, the suspension is weight-tuned and there''s a much shorter reach to the brake
levers. All this adds up to a great mountain bike that is sure to accommodate any woman''s anatomy. In addition to getting the size right, the saddle is incredibly comfortable. 
Attention to detail is apparent in every aspect from the frame finish to the careful design of each component. Each component is a solid performer without any fluff. 
The designers clearly did their homework and thought about size, weight, and funtionality throughout. And at less than 19 pounds, the bike is manageable for even the most petite cyclist.

We had 5 riders take the bike out for a spin and really put it to the test. The results were consistent and very positive. Our testers loved the manuverability 
and control they had with the redesigned frame on the 550-W. A definite improvement over the 2012 design. Four out of five testers listed quick handling
and responsivness were the key elements they noticed. Technical climbing and on the flats, the bike just cruises through the rough. Tight corners and obstacles were handled effortlessly. The fifth tester was more impressed with the smooth ride. The heavy-duty shocks absorbed even the worst bumps and provided a soft ride on all but the 
nastiest trails and biggest drops. The shifting was rated superb and typical of what we''ve come to expect from Adventure Works Cycles. On descents, the bike handled flawlessly and tracked very well. The bike is well balanced front-to-rear and frame flex was minimal. In particular, the testers
noted that the brake system had a unique combination of power and modulation.  While some brake setups can be overly touchy, these brakes had a good
amount of power, but also a good feel that allows you to apply as little or as much braking power as is needed. Second is their short break-in period. We found that they tend to break-in well before
the end of the first ride; while others take two to three rides (or more) to come to full power. 

On the negative side, the pedals were not quite up to our tester''s standards. 
Just for fun, we experimented with routine maintenance tasks. Overall we found most operations to be straight forward and easy to complete. The only exception was replacing the front wheel. The maintenance manual that comes
with the bike say to install the front wheel with the axle quick release or bolt, then compress the fork a few times before fastening and tightening the two quick-release mechanisms on the bottom of the dropouts. This is to seat the axle in the dropouts, and if you do not
do this, the axle will become seated after you tightened the two bottom quick releases, which will then become loose. It''s better to test the tightness carefully or you may notice that the two bottom quick releases have come loose enough to fall completely open. And that''s something you don''t want to experience
while out on the road! 

The Road-550-W frame is available in a variety of sizes and colors and has the same durable, high-quality aluminum that AWC is known for. At a MSRP of just under $1125.00, it''s comparable in price to its closest competitors and
we think that after a test drive you''l find the quality and performance above and beyond . You''ll have a grin on your face and be itching to get out on the road for more. While designed for serious road racing, the Road-550-W would be an excellent choice for just about any terrain and 
any level of experience. It''s a huge step in the right direction for female cyclists and well worth your consideration and hard-earned money.', '2013-11-15 00:00:00');

SELECT 'Copying data into production.scrap_reason';
\copy production.scrap_reason FROM 'scrap_reason.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.transaction_history';
\copy production.transaction_history FROM 'transaction_history.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.transaction_history_archive';
\copy production.transaction_history_archive FROM 'transaction_history_archive.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.unit_measure';
\copy production.unit_measure FROM 'unit_measure.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.work_order';
\copy production.work_order FROM 'work_order.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into production.work_order_routing';
\copy production.work_order_routing FROM 'work_order_routing.csv' DELIMITER E'\t' CSV;

-- Calculated columns that needed to be there just for the CSV import
ALTER TABLE production.work_order DROP COLUMN stocked_qty;
ALTER TABLE production.document DROP COLUMN document_level;

-- document HierarchyID column
ALTER TABLE production.document ADD document_node VARCHAR DEFAULT '/';
-- Convert from all the hex to a stream of hierarchyid bits
WITH RECURSIVE hier AS (
  SELECT row_guid, doc, get_byte(decode(substring(doc, 1, 2), 'hex'), 0)::bit(8)::varchar AS bits, 2 AS i
    FROM production.document
  UNION ALL
  SELECT e.row_guid, e.doc, hier.bits || get_byte(decode(substring(e.doc, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 AS i
    FROM production.document AS e INNER JOIN
      hier ON e.row_guid = hier.row_guid AND i < LENGTH(e.doc)
)
UPDATE production.document AS emp
  SET doc = COALESCE(trim(trailing '0' FROM hier.bits::TEXT), '')
  FROM hier
  WHERE emp.row_guid = hier.row_guid
    AND (hier.doc IS NULL OR i = LENGTH(hier.doc));

-- Convert bits to the real hieararchy paths
CREATE OR REPLACE FUNCTION f_ConvertDocNodes()
  RETURNS void AS
$func$
DECLARE
  got_none BOOLEAN;
BEGIN
  LOOP
  got_none := true;
  -- 01 = 0-3
  UPDATE production.document
   SET document_node = document_node || SUBSTRING(doc, 3,2)::bit(2)::INTEGER::VARCHAR || CASE SUBSTRING(doc, 5, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 6, 9999)
    WHERE doc LIKE '01%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 100 = 4-7
  UPDATE production.document
   SET document_node = document_node || (SUBSTRING(doc, 4,2)::bit(2)::INTEGER + 4)::VARCHAR || CASE SUBSTRING(doc, 6, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 7, 9999)
    WHERE doc LIKE '100%';
  IF FOUND THEN
    got_none := false;
  END IF;
  
  -- 101 = 8-15
  UPDATE production.document
   SET document_node = document_node || (SUBSTRING(doc, 4,3)::bit(3)::INTEGER + 8)::VARCHAR || CASE SUBSTRING(doc, 7, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 8, 9999)
    WHERE doc LIKE '101%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 110 = 16-79
  UPDATE production.document
   SET document_node = document_node || ((SUBSTRING(doc, 4,2)||SUBSTRING(doc, 7,1)||SUBSTRING(doc, 9,3))::bit(6)::INTEGER + 16)::VARCHAR || CASE SUBSTRING(doc, 12, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 13, 9999)
    WHERE doc LIKE '110%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 1110 = 80-1103
  UPDATE production.document
   SET document_node = document_node || ((SUBSTRING(doc, 5,3)||SUBSTRING(doc, 9,3)||SUBSTRING(doc, 13,1)||SUBSTRING(doc, 15,3))::bit(10)::INTEGER + 80)::VARCHAR || CASE SUBSTRING(doc, 18, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 19, 9999)
    WHERE doc LIKE '1110%';
  IF FOUND THEN
    got_none := false;
  END IF;
  EXIT WHEN got_none;
  END LOOP;
END
$func$ LANGUAGE plpgsql;

SELECT f_ConvertDocNodes();
-- Drop the original binary hierarchyid column
ALTER TABLE production.document DROP COLUMN doc;
DROP FUNCTION f_ConvertDocNodes();

-- product_document HierarchyID column
  ALTER TABLE production.product_document ADD document_node VARCHAR DEFAULT '/';
ALTER TABLE production.product_document ADD row_guid uuid NOT NULL CONSTRAINT "DF_ProductDocument_rowguid" DEFAULT (uuid_generate_v1());
-- Convert from all the hex to a stream of hierarchyid bits
WITH RECURSIVE hier AS (
  SELECT row_guid, doc, get_byte(decode(substring(doc, 1, 2), 'hex'), 0)::bit(8)::varchar AS bits, 2 AS i
    FROM production.product_document
  UNION ALL
  SELECT e.row_guid, e.doc, hier.bits || get_byte(decode(substring(e.doc, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 AS i
    FROM production.product_document AS e INNER JOIN
      hier ON e.row_guid = hier.row_guid AND i < LENGTH(e.doc)
)
UPDATE production.product_document AS emp
  SET doc = COALESCE(trim(trailing '0' FROM hier.bits::TEXT), '')
  FROM hier
  WHERE emp.row_guid = hier.row_guid
    AND (hier.doc IS NULL OR i = LENGTH(hier.doc));

-- Convert bits to the real hieararchy paths
CREATE OR REPLACE FUNCTION f_ConvertDocNodes()
  RETURNS void AS
$func$
DECLARE
  got_none BOOLEAN;
BEGIN
  LOOP
  got_none := true;
  -- 01 = 0-3
  UPDATE production.product_document
   SET document_node = document_node || SUBSTRING(doc, 3,2)::bit(2)::INTEGER::VARCHAR || CASE SUBSTRING(doc, 5, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 6, 9999)
    WHERE doc LIKE '01%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 100 = 4-7
  UPDATE production.product_document
   SET document_node = document_node || (SUBSTRING(doc, 4,2)::bit(2)::INTEGER + 4)::VARCHAR || CASE SUBSTRING(doc, 6, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 7, 9999)
    WHERE doc LIKE '100%';
  IF FOUND THEN
    got_none := false;
  END IF;
  
  -- 101 = 8-15
  UPDATE production.product_document
   SET document_node = document_node || (SUBSTRING(doc, 4,3)::bit(3)::INTEGER + 8)::VARCHAR || CASE SUBSTRING(doc, 7, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 8, 9999)
    WHERE doc LIKE '101%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 110 = 16-79
  UPDATE production.product_document
   SET document_node = document_node || ((SUBSTRING(doc, 4,2)||SUBSTRING(doc, 7,1)||SUBSTRING(doc, 9,3))::bit(6)::INTEGER + 16)::VARCHAR || CASE SUBSTRING(doc, 12, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 13, 9999)
    WHERE doc LIKE '110%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 1110 = 80-1103
  UPDATE production.product_document
   SET document_node = document_node || ((SUBSTRING(doc, 5,3)||SUBSTRING(doc, 9,3)||SUBSTRING(doc, 13,1)||SUBSTRING(doc, 15,3))::bit(10)::INTEGER + 80)::VARCHAR || CASE SUBSTRING(doc, 18, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 19, 9999)
    WHERE doc LIKE '1110%';
  IF FOUND THEN
    got_none := false;
  END IF;
  EXIT WHEN got_none;
  END LOOP;
END
$func$ LANGUAGE plpgsql;

SELECT f_ConvertDocNodes();
-- Drop the original binary hierarchyid column
ALTER TABLE production.product_document DROP COLUMN doc;
DROP FUNCTION f_ConvertDocNodes();
ALTER TABLE production.product_document DROP COLUMN row_guid;





CREATE SCHEMA purchasing
  CREATE TABLE product_vendor(
    product_id INT NOT NULL,
    business_entity_id INT NOT NULL,
    average_lead_time INT NOT NULL,
    standard_price numeric NOT NULL, -- money
    last_receipt_cost numeric NULL, -- money
    last_receipt_date TIMESTAMP NULL,
    min_order_qty INT NOT NULL,
    max_order_qty INT NOT NULL,
    on_order_qty INT NULL,
    unit_measure_code char(3) NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ProductVendor_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ProductVendor_AverageLeadTime" CHECK (average_lead_time >= 1),
    CONSTRAINT "CK_ProductVendor_StandardPrice" CHECK (standard_price > 0.00),
    CONSTRAINT "CK_ProductVendor_LastReceiptCost" CHECK (last_receipt_cost > 0.00),
    CONSTRAINT "CK_ProductVendor_MinOrderQty" CHECK (min_order_qty >= 1),
    CONSTRAINT "CK_ProductVendor_MaxOrderQty" CHECK (max_order_qty >= 1),
    CONSTRAINT "CK_ProductVendor_OnOrderQty" CHECK (on_order_qty >= 0)
  )
  CREATE TABLE purchase_order_detail(
    purchase_order_id INT NOT NULL,
    purchase_order_detail_id SERIAL NOT NULL, -- int
    due_date TIMESTAMP NOT NULL,
    order_qty smallint NOT NULL,
    product_id INT NOT NULL,
    unit_price numeric NOT NULL, -- money
    line_total numeric, -- AS ISNULL(order_qty * unit_price, 0.00),
    received_qty decimal(8, 2) NOT NULL,
    rejected_qty decimal(8, 2) NOT NULL,
    stocked_qty numeric, -- AS ISNULL(received_qty - rejected_qty, 0.00),
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_PurchaseOrderDetail_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_PurchaseOrderDetail_OrderQty" CHECK (order_qty > 0),
    CONSTRAINT "CK_PurchaseOrderDetail_UnitPrice" CHECK (unit_price >= 0.00),
    CONSTRAINT "CK_PurchaseOrderDetail_ReceivedQty" CHECK (received_qty >= 0.00),
    CONSTRAINT "CK_PurchaseOrderDetail_RejectedQty" CHECK (rejected_qty >= 0.00)
  )
  CREATE TABLE purchase_order_header(
    purchase_order_id SERIAL NOT NULL,  -- int
    revision_number smallint NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_RevisionNumber" DEFAULT (0),  -- tinyint
    status smallint NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_Status" DEFAULT (1),  -- tinyint
    employee_id INT NOT NULL,
    vendor_id INT NOT NULL,
    ship_method_id INT NOT NULL,
    order_date TIMESTAMP NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_OrderDate" DEFAULT (NOW()),
    ship_date TIMESTAMP NULL,
    sub_total numeric NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_SubTotal" DEFAULT (0.00),  -- money
    tax_amt numeric NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_TaxAmt" DEFAULT (0.00),  -- money
    freight numeric NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_Freight" DEFAULT (0.00),  -- money
    total_due numeric, -- AS ISNULL(sub_total + tax_amt + freight, 0) PERSISTED NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_PurchaseOrderHeader_Status" CHECK (status BETWEEN 1 AND 4), -- 1 = Pending; 2 = Approved; 3 = Rejected; 4 = Complete
    CONSTRAINT "CK_PurchaseOrderHeader_ShipDate" CHECK ((ship_date >= order_date) OR (ship_date IS NULL)),
    CONSTRAINT "CK_PurchaseOrderHeader_SubTotal" CHECK (sub_total >= 0.00),
    CONSTRAINT "CK_PurchaseOrderHeader_TaxAmt" CHECK (tax_amt >= 0.00),
    CONSTRAINT "CK_PurchaseOrderHeader_Freight" CHECK (freight >= 0.00)
  )
  CREATE TABLE ship_method(
    ship_method_id SERIAL NOT NULL, -- int
    name "name" NOT NULL,
    ship_base numeric NOT NULL CONSTRAINT "DF_ShipMethod_ShipBase" DEFAULT (0.00), -- money
    ship_rate numeric NOT NULL CONSTRAINT "DF_ShipMethod_ShipRate" DEFAULT (0.00), -- money
    row_guid uuid NOT NULL CONSTRAINT "DF_ShipMethod_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ShipMethod_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ShipMethod_ShipBase" CHECK (ship_base > 0.00),
    CONSTRAINT "CK_ShipMethod_ShipRate" CHECK (ship_rate > 0.00)
  )
  CREATE TABLE vendor(
    business_entity_id INT NOT NULL,
    account_number "account_number" NOT NULL,
    name "name" NOT NULL,
    credit_rating smallint NOT NULL, -- tinyint
    preferred_vendor_status "flag" NOT NULL CONSTRAINT "DF_Vendor_PreferredVendorStatus" DEFAULT (true),
    active_flag "flag" NOT NULL CONSTRAINT "DF_Vendor_ActiveFlag" DEFAULT (true),
    purchasing_web_service_url varchar(1024) NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Vendor_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Vendor_CreditRating" CHECK (credit_rating BETWEEN 1 AND 5)
  );

COMMENT ON SCHEMA purchasing IS 'Contains objects related to vendors and purchase orders.';

SELECT 'Copying data into purchasing.product_vendor';
\copy purchasing.product_vendor FROM 'product_vendor.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into purchasing.purchase_order_detail';
\copy purchasing.purchase_order_detail FROM 'purchase_order_detail.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into purchasing.purchase_order_header';
\copy purchasing.purchase_order_header FROM 'purchase_order_header.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into purchasing.ship_method';
\copy purchasing.ship_method FROM 'ship_method.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into purchasing.vendor';
\copy purchasing.vendor FROM 'vendor.csv' DELIMITER E'\t' CSV;

-- Calculated columns that needed to be there just for the CSV import
ALTER TABLE purchasing.purchase_order_detail DROP COLUMN line_total;
ALTER TABLE purchasing.purchase_order_detail DROP COLUMN stocked_qty;
ALTER TABLE purchasing.purchase_order_header DROP COLUMN total_due;



CREATE SCHEMA sales
  CREATE TABLE country_region_currency(
    country_region_code varchar(3) NOT NULL,
    currency_code char(3) NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_CountryRegionCurrency_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE credit_card(
    credit_card_id SERIAL NOT NULL, -- int
    card_type varchar(50) NOT NULL,
    card_number varchar(25) NOT NULL,
    exp_month smallint NOT NULL, -- tinyint
    exp_year smallint NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_CreditCard_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE currency(
    currency_code char(3) NOT NULL,
    name "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Currency_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE currency_rate(
    currency_rate_id SERIAL NOT NULL, -- int
    currency_rate_date TIMESTAMP NOT NULL,   
    from_currency_code char(3) NOT NULL,
    to_currency_code char(3) NOT NULL,
    average_rate numeric NOT NULL, -- money
    end_of_date_rate numeric NOT NULL,  -- money
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_CurrencyRate_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE customer(
    customer_id SERIAL NOT NULL, --  NOT FOR REPLICATION -- int
    -- A customer may either be a person, a store, or a person who works for a store
    person_id INT NULL, -- If this customer represents a person, this is non-null
    store_id INT NULL,  -- If the customer is a store, or is associated with a store then this is non-null.
    territory_id INT NULL,
    account_number VARCHAR, -- AS ISNULL('AW' + dbo.ufnLeadingZeros(customer_id), ''),
    row_guid uuid NOT NULL CONSTRAINT "DF_Customer_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Customer_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE person_credit_card(
    business_entity_id INT NOT NULL,
    credit_card_id INT NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_PersonCreditCard_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE sales_order_detail(
    sales_order_id INT NOT NULL,
    sales_order_detail_id SERIAL NOT NULL, -- int
    carrier_tracking_number varchar(25) NULL,
    order_qty smallint NOT NULL,
    product_id INT NOT NULL,
    special_offer_id INT NOT NULL,
    unit_price numeric NOT NULL, -- money
    unit_price_discount numeric NOT NULL CONSTRAINT "DF_SalesOrderDetail_UnitPriceDiscount" DEFAULT (0.0), -- money
    line_total numeric, -- AS ISNULL(unit_price * (1.0 - unit_price_discount) * order_qty, 0.0),
    row_guid uuid NOT NULL CONSTRAINT "DF_SalesOrderDetail_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesOrderDetail_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesOrderDetail_OrderQty" CHECK (order_qty > 0),
    CONSTRAINT "CK_SalesOrderDetail_UnitPrice" CHECK (unit_price >= 0.00),
    CONSTRAINT "CK_SalesOrderDetail_UnitPriceDiscount" CHECK (unit_price_discount >= 0.00)
  )
  CREATE TABLE sales_order_header(
    sales_order_id SERIAL NOT NULL, --  NOT FOR REPLICATION -- int
    revision_number smallint NOT NULL CONSTRAINT "DF_SalesOrderHeader_RevisionNumber" DEFAULT (0), -- tinyint
    order_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesOrderHeader_OrderDate" DEFAULT (NOW()),
    due_date TIMESTAMP NOT NULL,
    ship_date TIMESTAMP NULL,
    status smallint NOT NULL CONSTRAINT "DF_SalesOrderHeader_Status" DEFAULT (1), -- tinyint
    online_order_flag "flag" NOT NULL CONSTRAINT "DF_SalesOrderHeader_OnlineOrderFlag" DEFAULT (true),
    sales_order_number VARCHAR(23), -- AS ISNULL(N'SO' + CONVERT(nvarchar(23), sales_order_id), N'*** ERROR ***'),
    purchase_order_number "order_number" NULL,
    account_number "account_number" NULL,
    customer_id INT NOT NULL,
    sales_person_id INT NULL,
    territory_id INT NULL,
    bill_to_address_id INT NOT NULL,
    ship_to_address_id INT NOT NULL,
    ship_method_id INT NOT NULL,
    credit_card_id INT NULL,
    credit_card_approval_code varchar(15) NULL,   
    currency_rate_id INT NULL,
    sub_total numeric NOT NULL CONSTRAINT "DF_SalesOrderHeader_SubTotal" DEFAULT (0.00), -- money
    tax_amt numeric NOT NULL CONSTRAINT "DF_SalesOrderHeader_TaxAmt" DEFAULT (0.00), -- money
    freight numeric NOT NULL CONSTRAINT "DF_SalesOrderHeader_Freight" DEFAULT (0.00), -- money
    total_due numeric, -- AS ISNULL(sub_total + tax_amt + freight, 0),
    comment varchar(128) NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_SalesOrderHeader_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesOrderHeader_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesOrderHeader_Status" CHECK (status BETWEEN 0 AND 8),
    CONSTRAINT "CK_SalesOrderHeader_DueDate" CHECK (due_date >= order_date),
    CONSTRAINT "CK_SalesOrderHeader_ShipDate" CHECK ((ship_date >= order_date) OR (ship_date IS NULL)),
    CONSTRAINT "CK_SalesOrderHeader_SubTotal" CHECK (sub_total >= 0.00),
    CONSTRAINT "CK_SalesOrderHeader_TaxAmt" CHECK (tax_amt >= 0.00),
    CONSTRAINT "CK_SalesOrderHeader_Freight" CHECK (freight >= 0.00)
  )
  CREATE TABLE sales_order_header_sales_reason(
    sales_order_id INT NOT NULL,
    sales_reason_id INT NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesOrderHeaderSalesReason_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE sales_person(
    business_entity_id INT NOT NULL,
    territory_id INT NULL,
    sales_quota numeric NULL, -- money
    bonus numeric NOT NULL CONSTRAINT "DF_SalesPerson_Bonus" DEFAULT (0.00), -- money
    commission_pct numeric NOT NULL CONSTRAINT "DF_SalesPerson_CommissionPct" DEFAULT (0.00), -- smallmoney -- money
    sales_ytd numeric NOT NULL CONSTRAINT "DF_SalesPerson_SalesYTD" DEFAULT (0.00), -- money
    sales_last_year numeric NOT NULL CONSTRAINT "DF_SalesPerson_SalesLastYear" DEFAULT (0.00), -- money
    row_guid uuid NOT NULL CONSTRAINT "DF_SalesPerson_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesPerson_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesPerson_SalesQuota" CHECK (sales_quota > 0.00),
    CONSTRAINT "CK_SalesPerson_Bonus" CHECK (bonus >= 0.00),
    CONSTRAINT "CK_SalesPerson_CommissionPct" CHECK (commission_pct >= 0.00),
    CONSTRAINT "CK_SalesPerson_SalesYTD" CHECK (sales_ytd >= 0.00),
    CONSTRAINT "CK_SalesPerson_SalesLastYear" CHECK (sales_last_year >= 0.00)
  )
  CREATE TABLE sales_person_quota_history(
    business_entity_id INT NOT NULL,
    quota_date TIMESTAMP NOT NULL,
    sales_quota numeric NOT NULL, -- money
    row_guid uuid NOT NULL CONSTRAINT "DF_SalesPersonQuotaHistory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesPersonQuotaHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesPersonQuotaHistory_SalesQuota" CHECK (sales_quota > 0.00)
  )
  CREATE TABLE sales_reason(
    sales_reason_id SERIAL NOT NULL, -- int
    name "name" NOT NULL,
    reason_type "name" NOT NULL,
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesReason_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE sales_tax_rate(
    sales_tax_rate_id SERIAL NOT NULL, -- int
    state_province_id INT NOT NULL,
    tax_type smallint NOT NULL, -- tinyint
    tax_rate numeric NOT NULL CONSTRAINT "DF_SalesTaxRate_TaxRate" DEFAULT (0.00), -- smallmoney -- money
    name "name" NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_SalesTaxRate_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesTaxRate_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesTaxRate_TaxType" CHECK (tax_type BETWEEN 1 AND 3)
  )
  CREATE TABLE sales_territory(
    territory_id SERIAL NOT NULL, -- int
    name "name" NOT NULL,
    country_region_code varchar(3) NOT NULL,
    "group" varchar(50) NOT NULL, -- group
    sales_ytd numeric NOT NULL CONSTRAINT "DF_SalesTerritory_SalesYTD" DEFAULT (0.00), -- money
    sales_last_year numeric NOT NULL CONSTRAINT "DF_SalesTerritory_SalesLastYear" DEFAULT (0.00), -- money
    cost_ytd numeric NOT NULL CONSTRAINT "DF_SalesTerritory_CostYTD" DEFAULT (0.00), -- money
    cost_last_year numeric NOT NULL CONSTRAINT "DF_SalesTerritory_CostLastYear" DEFAULT (0.00), -- money
    row_guid uuid NOT NULL CONSTRAINT "DF_SalesTerritory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesTerritory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesTerritory_SalesYTD" CHECK (sales_ytd >= 0.00),
    CONSTRAINT "CK_SalesTerritory_SalesLastYear" CHECK (sales_last_year >= 0.00),
    CONSTRAINT "CK_SalesTerritory_CostYTD" CHECK (cost_ytd >= 0.00),
    CONSTRAINT "CK_SalesTerritory_CostLastYear" CHECK (cost_last_year >= 0.00)
  )
  CREATE TABLE sales_territory_history(
    business_entity_id INT NOT NULL,  -- A sales person
    territory_id INT NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_SalesTerritoryHistory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SalesTerritoryHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesTerritoryHistory_EndDate" CHECK ((end_date >= start_date) OR (end_date IS NULL))
  )
  CREATE TABLE shopping_cart_item(
    shopping_cart_item_id SERIAL NOT NULL, -- int
    shipping_card_id varchar(50) NOT NULL,
    quantity INT NOT NULL CONSTRAINT "DF_ShoppingCartItem_Quantity" DEFAULT (1),
    product_id INT NOT NULL,
    date_created TIMESTAMP NOT NULL CONSTRAINT "DF_ShoppingCartItem_DateCreated" DEFAULT (NOW()),
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_ShoppingCartItem_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ShoppingCartItem_Quantity" CHECK (quantity >= 1)
  )
  CREATE TABLE special_offer(
    special_offer_id SERIAL NOT NULL, -- int
    description varchar(255) NOT NULL,
    discount_pct numeric NOT NULL CONSTRAINT "DF_SpecialOffer_DiscountPct" DEFAULT (0.00), -- smallmoney -- money
    type varchar(50) NOT NULL,
    category varchar(50) NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    min_qty INT NOT NULL CONSTRAINT "DF_SpecialOffer_MinQty" DEFAULT (0),
    max_qty INT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_SpecialOffer_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SpecialOffer_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SpecialOffer_EndDate" CHECK (end_date >= start_date),
    CONSTRAINT "CK_SpecialOffer_DiscountPct" CHECK (discount_pct >= 0.00),
    CONSTRAINT "CK_SpecialOffer_MinQty" CHECK (min_qty >= 0),
    CONSTRAINT "CK_SpecialOffer_MaxQty"  CHECK (max_qty >= 0)
  )
  CREATE TABLE special_offer_product(
    special_offer_id INT NOT NULL,
    product_id INT NOT NULL,
    row_guid uuid NOT NULL CONSTRAINT "DF_SpecialOfferProduct_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_SpecialOfferProduct_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE store(
    business_entity_id INT NOT NULL,
    name "name" NOT NULL,
    sales_person_id INT NULL,
    demographics XML NULL, -- XML(sales.StoreSurveySchemaCollection)
    row_guid uuid NOT NULL CONSTRAINT "DF_Store_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    modified_date TIMESTAMP NOT NULL CONSTRAINT "DF_Store_ModifiedDate" DEFAULT (NOW())
  );

COMMENT ON SCHEMA sales IS 'Contains objects related to customers, sales orders, and sales territories.';

SELECT 'Copying data into sales.country_region_currency';
\copy sales.country_region_currency FROM 'country_region_currency.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.credit_card';
\copy sales.credit_card FROM 'credit_card.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.currency';
\copy sales.currency FROM 'currency.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.currency_rate';
\copy sales.currency_rate FROM 'currency_rate.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.customer';
\copy sales.customer FROM 'customer.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.person_credit_card';
\copy sales.person_credit_card FROM 'person_credit_card.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_order_detail';
\copy sales.sales_order_detail FROM 'sales_order_detail.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_order_header';
\copy sales.sales_order_header FROM 'sales_order_header.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_order_header_sales_reason';
\copy sales.sales_order_header_sales_reason FROM 'sales_order_header_sales_reason.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_person';
\copy sales.sales_person FROM 'sales_person.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_person_quota_history';
\copy sales.sales_person_quota_history FROM 'sales_person_quota_history.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_reason';
\copy sales.sales_reason FROM 'sales_reason.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_tax_rate';
\copy sales.sales_tax_rate FROM 'sales_tax_rate.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_territory';
\copy sales.sales_territory FROM 'sales_territory.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_territory_history';
\copy sales.sales_territory_history FROM 'sales_territory_history.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.shopping_cart_item';
\copy sales.shopping_cart_item FROM 'shopping_cart_item.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.special_offer';
\copy sales.special_offer FROM 'special_offer.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.special_offer_product';
\copy sales.special_offer_product FROM 'special_offer_product.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.store';
\copy sales.store FROM 'store.csv' DELIMITER E'\t' CSV;

-- Calculated columns that needed to be there just for the CSV import
ALTER TABLE sales.customer DROP COLUMN account_number;
ALTER TABLE sales.sales_order_detail DROP COLUMN line_total;
ALTER TABLE sales.sales_order_header DROP COLUMN sales_order_number;



-------------------------------------
-- TABLE AND COLUMN COMMENTS
-------------------------------------

SET CLIENT_ENCODING=latin1;

-- COMMENT ON TABLE dbo.AWBuildVersion IS 'Current version number of the adventure_works2012_CS sample database.';
--   COMMENT ON COLUMN dbo.AWBuildVersion.SystemInformationID IS 'Primary key for AWBuildVersion records.';
--   COMMENT ON COLUMN AWBui.COLU.Version IS 'Version number of the database in 9.yy.mm.dd.00 format.';
--   COMMENT ON COLUMN dbo.AWBuildVersion.VersionDate IS 'Date and time the record was last updated.';

-- COMMENT ON TABLE dbo.DatabaseLog IS 'Audit table tracking all DDL changes made to the adventure_works database. Data is captured by the database trigger ddlDatabaseTriggerLog.';
--   COMMENT ON COLUMN dbo.DatabaseLog.PostTime IS 'The date and time the DDL change occurred.';
--   COMMENT ON COLUMN dbo.DatabaseLog.DatabaseUser IS 'The user who implemented the DDL change.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Event IS 'The type of DDL statement that was executed.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Schema IS 'The schema to which the changed object belongs.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Object IS 'The object that was changed by the DDL statment.';
--   COMMENT ON COLUMN dbo.DatabaseLog.TSQL IS 'The exact Transact-SQL statement that was executed.';
--   COMMENT ON COLUMN dbo.DatabaseLog.XmlEvent IS 'The raw XML data generated by database trigger.';

-- COMMENT ON TABLE dbo.ErrorLog IS 'Audit table tracking errors in the the adventure_works database that are caught by the CATCH block of a TRY...CATCH construct. Data is inserted by stored procedure dbo.uspLogError when it is executed from inside the CATCH block of a TRY...CATCH construct.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorLogID IS 'Primary key for ErrorLog records.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorTime IS 'The date and time at which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.UserName IS 'The user who executed the batch in which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorNumber IS 'The error number of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorSeverity IS 'The severity of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorState IS 'The state number of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorProcedure IS 'The name of the stored procedure or trigger where the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorLine IS 'The line number at which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorMessage IS 'The message text of the error that occurred.';

COMMENT ON TABLE person.address IS 'Street address information for customers, employees, and vendors.';
  COMMENT ON COLUMN person.address.address_id IS 'Primary key for address records.';
  COMMENT ON COLUMN person.address.address_line_1 IS 'First street address line.';
  COMMENT ON COLUMN person.address.address_line_2 IS 'Second street address line.';
  COMMENT ON COLUMN person.address.city IS 'name of the city.';
  COMMENT ON COLUMN person.address.state_province_id IS 'Unique identification number for the state or province. Foreign key to state_province table.';
  COMMENT ON COLUMN person.address.postal_code IS 'Postal code for the street address.';
  COMMENT ON COLUMN person.address.spatial_location IS 'Latitude and longitude of this address.';

COMMENT ON TABLE person.address_type IS 'Types of addresses stored in the address table.';
  COMMENT ON COLUMN person.address_type.address_type_id IS 'Primary key for address_type records.';
  COMMENT ON COLUMN person.address_type.name IS 'address type description. For example, Billing, Home, or Shipping.';

COMMENT ON TABLE production.bill_of_materials IS 'Items required to make bicycles and bicycle subassemblies. It identifies the heirarchical relationship between a parent product and its components.';
  COMMENT ON COLUMN production.bill_of_materials.bill_of_materials_id IS 'Primary key for bill_of_materials records.';
  COMMENT ON COLUMN production.bill_of_materials.product_assembly_id IS 'Parent product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.bill_of_materials.component_id IS 'Component identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.bill_of_materials.start_date IS 'Date the component started being used in the assembly item.';
  COMMENT ON COLUMN production.bill_of_materials.end_date IS 'Date the component stopped being used in the assembly item.';
  COMMENT ON COLUMN production.bill_of_materials.unit_measure_code IS 'Standard code identifying the unit of measure for the quantity.';
  COMMENT ON COLUMN production.bill_of_materials.bom_level IS 'Indicates the depth the component is from its parent (AssemblyID).';
  COMMENT ON COLUMN production.bill_of_materials.per_assembly_qty IS 'quantity of the component needed to create the assembly.';

COMMENT ON TABLE person.business_entity IS 'Source of the ID that connects vendors, customers, and employees with address and contact information.';
  COMMENT ON COLUMN person.business_entity.business_entity_id IS 'Primary key for all customers, vendors, and employees.';

COMMENT ON TABLE person.business_entity_address IS 'Cross-reference table mapping customers, vendors, and employees to their addresses.';
  COMMENT ON COLUMN person.business_entity_address.business_entity_id IS 'Primary key. Foreign key to business_entity.business_entity_id.';
  COMMENT ON COLUMN person.business_entity_address.address_id IS 'Primary key. Foreign key to address.address_id.';
  COMMENT ON COLUMN person.business_entity_address.address_type_id IS 'Primary key. Foreign key to address_type.address_type_id.';

COMMENT ON TABLE person.business_entity_contact IS 'Cross-reference table mapping stores, vendors, and employees to people';
  COMMENT ON COLUMN person.business_entity_contact.business_entity_id IS 'Primary key. Foreign key to business_entity.business_entity_id.';
  COMMENT ON COLUMN person.business_entity_contact.person_id IS 'Primary key. Foreign key to person.business_entity_id.';
  COMMENT ON COLUMN person.business_entity_contact.contact_type_id IS 'Primary key.  Foreign key to contact_type.contact_type_id.';

COMMENT ON TABLE person.contact_type IS 'Lookup table containing the types of business entity contacts.';
  COMMENT ON COLUMN person.contact_type.contact_type_id IS 'Primary key for contact_type records.';
  COMMENT ON COLUMN person.contact_type.name IS 'Contact type description.';

COMMENT ON TABLE sales.country_region_currency IS 'Cross-reference table mapping ISO currency codes to a country or region.';
  COMMENT ON COLUMN sales.country_region_currency.country_region_code IS 'ISO code for countries and regions. Foreign key to country_region.country_region_code.';
  COMMENT ON COLUMN sales.country_region_currency.currency_code IS 'ISO standard currency code. Foreign key to currency.currency_code.';

COMMENT ON TABLE person.country_region IS 'Lookup table containing the ISO standard codes for countries and regions.';
  COMMENT ON COLUMN person.country_region.country_region_code IS 'ISO standard code for countries and regions.';
  COMMENT ON COLUMN person.country_region.name IS 'Country or region name.';

COMMENT ON TABLE sales.credit_card IS 'customer credit card information.';
  COMMENT ON COLUMN sales.credit_card.credit_card_id IS 'Primary key for credit_card records.';
  COMMENT ON COLUMN sales.credit_card.card_type IS 'Credit card name.';
  COMMENT ON COLUMN sales.credit_card.card_number IS 'Credit card number.';
  COMMENT ON COLUMN sales.credit_card.exp_month IS 'Credit card expiration month.';
  COMMENT ON COLUMN sales.credit_card.exp_year IS 'Credit card expiration year.';

COMMENT ON TABLE production.culture IS 'Lookup table containing the languages in which some adventure_works data is stored.';
  COMMENT ON COLUMN production.culture.culture_id IS 'Primary key for culture records.';
  COMMENT ON COLUMN production.culture.name IS 'culture description.';

COMMENT ON TABLE sales.currency IS 'Lookup table containing standard ISO currencies.';
  COMMENT ON COLUMN sales.currency.currency_code IS 'The ISO code for the currency.';
  COMMENT ON COLUMN sales.currency.name IS 'currency name.';

COMMENT ON TABLE sales.currency_rate IS 'currency exchange rates.';
  COMMENT ON COLUMN sales.currency_rate.currency_rate_id IS 'Primary key for currency_rate records.';
  COMMENT ON COLUMN sales.currency_rate.currency_rate_date IS 'Date and time the exchange rate was obtained.';
  COMMENT ON COLUMN sales.currency_rate.from_currency_code IS 'Exchange rate was converted from this currency code.';
  COMMENT ON COLUMN sales.currency_rate.to_currency_code IS 'Exchange rate was converted to this currency code.';
  COMMENT ON COLUMN sales.currency_rate.average_rate IS 'Average exchange rate for the day.';
  COMMENT ON COLUMN sales.currency_rate.end_of_date_rate IS 'Final exchange rate for the day.';

COMMENT ON TABLE sales.customer IS 'Current customer information. Also see the person and store tables.';
  COMMENT ON COLUMN sales.customer.customer_id IS 'Primary key.';
  COMMENT ON COLUMN sales.customer.person_id IS 'Foreign key to person.business_entity_id';
  COMMENT ON COLUMN sales.customer.store_id IS 'Foreign key to store.business_entity_id';
  COMMENT ON COLUMN sales.customer.territory_id IS 'ID of the territory in which the customer is located. Foreign key to sales_territory.SalesTerritoryID.';
--  COMMENT ON COLUMN sales.customer.account_number IS 'Unique number identifying the customer assigned by the accounting system.';

COMMENT ON TABLE human_resources.department IS 'Lookup table containing the departments within the Adventure Works Cycles company.';
  COMMENT ON COLUMN human_resources.department.department_id IS 'Primary key for department records.';
  COMMENT ON COLUMN human_resources.department.name IS 'name of the department.';
  COMMENT ON COLUMN human_resources.department.group_name IS 'name of the group to which the department belongs.';

COMMENT ON TABLE production.document IS 'product maintenance documents.';
  COMMENT ON COLUMN production.document.document_node IS 'Primary key for document records.';
--  COMMENT ON COLUMN production.document.document_level IS 'Depth in the document hierarchy.';
  COMMENT ON COLUMN production.document.title IS 'title of the document.';
  COMMENT ON COLUMN production.document.owner IS 'employee who controls the document.  Foreign key to employee.business_entity_id';
  COMMENT ON COLUMN production.document.folder_flag IS '0 = This is a folder, 1 = This is a document.';
  COMMENT ON COLUMN production.document.file_name IS 'File name of the document';
  COMMENT ON COLUMN production.document.file_extension IS 'File extension indicating the document type. For example, .doc or .txt.';
  COMMENT ON COLUMN production.document.revision IS 'revision number of the document.';
  COMMENT ON COLUMN production.document.change_number IS 'Engineering change approval number.';
  COMMENT ON COLUMN production.document.status IS '1 = Pending approval, 2 = Approved, 3 = Obsolete';
  COMMENT ON COLUMN production.document.document_summary IS 'document abstract.';
  COMMENT ON COLUMN production.document.document IS 'Complete document.';
  COMMENT ON COLUMN production.document.row_guid IS 'ROWGUIDCOL number uniquely identifying the record. Required for FileStream.';

COMMENT ON TABLE person.email_address IS 'Where to send a person email.';
  COMMENT ON COLUMN person.email_address.business_entity_id IS 'Primary key. person associated with this email address.  Foreign key to person.business_entity_id';
  COMMENT ON COLUMN person.email_address.email_address_id IS 'Primary key. ID of this email address.';
  COMMENT ON COLUMN person.email_address.email_address IS 'E-mail address for the person.';

COMMENT ON TABLE human_resources.employee IS 'employee information such as salary, department, and title.';
  COMMENT ON COLUMN human_resources.employee.business_entity_id IS 'Primary key for employee records.  Foreign key to business_entity.business_entity_id.';
  COMMENT ON COLUMN human_resources.employee.national_id_number IS 'Unique national identification number such as a social security number.';
  COMMENT ON COLUMN human_resources.employee.login_id IS 'Network login.';
  COMMENT ON COLUMN human_resources.employee.organization_node IS 'Where the employee is located in corporate hierarchy.';
--  COMMENT ON COLUMN human_resources.employee.organization_level IS 'The depth of the employee in the corporate hierarchy.';
  COMMENT ON COLUMN human_resources.employee.job_title IS 'Work title such as Buyer or sales Representative.';
  COMMENT ON COLUMN human_resources.employee.birth_date IS 'Date of birth.';
  COMMENT ON COLUMN human_resources.employee.martial_status IS 'M = Married, S = Single';
  COMMENT ON COLUMN human_resources.employee.gender IS 'M = Male, F = Female';
  COMMENT ON COLUMN human_resources.employee.hire_date IS 'employee hired on this date.';
  COMMENT ON COLUMN human_resources.employee.salaried_flag IS 'Job classification. 0 = Hourly, not exempt from collective bargaining. 1 = Salaried, exempt from collective bargaining.';
  COMMENT ON COLUMN human_resources.employee.vacation_hours IS 'Number of available vacation hours.';
  COMMENT ON COLUMN human_resources.employee.sick_leave_hours IS 'Number of available sick leave hours.';
  COMMENT ON COLUMN human_resources.employee.current_flag IS '0 = Inactive, 1 = Active';

COMMENT ON TABLE human_resources.employee_department_history IS 'employee department transfers.';
  COMMENT ON COLUMN human_resources.employee_department_history.business_entity_id IS 'employee identification number. Foreign key to employee.business_entity_id.';
  COMMENT ON COLUMN human_resources.employee_department_history.department_id IS 'department in which the employee worked including currently. Foreign key to department.department_id.';
  COMMENT ON COLUMN human_resources.employee_department_history.shift_id IS 'Identifies which 8-hour shift the employee works. Foreign key to shift.shift.ID.';
  COMMENT ON COLUMN human_resources.employee_department_history.start_date IS 'Date the employee started work in the department.';
  COMMENT ON COLUMN human_resources.employee_department_history.end_date IS 'Date the employee left the department. NULL = Current department.';

COMMENT ON TABLE human_resources.employee_pay_history IS 'employee pay history.';
  COMMENT ON COLUMN human_resources.employee_pay_history.business_entity_id IS 'employee identification number. Foreign key to employee.business_entity_id.';
  COMMENT ON COLUMN human_resources.employee_pay_history.rate_change_date IS 'Date the change in pay is effective';
  COMMENT ON COLUMN human_resources.employee_pay_history.rate IS 'Salary hourly rate.';
  COMMENT ON COLUMN human_resources.employee_pay_history.pay_frequency IS '1 = Salary received monthly, 2 = Salary received biweekly';

COMMENT ON TABLE production.illustration IS 'Bicycle assembly diagrams.';
  COMMENT ON COLUMN production.illustration.illustration_id IS 'Primary key for illustration records.';
  COMMENT ON COLUMN production.illustration.diagram IS 'Illustrations used in manufacturing instructions. Stored as XML.';

COMMENT ON TABLE human_resources.job_candidate IS 'Résumés submitted to Human Resources by job applicants.';
  COMMENT ON COLUMN human_resources.job_candidate.job_candidate_id IS 'Primary key for job_candidate records.';
  COMMENT ON COLUMN human_resources.job_candidate.business_entity_id IS 'employee identification number if applicant was hired. Foreign key to employee.business_entity_id.';
  COMMENT ON COLUMN human_resources.job_candidate.resume IS 'Résumé in XML format.';

COMMENT ON TABLE production.location IS 'product inventory and manufacturing locations.';
  COMMENT ON COLUMN production.location.location_id IS 'Primary key for location records.';
  COMMENT ON COLUMN production.location.name IS 'location description.';
  COMMENT ON COLUMN production.location.cost_rate IS 'Standard hourly cost of the manufacturing location.';
  COMMENT ON COLUMN production.location.availability IS 'Work capacity (in hours) of the manufacturing location.';

COMMENT ON TABLE person.password IS 'One way hashed authentication information';
  COMMENT ON COLUMN person.password.password_hash IS 'password for the e-mail account.';
  COMMENT ON COLUMN person.password.password_salt IS 'Random value concatenated with the password string before the password is hashed.';

COMMENT ON TABLE person.person IS 'Human beings involved with adventure_works: employees, customer contacts, and vendor contacts.';
  COMMENT ON COLUMN person.person.business_entity_id IS 'Primary key for person records.';
  COMMENT ON COLUMN person.person.person_type IS 'Primary type of person: SC = store Contact, IN = Individual (retail) customer, SP = sales person, EM = employee (non-sales), VC = vendor contact, GC = General contact';
  COMMENT ON COLUMN person.person.name_style IS '0 = The data in first_name and last_name are stored in western style (first name, last name) order.  1 = Eastern style (last name, first name) order.';
  COMMENT ON COLUMN person.person.title IS 'A courtesy title. For example, Mr. or Ms.';
  COMMENT ON COLUMN person.person.first_name IS 'First name of the person.';
  COMMENT ON COLUMN person.person.middle_name IS 'Middle name or middle initial of the person.';
  COMMENT ON COLUMN person.person.last_name IS 'Last name of the person.';
  COMMENT ON COLUMN person.person.suffix IS 'Surname suffix. For example, Sr. or Jr.';
  COMMENT ON COLUMN person.person.email_promotion IS '0 = Contact does not wish to receive e-mail promotions, 1 = Contact does wish to receive e-mail promotions from adventure_works, 2 = Contact does wish to receive e-mail promotions from adventure_works and selected partners.';
  COMMENT ON COLUMN person.person.demographics IS 'Personal information such as hobbies, and income collected from online shoppers. Used for sales analysis.';
  COMMENT ON COLUMN person.person.additional_contact_info IS 'Additional contact information about the person stored in xml format.';

COMMENT ON TABLE sales.person_credit_card IS 'Cross-reference table mapping people to their credit card information in the credit_card table.';
  COMMENT ON COLUMN sales.person_credit_card.business_entity_id IS 'Business entity identification number. Foreign key to person.business_entity_id.';
  COMMENT ON COLUMN sales.person_credit_card.credit_card_id IS 'Credit card identification number. Foreign key to credit_card.credit_card_id.';

COMMENT ON TABLE person.person_phone IS 'Telephone number and type of a person.';
  COMMENT ON COLUMN person.person_phone.business_entity_id IS 'Business entity identification number. Foreign key to person.business_entity_id.';
  COMMENT ON COLUMN person.person_phone.phone_number IS 'Telephone number identification number.';
  COMMENT ON COLUMN person.person_phone.phone_number_type_id IS 'Kind of phone number. Foreign key to phone_number_type.phone_number_type_id.';

COMMENT ON TABLE person.phone_number_type IS 'type of phone number of a person.';
  COMMENT ON COLUMN person.phone_number_type.phone_number_type_id IS 'Primary key for telephone number type records.';
  COMMENT ON COLUMN person.phone_number_type.name IS 'name of the telephone number type';

COMMENT ON TABLE production.product IS 'Products sold or used in the manfacturing of sold products.';
  COMMENT ON COLUMN production.product.product_id IS 'Primary key for product records.';
  COMMENT ON COLUMN production.product.name IS 'name of the product.';
  COMMENT ON COLUMN production.product.product_number IS 'Unique product identification number.';
  COMMENT ON COLUMN production.product.make_flag IS '0 = product is purchased, 1 = product is manufactured in-house.';
  COMMENT ON COLUMN production.product.finished_goods_flag IS '0 = product is not a salable item. 1 = product is salable.';
  COMMENT ON COLUMN production.product.color IS 'product color.';
  COMMENT ON COLUMN production.product.safety_stock_level IS 'Minimum inventory quantity.';
  COMMENT ON COLUMN production.product.reorder_point IS 'Inventory level that triggers a purchase order or work order.';
  COMMENT ON COLUMN production.product.standard_cost IS 'Standard cost of the product.';
  COMMENT ON COLUMN production.product.list_price IS 'Selling price.';
  COMMENT ON COLUMN production.product.size IS 'product size.';
  COMMENT ON COLUMN production.product.size_unit_measure_code IS 'Unit of measure for size column.';
  COMMENT ON COLUMN production.product.weight_unit_measure_code IS 'Unit of measure for weight column.';
  COMMENT ON COLUMN production.product.weight IS 'product weight.';
  COMMENT ON COLUMN production.product.days_to_manufacture IS 'Number of days required to manufacture the product.';
  COMMENT ON COLUMN production.product.product_line IS 'R = Road, M = Mountain, T = Touring, S = Standard';
  COMMENT ON COLUMN production.product.class IS 'H = High, M = Medium, L = Low';
  COMMENT ON COLUMN production.product.style IS 'W = Womens, M = Mens, U = Universal';
  COMMENT ON COLUMN production.product.product_subcategory_id IS 'product is a member of this product subcategory. Foreign key to ProductSubCategory.ProductSubCategoryID.';
  COMMENT ON COLUMN production.product.product_model_id IS 'product is a member of this product model. Foreign key to product_model.product_model_id.';
  COMMENT ON COLUMN production.product.sell_start_date IS 'Date the product was available for sale.';
  COMMENT ON COLUMN production.product.sell_end_date IS 'Date the product was no longer available for sale.';
  COMMENT ON COLUMN production.product.discontinued_date IS 'Date the product was discontinued.';

COMMENT ON TABLE production.product_category IS 'High-level product categorization.';
  COMMENT ON COLUMN production.product_category.product_category_id IS 'Primary key for product_category records.';
  COMMENT ON COLUMN production.product_category.name IS 'category description.';

COMMENT ON TABLE production.product_cost_history IS 'Changes in the cost of a product over time.';
  COMMENT ON COLUMN production.product_cost_history.product_id IS 'product identification number. Foreign key to product.product_id';
  COMMENT ON COLUMN production.product_cost_history.start_date IS 'product cost start date.';
  COMMENT ON COLUMN production.product_cost_history.end_date IS 'product cost end date.';
  COMMENT ON COLUMN production.product_cost_history.standard_cost IS 'Standard cost of the product.';

COMMENT ON TABLE production.product_description IS 'product descriptions in several languages.';
  COMMENT ON COLUMN production.product_description.product_description_id IS 'Primary key for product_description records.';
  COMMENT ON COLUMN production.product_description.description IS 'description of the product.';

COMMENT ON TABLE production.product_document IS 'Cross-reference table mapping products to related product documents.';
  COMMENT ON COLUMN production.product_document.product_id IS 'product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.product_document.document_node IS 'document identification number. Foreign key to document.document_node.';

COMMENT ON TABLE production.product_inventory IS 'product inventory information.';
  COMMENT ON COLUMN production.product_inventory.product_id IS 'product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.product_inventory.location_id IS 'Inventory location identification number. Foreign key to location.location_id.';
  COMMENT ON COLUMN production.product_inventory.shelf IS 'Storage compartment within an inventory location.';
  COMMENT ON COLUMN production.product_inventory.bin IS 'Storage container on a shelf in an inventory location.';
  COMMENT ON COLUMN production.product_inventory.quantity IS 'quantity of products in the inventory location.';

COMMENT ON TABLE production.product_list_price_history IS 'Changes in the list price of a product over time.';
  COMMENT ON COLUMN production.product_list_price_history.product_id IS 'product identification number. Foreign key to product.product_id';
  COMMENT ON COLUMN production.product_list_price_history.start_date IS 'List price start date.';
  COMMENT ON COLUMN production.product_list_price_history.end_date IS 'List price end date';
  COMMENT ON COLUMN production.product_list_price_history.list_price IS 'product list price.';

COMMENT ON TABLE production.product_model IS 'product model classification.';
  COMMENT ON COLUMN production.product_model.product_model_id IS 'Primary key for product_model records.';
  COMMENT ON COLUMN production.product_model.name IS 'product model description.';
  COMMENT ON COLUMN production.product_model.catalog_description IS 'Detailed product catalog information in xml format.';
  COMMENT ON COLUMN production.product_model.instructions IS 'Manufacturing instructions in xml format.';

COMMENT ON TABLE production.product_model_illustration IS 'Cross-reference table mapping product models and illustrations.';
  COMMENT ON COLUMN production.product_model_illustration.product_model_id IS 'Primary key. Foreign key to product_model.product_model_id.';
  COMMENT ON COLUMN production.product_model_illustration.illustration_id IS 'Primary key. Foreign key to illustration.illustration_id.';

COMMENT ON TABLE production.product_model_product_description_culture IS 'Cross-reference table mapping product descriptions and the language the description is written in.';
  COMMENT ON COLUMN production.product_model_product_description_culture.product_model_id IS 'Primary key. Foreign key to product_model.product_model_id.';
  COMMENT ON COLUMN production.product_model_product_description_culture.product_description_id IS 'Primary key. Foreign key to product_description.product_description_id.';
  COMMENT ON COLUMN production.product_model_product_description_culture.culture_id IS 'culture identification number. Foreign key to culture.culture_id.';

COMMENT ON TABLE production.product_photo IS 'product images.';
  COMMENT ON COLUMN production.product_photo.product_photo_id IS 'Primary key for product_photo records.';
  COMMENT ON COLUMN production.product_photo.thumbnail_photo IS 'Small image of the product.';
  COMMENT ON COLUMN production.product_photo.thumbnail_photo_file_name IS 'Small image file name.';
  COMMENT ON COLUMN production.product_photo.large_photo IS 'Large image of the product.';
  COMMENT ON COLUMN production.product_photo.large_photo_file_name IS 'Large image file name.';

COMMENT ON TABLE production.product_product_photo IS 'Cross-reference table mapping products and product photos.';
  COMMENT ON COLUMN production.product_product_photo.product_id IS 'product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.product_product_photo.product_photo_id IS 'product photo identification number. Foreign key to product_photo.product_photo_id.';
  COMMENT ON COLUMN production.product_product_photo.Primary IS '0 = Photo is not the principal image. 1 = Photo is the principal image.';

COMMENT ON TABLE production.product_review IS 'customer reviews of products they have purchased.';
  COMMENT ON COLUMN production.product_review.product_review_id IS 'Primary key for product_review records.';
  COMMENT ON COLUMN production.product_review.product_id IS 'product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.product_review.reviewer_name IS 'name of the reviewer.';
  COMMENT ON COLUMN production.product_review.review_date IS 'Date review was submitted.';
  COMMENT ON COLUMN production.product_review.email_address IS 'Reviewer''s e-mail address.';
  COMMENT ON COLUMN production.product_review.rating IS 'product rating given by the reviewer. Scale is 1 to 5 with 5 as the highest rating.';
  COMMENT ON COLUMN production.product_review.comments IS 'Reviewer''s comments';

COMMENT ON TABLE production.product_subcategory IS 'product subcategories. See product_category table.';
  COMMENT ON COLUMN production.product_subcategory.product_subcategory_id IS 'Primary key for product_subcategory records.';
  COMMENT ON COLUMN production.product_subcategory.product_category_id IS 'product category identification number. Foreign key to product_category.product_category_id.';
  COMMENT ON COLUMN production.product_subcategory.name IS 'Subcategory description.';

COMMENT ON TABLE purchasing.product_vendor IS 'Cross-reference table mapping vendors with the products they supply.';
  COMMENT ON COLUMN purchasing.product_vendor.product_id IS 'Primary key. Foreign key to product.product_id.';
  COMMENT ON COLUMN purchasing.product_vendor.business_entity_id IS 'Primary key. Foreign key to vendor.business_entity_id.';
  COMMENT ON COLUMN purchasing.product_vendor.average_lead_time IS 'The average span of time (in days) between placing an order with the vendor and receiving the purchased product.';
  COMMENT ON COLUMN purchasing.product_vendor.standard_price IS 'The vendor''s usual selling price.';
  COMMENT ON COLUMN purchasing.product_vendor.last_receipt_cost IS 'The selling price when last purchased.';
  COMMENT ON COLUMN purchasing.product_vendor.last_receipt_date IS 'Date the product was last received by the vendor.';
  COMMENT ON COLUMN purchasing.product_vendor.min_order_qty IS 'The maximum quantity that should be ordered.';
  COMMENT ON COLUMN purchasing.product_vendor.max_order_qty IS 'The minimum quantity that should be ordered.';
  COMMENT ON COLUMN purchasing.product_vendor.on_order_qty IS 'The quantity currently on order.';
  COMMENT ON COLUMN purchasing.product_vendor.unit_measure_code IS 'The product''s unit of measure.';

COMMENT ON TABLE purchasing.purchase_order_detail IS 'Individual products associated with a specific purchase order. See purchase_order_header.';
  COMMENT ON COLUMN purchasing.purchase_order_detail.purchase_order_id IS 'Primary key. Foreign key to purchase_order_header.purchase_order_id.';
  COMMENT ON COLUMN purchasing.purchase_order_detail.purchase_order_detail_id IS 'Primary key. One line number per purchased product.';
  COMMENT ON COLUMN purchasing.purchase_order_detail.due_date IS 'Date the product is expected to be received.';
  COMMENT ON COLUMN purchasing.purchase_order_detail.order_qty IS 'quantity ordered.';
  COMMENT ON COLUMN purchasing.purchase_order_detail.product_id IS 'product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN purchasing.purchase_order_detail.unit_price IS 'vendor''s selling price of a single product.';
--  COMMENT ON COLUMN purchasing.purchase_order_detail.line_total IS 'Per product subtotal. Computed as order_qty * unit_price.';
  COMMENT ON COLUMN purchasing.purchase_order_detail.received_qty IS 'quantity actually received from the vendor.';
  COMMENT ON COLUMN purchasing.purchase_order_detail.rejected_qty IS 'quantity rejected during inspection.';
--  COMMENT ON COLUMN purchasing.purchase_order_detail.stocked_qty IS 'quantity accepted into inventory. Computed as received_qty - rejected_qty.';

COMMENT ON TABLE purchasing.purchase_order_header IS 'General purchase order information. See purchase_order_detail.';
  COMMENT ON COLUMN purchasing.purchase_order_header.purchase_order_id IS 'Primary key.';
  COMMENT ON COLUMN purchasing.purchase_order_header.revision_number IS 'Incremental number to track changes to the purchase order over time.';
  COMMENT ON COLUMN purchasing.purchase_order_header.status IS 'Order current status. 1 = Pending; 2 = Approved; 3 = Rejected; 4 = Complete';
  COMMENT ON COLUMN purchasing.purchase_order_header.employee_id IS 'employee who created the purchase order. Foreign key to employee.business_entity_id.';
  COMMENT ON COLUMN purchasing.purchase_order_header.vendor_id IS 'vendor with whom the purchase order is placed. Foreign key to vendor.business_entity_id.';
  COMMENT ON COLUMN purchasing.purchase_order_header.ship_method_id IS 'Shipping method. Foreign key to ship_method.ship_method_id.';
  COMMENT ON COLUMN purchasing.purchase_order_header.order_date IS 'Purchase order creation date.';
  COMMENT ON COLUMN purchasing.purchase_order_header.ship_date IS 'Estimated shipment date from the vendor.';
  COMMENT ON COLUMN purchasing.purchase_order_header.sub_total IS 'Purchase order subtotal. Computed as SUM(purchase_order_detail.line_total)for the appropriate purchase_order_id.';
  COMMENT ON COLUMN purchasing.purchase_order_header.tax_amt IS 'Tax amount.';
  COMMENT ON COLUMN purchasing.purchase_order_header.freight IS 'Shipping cost.';
--  COMMENT ON COLUMN purchasing.purchase_order_header.total_due IS 'Total due to vendor. Computed as Subtotal + tax_amt + freight.';

COMMENT ON TABLE sales.sales_order_detail IS 'Individual products associated with a specific sales order. See sales_order_header.';
  COMMENT ON COLUMN sales.sales_order_detail.sales_order_id IS 'Primary key. Foreign key to sales_order_header.sales_order_id.';
  COMMENT ON COLUMN sales.sales_order_detail.sales_order_detail_id IS 'Primary key. One incremental unique number per product sold.';
  COMMENT ON COLUMN sales.sales_order_detail.carrier_tracking_number IS 'Shipment tracking number supplied by the shipper.';
  COMMENT ON COLUMN sales.sales_order_detail.order_qty IS 'quantity ordered per product.';
  COMMENT ON COLUMN sales.sales_order_detail.product_id IS 'product sold to customer. Foreign key to product.product_id.';
  COMMENT ON COLUMN sales.sales_order_detail.special_offer_id IS 'Promotional code. Foreign key to special_offer.special_offer_id.';
  COMMENT ON COLUMN sales.sales_order_detail.unit_price IS 'Selling price of a single product.';
  COMMENT ON COLUMN sales.sales_order_detail.unit_price_discount IS 'Discount amount.';
--  COMMENT ON COLUMN sales.sales_order_detail.line_total IS 'Per product subtotal. Computed as unit_price * (1 - unit_price_discount) * order_qty.';

COMMENT ON TABLE sales.sales_order_header IS 'General sales order information.';
  COMMENT ON COLUMN sales.sales_order_header.sales_order_id IS 'Primary key.';
  COMMENT ON COLUMN sales.sales_order_header.revision_number IS 'Incremental number to track changes to the sales order over time.';
  COMMENT ON COLUMN sales.sales_order_header.order_date IS 'Dates the sales order was created.';
  COMMENT ON COLUMN sales.sales_order_header.due_date IS 'Date the order is due to the customer.';
  COMMENT ON COLUMN sales.sales_order_header.ship_date IS 'Date the order was shipped to the customer.';
  COMMENT ON COLUMN sales.sales_order_header.status IS 'Order current status. 1 = In process; 2 = Approved; 3 = Backordered; 4 = Rejected; 5 = Shipped; 6 = Cancelled';
  COMMENT ON COLUMN sales.sales_order_header.online_order_flag IS '0 = Order placed by sales person. 1 = Order placed online by customer.';
--  COMMENT ON COLUMN sales.sales_order_header.sales_order_number IS 'Unique sales order identification number.';
  COMMENT ON COLUMN sales.sales_order_header.purchase_order_number IS 'customer purchase order number reference.';
  COMMENT ON COLUMN sales.sales_order_header.account_number IS 'Financial accounting number reference.';
  COMMENT ON COLUMN sales.sales_order_header.customer_id IS 'customer identification number. Foreign key to customer.business_entity_id.';
  COMMENT ON COLUMN sales.sales_order_header.sales_person_id IS 'sales person who created the sales order. Foreign key to sales_person.business_entity_id.';
  COMMENT ON COLUMN sales.sales_order_header.territory_id IS 'Territory in which the sale was made. Foreign key to sales_territory.SalesTerritoryID.';
  COMMENT ON COLUMN sales.sales_order_header.bill_to_address_id IS 'customer billing address. Foreign key to address.address_id.';
  COMMENT ON COLUMN sales.sales_order_header.ship_to_address_id IS 'customer shipping address. Foreign key to address.address_id.';
  COMMENT ON COLUMN sales.sales_order_header.ship_method_id IS 'Shipping method. Foreign key to ship_method.ship_method_id.';
  COMMENT ON COLUMN sales.sales_order_header.credit_card_id IS 'Credit card identification number. Foreign key to credit_card.credit_card_id.';
  COMMENT ON COLUMN sales.sales_order_header.credit_card_approval_code IS 'Approval code provided by the credit card company.';
  COMMENT ON COLUMN sales.sales_order_header.currency_rate_id IS 'currency exchange rate used. Foreign key to currency_rate.currency_rate_id.';
  COMMENT ON COLUMN sales.sales_order_header.sub_total IS 'sales subtotal. Computed as SUM(sales_order_detail.line_total)for the appropriate sales_order_id.';
  COMMENT ON COLUMN sales.sales_order_header.tax_amt IS 'Tax amount.';
  COMMENT ON COLUMN sales.sales_order_header.freight IS 'Shipping cost.';
  COMMENT ON COLUMN sales.sales_order_header.total_due IS 'Total due from customer. Computed as Subtotal + tax_amt + freight.';
  COMMENT ON COLUMN sales.sales_order_header.comment IS 'sales representative comments.';

COMMENT ON TABLE sales.sales_order_header_sales_reason IS 'Cross-reference table mapping sales orders to sales reason codes.';
  COMMENT ON COLUMN sales.sales_order_header_sales_reason.sales_order_id IS 'Primary key. Foreign key to sales_order_header.sales_order_id.';
  COMMENT ON COLUMN sales.sales_order_header_sales_reason.sales_reason_id IS 'Primary key. Foreign key to sales_reason.sales_reason_id.';

COMMENT ON TABLE sales.sales_person IS 'sales representative current information.';
  COMMENT ON COLUMN sales.sales_person.business_entity_id IS 'Primary key for sales_person records. Foreign key to employee.business_entity_id';
  COMMENT ON COLUMN sales.sales_person.territory_id IS 'Territory currently assigned to. Foreign key to sales_territory.SalesTerritoryID.';
  COMMENT ON COLUMN sales.sales_person.sales_quota IS 'Projected yearly sales.';
  COMMENT ON COLUMN sales.sales_person.bonus IS 'bonus due if quota is met.';
  COMMENT ON COLUMN sales.sales_person.commission_pct IS 'Commision percent received per sale.';
  COMMENT ON COLUMN sales.sales_person.sales_ytd IS 'sales total year to date.';
  COMMENT ON COLUMN sales.sales_person.sales_last_year IS 'sales total of previous year.';

COMMENT ON TABLE sales.sales_person_quota_history IS 'sales performance tracking.';
  COMMENT ON COLUMN sales.sales_person_quota_history.business_entity_id IS 'sales person identification number. Foreign key to sales_person.business_entity_id.';
  COMMENT ON COLUMN sales.sales_person_quota_history.quota_date IS 'sales quota date.';
  COMMENT ON COLUMN sales.sales_person_quota_history.sales_quota IS 'sales quota amount.';

COMMENT ON TABLE sales.sales_reason IS 'Lookup table of customer purchase reasons.';
  COMMENT ON COLUMN sales.sales_reason.sales_reason_id IS 'Primary key for sales_reason records.';
  COMMENT ON COLUMN sales.sales_reason.name IS 'sales reason description.';
  COMMENT ON COLUMN sales.sales_reason.reason_type IS 'category the sales reason belongs to.';

COMMENT ON TABLE sales.sales_tax_rate IS 'Tax rate lookup table.';
  COMMENT ON COLUMN sales.sales_tax_rate.sales_tax_rate_id IS 'Primary key for sales_tax_rate records.';
  COMMENT ON COLUMN sales.sales_tax_rate.state_province_id IS 'State, province, or country/region the sales tax applies to.';
  COMMENT ON COLUMN sales.sales_tax_rate.tax_type IS '1 = Tax applied to retail transactions, 2 = Tax applied to wholesale transactions, 3 = Tax applied to all sales (retail and wholesale) transactions.';
  COMMENT ON COLUMN sales.sales_tax_rate.tax_rate IS 'Tax rate amount.';
  COMMENT ON COLUMN sales.sales_tax_rate.name IS 'Tax rate description.';

COMMENT ON TABLE sales.sales_territory IS 'sales territory lookup table.';
  COMMENT ON COLUMN sales.sales_territory.territory_id IS 'Primary key for sales_territory records.';
  COMMENT ON COLUMN sales.sales_territory.name IS 'sales territory description';
  COMMENT ON COLUMN sales.sales_territory.country_region_code IS 'ISO standard country or region code. Foreign key to country_region.country_region_code.';
  COMMENT ON COLUMN sales.sales_territory.group IS 'Geographic area to which the sales territory belong.';
  COMMENT ON COLUMN sales.sales_territory.sales_ytd IS 'sales in the territory year to date.';
  COMMENT ON COLUMN sales.sales_territory.sales_last_year IS 'sales in the territory the previous year.';
  COMMENT ON COLUMN sales.sales_territory.cost_ytd IS 'Business costs in the territory year to date.';
  COMMENT ON COLUMN sales.sales_territory.cost_last_year IS 'Business costs in the territory the previous year.';

COMMENT ON TABLE sales.sales_territory_history IS 'sales representative transfers to other sales territories.';
  COMMENT ON COLUMN sales.sales_territory_history.business_entity_id IS 'Primary key. The sales rep.  Foreign key to sales_person.business_entity_id.';
  COMMENT ON COLUMN sales.sales_territory_history.territory_id IS 'Primary key. Territory identification number. Foreign key to sales_territory.SalesTerritoryID.';
  COMMENT ON COLUMN sales.sales_territory_history.start_date IS 'Primary key. Date the sales representive started work in the territory.';
  COMMENT ON COLUMN sales.sales_territory_history.end_date IS 'Date the sales representative left work in the territory.';

COMMENT ON TABLE production.scrap_reason IS 'Manufacturing failure reasons lookup table.';
  COMMENT ON COLUMN production.scrap_reason.scrap_reason_id IS 'Primary key for scrap_reason records.';
  COMMENT ON COLUMN production.scrap_reason.name IS 'Failure description.';

COMMENT ON TABLE human_resources.shift IS 'Work shift lookup table.';
  COMMENT ON COLUMN human_resources.shift.shift_id IS 'Primary key for shift records.';
  COMMENT ON COLUMN human_resources.shift.name IS 'shift description.';
  COMMENT ON COLUMN human_resources.shift.start_time IS 'shift start time.';
  COMMENT ON COLUMN human_resources.shift.end_time IS 'shift end time.';

COMMENT ON TABLE purchasing.ship_method IS 'Shipping company lookup table.';
  COMMENT ON COLUMN purchasing.ship_method.ship_method_id IS 'Primary key for ship_method records.';
  COMMENT ON COLUMN purchasing.ship_method.name IS 'Shipping company name.';
  COMMENT ON COLUMN purchasing.ship_method.ship_base IS 'Minimum shipping charge.';
  COMMENT ON COLUMN purchasing.ship_method.ship_rate IS 'Shipping charge per pound.';

COMMENT ON TABLE sales.shopping_cart_item IS 'Contains online customer orders until the order is submitted or cancelled.';
  COMMENT ON COLUMN sales.shopping_cart_item.shopping_cart_item_id IS 'Primary key for shopping_cart_item records.';
  COMMENT ON COLUMN sales.shopping_cart_item.shipping_card_id IS 'Shopping cart identification number.';
  COMMENT ON COLUMN sales.shopping_cart_item.quantity IS 'product quantity ordered.';
  COMMENT ON COLUMN sales.shopping_cart_item.product_id IS 'product ordered. Foreign key to product.product_id.';
  COMMENT ON COLUMN sales.shopping_cart_item.date_created IS 'Date the time the record was created.';

COMMENT ON TABLE sales.special_offer IS 'Sale discounts lookup table.';
  COMMENT ON COLUMN sales.special_offer.special_offer_id IS 'Primary key for special_offer records.';
  COMMENT ON COLUMN sales.special_offer.description IS 'Discount description.';
  COMMENT ON COLUMN sales.special_offer.discount_pct IS 'Discount precentage.';
  COMMENT ON COLUMN sales.special_offer.type IS 'Discount type category.';
  COMMENT ON COLUMN sales.special_offer.category IS 'group the discount applies to such as Reseller or customer.';
  COMMENT ON COLUMN sales.special_offer.start_date IS 'Discount start date.';
  COMMENT ON COLUMN sales.special_offer.end_date IS 'Discount end date.';
  COMMENT ON COLUMN sales.special_offer.min_qty IS 'Minimum discount percent allowed.';
  COMMENT ON COLUMN sales.special_offer.max_qty IS 'Maximum discount percent allowed.';

COMMENT ON TABLE sales.special_offer_product IS 'Cross-reference table mapping products to special offer discounts.';
  COMMENT ON COLUMN sales.special_offer_product.special_offer_id IS 'Primary key for special_offer_product records.';
  COMMENT ON COLUMN sales.special_offer_product.product_id IS 'product identification number. Foreign key to product.product_id.';

COMMENT ON TABLE person.state_province IS 'State and province lookup table.';
  COMMENT ON COLUMN person.state_province.state_province_id IS 'Primary key for state_province records.';
  COMMENT ON COLUMN person.state_province.state_province_code IS 'ISO standard state or province code.';
  COMMENT ON COLUMN person.state_province.country_region_code IS 'ISO standard country or region code. Foreign key to country_region.country_region_code.';
  COMMENT ON COLUMN person.state_province.is_only_state_province_flag IS '0 = state_province_code exists. 1 = state_province_code unavailable, using country_region_code.';
  COMMENT ON COLUMN person.state_province.name IS 'State or province description.';
  COMMENT ON COLUMN person.state_province.territory_id IS 'ID of the territory in which the state or province is located. Foreign key to sales_territory.SalesTerritoryID.';

COMMENT ON TABLE sales.store IS 'Customers (resellers) of Adventure Works products.';
  COMMENT ON COLUMN sales.store.business_entity_id IS 'Primary key. Foreign key to customer.business_entity_id.';
  COMMENT ON COLUMN sales.store.name IS 'name of the store.';
  COMMENT ON COLUMN sales.store.sales_person_id IS 'ID of the sales person assigned to the customer. Foreign key to sales_person.business_entity_id.';
  COMMENT ON COLUMN sales.store.demographics IS 'Demographic informationg about the store such as the number of employees, annual sales and store type.';


COMMENT ON TABLE production.transaction_history IS 'Record of each purchase order, sales order, or work order transaction year to date.';
  COMMENT ON COLUMN production.transaction_history.transaction_id IS 'Primary key for transaction_history records.';
  COMMENT ON COLUMN production.transaction_history.product_id IS 'product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.transaction_history.reference_order_id IS 'Purchase order, sales order, or work order identification number.';
  COMMENT ON COLUMN production.transaction_history.reference_order_line_id IS 'Line number associated with the purchase order, sales order, or work order.';
  COMMENT ON COLUMN production.transaction_history.transaction_date IS 'Date and time of the transaction.';
  COMMENT ON COLUMN production.transaction_history.transaction_type IS 'W = work_order, S = SalesOrder, P = PurchaseOrder';
  COMMENT ON COLUMN production.transaction_history.quantity IS 'product quantity.';
  COMMENT ON COLUMN production.transaction_history.actual_cost IS 'product cost.';

COMMENT ON TABLE production.transaction_history_archive IS 'Transactions for previous years.';
  COMMENT ON COLUMN production.transaction_history_archive.transaction_id IS 'Primary key for transaction_history_archive records.';
  COMMENT ON COLUMN production.transaction_history_archive.product_id IS 'product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.transaction_history_archive.reference_order_id IS 'Purchase order, sales order, or work order identification number.';
  COMMENT ON COLUMN production.transaction_history_archive.reference_order_line_id IS 'Line number associated with the purchase order, sales order, or work order.';
  COMMENT ON COLUMN production.transaction_history_archive.transaction_date IS 'Date and time of the transaction.';
  COMMENT ON COLUMN production.transaction_history_archive.transaction_type IS 'W = Work Order, S = sales Order, P = Purchase Order';
  COMMENT ON COLUMN production.transaction_history_archive.quantity IS 'product quantity.';
  COMMENT ON COLUMN production.transaction_history_archive.actual_cost IS 'product cost.';

COMMENT ON TABLE production.unit_measure IS 'Unit of measure lookup table.';
  COMMENT ON COLUMN production.unit_measure.unit_measure_code IS 'Primary key.';
  COMMENT ON COLUMN production.unit_measure.name IS 'Unit of measure description.';

COMMENT ON TABLE purchasing.vendor IS 'Companies from whom Adventure Works Cycles purchases parts or other goods.';
  COMMENT ON COLUMN purchasing.vendor.business_entity_id IS 'Primary key for vendor records.  Foreign key to business_entity.business_entity_id';
  COMMENT ON COLUMN purchasing.vendor.account_number IS 'vendor account (identification) number.';
  COMMENT ON COLUMN purchasing.vendor.name IS 'Company name.';
  COMMENT ON COLUMN purchasing.vendor.credit_rating IS '1 = Superior, 2 = Excellent, 3 = Above average, 4 = Average, 5 = Below average';
  COMMENT ON COLUMN purchasing.vendor.preferred_vendor_status IS '0 = Do not use if another vendor is available. 1 = Preferred over other vendors supplying the same product.';
  COMMENT ON COLUMN purchasing.vendor.active_flag IS '0 = vendor no longer used. 1 = vendor is actively used.';
  COMMENT ON COLUMN purchasing.vendor.purchasing_web_service_url IS 'vendor URL.';

COMMENT ON TABLE production.work_order IS 'Manufacturing work orders.';
  COMMENT ON COLUMN production.work_order.work_order_id IS 'Primary key for work_order records.';
  COMMENT ON COLUMN production.work_order.product_id IS 'product identification number. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.work_order.order_qty IS 'product quantity to build.';
--  COMMENT ON COLUMN production.work_order.stocked_qty IS 'quantity built and put in inventory.';
  COMMENT ON COLUMN production.work_order.scrapped_qty IS 'quantity that failed inspection.';
  COMMENT ON COLUMN production.work_order.start_date IS 'Work order start date.';
  COMMENT ON COLUMN production.work_order.end_date IS 'Work order end date.';
  COMMENT ON COLUMN production.work_order.due_date IS 'Work order due date.';
  COMMENT ON COLUMN production.work_order.scrap_reason_id IS 'Reason for inspection failure.';

COMMENT ON TABLE production.work_order_routing IS 'Work order details.';
  COMMENT ON COLUMN production.work_order_routing.work_order_id IS 'Primary key. Foreign key to work_order.work_order_id.';
  COMMENT ON COLUMN production.work_order_routing.product_id IS 'Primary key. Foreign key to product.product_id.';
  COMMENT ON COLUMN production.work_order_routing.operation_sequence IS 'Primary key. Indicates the manufacturing process sequence.';
  COMMENT ON COLUMN production.work_order_routing.location_id IS 'Manufacturing location where the part is processed. Foreign key to location.location_id.';
  COMMENT ON COLUMN production.work_order_routing.scheduled_start_date IS 'Planned manufacturing start date.';
  COMMENT ON COLUMN production.work_order_routing.scheduled_end_date IS 'Planned manufacturing end date.';
  COMMENT ON COLUMN production.work_order_routing.actual_start_date IS 'Actual start date.';
  COMMENT ON COLUMN production.work_order_routing.actual_end_date IS 'Actual end date.';
  COMMENT ON COLUMN production.work_order_routing.actual_resource_hrs IS 'Number of manufacturing hours used.';
  COMMENT ON COLUMN production.work_order_routing.planned_cost IS 'Estimated manufacturing cost.';
  COMMENT ON COLUMN production.work_order_routing.actual_cost IS 'Actual manufacturing cost.';



-------------------------------------
-- PRIMARY KEYS
-------------------------------------

-- ALTER TABLE dbo.AWBuildVersion ADD
--     CONSTRAINT "PK_AWBuildVersion_SystemInformationID" PRIMARY KEY
--     (SystemInformationID);
-- CLUSTER dbo.AWBuildVersion USING "PK_AWBuildVersion_SystemInformationID";

-- ALTER TABLE dbo.DatabaseLog ADD
--     CONSTRAINT "PK_DatabaseLog_DatabaseLogID" PRIMARY KEY
--     (DatabaseLogID);

ALTER TABLE person.address ADD
    CONSTRAINT "PK_Address_AddressID" PRIMARY KEY
    (address_id);
CLUSTER person.address USING "PK_Address_AddressID";

ALTER TABLE person.address_type ADD
    CONSTRAINT "PK_AddressType_AddressTypeID" PRIMARY KEY
    (address_type_id);
CLUSTER person.address_type USING "PK_AddressType_AddressTypeID";

ALTER TABLE production.bill_of_materials ADD
    CONSTRAINT "PK_BillOfMaterials_BillOfMaterialsID" PRIMARY KEY
    (bill_of_materials_id);

ALTER TABLE person.business_entity ADD
    CONSTRAINT "PK_BusinessEntity_BusinessEntityID" PRIMARY KEY
    (business_entity_id);
CLUSTER person.business_entity USING "PK_BusinessEntity_BusinessEntityID";

ALTER TABLE person.business_entity_address ADD
    CONSTRAINT "PK_BusinessEntityAddress_BusinessEntityID_AddressID_AddressType" PRIMARY KEY
    (business_entity_id, address_id, address_type_id);
CLUSTER person.business_entity_address USING "PK_BusinessEntityAddress_BusinessEntityID_AddressID_AddressType";

ALTER TABLE person.business_entity_contact ADD
    CONSTRAINT "PK_BusinessEntityContact_BusinessEntityID_PersonID_ContactTypeI" PRIMARY KEY
    (business_entity_id, person_id, contact_type_id);
CLUSTER person.business_entity_contact USING "PK_BusinessEntityContact_BusinessEntityID_PersonID_ContactTypeI";

ALTER TABLE person.contact_type ADD
    CONSTRAINT "PK_ContactType_ContactTypeID" PRIMARY KEY
    (contact_type_id);
CLUSTER person.contact_type USING "PK_ContactType_ContactTypeID";

ALTER TABLE sales.country_region_currency ADD
    CONSTRAINT "PK_CountryRegionCurrency_CountryRegionCode_CurrencyCode" PRIMARY KEY
    (country_region_code, currency_code);
CLUSTER sales.country_region_currency USING "PK_CountryRegionCurrency_CountryRegionCode_CurrencyCode";

ALTER TABLE person.country_region ADD
    CONSTRAINT "PK_CountryRegion_CountryRegionCode" PRIMARY KEY
    (country_region_code);
CLUSTER person.country_region USING "PK_CountryRegion_CountryRegionCode";

ALTER TABLE sales.credit_card ADD
    CONSTRAINT "PK_CreditCard_CreditCardID" PRIMARY KEY
    (credit_card_id);
CLUSTER sales.credit_card USING "PK_CreditCard_CreditCardID";

ALTER TABLE sales.currency ADD
    CONSTRAINT "PK_Currency_CurrencyCode" PRIMARY KEY
    (currency_code);
CLUSTER sales.currency USING "PK_Currency_CurrencyCode";

ALTER TABLE sales.currency_rate ADD
    CONSTRAINT "PK_CurrencyRate_CurrencyRateID" PRIMARY KEY
    (currency_rate_id);
CLUSTER sales.currency_rate USING "PK_CurrencyRate_CurrencyRateID";

ALTER TABLE sales.customer ADD
    CONSTRAINT "PK_Customer_CustomerID" PRIMARY KEY
    (customer_id);
CLUSTER sales.customer USING "PK_Customer_CustomerID";

ALTER TABLE production.culture ADD
    CONSTRAINT "PK_Culture_CultureID" PRIMARY KEY
    (culture_id);
CLUSTER production.culture USING "PK_Culture_CultureID";

ALTER TABLE production.document ADD
    CONSTRAINT "PK_Document_DocumentNode" PRIMARY KEY
    (document_node);
CLUSTER production.document USING "PK_Document_DocumentNode";

ALTER TABLE person.email_address ADD
    CONSTRAINT "PK_EmailAddress_BusinessEntityID_EmailAddressID" PRIMARY KEY
    (business_entity_id, email_address_id);
CLUSTER person.email_address USING "PK_EmailAddress_BusinessEntityID_EmailAddressID";

ALTER TABLE human_resources.department ADD
    CONSTRAINT "PK_Department_DepartmentID" PRIMARY KEY
    (department_id);
CLUSTER human_resources.department USING "PK_Department_DepartmentID";

ALTER TABLE human_resources.employee ADD
    CONSTRAINT "PK_Employee_BusinessEntityID" PRIMARY KEY
    (business_entity_id);
CLUSTER human_resources.employee USING "PK_Employee_BusinessEntityID";

ALTER TABLE human_resources.employee_department_history ADD
    CONSTRAINT "PK_EmployeeDepartmentHistory_BusinessEntityID_StartDate_Departm" PRIMARY KEY
    (business_entity_id, start_date, department_id, shift_id);
CLUSTER human_resources.employee_department_history USING "PK_EmployeeDepartmentHistory_BusinessEntityID_StartDate_Departm";

ALTER TABLE human_resources.employee_pay_history ADD
    CONSTRAINT "PK_EmployeePayHistory_BusinessEntityID_RateChangeDate" PRIMARY KEY
    (business_entity_id, rate_change_date);
CLUSTER human_resources.employee_pay_history USING "PK_EmployeePayHistory_BusinessEntityID_RateChangeDate";

ALTER TABLE human_resources.job_candidate ADD
    CONSTRAINT "PK_JobCandidate_JobCandidateID" PRIMARY KEY
    (job_candidate_id);
CLUSTER human_resources.job_candidate USING "PK_JobCandidate_JobCandidateID";

ALTER TABLE production.illustration ADD
    CONSTRAINT "PK_Illustration_IllustrationID" PRIMARY KEY
    (illustration_id);
CLUSTER production.illustration USING "PK_Illustration_IllustrationID";

ALTER TABLE production.location ADD
    CONSTRAINT "PK_Location_LocationID" PRIMARY KEY
    (location_id);
CLUSTER production.location USING "PK_Location_LocationID";

ALTER TABLE person.password ADD
    CONSTRAINT "PK_Password_BusinessEntityID" PRIMARY KEY
    (business_entity_id);
CLUSTER person.password USING "PK_Password_BusinessEntityID";

ALTER TABLE person.person ADD
    CONSTRAINT "PK_Person_BusinessEntityID" PRIMARY KEY
    (business_entity_id);
CLUSTER person.person USING "PK_Person_BusinessEntityID";

ALTER TABLE person.person_phone ADD
    CONSTRAINT "PK_PersonPhone_BusinessEntityID_PhoneNumber_PhoneNumberTypeID" PRIMARY KEY
    (business_entity_id, phone_number, phone_number_type_id);
CLUSTER person.person_phone USING "PK_PersonPhone_BusinessEntityID_PhoneNumber_PhoneNumberTypeID";

ALTER TABLE person.phone_number_type ADD
    CONSTRAINT "PK_PhoneNumberType_PhoneNumberTypeID" PRIMARY KEY
    (phone_number_type_id);
CLUSTER person.phone_number_type USING "PK_PhoneNumberType_PhoneNumberTypeID";

ALTER TABLE production.product ADD
    CONSTRAINT "PK_Product_ProductID" PRIMARY KEY
    (product_id);
CLUSTER production.product USING "PK_Product_ProductID";

ALTER TABLE production.product_category ADD
    CONSTRAINT "PK_ProductCategory_ProductCategoryID" PRIMARY KEY
    (product_category_id);
CLUSTER production.product_category USING "PK_ProductCategory_ProductCategoryID";

ALTER TABLE production.product_cost_history ADD
    CONSTRAINT "PK_ProductCostHistory_ProductID_StartDate" PRIMARY KEY
    (product_id, start_date);
CLUSTER production.product_cost_history USING "PK_ProductCostHistory_ProductID_StartDate";

ALTER TABLE production.product_description ADD
    CONSTRAINT "PK_ProductDescription_ProductDescriptionID" PRIMARY KEY
    (product_description_id);
CLUSTER production.product_description USING "PK_ProductDescription_ProductDescriptionID";

ALTER TABLE production.product_document ADD
    CONSTRAINT "PK_ProductDocument_ProductID_DocumentNode" PRIMARY KEY
    (product_id, document_node);
CLUSTER production.product_document USING "PK_ProductDocument_ProductID_DocumentNode";

ALTER TABLE production.product_inventory ADD
    CONSTRAINT "PK_ProductInventory_ProductID_LocationID" PRIMARY KEY
    (product_id, location_id);
CLUSTER production.product_inventory USING "PK_ProductInventory_ProductID_LocationID";

ALTER TABLE production.product_list_price_history ADD
    CONSTRAINT "PK_ProductListPriceHistory_ProductID_StartDate" PRIMARY KEY
    (product_id, start_date);
CLUSTER production.product_list_price_history USING "PK_ProductListPriceHistory_ProductID_StartDate";

ALTER TABLE production.product_model ADD
    CONSTRAINT "PK_ProductModel_ProductModelID" PRIMARY KEY
    (product_model_id);
CLUSTER production.product_model USING "PK_ProductModel_ProductModelID";

ALTER TABLE production.product_model_illustration ADD
    CONSTRAINT "PK_ProductModelIllustration_ProductModelID_IllustrationID" PRIMARY KEY
    (product_model_id, illustration_id);
CLUSTER production.product_model_illustration USING "PK_ProductModelIllustration_ProductModelID_IllustrationID";

ALTER TABLE production.product_model_product_description_culture ADD
    CONSTRAINT "PK_ProductModelProductDescriptionCulture_ProductModelID_Product" PRIMARY KEY
    (product_model_id, product_description_id, culture_id);
CLUSTER production.product_model_product_description_culture USING "PK_ProductModelProductDescriptionCulture_ProductModelID_Product";

ALTER TABLE production.product_photo ADD
    CONSTRAINT "PK_ProductPhoto_ProductPhotoID" PRIMARY KEY
    (product_photo_id);
CLUSTER production.product_photo USING "PK_ProductPhoto_ProductPhotoID";

ALTER TABLE production.product_product_photo ADD
    CONSTRAINT "PK_ProductProductPhoto_ProductID_ProductPhotoID" PRIMARY KEY
    (product_id, product_photo_id);

ALTER TABLE production.product_review ADD
    CONSTRAINT "PK_ProductReview_ProductReviewID" PRIMARY KEY
    (product_review_id);
CLUSTER production.product_review USING "PK_ProductReview_ProductReviewID";

ALTER TABLE production.product_subcategory ADD
    CONSTRAINT "PK_ProductSubcategory_ProductSubcategoryID" PRIMARY KEY
    (product_subcategory_id);
CLUSTER production.product_subcategory USING "PK_ProductSubcategory_ProductSubcategoryID";

ALTER TABLE purchasing.product_vendor ADD
    CONSTRAINT "PK_ProductVendor_ProductID_BusinessEntityID" PRIMARY KEY
    (product_id, business_entity_id);
CLUSTER purchasing.product_vendor USING "PK_ProductVendor_ProductID_BusinessEntityID";

ALTER TABLE purchasing.purchase_order_detail ADD
    CONSTRAINT "PK_PurchaseOrderDetail_PurchaseOrderID_PurchaseOrderDetailID" PRIMARY KEY
    (purchase_order_id, purchase_order_detail_id);
CLUSTER purchasing.purchase_order_detail USING "PK_PurchaseOrderDetail_PurchaseOrderID_PurchaseOrderDetailID";

ALTER TABLE purchasing.purchase_order_header ADD
    CONSTRAINT "PK_PurchaseOrderHeader_PurchaseOrderID" PRIMARY KEY
    (purchase_order_id);
CLUSTER purchasing.purchase_order_header USING "PK_PurchaseOrderHeader_PurchaseOrderID";

ALTER TABLE sales.person_credit_card ADD
    CONSTRAINT "PK_PersonCreditCard_BusinessEntityID_CreditCardID" PRIMARY KEY
    (business_entity_id, credit_card_id);
CLUSTER sales.person_credit_card USING "PK_PersonCreditCard_BusinessEntityID_CreditCardID";

ALTER TABLE sales.sales_order_detail ADD
    CONSTRAINT "PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID" PRIMARY KEY
    (sales_order_id, sales_order_detail_id);
CLUSTER sales.sales_order_detail USING "PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID";

ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "PK_SalesOrderHeader_SalesOrderID" PRIMARY KEY
    (sales_order_id);
CLUSTER sales.sales_order_header USING "PK_SalesOrderHeader_SalesOrderID";

ALTER TABLE sales.sales_order_header_sales_reason ADD
    CONSTRAINT "PK_SalesOrderHeaderSalesReason_SalesOrderID_SalesReasonID" PRIMARY KEY
    (sales_order_id, sales_reason_id);
CLUSTER sales.sales_order_header_sales_reason USING "PK_SalesOrderHeaderSalesReason_SalesOrderID_SalesReasonID";

ALTER TABLE sales.sales_person ADD
    CONSTRAINT "PK_SalesPerson_BusinessEntityID" PRIMARY KEY
    (business_entity_id);
CLUSTER sales.sales_person USING "PK_SalesPerson_BusinessEntityID";

ALTER TABLE sales.sales_person_quota_history ADD
    CONSTRAINT "PK_SalesPersonQuotaHistory_BusinessEntityID_QuotaDate" PRIMARY KEY
    (business_entity_id, quota_date); -- product_category_id);
CLUSTER sales.sales_person_quota_history USING "PK_SalesPersonQuotaHistory_BusinessEntityID_QuotaDate";

ALTER TABLE sales.sales_reason ADD
    CONSTRAINT "PK_SalesReason_SalesReasonID" PRIMARY KEY
    (sales_reason_id);
CLUSTER sales.sales_reason USING "PK_SalesReason_SalesReasonID";

ALTER TABLE sales.sales_tax_rate ADD
    CONSTRAINT "PK_SalesTaxRate_SalesTaxRateID" PRIMARY KEY
    (sales_tax_rate_id);
CLUSTER sales.sales_tax_rate USING "PK_SalesTaxRate_SalesTaxRateID";

ALTER TABLE sales.sales_territory ADD
    CONSTRAINT "PK_SalesTerritory_TerritoryID" PRIMARY KEY
    (territory_id);
CLUSTER sales.sales_territory USING "PK_SalesTerritory_TerritoryID";

ALTER TABLE sales.sales_territory_history ADD
    CONSTRAINT "PK_SalesTerritoryHistory_BusinessEntityID_StartDate_TerritoryID" PRIMARY KEY
    (business_entity_id,  --sales person,
     start_date, territory_id);
CLUSTER sales.sales_territory_history USING "PK_SalesTerritoryHistory_BusinessEntityID_StartDate_TerritoryID";

ALTER TABLE production.scrap_reason ADD
    CONSTRAINT "PK_ScrapReason_ScrapReasonID" PRIMARY KEY
    (scrap_reason_id);
CLUSTER production.scrap_reason USING "PK_ScrapReason_ScrapReasonID";

ALTER TABLE human_resources.shift ADD
    CONSTRAINT "PK_Shift_ShiftID" PRIMARY KEY
    (shift_id);
CLUSTER human_resources.shift USING "PK_Shift_ShiftID";

ALTER TABLE purchasing.ship_method ADD
    CONSTRAINT "PK_ShipMethod_ShipMethodID" PRIMARY KEY
    (ship_method_id);
CLUSTER purchasing.ship_method USING "PK_ShipMethod_ShipMethodID";

ALTER TABLE sales.shopping_cart_item ADD
    CONSTRAINT "PK_ShoppingCartItem_ShoppingCartItemID" PRIMARY KEY
    (shopping_cart_item_id);
CLUSTER sales.shopping_cart_item USING "PK_ShoppingCartItem_ShoppingCartItemID";

ALTER TABLE sales.special_offer ADD
    CONSTRAINT "PK_SpecialOffer_SpecialOfferID" PRIMARY KEY
    (special_offer_id);
CLUSTER sales.special_offer USING "PK_SpecialOffer_SpecialOfferID";

ALTER TABLE sales.special_offer_product ADD
    CONSTRAINT "PK_SpecialOfferProduct_SpecialOfferID_ProductID" PRIMARY KEY
    (special_offer_id, product_id);
CLUSTER sales.special_offer_product USING "PK_SpecialOfferProduct_SpecialOfferID_ProductID";

ALTER TABLE person.state_province ADD
    CONSTRAINT "PK_StateProvince_StateProvinceID" PRIMARY KEY
    (state_province_id);
CLUSTER person.state_province USING "PK_StateProvince_StateProvinceID";

ALTER TABLE sales.store ADD
    CONSTRAINT "PK_Store_BusinessEntityID" PRIMARY KEY
    (business_entity_id);
CLUSTER sales.store USING "PK_Store_BusinessEntityID";

ALTER TABLE production.transaction_history ADD
    CONSTRAINT "PK_TransactionHistory_TransactionID" PRIMARY KEY
    (transaction_id);
CLUSTER production.transaction_history USING "PK_TransactionHistory_TransactionID";

ALTER TABLE production.transaction_history_archive ADD
    CONSTRAINT "PK_TransactionHistoryArchive_TransactionID" PRIMARY KEY
    (transaction_id);
CLUSTER production.transaction_history_archive USING "PK_TransactionHistoryArchive_TransactionID";

ALTER TABLE production.unit_measure ADD
    CONSTRAINT "PK_UnitMeasure_UnitMeasureCode" PRIMARY KEY
    (unit_measure_code);
CLUSTER production.unit_measure USING "PK_UnitMeasure_UnitMeasureCode";

ALTER TABLE purchasing.vendor ADD
    CONSTRAINT "PK_Vendor_BusinessEntityID" PRIMARY KEY
    (business_entity_id);
CLUSTER purchasing.vendor USING "PK_Vendor_BusinessEntityID";

ALTER TABLE production.work_order ADD
    CONSTRAINT "PK_WorkOrder_WorkOrderID" PRIMARY KEY
    (work_order_id);
CLUSTER production.work_order USING "PK_WorkOrder_WorkOrderID";

ALTER TABLE production.work_order_routing ADD
    CONSTRAINT "PK_WorkOrderRouting_WorkOrderID_ProductID_OperationSequence" PRIMARY KEY
    (work_order_id, product_id, operation_sequence);
CLUSTER production.work_order_routing USING "PK_WorkOrderRouting_WorkOrderID_ProductID_OperationSequence";



-------------------------------------
-- FOREIGN KEYS
-------------------------------------

ALTER TABLE person.address ADD
    CONSTRAINT "FK_Address_StateProvince_StateProvinceID" FOREIGN KEY
    (state_province_id) REFERENCES person.state_province(state_province_id);

ALTER TABLE production.bill_of_materials ADD
    CONSTRAINT "FK_BillOfMaterials_Product_ProductAssemblyID" FOREIGN KEY
    (product_assembly_id) REFERENCES production.product(product_id);
ALTER TABLE production.bill_of_materials ADD
    CONSTRAINT "FK_BillOfMaterials_Product_ComponentID" FOREIGN KEY
    (component_id) REFERENCES production.product(product_id);
ALTER TABLE production.bill_of_materials ADD
    CONSTRAINT "FK_BillOfMaterials_UnitMeasure_UnitMeasureCode" FOREIGN KEY
    (unit_measure_code) REFERENCES production.unit_measure(unit_measure_code);

ALTER TABLE person.business_entity_address ADD
    CONSTRAINT "FK_BusinessEntityAddress_Address_AddressID" FOREIGN KEY
    (address_id) REFERENCES person.address(address_id);
ALTER TABLE person.business_entity_address ADD
    CONSTRAINT "FK_BusinessEntityAddress_AddressType_AddressTypeID" FOREIGN KEY
    (address_type_id) REFERENCES person.address_type(address_type_id);
ALTER TABLE person.business_entity_address ADD
    CONSTRAINT "FK_BusinessEntityAddress_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.business_entity(business_entity_id);

ALTER TABLE person.business_entity_contact ADD
    CONSTRAINT "FK_BusinessEntityContact_Person_PersonID" FOREIGN KEY
    (person_id) REFERENCES person.person(business_entity_id);
ALTER TABLE person.business_entity_contact ADD
    CONSTRAINT "FK_BusinessEntityContact_ContactType_ContactTypeID" FOREIGN KEY
    (contact_type_id) REFERENCES person.contact_type(contact_type_id);
ALTER TABLE person.business_entity_contact ADD
    CONSTRAINT "FK_BusinessEntityContact_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.business_entity(business_entity_id);

ALTER TABLE sales.country_region_currency ADD
    CONSTRAINT "FK_CountryRegionCurrency_CountryRegion_CountryRegionCode" FOREIGN KEY
    (country_region_code) REFERENCES person.country_region(country_region_code);
ALTER TABLE sales.country_region_currency ADD
    CONSTRAINT "FK_CountryRegionCurrency_Currency_CurrencyCode" FOREIGN KEY
    (currency_code) REFERENCES sales.currency(currency_code);

ALTER TABLE sales.currency_rate ADD
    CONSTRAINT "FK_CurrencyRate_Currency_FromCurrencyCode" FOREIGN KEY
    (from_currency_code) REFERENCES sales.currency(currency_code);
ALTER TABLE sales.currency_rate ADD
    CONSTRAINT "FK_CurrencyRate_Currency_ToCurrencyCode" FOREIGN KEY
    (to_currency_code) REFERENCES sales.currency(currency_code);

ALTER TABLE sales.customer ADD
    CONSTRAINT "FK_Customer_Person_PersonID" FOREIGN KEY
    (person_id) REFERENCES person.person(business_entity_id);
ALTER TABLE sales.customer ADD
    CONSTRAINT "FK_Customer_Store_StoreID" FOREIGN KEY
    (store_id) REFERENCES sales.store(business_entity_id);
ALTER TABLE sales.customer ADD
    CONSTRAINT "FK_Customer_SalesTerritory_TerritoryID" FOREIGN KEY
    (territory_id) REFERENCES sales.sales_territory(territory_id);

ALTER TABLE production.document ADD
    CONSTRAINT "FK_Document_Employee_Owner" FOREIGN KEY
    (owner) REFERENCES human_resources.employee(business_entity_id);

ALTER TABLE person.email_address ADD
    CONSTRAINT "FK_EmailAddress_Person_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.person(business_entity_id);

ALTER TABLE human_resources.employee ADD
    CONSTRAINT "FK_Employee_Person_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.person(business_entity_id);

ALTER TABLE human_resources.employee_department_history ADD
    CONSTRAINT "FK_EmployeeDepartmentHistory_Department_DepartmentID" FOREIGN KEY
    (department_id) REFERENCES human_resources.department(department_id);
ALTER TABLE human_resources.employee_department_history ADD
    CONSTRAINT "FK_EmployeeDepartmentHistory_Employee_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES human_resources.employee(business_entity_id);
ALTER TABLE human_resources.employee_department_history ADD
    CONSTRAINT "FK_EmployeeDepartmentHistory_Shift_ShiftID" FOREIGN KEY
    (shift_id) REFERENCES human_resources.shift(shift_id);

ALTER TABLE human_resources.employee_pay_history ADD
    CONSTRAINT "FK_EmployeePayHistory_Employee_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES human_resources.employee(business_entity_id);

ALTER TABLE human_resources.job_candidate ADD
    CONSTRAINT "FK_JobCandidate_Employee_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES human_resources.employee(business_entity_id);

ALTER TABLE person.password ADD
    CONSTRAINT "FK_Password_Person_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.person(business_entity_id);

ALTER TABLE person.person ADD
    CONSTRAINT "FK_Person_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.business_entity(business_entity_id);

ALTER TABLE sales.person_credit_card ADD
    CONSTRAINT "FK_PersonCreditCard_Person_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.person(business_entity_id);
ALTER TABLE sales.person_credit_card ADD
    CONSTRAINT "FK_PersonCreditCard_CreditCard_CreditCardID" FOREIGN KEY
    (credit_card_id) REFERENCES sales.credit_card(credit_card_id);

ALTER TABLE person.person_phone ADD
    CONSTRAINT "FK_PersonPhone_Person_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.person(business_entity_id);
ALTER TABLE person.person_phone ADD
    CONSTRAINT "FK_PersonPhone_PhoneNumberType_PhoneNumberTypeID" FOREIGN KEY
    (phone_number_type_id) REFERENCES person.phone_number_type(phone_number_type_id);

ALTER TABLE production.product ADD
    CONSTRAINT "FK_Product_UnitMeasure_SizeUnitMeasureCode" FOREIGN KEY
    (size_unit_measure_code) REFERENCES production.unit_measure(unit_measure_code);
ALTER TABLE production.product ADD
    CONSTRAINT "FK_Product_UnitMeasure_WeightUnitMeasureCode" FOREIGN KEY
    (weight_unit_measure_code) REFERENCES production.unit_measure(unit_measure_code);
ALTER TABLE production.product ADD
    CONSTRAINT "FK_Product_ProductModel_ProductModelID" FOREIGN KEY
    (product_model_id) REFERENCES production.product_model(product_model_id);
ALTER TABLE production.product ADD
    CONSTRAINT "FK_Product_ProductSubcategory_ProductSubcategoryID" FOREIGN KEY
    (product_subcategory_id) REFERENCES production.product_subcategory(product_subcategory_id);

ALTER TABLE production.product_cost_history ADD
    CONSTRAINT "FK_ProductCostHistory_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);

ALTER TABLE production.product_document ADD
    CONSTRAINT "FK_ProductDocument_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);
ALTER TABLE production.product_document ADD
    CONSTRAINT "FK_ProductDocument_Document_DocumentNode" FOREIGN KEY
    (document_node) REFERENCES production.document(document_node);

ALTER TABLE production.product_inventory ADD
    CONSTRAINT "FK_ProductInventory_Location_LocationID" FOREIGN KEY
    (location_id) REFERENCES production.location(location_id);
ALTER TABLE production.product_inventory ADD
    CONSTRAINT "FK_ProductInventory_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);

ALTER TABLE production.product_list_price_history ADD
    CONSTRAINT "FK_ProductListPriceHistory_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);

ALTER TABLE production.product_model_illustration ADD
    CONSTRAINT "FK_ProductModelIllustration_ProductModel_ProductModelID" FOREIGN KEY
    (product_model_id) REFERENCES production.product_model(product_model_id);
ALTER TABLE production.product_model_illustration ADD
    CONSTRAINT "FK_ProductModelIllustration_Illustration_IllustrationID" FOREIGN KEY
    (illustration_id) REFERENCES production.illustration(illustration_id);

ALTER TABLE production.product_model_product_description_culture ADD
    CONSTRAINT "FK_ProductModelProductDescriptionCulture_ProductDescription_Pro" FOREIGN KEY
    (product_description_id) REFERENCES production.product_description(product_description_id);
ALTER TABLE production.product_model_product_description_culture ADD
    CONSTRAINT "FK_ProductModelProductDescriptionCulture_Culture_CultureID" FOREIGN KEY
    (culture_id) REFERENCES production.culture(culture_id);
ALTER TABLE production.product_model_product_description_culture ADD
    CONSTRAINT "FK_ProductModelProductDescriptionCulture_ProductModel_ProductMo" FOREIGN KEY
    (product_model_id) REFERENCES production.product_model(product_model_id);

ALTER TABLE production.product_product_photo ADD
    CONSTRAINT "FK_ProductProductPhoto_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);
ALTER TABLE production.product_product_photo ADD
    CONSTRAINT "FK_ProductProductPhoto_ProductPhoto_ProductPhotoID" FOREIGN KEY
    (product_photo_id) REFERENCES production.product_photo(product_photo_id);

ALTER TABLE production.product_review ADD
    CONSTRAINT "FK_ProductReview_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);

ALTER TABLE production.product_subcategory ADD
    CONSTRAINT "FK_ProductSubcategory_ProductCategory_ProductCategoryID" FOREIGN KEY
    (product_category_id) REFERENCES production.product_category(product_category_id);

ALTER TABLE purchasing.product_vendor ADD
    CONSTRAINT "FK_ProductVendor_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);
ALTER TABLE purchasing.product_vendor ADD
    CONSTRAINT "FK_ProductVendor_UnitMeasure_UnitMeasureCode" FOREIGN KEY
    (unit_measure_code) REFERENCES production.unit_measure(unit_measure_code);
ALTER TABLE purchasing.product_vendor ADD
    CONSTRAINT "FK_ProductVendor_Vendor_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES purchasing.vendor(business_entity_id);

ALTER TABLE purchasing.purchase_order_detail ADD
    CONSTRAINT "FK_PurchaseOrderDetail_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);
ALTER TABLE purchasing.purchase_order_detail ADD
    CONSTRAINT "FK_PurchaseOrderDetail_PurchaseOrderHeader_PurchaseOrderID" FOREIGN KEY
    (purchase_order_id) REFERENCES purchasing.purchase_order_header(purchase_order_id);

ALTER TABLE purchasing.purchase_order_header ADD
    CONSTRAINT "FK_PurchaseOrderHeader_Employee_EmployeeID" FOREIGN KEY
    (employee_id) REFERENCES human_resources.employee(business_entity_id);
ALTER TABLE purchasing.purchase_order_header ADD
    CONSTRAINT "FK_PurchaseOrderHeader_Vendor_VendorID" FOREIGN KEY
    (vendor_id) REFERENCES purchasing.vendor(business_entity_id);
ALTER TABLE purchasing.purchase_order_header ADD
    CONSTRAINT "FK_PurchaseOrderHeader_ShipMethod_ShipMethodID" FOREIGN KEY
    (ship_method_id) REFERENCES purchasing.ship_method(ship_method_id);

ALTER TABLE sales.sales_order_detail ADD
    CONSTRAINT "FK_SalesOrderDetail_SalesOrderHeader_SalesOrderID" FOREIGN KEY
    (sales_order_id) REFERENCES sales.sales_order_header(sales_order_id) ON DELETE CASCADE;
ALTER TABLE sales.sales_order_detail ADD
    CONSTRAINT "FK_SalesOrderDetail_SpecialOfferProduct_SpecialOfferIDProductID" FOREIGN KEY
    (special_offer_id, product_id) REFERENCES sales.special_offer_product(special_offer_id, product_id);

ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "FK_SalesOrderHeader_Address_BillToAddressID" FOREIGN KEY
    (bill_to_address_id) REFERENCES person.address(address_id);
ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "FK_SalesOrderHeader_Address_ShipToAddressID" FOREIGN KEY
    (ship_to_address_id) REFERENCES person.address(address_id);
ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "FK_SalesOrderHeader_CreditCard_CreditCardID" FOREIGN KEY
    (credit_card_id) REFERENCES sales.credit_card(credit_card_id);
ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "FK_SalesOrderHeader_CurrencyRate_CurrencyRateID" FOREIGN KEY
    (currency_rate_id) REFERENCES sales.currency_rate(currency_rate_id);
ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "FK_SalesOrderHeader_Customer_CustomerID" FOREIGN KEY
    (customer_id) REFERENCES sales.customer(customer_id);
ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "FK_SalesOrderHeader_SalesPerson_SalesPersonID" FOREIGN KEY
    (sales_person_id) REFERENCES sales.sales_person(business_entity_id);
ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "FK_SalesOrderHeader_ShipMethod_ShipMethodID" FOREIGN KEY
    (ship_method_id) REFERENCES purchasing.ship_method(ship_method_id);
ALTER TABLE sales.sales_order_header ADD
    CONSTRAINT "FK_SalesOrderHeader_SalesTerritory_TerritoryID" FOREIGN KEY
    (territory_id) REFERENCES sales.sales_territory(territory_id);

ALTER TABLE sales.sales_order_header_sales_reason ADD
    CONSTRAINT "FK_SalesOrderHeaderSalesReason_SalesReason_SalesReasonID" FOREIGN KEY
    (sales_reason_id) REFERENCES sales.sales_reason(sales_reason_id);
ALTER TABLE sales.sales_order_header_sales_reason ADD
    CONSTRAINT "FK_SalesOrderHeaderSalesReason_SalesOrderHeader_SalesOrderID" FOREIGN KEY
    (sales_order_id) REFERENCES sales.sales_order_header(sales_order_id) ON DELETE CASCADE;

ALTER TABLE sales.sales_person ADD
    CONSTRAINT "FK_SalesPerson_Employee_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES human_resources.employee(business_entity_id);
ALTER TABLE sales.sales_person ADD
    CONSTRAINT "FK_SalesPerson_SalesTerritory_TerritoryID" FOREIGN KEY
    (territory_id) REFERENCES sales.sales_territory(territory_id);

ALTER TABLE sales.sales_person_quota_history ADD
    CONSTRAINT "FK_SalesPersonQuotaHistory_SalesPerson_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES sales.sales_person(business_entity_id);

ALTER TABLE sales.sales_tax_rate ADD
    CONSTRAINT "FK_SalesTaxRate_StateProvince_StateProvinceID" FOREIGN KEY
    (state_province_id) REFERENCES person.state_province(state_province_id);

ALTER TABLE sales.sales_territory ADD
    CONSTRAINT "FK_SalesTerritory_CountryRegion_CountryRegionCode" FOREIGN KEY
    (country_region_code) REFERENCES person.country_region(country_region_code);

ALTER TABLE sales.sales_territory_history ADD
    CONSTRAINT "FK_SalesTerritoryHistory_SalesPerson_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES sales.sales_person(business_entity_id);
ALTER TABLE sales.sales_territory_history ADD
    CONSTRAINT "FK_SalesTerritoryHistory_SalesTerritory_TerritoryID" FOREIGN KEY
    (territory_id) REFERENCES sales.sales_territory(territory_id);

ALTER TABLE sales.shopping_cart_item ADD
    CONSTRAINT "FK_ShoppingCartItem_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);

ALTER TABLE sales.special_offer_product ADD
    CONSTRAINT "FK_SpecialOfferProduct_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);
ALTER TABLE sales.special_offer_product ADD
    CONSTRAINT "FK_SpecialOfferProduct_SpecialOffer_SpecialOfferID" FOREIGN KEY
    (special_offer_id) REFERENCES sales.special_offer(special_offer_id);

ALTER TABLE person.state_province ADD
    CONSTRAINT "FK_StateProvince_CountryRegion_CountryRegionCode" FOREIGN KEY
    (country_region_code) REFERENCES person.country_region(country_region_code);
ALTER TABLE person.state_province ADD
    CONSTRAINT "FK_StateProvince_SalesTerritory_TerritoryID" FOREIGN KEY
    (territory_id) REFERENCES sales.sales_territory(territory_id);

ALTER TABLE sales.store ADD
    CONSTRAINT "FK_Store_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.business_entity(business_entity_id);
ALTER TABLE sales.store ADD
    CONSTRAINT "FK_Store_SalesPerson_SalesPersonID" FOREIGN KEY
    (sales_person_id) REFERENCES sales.sales_person(business_entity_id);

ALTER TABLE production.transaction_history ADD
    CONSTRAINT "FK_TransactionHistory_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);

ALTER TABLE purchasing.vendor ADD
    CONSTRAINT "FK_Vendor_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (business_entity_id) REFERENCES person.business_entity(business_entity_id);

ALTER TABLE production.work_order ADD
    CONSTRAINT "FK_WorkOrder_Product_ProductID" FOREIGN KEY
    (product_id) REFERENCES production.product(product_id);
ALTER TABLE production.work_order ADD
    CONSTRAINT "FK_WorkOrder_ScrapReason_ScrapReasonID" FOREIGN KEY
    (scrap_reason_id) REFERENCES production.scrap_reason(scrap_reason_id);

ALTER TABLE production.work_order_routing ADD
    CONSTRAINT "FK_WorkOrderRouting_Location_LocationID" FOREIGN KEY
    (location_id) REFERENCES production.location(location_id);
ALTER TABLE production.work_order_routing ADD
    CONSTRAINT "FK_WorkOrderRouting_WorkOrder_WorkOrderID" FOREIGN KEY
    (work_order_id) REFERENCES production.work_order(work_order_id);



-------------------------------------
-- VIEWS
-------------------------------------

-- Fun to see the difference in XML-oriented queries between MSSQLServer and Postgres.
-- First here's an original MSSQL query:

-- CREATE VIEW [person].[v_additional_contact_info]
-- AS
-- SELECT
--     [business_entity_id]
--     ,[first_name]
--     ,[middle_name]
--     ,[last_name]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:telephoneNumber)[1]/act:number', 'nvarchar(50)') AS [TelephoneNumber]
--     ,LTRIM(RTRIM([ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:telephoneNumber/act:SpecialInstructions/text())[1]', 'nvarchar(max)'))) AS [TelephoneSpecialInstructions]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:Street)[1]', 'nvarchar(50)') AS [Street]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:city)[1]', 'nvarchar(50)') AS [city]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:state_province)[1]', 'nvarchar(50)') AS [state_province]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:postal_code)[1]', 'nvarchar(50)') AS [postal_code]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:country_region)[1]', 'nvarchar(50)') AS [country_region]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:SpecialInstructions/text())[1]', 'nvarchar(max)') AS [home_address_special_instruction]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:eMailAddress)[1]', 'nvarchar(128)') AS [email_address]
--     ,LTRIM(RTRIM([ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:SpecialInstructions/text())[1]', 'nvarchar(max)'))) AS [email_special_instructions]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:SpecialInstructions/act:telephoneNumber/act:number)[1]', 'nvarchar(50)') AS [email_telephone_number]
--     ,[row_guid]
--     ,[modified_date]
-- FROM [person].[person]
-- OUTER APPLY [additional_contact_info].nodes(
--     'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--     /ci:additional_contact_info') AS ContactInfo(ref)
-- WHERE [additional_contact_info] IS NOT NULL;


-- And now the Postgres version, which is a little more trim:

CREATE VIEW person.v_additional_contact_info
AS
SELECT
    p.business_entity_id
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,(xpath('(act:telephoneNumber)[1]/act:number/text()',                node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS TelephoneNumber
    ,BTRIM(
     (xpath('(act:telephoneNumber)[1]/act:SpecialInstructions/text()',   node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]::VARCHAR)
               AS TelephoneSpecialInstructions
    ,(xpath('(act:homePostalAddress)[1]/act:Street/text()',              node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS Street
    ,(xpath('(act:homePostalAddress)[1]/act:city/text()',                node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS city
    ,(xpath('(act:homePostalAddress)[1]/act:state_province/text()',       node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS state_province
    ,(xpath('(act:homePostalAddress)[1]/act:postal_code/text()',          node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS postal_code
    ,(xpath('(act:homePostalAddress)[1]/act:country_region/text()',       node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS country_region
    ,(xpath('(act:homePostalAddress)[1]/act:SpecialInstructions/text()', node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS home_address_special_instruction
    ,(xpath('(act:eMail)[1]/act:eMailAddress/text()',                    node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS email_address
    ,BTRIM(
     (xpath('(act:eMail)[1]/act:SpecialInstructions/text()',             node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]::VARCHAR)
               AS email_special_instructions
    ,(xpath('((act:eMail)[1]/act:SpecialInstructions/act:telephoneNumber)[1]/act:number/text()', node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS email_telephone_number
    ,p.row_guid
    ,p.modified_date
FROM person.person AS p
  LEFT OUTER JOIN
    (SELECT
      business_entity_id
      ,UNNEST(xpath('/ci:additional_contact_info',
        additional_contact_info,
        '{{ci,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo}}')) AS node
    FROM person.person
    WHERE additional_contact_info IS NOT NULL) AS additional
  ON p.business_entity_id = additional.business_entity_id;


CREATE VIEW human_resources.v_employee
AS
SELECT
    e.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,e.job_title 
    ,pp.phone_number
    ,pnt.name AS phone_number_type
    ,ea.email_address
    ,p.email_promotion
    ,a.address_line_1
    ,a.address_line_2
    ,a.city
    ,sp.name AS state_province_name
    ,a.postal_code
    ,cr.name AS country_region_name
    ,p.additional_contact_info
FROM human_resources.employee e
  INNER JOIN person.person p
    ON p.business_entity_id = e.business_entity_id
  INNER JOIN person.business_entity_address bea
    ON bea.business_entity_id = e.business_entity_id
  INNER JOIN person.address a
    ON a.address_id = bea.address_id
  INNER JOIN person.state_province sp
    ON sp.state_province_id = a.state_province_id
  INNER JOIN person.country_region cr
    ON cr.country_region_code = sp.country_region_code
  LEFT OUTER JOIN person.person_phone pp
    ON pp.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.phone_number_type pnt
    ON pp.phone_number_type_id = pnt.phone_number_type_id
  LEFT OUTER JOIN person.email_address ea
    ON p.business_entity_id = ea.business_entity_id;


CREATE VIEW human_resources.v_employee_department
AS
SELECT
    e.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,e.job_title
    ,d.name AS department
    ,d.group_name
    ,edh.start_date
FROM human_resources.employee e
  INNER JOIN person.person p
    ON p.business_entity_id = e.business_entity_id
  INNER JOIN human_resources.employee_department_history edh
    ON e.business_entity_id = edh.business_entity_id
  INNER JOIN human_resources.department d
    ON edh.department_id = d.department_id
WHERE edh.end_date IS NULL;


CREATE VIEW human_resources.v_employee_department_history
AS
SELECT
    e.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,s.name AS shift
    ,d.name AS department
    ,d.group_name
    ,edh.start_date
    ,edh.end_date
FROM human_resources.employee e
  INNER JOIN person.person p
    ON p.business_entity_id = e.business_entity_id
  INNER JOIN human_resources.employee_department_history edh
    ON e.business_entity_id = edh.business_entity_id
  INNER JOIN human_resources.department d
    ON edh.department_id = d.department_id
  INNER JOIN human_resources.shift s
    ON s.shift_id = edh.shift_id;


CREATE VIEW sales.v_individual_customer
AS
SELECT
    p.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,pp.phone_number
    ,pnt.name AS phone_number_type
    ,ea.email_address
    ,p.email_promotion
    ,at.name AS address_type
    ,a.address_line_1
    ,a.address_line_2
    ,a.city
    ,sp.name AS state_province_name
    ,a.postal_code
    ,cr.name AS country_region_name
    ,p.demographics
FROM person.person p
  INNER JOIN person.business_entity_address bea
    ON bea.business_entity_id = p.business_entity_id
  INNER JOIN person.address a
    ON a.address_id = bea.address_id
  INNER JOIN person.state_province sp
    ON sp.state_province_id = a.state_province_id
  INNER JOIN person.country_region cr
    ON cr.country_region_code = sp.country_region_code
  INNER JOIN person.address_type at
    ON at.address_type_id = bea.address_type_id
  INNER JOIN sales.customer c
    ON c.person_id = p.business_entity_id
  LEFT OUTER JOIN person.email_address ea
    ON ea.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.person_phone pp
    ON pp.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.phone_number_type pnt
    ON pnt.phone_number_type_id = pp.phone_number_type_id
WHERE c.store_id IS NULL;


CREATE VIEW sales.v_person_demographics
AS
SELECT
    business_entity_id
    ,CAST((xpath('n:TotalPurchaseYTD/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS money)
            AS TotalPurchaseYTD
    ,CAST((xpath('n:DateFirstPurchase/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS DATE)
            AS DateFirstPurchase
    ,CAST((xpath('n:birth_date/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS DATE)
            AS birth_date
    ,(xpath('n:martial_status/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(1)
            AS martial_status
    ,(xpath('n:YearlyIncome/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS YearlyIncome
    ,(xpath('n:gender/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(1)
            AS gender
    ,CAST((xpath('n:TotalChildren/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS TotalChildren
    ,CAST((xpath('n:NumberChildrenAtHome/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS NumberChildrenAtHome
    ,(xpath('n:Education/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS Education
    ,(xpath('n:Occupation/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS Occupation
    ,CAST((xpath('n:HomeOwnerFlag/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS BOOLEAN)
            AS HomeOwnerFlag
    ,CAST((xpath('n:NumberCarsOwned/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS NumberCarsOwned
FROM person.person
  WHERE demographics IS NOT NULL;


CREATE VIEW human_resources.v_job_candidate
AS
SELECT
    job_candidate_id
    ,business_entity_id
    ,(xpath('/n:Resume/n:Name/n:Name.Prefix/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.Prefix"
    ,(xpath('/n:Resume/n:Name/n:Name.First/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.First"
    ,(xpath('/n:Resume/n:Name/n:Name.Middle/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.Middle"
    ,(xpath('/n:Resume/n:Name/n:Name.Last/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.Last"
    ,(xpath('/n:Resume/n:Name/n:Name.suffix/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.suffix"
    ,(xpath('/n:Resume/n:Skills/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "Skills"
    ,(xpath('n:address/n:Addr.type/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Addr.type"
    ,(xpath('n:address/n:Addr.location/n:location/n:Loc.country_region/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "Addr.Loc.country_region"
    ,(xpath('n:address/n:Addr.location/n:location/n:Loc.State/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "Addr.Loc.State"
    ,(xpath('n:address/n:Addr.location/n:location/n:Loc.city/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "Addr.Loc.city"
    ,(xpath('n:address/n:Addr.postal_code/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(20)
                   AS "Addr.postal_code"
    ,(xpath('/n:Resume/n:EMail/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "EMail"
    ,(xpath('/n:Resume/n:WebSite/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "WebSite"
    ,modified_date
FROM human_resources.job_candidate;


-- In this case we UNNEST in order to have multiple previous employments listed for
-- each job candidate.  But things become very brittle when using UNNEST like this,
-- with multiple columns...
-- ... if any of our Employment fragments were missing something, such as randomly a
-- Emp.FunctionCategory is not there, then there will be 0 rows returned.  Each
-- Employment element must contain all 10 sub-elements for this approach to work.
-- (See the Education example below for a better alternate approach!)
CREATE VIEW human_resources.v_job_candidate_employment
AS
SELECT
    job_candidate_id
    ,CAST(UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.start_date/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::VARCHAR(20) AS DATE)
                                                AS "Emp.start_date"
    ,CAST(UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.end_date/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::VARCHAR(20) AS DATE)
                                                AS "Emp.end_date"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.OrgName/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar(100)
                                                AS "Emp.OrgName"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.job_title/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar(100)
                                                AS "Emp.job_title"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Responsibility/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.Responsibility"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.FunctionCategory/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.FunctionCategory"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.IndustryCategory/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.IndustryCategory"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.location/ns:location/ns:Loc.country_region/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.Loc.country_region"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.location/ns:location/ns:Loc.State/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.Loc.State"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.location/ns:location/ns:Loc.city/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.Loc.city"
  FROM human_resources.job_candidate;


-- In this data set, not every listed education has a minor.  (OK, actually NONE of them do!)
-- So instead of using multiple UNNEST as above, which would result in 0 rows returned,
-- we just UNNEST once in a derived table, then convert each XML fragment into a document again
-- with one <root> element and a shorter namespace for ns:, and finally just use xpath on
-- all the created documents.
CREATE VIEW human_resources.v_job_candidate_education
AS
SELECT
  jc.job_candidate_id
  ,(xpath('/root/ns:Education/ns:Edu.Level/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(50)
                             AS "Edu.Level"
  ,CAST((xpath('/root/ns:Education/ns:Edu.start_date/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::VARCHAR(20) AS DATE)
                             AS "Edu.start_date"
  ,CAST((xpath('/root/ns:Education/ns:Edu.end_date/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::VARCHAR(20) AS DATE)
                             AS "Edu.end_date"
  ,(xpath('/root/ns:Education/ns:Edu.Degree/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(50)
                             AS "Edu.Degree"
  ,(xpath('/root/ns:Education/ns:Edu.Major/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(50)
                             AS "Edu.Major"
  ,(xpath('/root/ns:Education/ns:Edu.Minor/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(50)
                             AS "Edu.Minor"
  ,(xpath('/root/ns:Education/ns:Edu.GPA/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(5)
                             AS "Edu.GPA"
  ,(xpath('/root/ns:Education/ns:Edu.GPAScale/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(5)
                             AS "Edu.GPAScale"
  ,(xpath('/root/ns:Education/ns:Edu.School/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(100)
                             AS "Edu.School"
  ,(xpath('/root/ns:Education/ns:Edu.location/ns:location/ns:Loc.country_region/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(100)
                             AS "Edu.Loc.country_region"
  ,(xpath('/root/ns:Education/ns:Edu.location/ns:location/ns:Loc.State/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(100)
                             AS "Edu.Loc.State"
  ,(xpath('/root/ns:Education/ns:Edu.location/ns:location/ns:Loc.city/text()', jc.doc, '{{ns,http://adventure_works.com}}'))[1]::varchar(100)
                             AS "Edu.Loc.city"
FROM (SELECT job_candidate_id
    -- Because the underlying XML data used in this example has namespaces defined at the document level,
    -- when we take individual fragments using UNNEST then each fragment has no idea of the namespaces.
    -- So here each fragment gets turned back into its own document with a root element that defines a
    -- simpler thing for "ns" since this will only be used only in the xpath queries above.
    ,('<root xmlns:ns="http://adventure_works.com">' ||
      unnesting.Education::varchar ||
      '</root>')::xml AS doc
  FROM (SELECT job_candidate_id
      ,UNNEST(xpath('/ns:Resume/ns:Education', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}')) AS Education
    FROM human_resources.job_candidate) AS unnesting) AS jc;


-- Products and product descriptions by language.
-- We're making this a materialized view so that performance can be better.
CREATE MATERIALIZED VIEW production.v_product_and_description
AS
SELECT
    p.product_id
    ,p.Name
    ,pm.name AS product_model
    ,pmx.culture_id
    ,pd.description
FROM production.product p
    INNER JOIN production.product_model pm
    ON p.product_model_id = pm.product_model_id
    INNER JOIN production.product_model_product_description_culture pmx
    ON pm.product_model_id = pmx.product_model_id
    INNER JOIN production.product_description pd
    ON pmx.product_description_id = pd.product_description_id;

-- Index the v_product_and_description view
CREATE UNIQUE INDEX ix_v_product_and_description ON production.v_product_and_description(culture_id, product_id);
CLUSTER production.v_product_and_description USING ix_v_product_and_description;
-- Note that with a materialized view, changes to the underlying tables will
-- not change the contents of the view.  In order to maintain the index, if there
-- are changes to any of the 4 tables then you would need to run:
--   REFRESH MATERIALIZED VIEW production.v_product_and_description;


CREATE VIEW production.v_product_model_catalog_description
AS
SELECT
  product_model_id
  ,Name
  ,(xpath('/p1:product_description/p1:Summary/html:p/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{html,http://www.w3.org/1999/xhtml}}'))[1]::varchar
                                 AS "Summary"
  ,(xpath('/p1:product_description/p1:Manufacturer/p1:Name/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar
                                  AS Manufacturer
  ,(xpath('/p1:product_description/p1:Manufacturer/p1:Copyright/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(30)
                                                  AS Copyright
  ,(xpath('/p1:product_description/p1:Manufacturer/p1:ProductURL/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                  AS ProductURL
  ,(xpath('/p1:product_description/p1:Features/wm:Warranty/wm:WarrantyPeriod/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                          AS WarrantyPeriod
  ,(xpath('/p1:product_description/p1:Features/wm:Warranty/wm:description/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                          AS WarrantyDescription
  ,(xpath('/p1:product_description/p1:Features/wm:Maintenance/wm:NoOfYears/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                             AS NoOfYears
  ,(xpath('/p1:product_description/p1:Features/wm:Maintenance/wm:description/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                             AS MaintenanceDescription
  ,(xpath('/p1:product_description/p1:Features/wf:wheel/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS Wheel
  ,(xpath('/p1:product_description/p1:Features/wf:saddle/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS Saddle
  ,(xpath('/p1:product_description/p1:Features/wf:pedal/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS Pedal
  ,(xpath('/p1:product_description/p1:Features/wf:BikeFrame/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar
                                              AS BikeFrame
  ,(xpath('/p1:product_description/p1:Features/wf:crankset/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS Crankset
  ,(xpath('/p1:product_description/p1:Picture/p1:Angle/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS PictureAngle
  ,(xpath('/p1:product_description/p1:Picture/p1:size/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS PictureSize
  ,(xpath('/p1:product_description/p1:Picture/p1:product_photo_id/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS product_photo_id
  ,(xpath('/p1:product_description/p1:Specifications/Material/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS Material
  ,(xpath('/p1:product_description/p1:Specifications/color/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS color
  ,(xpath('/p1:product_description/p1:Specifications/product_line/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS product_line
  ,(xpath('/p1:product_description/p1:Specifications/style/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS style
  ,(xpath('/p1:product_description/p1:Specifications/RiderExperience/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(1024)
                                                 AS RiderExperience
  ,row_guid
  ,modified_date
FROM production.product_model
WHERE catalog_description IS NOT NULL;


-- instructions have many locations, and locations have many steps
CREATE VIEW production.v_product_model_instruction
AS
SELECT
    pm.product_model_id
    ,pm.Name
    -- Access the overall instructions xml brought through from %line 2938 and %line 2943
    ,(xpath('/ns:root/text()', pm.instructions, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelManuInstructions}}'))[1]::varchar AS instructions
    -- Bring out information about the location, broken out in %line 2945
    ,CAST((xpath('@location_id', pm.MfgInstructions))[1]::varchar AS INTEGER) AS "location_id"
    ,CAST((xpath('@setup_hours', pm.MfgInstructions))[1]::varchar AS DECIMAL(9, 4)) AS "setup_hours"
    ,CAST((xpath('@machine_hours', pm.MfgInstructions))[1]::varchar AS DECIMAL(9, 4)) AS "machine_hours"
    ,CAST((xpath('@labor_hours', pm.MfgInstructions))[1]::varchar AS DECIMAL(9, 4)) AS "labor_hours"
    ,CAST((xpath('@lot_size', pm.MfgInstructions))[1]::varchar AS INTEGER) AS "lot_size"
    -- Show specific detail about each step broken out in %line 2940
    ,(xpath('/step/text()', pm.Step))[1]::varchar(1024) AS "Step"
    ,pm.row_guid
    ,pm.modified_date
FROM (SELECT locations.product_model_id, locations.Name, locations.row_guid, locations.modified_date
    ,locations.instructions, locations.MfgInstructions
    -- Further break out the location information from the inner query below into individual steps
    ,UNNEST(xpath('step', locations.MfgInstructions)) AS Step
  FROM (SELECT
      -- Just pass these through so they can be referenced at the outermost query
      product_model_id, Name, row_guid, modified_date, instructions
      -- And also break out instructions into individual locations to pass up to the middle query
      ,UNNEST(xpath('/ns:root/ns:location', instructions, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelManuInstructions}}')) AS MfgInstructions
    FROM production.product_model) AS locations) AS pm;


CREATE VIEW sales.v_sales_person
AS
SELECT
    s.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,e.job_title
    ,pp.phone_number
    ,pnt.name AS phone_number_type
    ,ea.email_address
    ,p.email_promotion
    ,a.address_line_1
    ,a.address_line_2
    ,a.city
    ,sp.name AS state_province_name
    ,a.postal_code
    ,cr.name AS country_region_name
    ,st.name AS territory_name
    ,st.group AS territory_group
    ,s.sales_quota
    ,s.sales_ytd
    ,s.sales_last_year
FROM sales.sales_person s
  INNER JOIN human_resources.employee e
    ON e.business_entity_id = s.business_entity_id
  INNER JOIN person.person p
    ON p.business_entity_id = s.business_entity_id
  INNER JOIN person.business_entity_address bea
    ON bea.business_entity_id = s.business_entity_id
  INNER JOIN person.address a
    ON a.address_id = bea.address_id
  INNER JOIN person.state_province sp
    ON sp.state_province_id = a.state_province_id
  INNER JOIN person.country_region cr
    ON cr.country_region_code = sp.country_region_code
  LEFT OUTER JOIN sales.sales_territory st
    ON st.territory_id = s.territory_id
  LEFT OUTER JOIN person.email_address ea
    ON ea.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.person_phone pp
    ON pp.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.phone_number_type pnt
    ON pnt.phone_number_type_id = pp.phone_number_type_id;


-- This view provides the aggregated data that gets used in the PIVOTed view below
CREATE VIEW sales.v_sales_person_sales_by_fiscal_years_date
AS
-- Of the 56 possible combinations of one of the 14 SalesPersons selling across one of
-- 4 FiscalYears, here we end up with 48 rows of aggregated data (since some sales people
-- were hired and started working in FY2012 or FY2013).
SELECT granular.sales_person_id, granular.full_name, granular.job_title, granular.sales_territory, SUM(granular.sub_total) AS sales_total, granular.fiscal_year
FROM
-- Brings back 3703 rows of data -- there are 3806 total sales done by a sales_person,
-- of which 103 do not have any sales territory.  This is fed into the outer GROUP BY
-- which results in 48 aggregated rows of sales data.
  (SELECT
      soh.sales_person_id
      ,p.first_name || ' ' || COALESCE(p.middle_name || ' ', '') || p.last_name AS full_name
      ,e.job_title
      ,st.name AS sales_territory
      ,soh.sub_total
      ,EXTRACT(YEAR FROM soh.order_date + '6 months'::interval) AS fiscal_year
  FROM sales.sales_person sp
    INNER JOIN sales.sales_order_header soh
      ON sp.business_entity_id = soh.sales_person_id
    INNER JOIN sales.sales_territory st
      ON sp.territory_id = st.territory_id
    INNER JOIN human_resources.employee e
      ON soh.sales_person_id = e.business_entity_id
    INNER JOIN person.person p
      ON p.business_entity_id = sp.business_entity_id
  ) AS granular
GROUP BY granular.sales_person_id, granular.full_name, granular.job_title, granular.sales_territory, granular.fiscal_year;

-- Note that this PIVOT query originally refered to years 2002-2004, which jived with
-- earlier versions of the adventure_works data.  Somewhere along the way all the dates
-- were cranked forward by exactly a decade, but this view wasn't updated, effectively
-- breaking it.  The hard-coded fiscal years below fix this issue.

-- Current sales data ranges from May 31, 2011 through June 30, 2014, so there's one
-- month of fiscal year 2011 data, but mostly FY 2012 through 2014.

-- This query properly shows no data for three of our sales people in 2012,
-- as they were hired during FY 2013.
CREATE VIEW sales.v_sales_person_sales_by_fiscal_years
AS
SELECT * FROM crosstab(
'SELECT
    sales_person_id
    ,full_name
    ,job_title
    ,sales_territory
    ,fiscal_year
    ,sales_total
FROM sales.v_sales_person_sales_by_fiscal_years_date
ORDER BY 2,4'
-- This set of fiscal years could have dynamically come from a SELECT DISTINCT,
-- but we wanted to omit 2011 and also ...
,$$SELECT unnest('{2012,2013,2014}'::text[])$$)
-- ... still the fiscal_year values have to be hard-coded here.
AS sales_total ("sales_person_id" integer, "full_name" text, "job_title" text, "sales_territory" text,
 "2012" DECIMAL(12, 4), "2013" DECIMAL(12, 4), "2014" DECIMAL(12, 4));


CREATE MATERIALIZED VIEW person.v_state_province_country_region
AS
SELECT
    sp.state_province_id
    ,sp.state_province_code
    ,sp.is_only_state_province_flag
    ,sp.name AS state_province_name
    ,sp.territory_id
    ,cr.country_region_code
    ,cr.name AS country_region_name
FROM person.state_province sp
    INNER JOIN person.country_region cr
    ON sp.country_region_code = cr.country_region_code;

CREATE UNIQUE INDEX ix_v_state_province_country_region ON person.v_state_province_country_region(state_province_id, country_region_code);
CLUSTER person.v_state_province_country_region USING ix_v_state_province_country_region;
-- If there are changes to either of these tables, this should be run to update the view:
--   REFRESH MATERIALIZED VIEW production.v_state_province_country_region;


CREATE VIEW sales.v_store_with_demographics
AS
SELECT
    business_entity_id
    ,Name
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:AnnualSales/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS money)
                                       AS "AnnualSales"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:AnnualRevenue/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS money)
                                       AS "AnnualRevenue"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:BankName/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(50)
                                  AS "BankName"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:BusinessType/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(5)
                                  AS "BusinessType"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:YearOpened/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "YearOpened"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Specialty/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(50)
                                  AS "Specialty"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:SquareFeet/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "SquareFeet"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Brands/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(30)
                                  AS "Brands"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Internet/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(30)
                                  AS "Internet"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:NumberEmployees/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "NumberEmployees"
FROM sales.store;


CREATE VIEW sales.v_store_with_contact
AS
SELECT
    s.business_entity_id
    ,s.Name
    ,ct.name AS contact_type
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,pp.phone_number
    ,pnt.name AS phone_number_type
    ,ea.email_address
    ,p.email_promotion
FROM sales.store s
  INNER JOIN person.business_entity_contact bec
    ON bec.business_entity_id = s.business_entity_id
  INNER JOIN person.contact_type ct
    ON ct.contact_type_id = bec.contact_type_id
  INNER JOIN person.person p
    ON p.business_entity_id = bec.person_id
  LEFT OUTER JOIN person.email_address ea
    ON ea.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.person_phone pp
    ON pp.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.phone_number_type pnt
    ON pnt.phone_number_type_id = pp.phone_number_type_id;


CREATE VIEW sales.v_store_with_addresses
AS
SELECT
    s.business_entity_id
    ,s.Name
    ,at.name AS address_type
    ,a.address_line_1
    ,a.address_line_2
    ,a.city
    ,sp.name AS state_province_name
    ,a.postal_code
    ,cr.name AS country_region_name
FROM sales.store s
  INNER JOIN person.business_entity_address bea
    ON bea.business_entity_id = s.business_entity_id
  INNER JOIN person.address a
    ON a.address_id = bea.address_id
  INNER JOIN person.state_province sp
    ON sp.state_province_id = a.state_province_id
  INNER JOIN person.country_region cr
    ON cr.country_region_code = sp.country_region_code
  INNER JOIN person.address_type at
    ON at.address_type_id = bea.address_type_id;


CREATE VIEW purchasing.v_vendor_with_contacts
AS
SELECT
    v.business_entity_id
    ,v.Name
    ,ct.name AS contact_type
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,pp.phone_number
    ,pnt.name AS phone_number_type
    ,ea.email_address
    ,p.email_promotion
FROM purchasing.vendor v
  INNER JOIN person.business_entity_contact bec
    ON bec.business_entity_id = v.business_entity_id
  INNER JOIN person.contact_type ct
    ON ct.contact_type_id = bec.contact_type_id
  INNER JOIN person.person p
    ON p.business_entity_id = bec.person_id
  LEFT OUTER JOIN person.email_address ea
    ON ea.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.person_phone pp
    ON pp.business_entity_id = p.business_entity_id
  LEFT OUTER JOIN person.phone_number_type pnt
    ON pnt.phone_number_type_id = pp.phone_number_type_id;


CREATE VIEW purchasing.v_vendor_with_addresses
AS
SELECT
    v.business_entity_id
    ,v.Name
    ,at.name AS address_type
    ,a.address_line_1
    ,a.address_line_2
    ,a.city
    ,sp.name AS state_province_name
    ,a.postal_code
    ,cr.name AS country_region_name
FROM purchasing.vendor v
  INNER JOIN person.business_entity_address bea
    ON bea.business_entity_id = v.business_entity_id
  INNER JOIN person.address a
    ON a.address_id = bea.address_id
  INNER JOIN person.state_province sp
    ON sp.state_province_id = a.state_province_id
  INNER JOIN person.country_region cr
    ON cr.country_region_code = sp.country_region_code
  INNER JOIN person.address_type at
    ON at.address_type_id = bea.address_type_id;


-- Convenience views

CREATE SCHEMA pe
  CREATE VIEW a AS SELECT address_id AS id, * FROM person.address
  CREATE VIEW at AS SELECT address_type_id AS id, * FROM person.address_type
  CREATE VIEW be AS SELECT business_entity_id AS id, * FROM person.business_entity
  CREATE VIEW bea AS SELECT business_entity_id AS id, * FROM person.business_entity_address
  CREATE VIEW bec AS SELECT business_entity_id AS id, * FROM person.business_entity_contact
  CREATE VIEW ct AS SELECT contact_type_id AS id, * FROM person.contact_type
  CREATE VIEW cr AS SELECT * FROM person.country_region
  CREATE VIEW e AS SELECT email_address_id AS id, * FROM person.email_address
  CREATE VIEW pa AS SELECT business_entity_id AS id, * FROM person.password
  CREATE VIEW p AS SELECT business_entity_id AS id, * FROM person.person
  CREATE VIEW pp AS SELECT business_entity_id AS id, * FROM person.person_phone
  CREATE VIEW pnt AS SELECT phone_number_type_id AS id, * FROM person.phone_number_type
  CREATE VIEW sp AS SELECT state_province_id AS id, * FROM person.state_province
;
CREATE SCHEMA hr
  CREATE VIEW d AS SELECT department_id AS id, * FROM human_resources.department
  CREATE VIEW e AS SELECT business_entity_id AS id, * FROM human_resources.employee
  CREATE VIEW edh AS SELECT business_entity_id AS id, * FROM human_resources.employee_department_history
  CREATE VIEW eph AS SELECT business_entity_id AS id, * FROM human_resources.employee_pay_history
  CREATE VIEW jc AS SELECT job_candidate_id AS id, * FROM human_resources.job_candidate
  CREATE VIEW s AS SELECT shift_id AS id, * FROM human_resources.shift
;
CREATE SCHEMA pr
  CREATE VIEW bom AS SELECT bill_of_materials_id AS id, * FROM production.bill_of_materials
  CREATE VIEW c AS SELECT culture_id AS id, * FROM production.culture
  CREATE VIEW d AS SELECT * FROM production.document
  CREATE VIEW i AS SELECT illustration_id AS id, * FROM production.illustration
  CREATE VIEW l AS SELECT location_id AS id, * FROM production.location
  CREATE VIEW p AS SELECT product_id AS id, * FROM production.product
  CREATE VIEW pc AS SELECT product_category_id AS id, * FROM production.product_category
  CREATE VIEW pch AS SELECT product_id AS id, * FROM production.product_cost_history
  CREATE VIEW pd AS SELECT product_description_id AS id, * FROM production.product_description
  CREATE VIEW pdoc AS SELECT product_id AS id, * FROM production.product_document
  CREATE VIEW pi AS SELECT product_id AS id, * FROM production.product_inventory
  CREATE VIEW plph AS SELECT product_id AS id, * FROM production.product_list_price_history
  CREATE VIEW pm AS SELECT product_model_id AS id, * FROM production.product_model
  CREATE VIEW pmi AS SELECT * FROM production.product_model_illustration
  CREATE VIEW pmpdc AS SELECT * FROM production.product_model_product_description_culture
  CREATE VIEW pp AS SELECT product_photo_id AS id, * FROM production.product_photo
  CREATE VIEW ppp AS SELECT * FROM production.product_product_photo
  CREATE VIEW pr AS SELECT product_review_id AS id, * FROM production.product_review
  CREATE VIEW psc AS SELECT product_subcategory_id AS id, * FROM production.product_subcategory
  CREATE VIEW sr AS SELECT scrap_reason_id AS id, * FROM production.scrap_reason
  CREATE VIEW th AS SELECT transaction_id AS id, * FROM production.transaction_history
  CREATE VIEW tha AS SELECT transaction_id AS id, * FROM production.transaction_history_archive
  CREATE VIEW um AS SELECT unit_measure_code AS id, * FROM production.unit_measure
  CREATE VIEW w AS SELECT work_order_id AS id, * FROM production.work_order
  CREATE VIEW wr AS SELECT work_order_id AS id, * FROM production.work_order_routing
;
CREATE SCHEMA pu
  CREATE VIEW pv AS SELECT product_id AS id, * FROM purchasing.product_vendor
  CREATE VIEW pod AS SELECT purchase_order_detail_id AS id, * FROM purchasing.purchase_order_detail
  CREATE VIEW poh AS SELECT purchase_order_id AS id, * FROM purchasing.purchase_order_header
  CREATE VIEW sm AS SELECT ship_method_id AS id, * FROM purchasing.ship_method
  CREATE VIEW v AS SELECT business_entity_id AS id, * FROM purchasing.vendor
;
CREATE SCHEMA sa
  CREATE VIEW crc AS SELECT * FROM sales.country_region_currency
  CREATE VIEW cc AS SELECT credit_card_id AS id, * FROM sales.credit_card
  CREATE VIEW cu AS SELECT currency_code AS id, * FROM sales.currency
  CREATE VIEW cr AS SELECT * FROM sales.currency_rate
  CREATE VIEW c AS SELECT customer_id AS id, * FROM sales.customer
  CREATE VIEW pcc AS SELECT business_entity_id AS id, * FROM sales.person_credit_card
  CREATE VIEW sod AS SELECT sales_order_detail_id AS id, * FROM sales.sales_order_detail
  CREATE VIEW soh AS SELECT sales_order_id AS id, * FROM sales.sales_order_header
  CREATE VIEW sohsr AS SELECT * FROM sales.sales_order_header_sales_reason
  CREATE VIEW sp AS SELECT business_entity_id AS id, * FROM sales.sales_person
  CREATE VIEW spqh AS SELECT business_entity_id AS id, * FROM sales.sales_person_quota_history
  CREATE VIEW sr AS SELECT sales_reason_id AS id, * FROM sales.sales_reason
  CREATE VIEW tr AS SELECT sales_tax_rate_id AS id, * FROM sales.sales_tax_rate
  CREATE VIEW st AS SELECT territory_id AS id, * FROM sales.sales_territory
  CREATE VIEW sth AS SELECT territory_id AS id, * FROM sales.sales_territory_history
  CREATE VIEW sci AS SELECT shopping_cart_item_id AS id, * FROM sales.shopping_cart_item
  CREATE VIEW so AS SELECT special_offer_id AS id, * FROM sales.special_offer
  CREATE VIEW sop AS SELECT special_offer_id AS id, * FROM sales.special_offer_product
  CREATE VIEW s AS SELECT business_entity_id AS id, * FROM sales.store
;

-- Ensure that Perry Skountrianos' change for Türkiye is implemented properly if it was intended
-- https://github.com/microsoft/sql-server-samples/commit/cca0f1920e3bec5b9cef97e1fdc32b6883526581
-- Fix any messed up one if such a thing exists and is not proper unicode
UPDATE person.country_region SET name='T' || U&'\00FC' || 'rkiye' WHERE name='Türkiye';
-- Optionally you can uncomment this to update "Turkey" to the unicode-appropriate rendition of "Türkiye"
-- UPDATE person.country_region SET name='T' || U&'\00FC' || 'rkiye' WHERE name='Turkey';

-- If you intend to use this data with The Brick (or some other Rails project) then you may want
-- to rename the "class" column in production.product so it does not interfere with Ruby's reserved
-- keyword "class":
-- ALTER TABLE production.product RENAME COLUMN class TO class_;
\pset tuples_only off



-- 805 rows in business_entity but not in person
-- SELECT be.business_entity_id FROM person.business_entity AS be LEFT OUTER JOIN person.person AS p ON be.business_entity_id = p.business_entity_id WHERE p.business_entity_id IS NULL;

-- All the tables in adventure_works:
-- (Did you know that \dt can filter schema and table names using RegEx?)
\dt (human_resources|person|production|purchasing|sales).*
