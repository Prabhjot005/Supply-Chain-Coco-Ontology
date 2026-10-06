-- ============================================================
-- Phase 6: Stage for skills
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE STAGE SKILL_STAGE
  COMMENT = 'Internal stage for storing reusable supply chain agent skills';
