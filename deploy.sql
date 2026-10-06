-- ============================================================
-- MASTER DEPLOY SCRIPT
-- Supply Chain Ontology & Governed Conversational Analytics
-- Run this file to deploy all objects to Snowflake in order.
-- ============================================================
-- 
-- Prerequisites:
--   - ACCOUNTADMIN access
--   - COMPUTE_WH warehouse exists
--
-- Total objects: 50
--   Phase 1: 1 database, 1 schema, 5 roles, grants
--   Phase 2: 9 base tables, 1 alerts table, sample data
--   Phase 3: 5 masking policies
--   Phase 4: 4 dynamic tables
--   Phase 5: 3 streams, 3 tasks
--   Phase 6: 4 custom tools (1 UDF + 3 SPs), 1 ML model
--   Phase 7: 1 stage, 5 skills (uploaded separately)
--   Phase 8: 1 semantic view, 4 agents
--   Phase 9: 1 Streamlit app (deployed separately via SiS)
--   Phase 10: 3 CoCo automations (team-based daily briefs)
--
-- Execution order (run each file in sequence):
-- ============================================================

-- Phase 1: Foundation
-- Run: 01_foundation/01_database_schema.sql
-- Run: 01_foundation/02_roles.sql
-- Run: 01_foundation/03_grants.sql

-- Phase 2: Base Tables + Sample Data
-- Run: 02_base_tables/01_master_tables.sql
-- Run: 02_base_tables/02_operational_tables.sql
-- Run: 02_base_tables/03_alerts_table.sql
-- Run: 02_base_tables/04_sample_data.sql

-- Phase 3: Masking Policies
-- Run: 03_masking_policies/01_masking_policies.sql

-- Phase 4: Dynamic Tables
-- Run: 04_dynamic_tables/01_dynamic_tables.sql

-- Phase 5: Streams + Tasks
-- Run: 05_streams_tasks/01_streams.sql
-- Run: 05_streams_tasks/02_tasks.sql

-- Phase 6: Custom Tools + ML Model
-- Run: 06_custom_tools/01_generate_scorecard.sql
-- Run: 06_custom_tools/02_create_purchase_order.sql
-- Run: 06_custom_tools/03_trigger_expedite.sql
-- Run: 06_custom_tools/04_update_supplier_rating.sql
-- Run: 07_ml_model/01_demand_forecast_model.sql

-- Phase 7: Stage + Skills
-- Run: 08_skills/00_create_stage.sql
-- Then upload skills to stage:
--   PUT file://08_skills/supplier_scorecard/SKILL.md @SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/supplier_scorecard/
--   PUT file://08_skills/reorder_advisor/SKILL.md @SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/reorder_advisor/
--   PUT file://08_skills/shipment_tracker/SKILL.md @SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/shipment_tracker/
--   PUT file://08_skills/demand_planner/SKILL.md @SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/demand_planner/
--   PUT file://08_skills/cost_analyzer/SKILL.md @SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/cost_analyzer/

-- Phase 8: Semantic View + Agents
-- Run: 09_semantic_view/01_supply_chain_ontology.sql
-- Run: 10_agents/01_procurement_agent.sql
-- Run: 10_agents/02_planning_agent.sql
-- Run: 10_agents/03_logistics_agent.sql
-- Run: 10_agents/04_supply_chain_agent.sql

-- Phase 9: Streamlit App
-- Deploy via Snowsight: AI & ML > Streamlit > Create Streamlit App
-- Upload: 11_streamlit/app.py
-- Set warehouse: COMPUTE_WH
-- Set database/schema: SUPPLY_CHAIN_DB.SCM

-- Phase 10: CoCo Automations (team-based daily briefs)
-- Deploy via CoCo CLI from the project root directory:
--
-- Logistics (weekdays 7:30 AM IST — fires first, shipment status feeds others):
--   cortex automation create --name LOGISTICS_DAILY_BRIEF --schedule "weekdays at 7:30am" --timezone "Asia/Kolkata" --prompt-file "12_automations/logistics_daily_brief_prompt.md"
--
-- Planning (weekdays 8:00 AM IST — inventory + fulfillment status):
--   cortex automation create --name PLANNING_DAILY_BRIEF --schedule "weekdays at 8:00am" --timezone "Asia/Kolkata" --prompt-file "12_automations/planning_daily_brief_prompt.md"
--
-- Procurement (weekdays 8:30 AM IST — supplier scores + cost trends + reorders):
--   cortex automation create --name PROCUREMENT_DAILY_BRIEF --schedule "weekdays at 8:30am" --timezone "Asia/Kolkata" --prompt-file "12_automations/procurement_daily_brief_prompt.md"
--
-- Verify all automations:
--   cortex automation list
--   cortex automation doctor LOGISTICS_DAILY_BRIEF
--   cortex automation doctor PLANNING_DAILY_BRIEF
--   cortex automation doctor PROCUREMENT_DAILY_BRIEF
