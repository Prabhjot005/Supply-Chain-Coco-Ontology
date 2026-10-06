-- ============================================================
-- Phase 5: Custom Tool — TRIGGER_EXPEDITE (SP, write)
-- Unified expedite for both shipments and orders
-- Updates priority + expedited_at on source record
-- Inserts to SUPPLY_CHAIN_ALERTS with jira_ticket_id = NULL
-- Agent handles Jira ticket creation via MCP after SP succeeds
-- Guardrails: duplicate 48h check, escalation cap (3x)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE PROCEDURE TRIGGER_EXPEDITE(
    p_expedite_type VARCHAR,    -- 'SHIPMENT' or 'ORDER'
    p_record_id VARCHAR,
    p_reason VARCHAR,
    p_priority VARCHAR          -- 'HIGH' or 'CRITICAL'
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Expedite shipment or order. Guardrails + DB writes only. Agent handles Jira/Slack via MCP.'
EXECUTE AS OWNER  -- persona roles stay read-only; writes only via guardrailed tools
AS
BEGIN
    -- Guardrail 1: Validate expedite_type
    IF (:p_expedite_type NOT IN ('SHIPMENT', 'ORDER')) THEN
        RETURN 'ERROR: expedite_type must be SHIPMENT or ORDER.';
    END IF;

    -- Guardrail 2: Check record exists
    IF (:p_expedite_type = 'SHIPMENT') THEN
        LET ship_exists INT;
        SELECT COUNT(*) INTO :ship_exists FROM SUPPLY_CHAIN_DB.SCM.SHIPMENTS WHERE shipment_id = :p_record_id;
        IF (:ship_exists = 0) THEN
            RETURN 'ERROR: Shipment ' || :p_record_id || ' not found.';
        END IF;
    ELSE
        LET order_exists INT;
        SELECT COUNT(*) INTO :order_exists FROM SUPPLY_CHAIN_DB.SCM.ORDERS WHERE order_id = :p_record_id;
        IF (:order_exists = 0) THEN
            RETURN 'ERROR: Order ' || :p_record_id || ' not found.';
        END IF;
    END IF;

    -- Guardrail 3: Duplicate expedite check (same record in last 48 hours)
    LET recent_expedite INT;
    SELECT COUNT(*) INTO :recent_expedite
    FROM SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS
    WHERE record_id = :p_record_id
      AND alert_type = 'EXPEDITE'
      AND created_at >= DATEADD('hour', -48, CURRENT_TIMESTAMP());

    IF (:recent_expedite > 0) THEN
        RETURN 'GUARDRAIL_DUPLICATE: Already expedited in last 48 hours.';
    END IF;

    -- Guardrail 4: Escalation cap (max 3 expedites per record)
    LET total_expedites INT;
    SELECT COUNT(*) INTO :total_expedites
    FROM SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS
    WHERE record_id = :p_record_id
      AND alert_type = 'EXPEDITE';

    IF (:total_expedites >= 3) THEN
        RETURN 'GUARDRAIL_ESCALATION: Expedited ' || :total_expedites || ' times already.';
    END IF;

    -- Step 1: Update source record (no jira_ticket_id — agent fills it via MCP)
    IF (:p_expedite_type = 'SHIPMENT') THEN
        UPDATE SUPPLY_CHAIN_DB.SCM.SHIPMENTS
        SET priority = 'EXPEDITED',
            expedited_at = CURRENT_TIMESTAMP()
        WHERE shipment_id = :p_record_id;
    ELSE
        UPDATE SUPPLY_CHAIN_DB.SCM.ORDERS
        SET priority = 'EXPEDITED',
            expedited_at = CURRENT_TIMESTAMP()
        WHERE order_id = :p_record_id;
    END IF;

    -- Step 2: Insert alert with jira_ticket_id = NULL (agent fills after MCP call)
    LET alert_id_val INT;
    INSERT INTO SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS (
        alert_type, record_type, record_id, priority, reason,
        slack_channel, status, created_by
    ) VALUES (
        'EXPEDITE',
        :p_expedite_type,
        :p_record_id,
        :p_priority,
        :p_reason,
        '#supply-chain-alerts',
        'OPEN',
        CURRENT_USER()
    );

    SELECT MAX(alert_id) INTO :alert_id_val
    FROM SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS
    WHERE record_id = :p_record_id AND alert_type = 'EXPEDITE';

    -- Step 3: Return success — instructs agent to create Jira ticket via MCP
    RETURN 'SUCCESS: Expedited ' || :p_expedite_type || ' ' || :p_record_id ||
           '. Alert ID: ' || :alert_id_val ||
           '. Priority: ' || :p_priority ||
           '. NEXT: Create Jira ticket in project SCRUM and update alert with ticket key using UPDATE_ALERT_JIRA.';
END;

-- Grant usage
GRANT USAGE ON PROCEDURE TRIGGER_EXPEDITE(VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON PROCEDURE TRIGGER_EXPEDITE(VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO ROLE LOGISTICS_ROLE;
GRANT USAGE ON PROCEDURE TRIGGER_EXPEDITE(VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO ROLE PROCUREMENT_ROLE;
