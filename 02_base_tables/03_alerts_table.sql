-- ============================================================
-- Phase 2: Base Tables — SUPPLY_CHAIN_ALERTS
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE TABLE SUPPLY_CHAIN_ALERTS (
    alert_id            INT AUTOINCREMENT PRIMARY KEY,
    alert_type          VARCHAR(20)   NOT NULL,   -- 'EXPEDITE', 'LOW_STOCK', 'ORDER_RISK'
    record_type         VARCHAR(20)   NOT NULL,   -- 'SHIPMENT' or 'ORDER'
    record_id           VARCHAR(10)   NOT NULL,
    priority            VARCHAR(20),              -- 'HIGH' or 'CRITICAL'
    reason              VARCHAR(500),
    jira_ticket_id      VARCHAR(20),
    jira_ticket_status  VARCHAR(20)   DEFAULT 'OPEN',  -- 'OPEN', 'IN_PROGRESS', 'DONE'
    slack_channel       VARCHAR(50),
    slack_message_ts    VARCHAR(50),
    status              VARCHAR(20)   DEFAULT 'OPEN',  -- 'OPEN', 'ACKNOWLEDGED', 'RESOLVED'
    created_at          TIMESTAMP     DEFAULT CURRENT_TIMESTAMP(),
    resolved_at         TIMESTAMP,
    created_by          VARCHAR(50)
)
DATA_RETENTION_TIME_IN_DAYS = 90
COMMENT = 'Centralized alert table for all supply chain events — shipment delays, low stock, order risk';
