-- ============================================================
-- Phase 5: Custom Tool — GENERATE_SCORECARD (UDF, read-only)
-- Computes composite supplier score: OTD weight + quality weight + cost weight
-- No confirmation needed (read-only)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE FUNCTION GENERATE_SCORECARD(p_supplier_id VARCHAR)
RETURNS OBJECT
LANGUAGE SQL
COMMENT = 'Computes composite supplier score (0-10) from OTD, quality rating, and cost. Read-only UDF.'
AS
$$
    SELECT OBJECT_CONSTRUCT(
        'supplier_id', s.supplier_id,
        'supplier_name', s.name,
        'quality_rating', s.quality_rating,
        'otd_percentage', COALESCE(dp.otd_percentage, 0),
        'avg_lead_time', COALESCE(dp.avg_lead_time_days, 0),
        'total_shipments', COALESCE(dp.total_shipments, 0),
        'quality_score', CASE s.quality_rating
            WHEN 'A' THEN 10
            WHEN 'B' THEN 7.5
            WHEN 'C' THEN 5
            WHEN 'D' THEN 2.5
            ELSE 0
        END,
        'otd_score', LEAST(COALESCE(dp.otd_percentage, 0) / 10.0, 10),
        'cost_score', CASE
            WHEN COALESCE(lc.avg_landed_cost, 0) = 0 THEN 5
            WHEN lc.avg_landed_cost <= 15 THEN 9
            WHEN lc.avg_landed_cost <= 30 THEN 7
            WHEN lc.avg_landed_cost <= 100 THEN 5
            WHEN lc.avg_landed_cost <= 200 THEN 3
            ELSE 1
        END,
        'composite_score', ROUND(
            (CASE s.quality_rating WHEN 'A' THEN 10 WHEN 'B' THEN 7.5 WHEN 'C' THEN 5 WHEN 'D' THEN 2.5 ELSE 0 END * 0.3)
            + (LEAST(COALESCE(dp.otd_percentage, 0) / 10.0, 10) * 0.4)
            + (CASE
                WHEN COALESCE(lc.avg_landed_cost, 0) = 0 THEN 5
                WHEN lc.avg_landed_cost <= 15 THEN 9
                WHEN lc.avg_landed_cost <= 30 THEN 7
                WHEN lc.avg_landed_cost <= 100 THEN 5
                WHEN lc.avg_landed_cost <= 200 THEN 3
                ELSE 1
            END * 0.3)
        , 1),
        'weight_quality', 0.3,
        'weight_otd', 0.4,
        'weight_cost', 0.3
    )
    FROM SUPPLIERS s
    LEFT JOIN (
        SELECT supplier_id,
               SUM(total_shipments) AS total_shipments,
               ROUND(SUM(on_time_count) * 100.0 / NULLIF(SUM(total_shipments), 0), 2) AS otd_percentage,
               ROUND(AVG(avg_lead_time_days), 1) AS avg_lead_time_days
        FROM DT_DELIVERY_PERF
        GROUP BY supplier_id
    ) dp ON s.supplier_id = dp.supplier_id
    LEFT JOIN (
        SELECT supplier_id,
               ROUND(AVG(landed_cost_per_unit), 2) AS avg_landed_cost
        FROM DT_LANDED_COST
        GROUP BY supplier_id
    ) lc ON s.supplier_id = lc.supplier_id
    WHERE s.supplier_id = p_supplier_id
$$;

-- Grant usage
GRANT USAGE ON FUNCTION GENERATE_SCORECARD(VARCHAR) TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON FUNCTION GENERATE_SCORECARD(VARCHAR) TO ROLE PROCUREMENT_ROLE;
