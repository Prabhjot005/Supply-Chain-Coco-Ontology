-- ============================================================
-- Phase 2: Base Tables — Master Tables (Access History audit)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;
USE WAREHOUSE COMPUTE_WH;

-- SUPPLIERS: master data for all suppliers
CREATE OR REPLACE TABLE SUPPLIERS (
    supplier_id     VARCHAR(10)   PRIMARY KEY,
    name            VARCHAR(100)  NOT NULL,
    country         VARCHAR(50)   NOT NULL,
    lead_time_days  INT           NOT NULL,
    quality_rating  VARCHAR(1)    NOT NULL DEFAULT 'B'  -- A/B/C/D/F
)
COMMENT = 'Supplier master data — audited via Access History (365 days)';

-- PARTS: SKU catalog
CREATE OR REPLACE TABLE PARTS (
    part_id         VARCHAR(10)   PRIMARY KEY,
    description     VARCHAR(200)  NOT NULL,
    category        VARCHAR(50)   NOT NULL,
    unit_cost       NUMBER(10,2)  NOT NULL,
    weight_kg       NUMBER(8,2)
)
COMMENT = 'Part/SKU catalog — audited via Access History (365 days)';

-- PLANTS: manufacturing/warehouse locations
CREATE OR REPLACE TABLE PLANTS (
    plant_id        VARCHAR(10)   PRIMARY KEY,
    name            VARCHAR(100)  NOT NULL,
    city            VARCHAR(50)   NOT NULL,
    country         VARCHAR(50)   NOT NULL,
    capacity        INT           NOT NULL
)
COMMENT = 'Plant/warehouse locations — audited via Access History (365 days)';

-- CUSTOMERS: customer master
CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id     VARCHAR(10)   PRIMARY KEY,
    name            VARCHAR(100)  NOT NULL,
    segment         VARCHAR(50)   NOT NULL,
    region          VARCHAR(50)   NOT NULL
)
COMMENT = 'Customer master data — audited via Access History (365 days)';
