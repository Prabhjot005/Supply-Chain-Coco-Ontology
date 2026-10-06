-- ============================================================
-- Phase 8: LOGISTICS_AGENT (sub-agent)
-- Domain: Logistics
-- Skills: shipment_tracker
-- Tools: Cortex Analyst, TRIGGER_EXPEDITE, UPDATE_ALERT_JIRA (generic)
-- MCP: ATLASSIAN_MCP (Jira), GMAIL, SLACK_MCP (Slack alerts)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE AGENT LOGISTICS_AGENT
  COMMENT = 'Logistics domain sub-agent with Jira MCP integration'
  FROM SPECIFICATION $$
orchestration:
  tool_not_accessible: accept
  budget: { seconds: 60, tokens: 32000 }
instructions:
  response: |
    You are the Logistics Specialist. Domain: shipment tracking, delay detection, revised ETAs, expedite.
    Classify in-transit shipments as ON_TRACK/AT_RISK/DELAYED/CRITICAL.
    
    EXPEDITE WORKFLOW:
    1. Present details and confirm with user before proceeding.
    2. Call TRIGGER_EXPEDITE to validate guardrails and update the database.
    3. If SUCCESS: Use ATLASSIAN_MCP to create a Jira issue in project SCRUM (type: Task, summary: "[EXPEDITE] <type> <id> - <reason>", include priority and details in description).
    4. After Jira ticket created: Call UPDATE_ALERT_JIRA with the record_id and Jira ticket key (e.g. SCRUM-123).
    5. Send Slack alert via SLACK_MCP to #supply-chain-alerts:
       "[EXPEDITE] <type> <record_id> — <supplier/customer> → <plant>
        Priority: <priority> | Jira: <ticket_key>
        Reason: <reason>
        Affected orders: <order_ids if any>"
    6. Confirm to user: expedite processed, Jira ticket created and linked, Slack alert sent.
    
    If TRIGGER_EXPEDITE returns GUARDRAIL error, report it clearly. Do NOT create Jira ticket or Slack alert.
    Guardrails: 48h duplicate check, max 3 expedites per record.
    If Slack send fails, log the failure but do NOT block the workflow.
skills:
  - name: shipment_tracker
    source:
      type: STAGE
      path: "@SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/shipment_tracker"
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: SupplyChainAnalyst
      description: Query supply chain data via semantic view
  - tool_spec:
      type: generic
      name: TRIGGER_EXPEDITE
      description: "Expedite a shipment or order. REQUIRES USER CONFIRMATION."
      input_schema:
        type: object
        properties:
          p_expedite_type:
            type: string
            description: "SHIPMENT or ORDER"
          p_record_id:
            type: string
            description: "Shipment ID or Order ID"
          p_reason:
            type: string
            description: "Reason for expediting"
          p_priority:
            type: string
            description: "HIGH or CRITICAL"
        required: ["p_expedite_type", "p_record_id", "p_reason", "p_priority"]
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
  TRIGGER_EXPEDITE:
    identifier: SUPPLY_CHAIN_DB.SCM.TRIGGER_EXPEDITE
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
$$;

GRANT USAGE ON AGENT LOGISTICS_AGENT TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON AGENT LOGISTICS_AGENT TO ROLE LOGISTICS_ROLE;
