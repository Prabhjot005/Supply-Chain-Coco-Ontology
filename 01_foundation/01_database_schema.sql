-- ============================================================
-- Phase 1: Foundation — Database and Schema
-- ============================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS SUPPLY_CHAIN_DB
  COMMENT = 'Supply Chain Ontology and Governed Conversational Analytics';

CREATE SCHEMA IF NOT EXISTS SUPPLY_CHAIN_DB.SCM
  COMMENT = 'Supply Chain Management — core schema for ontology, agents, and analytics';

USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;
USE WAREHOUSE COMPUTE_WH;
