-- ============================================================
-- Phase 1: Foundation — Roles and Hierarchy
-- ============================================================
-- Role hierarchy:
--   ACCOUNTADMIN
--     └── SUPPLY_CHAIN_ADMIN (DDL, maintenance, bypasses all masks)
--           ├── SC_AGENT_ROLE (primary agent — full read, bypasses masks)
--           ├── PROCUREMENT_ROLE (domain-restricted)
--           ├── PLANNING_ROLE (domain-restricted)
--           └── LOGISTICS_ROLE (domain-restricted)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- Create roles
CREATE ROLE IF NOT EXISTS SUPPLY_CHAIN_ADMIN
  COMMENT = 'Admin role for supply chain project — DDL, maintenance, bypasses all masking policies';

CREATE ROLE IF NOT EXISTS SC_AGENT_ROLE
  COMMENT = 'Primary agent role — full read access, bypasses masking policies, no DDL';

CREATE ROLE IF NOT EXISTS PROCUREMENT_ROLE
  COMMENT = 'Procurement domain — sees cost data, supplier ratings, landed cost. Masked: customer details, safety stock';

CREATE ROLE IF NOT EXISTS PLANNING_ROLE
  COMMENT = 'Planning domain — sees customers, inventory details, safety stock, reorder points. Masked: cost data, supplier ratings, carrier';

CREATE ROLE IF NOT EXISTS LOGISTICS_ROLE
  COMMENT = 'Logistics domain — sees shipment details, carrier performance. Masked: cost data, customer data, safety stock, reorder points';

-- Build role hierarchy
GRANT ROLE SUPPLY_CHAIN_ADMIN TO ROLE ACCOUNTADMIN;
GRANT ROLE SC_AGENT_ROLE TO ROLE SUPPLY_CHAIN_ADMIN;
GRANT ROLE PROCUREMENT_ROLE TO ROLE SUPPLY_CHAIN_ADMIN;
GRANT ROLE PLANNING_ROLE TO ROLE SUPPLY_CHAIN_ADMIN;
GRANT ROLE LOGISTICS_ROLE TO ROLE SUPPLY_CHAIN_ADMIN;
