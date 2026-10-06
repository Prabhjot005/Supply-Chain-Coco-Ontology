-- ============================================================
-- Phase 5: ML FORECAST Model — Multi-series demand forecasting
-- Train once, infer many. One model for all part/plant combos.
-- Rebuild on demand via staleness guardrail (7 days).
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

-- Prepare training data: daily demand by part_plant_key
CREATE OR REPLACE VIEW V_DEMAND_TRAINING_DATA AS
SELECT
    o.order_date::DATE AS ds,
    ol.part_id || '_' || o.plant_id AS part_plant_key,
    SUM(ol.quantity) AS daily_demand
FROM ORDERS o
JOIN ORDER_LINES ol ON o.order_id = ol.order_id
WHERE o.order_date >= DATEADD('day', -180, CURRENT_DATE())
GROUP BY o.order_date::DATE, ol.part_id || '_' || o.plant_id
-- FORECAST needs >= 2 timestamps per series; single-order series would fail training
QUALIFY COUNT(DISTINCT o.order_date::DATE) OVER (PARTITION BY ol.part_id || '_' || o.plant_id) >= 2;

-- Build the multi-series forecast model
-- SERIES_COLNAME allows one model to handle all part/plant combinations
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST DEMAND_FORECAST_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'V_DEMAND_TRAINING_DATA'),
    SERIES_COLNAME => 'PART_PLANT_KEY',
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'DAILY_DEMAND'
);

-- Grant usage on the model
-- NOTE: USAGE grants on SNOWFLAKE.ML.FORECAST instances are rejected
-- ("Invalid object type 'INSTANCE_BUNDLE'"). Persona roles can already call
-- DEMAND_FORECAST_MODEL!FORECAST (verified as PLANNING_ROLE), so these are not needed.
-- GRANT USAGE ON SNOWFLAKE.ML.FORECAST DEMAND_FORECAST_MODEL TO ROLE SC_AGENT_ROLE;
-- GRANT USAGE ON SNOWFLAKE.ML.FORECAST DEMAND_FORECAST_MODEL TO ROLE PLANNING_ROLE;
-- GRANT USAGE ON SNOWFLAKE.ML.FORECAST DEMAND_FORECAST_MODEL TO ROLE PROCUREMENT_ROLE;

-- Example inference (for verification):
-- CALL DEMAND_FORECAST_MODEL!FORECAST(FORECASTING_PERIODS => 30);
-- Returns: ds, part_plant_key, forecast, lower_bound, upper_bound
