-- ============================================================
-- Phase 8: SUPPLY_CHAIN_AGENT (primary agent)
-- NO skills â€” all skills live on domain sub-agents
-- Tools: Cortex Analyst, Data to Chart, 5 generic tools, 3 agent toolsets
-- MCP: ATLASSIAN_MCP (Jira), GMAIL, SLACK_MCP (Slack alerts)
-- Tool type for SPs/UDFs: generic (not snowflake_tool)
-- Each generic tool requires: input_schema + execution_environment in tool_resources
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE AGENT SUPPLY_CHAIN_AGENT
  COMMENT = 'Primary supply chain agent with MCP integrations'
  FROM SPECIFICATION $$
orchestration:
  tool_not_accessible: accept
  budget: { seconds: 60, tokens: 32000 }
instructions:
  response: |
    You are the Supply Chain Analyst. Answer data questions directly via Cortex Analyst.
    Delegate domain workflows to sub-agents.
    ROUTING: Supplier evaluation, cost analysis, reorder -> PROCUREMENT_TOOLS.
    Demand forecasting, inventory -> PLANNING_TOOLS.
    Shipment tracking, delay, expedite -> LOGISTICS_TOOLS.
    CROSS-PERSONA CONSISTENCY: OTD% = on-time/total x100. Fill Rate% = fulfilled/ordered x100.
    DOI = on_hand/daily_demand. Landed Cost = material+freight+duty.
    GUARDRAILS: All writes require user confirmation. If data stale or insufficient, disclose.
    GOVERNANCE: Column masking policies return NULL for data the user's role may not see
    (cost/price for Planning and Logistics; customer details for Procurement and Logistics;
    safety stock outside Planning; reorder point for Logistics). If a metric comes back NULL
    for these fields, say it is restricted for the user's role. Do not call it a pipeline
    failure, and do not estimate it from other columns.
    
    MCP INTEGRATIONS:
    - Use ATLASSIAN_MCP for Jira ticket creation (project: SCRUM) after expedites or POs.
    - Use GMAIL for sending email notifications when requested.
    - After TRIGGER_EXPEDITE succeeds, create Jira ticket then call UPDATE_ALERT_JIRA with ticket key.
    
    SLACK NOTIFICATIONS (via SLACK_MCP):
    - After TRIGGER_EXPEDITE succeeds + Jira created, send a message to #supply-chain-alerts:
      "[EXPEDITE] <type> <record_id> — <supplier/customer> → <plant>
       Priority: <priority> | Jira: <ticket_key>
       Reason: <reason>"
    - After CREATE_PURCHASE_ORDER succeeds, send to #supply-chain-alerts:
      "[PO CREATED] <part_id> from <supplier> — Qty: <quantity>
       Plant: <plant> | Est. cost: $<amount>
       Reason: <reason>"
    - After UPDATE_SUPPLIER_RATING succeeds, send to #supply-chain-alerts:
      "[RATING CHANGE] <supplier_name> — <old_rating> → <new_rating>
       Reason: <reason>"
    - If Slack send fails, log the failure but do NOT block the workflow. The DB write and Jira ticket are the critical path.
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: SupplyChainAnalyst
      description: Query supply chain data via semantic view with 4 canonical metrics
  - tool_spec:
      type: data_to_chart
      name: data_to_chart
      description: Generate visualizations from query results
  - tool_spec:
      type: generic
      name: GENERATE_SCORECARD
      description: "Compute supplier score 0-10. Read-only."
      input_schema:
        type: object
        properties:
          p_supplier_id:
            type: string
            description: "Supplier ID"
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
            description: "Part ID"
          p_supplier_id:
            type: string
            description: "Supplier ID"
          p_plant_id:
            type: string
            description: "Plant ID"
          p_quantity:
            type: number
            description: "Quantity"
          p_reason:
            type: string
            description: "Reason"
        required: ["p_part_id", "p_supplier_id", "p_plant_id", "p_quantity", "p_reason"]
  - tool_spec:
      type: generic
      name: TRIGGER_EXPEDITE
      description: "Expedite shipment or order. REQUIRES USER CONFIRMATION."
      input_schema:
        type: object
        properties:
          p_expedite_type:
            type: string
            description: "SHIPMENT or ORDER"
          p_record_id:
            type: string
            description: "Record ID"
          p_reason:
            type: string
            description: "Reason"
          p_priority:
            type: string
            description: "HIGH or CRITICAL"
        required: ["p_expedite_type", "p_record_id", "p_reason", "p_priority"]
  - tool_spec:
      type: generic
      name: UPDATE_SUPPLIER_RATING
      description: "Update supplier rating. REQUIRES USER CONFIRMATION."
      input_schema:
        type: object
        properties:
          p_supplier_id:
            type: string
            description: "Supplier ID"
          p_new_rating:
            type: string
            description: "A, B, C, D, or F"
          p_reason:
            type: string
            description: "Reason"
          p_override:
            type: boolean
            description: "TRUE for manual override"
        required: ["p_supplier_id", "p_new_rating", "p_reason", "p_override"]
  - tool_spec:
      type: generic
      name: UPDATE_ALERT_JIRA
      description: "Link a real Jira ticket key to an expedite alert record."
      input_schema:
        type: object
        properties:
          p_record_id:
            type: string
            description: "The record_id (shipment_id or order_id)"
          p_jira_ticket_id:
            type: string
            description: "The Jira ticket key, e.g. SCRUM-123"
        required: ["p_record_id", "p_jira_ticket_id"]
  - tool_spec:
      type: agent_toolset
      name: PROCUREMENT_TOOLS
  - tool_spec:
      type: agent_toolset
      name: PLANNING_TOOLS
  - tool_spec:
      type: agent_toolset
      name: LOGISTICS_TOOLS
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
  TRIGGER_EXPEDITE:
    identifier: SUPPLY_CHAIN_DB.SCM.TRIGGER_EXPEDITE
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
  UPDATE_ALERT_JIRA:
    identifier: SUPPLY_CHAIN_DB.SCM.UPDATE_ALERT_JIRA
    type: procedure
    execution_environment:
      type: warehouse
      warehouse: COMPUTE_WH
  PROCUREMENT_TOOLS:
    agent_name: SUPPLY_CHAIN_DB.SCM.PROCUREMENT_AGENT
  PLANNING_TOOLS:
    agent_name: SUPPLY_CHAIN_DB.SCM.PLANNING_AGENT
  LOGISTICS_TOOLS:
    agent_name: SUPPLY_CHAIN_DB.SCM.LOGISTICS_AGENT
$$;

GRANT USAGE ON AGENT SUPPLY_CHAIN_AGENT TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON AGENT SUPPLY_CHAIN_AGENT TO ROLE PROCUREMENT_ROLE;
GRANT USAGE ON AGENT SUPPLY_CHAIN_AGENT TO ROLE PLANNING_ROLE;
GRANT USAGE ON AGENT SUPPLY_CHAIN_AGENT TO ROLE LOGISTICS_ROLE;
