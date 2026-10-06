-- ============================================================
-- Phase 5: Custom Tool — UPDATE_ALERT_JIRA (SP, write)
-- Links a real Jira ticket key to an expedite alert and source record.
-- Called by agent after creating a Jira ticket via ATLASSIAN_MCP.
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE PROCEDURE UPDATE_ALERT_JIRA(
    p_record_id VARCHAR,        -- shipment_id or order_id
    p_jira_ticket_id VARCHAR    -- e.g. SCRUM-123
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Updates SUPPLY_CHAIN_ALERTS and source record with real Jira ticket ID from MCP.'
EXECUTE AS OWNER  -- persona roles stay read-only; writes only via guardrailed tools
AS
BEGIN
    -- Update the open alert for this record
    UPDATE SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS
    SET jira_ticket_id = :p_jira_ticket_id,
        jira_ticket_status = 'OPEN'
    WHERE record_id = :p_record_id
      AND alert_type = 'EXPEDITE'
      AND status = 'OPEN'
      AND jira_ticket_id IS NULL;

    LET updated_rows INT;
    SELECT COUNT(*) INTO :updated_rows
    FROM SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS
    WHERE record_id = :p_record_id
      AND jira_ticket_id = :p_jira_ticket_id;

    IF (:updated_rows = 0) THEN
        RETURN 'WARNING: No open alert found for record ' || :p_record_id || ' without a Jira ticket.';
    END IF;

    -- Also update the source record (shipment or order)
    UPDATE SUPPLY_CHAIN_DB.SCM.SHIPMENTS
    SET jira_ticket_id = :p_jira_ticket_id
    WHERE shipment_id = :p_record_id;

    UPDATE SUPPLY_CHAIN_DB.SCM.ORDERS
    SET jira_ticket_id = :p_jira_ticket_id
    WHERE order_id = :p_record_id;

    RETURN 'SUCCESS: Linked Jira ticket ' || :p_jira_ticket_id || ' to record ' || :p_record_id;
END;

-- Grant usage
GRANT USAGE ON PROCEDURE UPDATE_ALERT_JIRA(VARCHAR, VARCHAR) TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON PROCEDURE UPDATE_ALERT_JIRA(VARCHAR, VARCHAR) TO ROLE LOGISTICS_ROLE;
GRANT USAGE ON PROCEDURE UPDATE_ALERT_JIRA(VARCHAR, VARCHAR) TO ROLE PROCUREMENT_ROLE;
