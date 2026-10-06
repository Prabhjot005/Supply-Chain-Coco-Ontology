-- ============================================================
-- Phase 4: Dynamic Tables (4) — INCREMENTAL refresh mode
-- All DTs are time-independent (no CURRENT_DATE).
-- Risk scoring is computed by V_ORDER_FULFILLMENT view at query time.
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

-- ===================== DT_DELIVERY_PERF =====================
-- Canonical metric: On-Time Delivery %
CREATE OR REPLACE DYNAMIC TABLE DT_DELIVERY_PERF
  TARGET_LAG = '1 hour'
  WAREHOUSE = COMPUTE_WH
  REFRESH_MODE = INCREMENTAL
  DATA_RETENTION_TIME_IN_DAYS = 90
  COMMENT = 'Delivery performance: OTD%, avg lead time, late shipment count by supplier/carrier/plant'
AS
SELECT
    sh.supplier_id, s.name AS supplier_name, sh.plant_id, pl.name AS plant_name, sh.carrier,
    COUNT(*) AS total_shipments,
    COUNT(CASE WHEN sh.actual_delivery <= sh.expected_delivery THEN 1 END) AS on_time_count,
    COUNT(CASE WHEN sh.actual_delivery > sh.expected_delivery THEN 1 END) AS late_count,
    ROUND(COUNT(CASE WHEN sh.actual_delivery <= sh.expected_delivery THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS otd_percentage,
    ROUND(AVG(DATEDIFF('day', sh.ship_date, sh.actual_delivery)), 1) AS avg_lead_time_days,
    ROUND(AVG(CASE WHEN sh.actual_delivery > sh.expected_delivery THEN DATEDIFF('day', sh.expected_delivery, sh.actual_delivery) END), 1) AS avg_delay_days
FROM SHIPMENTS sh
JOIN SUPPLIERS s ON sh.supplier_id = s.supplier_id
JOIN PLANTS pl ON sh.plant_id = pl.plant_id
WHERE sh.actual_delivery IS NOT NULL
GROUP BY sh.supplier_id, s.name, sh.plant_id, pl.name, sh.carrier;


-- ===================== DT_ORDER_FULFILLMENT =====================
-- Raw fulfillment data + stock coverage (no CURRENT_DATE).
-- Risk score (0-12) is computed by V_ORDER_FULFILLMENT view.
CREATE OR REPLACE DYNAMIC TABLE DT_ORDER_FULFILLMENT
  TARGET_LAG = '1 hour'
  WAREHOUSE = COMPUTE_WH
  REFRESH_MODE = INCREMENTAL
  DATA_RETENTION_TIME_IN_DAYS = 90
  COMMENT = 'Order fulfillment raw data: fill rate + stock coverage. Risk scoring computed by V_ORDER_FULFILLMENT view.'
AS
WITH order_summary AS (
    SELECT o.order_id, o.customer_id, c.name AS customer_name, o.plant_id, pl.name AS plant_name,
           o.order_date, o.requested_date, o.status,
           SUM(ol.quantity) AS total_ordered,
           SUM(ol.fulfilled_quantity) AS total_fulfilled,
           ROUND(SUM(ol.fulfilled_quantity) * 100.0 / NULLIF(SUM(ol.quantity), 0), 2) AS fulfillment_ratio
    FROM ORDERS o
    JOIN ORDER_LINES ol ON o.order_id = ol.order_id
    JOIN CUSTOMERS c ON o.customer_id = c.customer_id
    JOIN PLANTS pl ON o.plant_id = pl.plant_id
    WHERE o.status IN ('OPEN', 'PARTIAL')
    GROUP BY o.order_id, o.customer_id, c.name, o.plant_id, pl.name, o.order_date, o.requested_date, o.status
),
stock_coverage AS (
    SELECT os.order_id,
           MIN(CASE WHEN i.on_hand_qty IS NOT NULL
                THEN i.on_hand_qty / NULLIF(GREATEST((ol.quantity - ol.fulfilled_quantity), 1) / 30.0, 0)
                ELSE 0 END) AS stock_coverage_days
    FROM order_summary os
    JOIN ORDER_LINES ol ON os.order_id = ol.order_id
    LEFT JOIN INVENTORY i ON os.plant_id = i.plant_id AND ol.part_id = i.part_id
    GROUP BY os.order_id
)
SELECT
    os.order_id, os.customer_id, os.customer_name, os.plant_id, os.plant_name,
    os.order_date, os.requested_date, os.status,
    os.total_ordered, os.total_fulfilled, os.fulfillment_ratio,
    ROUND(COALESCE(sc.stock_coverage_days, 0), 1) AS stock_coverage_days
FROM order_summary os
LEFT JOIN stock_coverage sc ON os.order_id = sc.order_id;


-- ===================== V_ORDER_FULFILLMENT =====================
-- View layer: adds time-dependent risk scoring on top of DT
-- Risk score 0-12 from 4 factors (3 points each):
--   Factor 1: Stock Coverage  — >14d (0), 7-14d (1), 3-7d (2), <3d (3)
--   Factor 2: Fulfillment Gap — >=90% (0), 50-89% (1), 1-49% (2), 0% (3)
--   Factor 3: Shipment Risk   — proxy from stock coverage
--   Factor 4: Order Urgency   — >14d (0), 7-14d (1), 3-7d (2), <3d or past (3)
CREATE OR REPLACE VIEW V_ORDER_FULFILLMENT
  COMMENT = 'Adds time-dependent risk scoring (0-12) on top of DT_ORDER_FULFILLMENT using CURRENT_DATE()'
AS
WITH base AS (
    SELECT dt.*,
        DATEDIFF('day', CURRENT_DATE(), dt.requested_date) AS days_remaining,
        CASE WHEN dt.stock_coverage_days > 14 THEN 0 WHEN dt.stock_coverage_days BETWEEN 7 AND 14 THEN 1 WHEN dt.stock_coverage_days BETWEEN 3 AND 7 THEN 2 ELSE 3 END AS f1_stock,
        CASE WHEN dt.fulfillment_ratio >= 90 THEN 0 WHEN dt.fulfillment_ratio BETWEEN 50 AND 89 THEN 1 WHEN dt.fulfillment_ratio BETWEEN 1 AND 49 THEN 2 ELSE 3 END AS f2_fulfillment,
        CASE WHEN dt.stock_coverage_days > 14 THEN 0 WHEN dt.stock_coverage_days BETWEEN 7 AND 14 THEN 1 WHEN dt.stock_coverage_days BETWEEN 3 AND 7 THEN 2 ELSE 3 END AS f3_shipment,
        CASE WHEN DATEDIFF('day', CURRENT_DATE(), dt.requested_date) > 14 THEN 0 WHEN DATEDIFF('day', CURRENT_DATE(), dt.requested_date) BETWEEN 7 AND 14 THEN 1 WHEN DATEDIFF('day', CURRENT_DATE(), dt.requested_date) BETWEEN 3 AND 7 THEN 2 ELSE 3 END AS f4_urgency
    FROM DT_ORDER_FULFILLMENT dt
)
SELECT
    order_id, customer_id, customer_name, plant_id, plant_name,
    order_date, requested_date, status,
    total_ordered, total_fulfilled, fulfillment_ratio,
    stock_coverage_days, days_remaining,
    (f1_stock + f2_fulfillment + f3_shipment + f4_urgency) AS risk_score,
    CASE
        WHEN (f1_stock + f2_fulfillment + f3_shipment + f4_urgency) BETWEEN 0 AND 2 THEN 'LOW'
        WHEN (f1_stock + f2_fulfillment + f3_shipment + f4_urgency) BETWEEN 3 AND 5 THEN 'MEDIUM'
        WHEN (f1_stock + f2_fulfillment + f3_shipment + f4_urgency) BETWEEN 6 AND 8 THEN 'HIGH'
        ELSE 'CRITICAL'
    END AS risk_level,
    CONCAT_WS('; ',
        CASE WHEN stock_coverage_days < 7 THEN 'Low stock (' || ROUND(stock_coverage_days, 0) || ' days)' END,
        CASE WHEN fulfillment_ratio < 50 THEN 'Low fulfillment (' || ROUND(fulfillment_ratio, 0) || '%)' END,
        CASE WHEN DATEDIFF('day', CURRENT_DATE(), requested_date) < 7 THEN 'Due soon (' || DATEDIFF('day', CURRENT_DATE(), requested_date) || ' days)' END
    ) AS risk_reason
FROM base;


-- ===================== DT_INVENTORY_POSITION =====================
-- Canonical metric: Days of Inventory (DOI)
-- Uses all historical order data for demand averaging (no date filter with CURRENT_DATE)
CREATE OR REPLACE DYNAMIC TABLE DT_INVENTORY_POSITION
  TARGET_LAG = '1 hour'
  WAREHOUSE = COMPUTE_WH
  REFRESH_MODE = INCREMENTAL
  DATA_RETENTION_TIME_IN_DAYS = 90
  COMMENT = 'Inventory position: DOI, stockout risk, reorder candidates by part/plant'
AS
WITH daily_demand AS (
    SELECT ol.part_id, o.plant_id,
           COALESCE(SUM(ol.quantity) / NULLIF(DATEDIFF('day', MIN(o.order_date), MAX(o.order_date)), 0), 0) AS avg_daily_demand
    FROM ORDER_LINES ol
    JOIN ORDERS o ON ol.order_id = o.order_id
    GROUP BY ol.part_id, o.plant_id
)
SELECT
    i.inventory_id, i.plant_id, pl.name AS plant_name, i.part_id, p.description AS part_name, p.category,
    i.on_hand_qty, i.safety_stock_qty, i.reorder_point,
    COALESCE(dd.avg_daily_demand, 0) AS avg_daily_demand,
    CASE WHEN COALESCE(dd.avg_daily_demand, 0) > 0 THEN ROUND(i.on_hand_qty / dd.avg_daily_demand, 1) ELSE 999 END AS doi,
    i.on_hand_qty < i.safety_stock_qty AS stockout_risk,
    i.on_hand_qty < i.reorder_point AS reorder_candidate,
    i.last_updated
FROM INVENTORY i
JOIN PARTS p ON i.part_id = p.part_id
JOIN PLANTS pl ON i.plant_id = pl.plant_id
LEFT JOIN daily_demand dd ON i.part_id = dd.part_id AND i.plant_id = dd.plant_id;


-- ===================== DT_LANDED_COST =====================
-- Canonical metric: Landed Cost per Unit = material + freight + duty
CREATE OR REPLACE DYNAMIC TABLE DT_LANDED_COST
  TARGET_LAG = '1 hour'
  WAREHOUSE = COMPUTE_WH
  REFRESH_MODE = INCREMENTAL
  DATA_RETENTION_TIME_IN_DAYS = 90
  COMMENT = 'Landed cost: material + freight + duty per unit by part/supplier'
AS
WITH shipment_totals AS (
    SELECT shipment_id, SUM(quantity) AS total_qty FROM SHIPMENT_LINES GROUP BY shipment_id
)
SELECT sh.supplier_id, s.name AS supplier_name, s.country AS supplier_country,
    sl.part_id, p.description AS part_name, sh.plant_id, pl.name AS plant_name, sh.ship_date,
    sl.unit_cost AS material_cost,
    ROUND(sh.freight_cost / NULLIF(st.total_qty, 0), 2) AS freight_per_unit,
    ROUND(sl.unit_cost * CASE s.country
        WHEN 'China' THEN 0.075 WHEN 'India' THEN 0.05 WHEN 'Germany' THEN 0.02
        WHEN 'Mexico' THEN 0.01 WHEN 'Japan' THEN 0.03 WHEN 'Sweden' THEN 0.02
        WHEN 'Brazil' THEN 0.04 WHEN 'USA' THEN 0.00 ELSE 0.03 END, 2) AS duty_per_unit,
    ROUND(sl.unit_cost + sh.freight_cost / NULLIF(st.total_qty, 0)
        + sl.unit_cost * CASE s.country
            WHEN 'China' THEN 0.075 WHEN 'India' THEN 0.05 WHEN 'Germany' THEN 0.02
            WHEN 'Mexico' THEN 0.01 WHEN 'Japan' THEN 0.03 WHEN 'Sweden' THEN 0.02
            WHEN 'Brazil' THEN 0.04 WHEN 'USA' THEN 0.00 ELSE 0.03 END, 2) AS landed_cost_per_unit,
    sl.quantity,
    ROUND(sh.freight_cost / NULLIF(st.total_qty, 0) * 100.0 / NULLIF(
        sl.unit_cost + sh.freight_cost / NULLIF(st.total_qty, 0)
        + sl.unit_cost * CASE s.country
            WHEN 'China' THEN 0.075 WHEN 'India' THEN 0.05 WHEN 'Germany' THEN 0.02
            WHEN 'Mexico' THEN 0.01 WHEN 'Japan' THEN 0.03 WHEN 'Sweden' THEN 0.02
            WHEN 'Brazil' THEN 0.04 WHEN 'USA' THEN 0.00 ELSE 0.03 END, 0), 2) AS freight_share_pct
FROM SHIPMENTS sh
JOIN SHIPMENT_LINES sl ON sh.shipment_id = sl.shipment_id
JOIN SUPPLIERS s ON sh.supplier_id = s.supplier_id
JOIN PARTS p ON sl.part_id = p.part_id
JOIN PLANTS pl ON sh.plant_id = pl.plant_id
JOIN shipment_totals st ON sh.shipment_id = st.shipment_id
WHERE sh.actual_delivery IS NOT NULL;


-- ===================== MASKING ON DT COLUMNS =====================
-- DTs refresh as SUPPLY_CHAIN_ADMIN (unmasked), so base-table masks do not
-- propagate. Re-apply the same policies on the derived sensitive columns.
ALTER DYNAMIC TABLE DT_LANDED_COST MODIFY COLUMN material_cost SET MASKING POLICY COST_DATA_MASK;
ALTER DYNAMIC TABLE DT_LANDED_COST MODIFY COLUMN freight_per_unit SET MASKING POLICY COST_DATA_MASK;
ALTER DYNAMIC TABLE DT_LANDED_COST MODIFY COLUMN duty_per_unit SET MASKING POLICY COST_DATA_MASK;
ALTER DYNAMIC TABLE DT_LANDED_COST MODIFY COLUMN landed_cost_per_unit SET MASKING POLICY COST_DATA_MASK;
ALTER DYNAMIC TABLE DT_DELIVERY_PERF MODIFY COLUMN carrier SET MASKING POLICY SUPPLIER_DETAIL_MASK;
ALTER DYNAMIC TABLE DT_ORDER_FULFILLMENT MODIFY COLUMN customer_name SET MASKING POLICY CUSTOMER_DATA_MASK;
ALTER DYNAMIC TABLE DT_INVENTORY_POSITION MODIFY COLUMN safety_stock_qty SET MASKING POLICY SAFETY_STOCK_MASK;
ALTER DYNAMIC TABLE DT_INVENTORY_POSITION MODIFY COLUMN reorder_point SET MASKING POLICY REORDER_POINT_MASK;


-- ===================== GRANTS ON DTs AND VIEW =====================
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE SC_AGENT_ROLE;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE SC_AGENT_ROLE;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE PROCUREMENT_ROLE;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE PROCUREMENT_ROLE;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE PLANNING_ROLE;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE PLANNING_ROLE;
GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE LOGISTICS_ROLE;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE LOGISTICS_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE SC_AGENT_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE SC_AGENT_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE PROCUREMENT_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE PLANNING_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE LOGISTICS_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE PROCUREMENT_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE PLANNING_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SUPPLY_CHAIN_DB.SCM TO ROLE LOGISTICS_ROLE;
