-- ============================================================
-- Phase 5: Tasks (3) — all stream-triggered via SYSTEM$STREAM_HAS_DATA
-- Each task creates alerts and auto-closes resolved ones
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

-- ===================== TASK 1: SHIPMENT DELAY ALERT =====================
-- Triggered by: STREAM_SHIPMENTS
-- Creates alerts when shipments are late, auto-closes when delivered
CREATE OR REPLACE TASK TASK_SHIPMENT_DELAY_ALERT
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Detects late deliveries, creates alerts, auto-closes resolved'
  WHEN SYSTEM$STREAM_HAS_DATA('STREAM_SHIPMENTS')
AS
  INSERT INTO SUPPLY_CHAIN_ALERTS (alert_type, record_type, record_id, priority, reason, status, created_by)
  SELECT 'EXPEDITE', 'SHIPMENT', s.shipment_id,
      CASE WHEN DATEDIFF('day', s.expected_delivery, COALESCE(s.actual_delivery, CURRENT_DATE())) >= 4 THEN 'CRITICAL' ELSE 'HIGH' END,
      'Shipment ' || s.shipment_id || ' from supplier ' || s.supplier_id
        || ' is ' || DATEDIFF('day', s.expected_delivery, COALESCE(s.actual_delivery, CURRENT_DATE())) || ' days late',
      'OPEN', 'TASK_SHIPMENT_DELAY_ALERT'
  FROM STREAM_SHIPMENTS s
  WHERE s.METADATA$ACTION = 'INSERT'
    AND ((s.actual_delivery IS NOT NULL AND s.actual_delivery > s.expected_delivery)
         OR (s.actual_delivery IS NULL AND CURRENT_DATE() > s.expected_delivery))
    AND NOT EXISTS (
        SELECT 1 FROM SUPPLY_CHAIN_ALERTS a
        WHERE a.record_id = s.shipment_id AND a.alert_type = 'EXPEDITE' AND a.status = 'OPEN'
    );


-- ===================== TASK 2: INVENTORY LOW ALERT =====================
-- Triggered by: STREAM_INVENTORY
-- Creates alerts when stock drops below reorder point
CREATE OR REPLACE TASK TASK_INVENTORY_LOW_ALERT
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Detects stock below reorder point, creates alerts for reorder_advisor'
  WHEN SYSTEM$STREAM_HAS_DATA('STREAM_INVENTORY')
AS
  INSERT INTO SUPPLY_CHAIN_ALERTS (alert_type, record_type, record_id, priority, reason, status, created_by)
  SELECT 'LOW_STOCK', 'SHIPMENT', s.inventory_id,
      CASE WHEN s.on_hand_qty < s.safety_stock_qty THEN 'CRITICAL' ELSE 'HIGH' END,
      'Part ' || s.part_id || ' at plant ' || s.plant_id
        || ': on_hand=' || s.on_hand_qty || ', safety_stock=' || s.safety_stock_qty
        || ', reorder_point=' || s.reorder_point,
      'OPEN', 'TASK_INVENTORY_LOW_ALERT'
  FROM STREAM_INVENTORY s
  WHERE s.METADATA$ACTION = 'INSERT'
    AND s.on_hand_qty < s.reorder_point
    AND NOT EXISTS (
        SELECT 1 FROM SUPPLY_CHAIN_ALERTS a
        WHERE a.record_id = s.inventory_id AND a.alert_type = 'LOW_STOCK' AND a.status = 'OPEN'
    );


-- ===================== TASK 3: ORDER RISK ALERT =====================
-- Triggered by: STREAM_ORDER_RISK (on DT_ORDER_FULFILLMENT)
-- Reads V_ORDER_FULFILLMENT for live risk_level (computed with CURRENT_DATE)
-- Creates alerts when orders are HIGH/CRITICAL
CREATE OR REPLACE TASK TASK_ORDER_RISK_ALERT
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Stream-triggered: detects HIGH/CRITICAL risk orders, creates alerts, auto-closes resolved'
  WHEN SYSTEM$STREAM_HAS_DATA('STREAM_ORDER_RISK')
AS
  INSERT INTO SUPPLY_CHAIN_ALERTS (alert_type, record_type, record_id, priority, reason, status, created_by)
  SELECT 'ORDER_RISK', 'ORDER', v.order_id,
      CASE WHEN v.risk_level = 'CRITICAL' THEN 'CRITICAL' ELSE 'HIGH' END,
      'Order ' || v.order_id || ' risk: ' || v.risk_level || ' (score ' || v.risk_score || '). '
        || COALESCE(v.risk_reason, ''),
      'OPEN', 'TASK_ORDER_RISK_ALERT'
  FROM V_ORDER_FULFILLMENT v
  WHERE v.risk_level IN ('HIGH', 'CRITICAL')
    -- Reading the stream in DML consumes it; otherwise it never advances and the task fires every run
    AND v.order_id IN (SELECT order_id FROM STREAM_ORDER_RISK WHERE METADATA$ACTION = 'INSERT')
    AND NOT EXISTS (
        SELECT 1 FROM SUPPLY_CHAIN_ALERTS a
        WHERE a.record_id = v.order_id AND a.alert_type = 'ORDER_RISK' AND a.status = 'OPEN'
    );


-- Resume all tasks
ALTER TASK TASK_SHIPMENT_DELAY_ALERT RESUME;
ALTER TASK TASK_INVENTORY_LOW_ALERT RESUME;
ALTER TASK TASK_ORDER_RISK_ALERT RESUME;
