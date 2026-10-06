-- ============================================================
-- Phase 5: Streams (3) — event-driven alerts and actions
-- NOT for feeding DTs (DTs auto-refresh from base tables)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

-- Captures delivery changes — triggers alerts on late arrivals
CREATE OR REPLACE STREAM STREAM_SHIPMENTS
  ON TABLE SHIPMENTS
  APPEND_ONLY = FALSE
  COMMENT = 'CDC on SHIPMENTS — triggers TASK_SHIPMENT_DELAY_ALERT for late deliveries';

-- Captures stock drops — triggers alerts when inventory falls below safety stock
CREATE OR REPLACE STREAM STREAM_INVENTORY
  ON TABLE INVENTORY
  APPEND_ONLY = FALSE
  COMMENT = 'CDC on INVENTORY — triggers TASK_INVENTORY_LOW_ALERT for low stock';

-- Captures fulfillment changes — triggers alerts when orders become HIGH/CRITICAL risk
-- Requires DT_ORDER_FULFILLMENT to use INCREMENTAL refresh
CREATE OR REPLACE STREAM STREAM_ORDER_RISK
  ON DYNAMIC TABLE DT_ORDER_FULFILLMENT
  COMMENT = 'CDC on DT_ORDER_FULFILLMENT — triggers TASK_ORDER_RISK_ALERT when fulfillment data changes';
