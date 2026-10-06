-- ============================================================
-- Phase 8: PLANNING_AGENT (sub-agent)
-- Domain: Demand / Planning
-- Skills: demand_planner, reorder_advisor
-- Tools: Cortex Analyst only (no generic tools)
-- MCP: SLACK_MCP (critical stock alerts)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE AGENT PLANNING_AGENT
  COMMENT = 'Planning domain sub-agent'
  FROM SPECIFICATION $$
orchestration:
  tool_not_accessible: accept
  budget: { seconds: 60, tokens: 32000 }
instructions:
  response: >
    You are the Planning Specialist. Domain: demand forecasting with ML FORECAST model,
    inventory planning, reorder timing. Use the pre-trained DEMAND_FORECAST_MODEL
    (multi-series, no retraining per query). Always show confidence intervals.
    If fewer than 60 days history, fall back to rolling average and disclose.
    
    SLACK NOTIFICATIONS (via SLACK_MCP):
    - When identifying CRITICAL stock levels (DOI < 3 days), send to #supply-chain-alerts:
      "[CRITICAL STOCK] <part_name> at <plant_name>
       DOI: <doi> days | On-hand: <qty> | Safety stock: <safety_qty>
       Avg daily demand: <demand> units
       Action: Reorder recommended"
    - If Slack send fails, log the failure but continue with the analysis.
skills:
  - name: demand_planner
    source:
      type: STAGE
      path: "@SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/demand_planner"
  - name: reorder_advisor
    source:
      type: STAGE
      path: "@SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/reorder_advisor"
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: SupplyChainAnalyst
      description: Query supply chain data via semantic view
tool_resources:
  SupplyChainAnalyst:
    semantic_view: SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ONTOLOGY
    execution_environment:
      type: warehouse
      warehouse: COMPUTE_WH
mcp_servers:
  - server_spec:
      name: SUPPLY_CHAIN_DB.SCM.SLACK_MCP
$$;

GRANT USAGE ON AGENT PLANNING_AGENT TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON AGENT PLANNING_AGENT TO ROLE PLANNING_ROLE;
