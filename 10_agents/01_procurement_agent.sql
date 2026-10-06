-- ============================================================
-- Phase 8: PROCUREMENT_AGENT (sub-agent)
-- Domain: Procurement
-- Skills: supplier_scorecard, cost_analyzer, reorder_advisor
-- Tools: Cortex Analyst, GENERATE_SCORECARD, CREATE_PURCHASE_ORDER, UPDATE_SUPPLIER_RATING
-- MCP: ATLASSIAN_MCP (Jira), GMAIL, SLACK_MCP (Slack alerts)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE AGENT PROCUREMENT_AGENT
  COMMENT = 'Procurement domain sub-agent with Jira MCP integration'
  FROM SPECIFICATION $$
orchestration:
  tool_not_accessible: accept
  budget: { seconds: 60, tokens: 32000 }
instructions:
  response: |
    You are the Procurement Specialist. Domain: supplier evaluation, cost analysis, reorder, PO creation.
    Before any write action, present the proposal and wait for confirmation.
    User can edit quantity and supplier. Never recommend based on cost alone.
    
    After CREATE_PURCHASE_ORDER succeeds, use ATLASSIAN_MCP to create a Jira issue in project SCRUM:
    - Issue type: Task
    - Summary: "[PO] <part_id> from <supplier_id> - Qty <quantity>"
    - Description: Include plant, quantity, reason, and any cost context.
    
    SLACK NOTIFICATIONS (via SLACK_MCP):
    - After CREATE_PURCHASE_ORDER succeeds + Jira created, send to #supply-chain-alerts:
      "[PO CREATED] <part_id> from <supplier_name> — Qty: <quantity>
       Plant: <plant_name> | Est. cost: $<amount> | Jira: <ticket_key>
       Reason: <reason>"
    - After UPDATE_SUPPLIER_RATING succeeds, send to #supply-chain-alerts:
      "[RATING CHANGE] <supplier_name> — <old_rating> → <new_rating>
       Reason: <reason>"
    - If Slack send fails, log the failure but do NOT block the workflow.
skills:
  - name: supplier_scorecard
    source:
      type: STAGE
      path: "@SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/supplier_scorecard"
  - name: cost_analyzer
    source:
      type: STAGE
      path: "@SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/cost_analyzer"
  - name: reorder_advisor
    source:
      type: STAGE
      path: "@SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/reorder_advisor"
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: SupplyChainAnalyst
      description: Query supply chain data via semantic view
  - tool_spec:
      type: generic
      name: GENERATE_SCORECARD
      description: "Compute supplier score (0-10). Read-only."
      input_schema:
        type: object
        properties:
          p_supplier_id:
            type: string
            description: "Supplier ID (e.g. S01)"
        required: ["p_supplier_id"]
  - tool_spec:
      type: generic
      name: CREATE_PURCHASE_ORDER
      description: "Create purchase order. REQUIRES USER CONFIRMATION."
      input_schema:
        type: object
        properties:
          p_part_id:
            type: string
            description: "Part ID to order"
          p_supplier_id:
            type: string
            description: "Supplier ID"
          p_plant_id:
            type: string
            description: "Destination plant ID"
          p_quantity:
            type: number
            description: "Quantity to order"
          p_reason:
            type: string
            description: "Reason for the purchase order"
        required: ["p_part_id", "p_supplier_id", "p_plant_id", "p_quantity", "p_reason"]
  - tool_spec:
      type: generic
      name: UPDATE_SUPPLIER_RATING
      description: "Update supplier rating. REQUIRES USER CONFIRMATION. Max 1 tier."
      input_schema:
        type: object
        properties:
          p_supplier_id:
            type: string
            description: "Supplier ID"
          p_new_rating:
            type: string
            description: "New rating: A, B, C, D, or F"
          p_reason:
            type: string
            description: "Reason for the change"
          p_override:
            type: boolean
            description: "TRUE for manual override, FALSE for data-driven"
        required: ["p_supplier_id", "p_new_rating", "p_reason", "p_override"]
mcp_servers:
  - server_spec:
      name: SUPPLY_CHAIN_DB.SCM.ATLASSIAN_MCP
  - server_spec:
      name: SUPPLY_CHAIN_DB.SCM.GMAIL
  - server_spec:
      name: SUPPLY_CHAIN_DB.SCM.SLACK_MCP
tool_resources:
  SupplyChainAnalyst:
    semantic_view: SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ONTOLOGY
    execution_environment:
      type: warehouse
      warehouse: COMPUTE_WH
  GENERATE_SCORECARD:
    identifier: SUPPLY_CHAIN_DB.SCM.GENERATE_SCORECARD
    type: function
    execution_environment:
      type: warehouse
      warehouse: COMPUTE_WH
  CREATE_PURCHASE_ORDER:
    identifier: SUPPLY_CHAIN_DB.SCM.CREATE_PURCHASE_ORDER
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: COMPUTE_WH
  UPDATE_SUPPLIER_RATING:
    identifier: SUPPLY_CHAIN_DB.SCM.UPDATE_SUPPLIER_RATING
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: COMPUTE_WH
$$;

GRANT USAGE ON AGENT PROCUREMENT_AGENT TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON AGENT PROCUREMENT_AGENT TO ROLE PROCUREMENT_ROLE;
