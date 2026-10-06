-- ============================================================
-- Phase 5: Custom Tool — UPDATE_SUPPLIER_RATING (SP, write)
-- Updates quality_rating on SUPPLIERS table
-- Supports data-driven (override=FALSE) and manual override (override=TRUE)
-- Guardrails: 1-tier cap, recent change 7d, override audit
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE PROCEDURE UPDATE_SUPPLIER_RATING(
    p_supplier_id VARCHAR,
    p_new_rating VARCHAR,       -- A/B/C/D/F
    p_reason VARCHAR,
    p_override BOOLEAN          -- TRUE = manual override, FALSE = data-driven
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Updates supplier quality rating. Guardrails: 1-tier cap, recent change check, override audit.'
EXECUTE AS OWNER  -- persona roles stay read-only; writes only via guardrailed tools
AS
BEGIN
    -- Validate rating value
    IF (:p_new_rating NOT IN ('A', 'B', 'C', 'D', 'F')) THEN
        RETURN 'ERROR: Rating must be A, B, C, D, or F. Got: ' || :p_new_rating;
    END IF;

    -- Check supplier exists
    LET current_rating VARCHAR;
    SELECT quality_rating INTO :current_rating FROM SUPPLIERS WHERE supplier_id = :p_supplier_id;
    IF (:current_rating IS NULL) THEN
        RETURN 'ERROR: Supplier ' || :p_supplier_id || ' not found.';
    END IF;

    -- No change needed
    IF (:current_rating = :p_new_rating) THEN
        RETURN 'NO_CHANGE: Supplier ' || :p_supplier_id || ' already has rating ' || :current_rating || '.';
    END IF;

    -- Guardrail 1: Rating change cap (max 1 tier per update)
    LET rating_order_current INT := CASE :current_rating WHEN 'A' THEN 1 WHEN 'B' THEN 2 WHEN 'C' THEN 3 WHEN 'D' THEN 4 WHEN 'F' THEN 5 END;
    LET rating_order_new INT := CASE :p_new_rating WHEN 'A' THEN 1 WHEN 'B' THEN 2 WHEN 'C' THEN 3 WHEN 'D' THEN 4 WHEN 'F' THEN 5 END;

    IF (ABS(:rating_order_current - :rating_order_new) > 1) THEN
        LET max_allowed VARCHAR;
        IF (:rating_order_new < :rating_order_current) THEN
            -- Upgrading: max 1 tier up
            LET max_order INT := :rating_order_current - 1;
            SELECT CASE :max_order WHEN 1 THEN 'A' WHEN 2 THEN 'B' WHEN 3 THEN 'C' WHEN 4 THEN 'D' END INTO :max_allowed;
        ELSE
            -- Downgrading: max 1 tier down
            LET max_order INT := :rating_order_current + 1;
            SELECT CASE :max_order WHEN 2 THEN 'B' WHEN 3 THEN 'C' WHEN 4 THEN 'D' WHEN 5 THEN 'F' END INTO :max_allowed;
        END IF;
        RETURN 'GUARDRAIL_RATING_CAP: Rating can only change one tier at a time. ' ||
               'Current: ' || :current_rating || ', Requested: ' || :p_new_rating ||
               ', Maximum allowed: ' || :max_allowed || '.';
    END IF;

    -- Guardrail 2: Recent change check (changed in last 7 days)
    -- We check if there was a recent alert about this supplier's rating change
    LET recent_change INT;
    SELECT COUNT(*) INTO :recent_change
    FROM SUPPLY_CHAIN_ALERTS
    WHERE record_id = :p_supplier_id
      AND alert_type = 'EXPEDITE'  -- reusing alert_type field; in production use a dedicated type
      AND reason LIKE '%rating%'
      AND created_at >= DATEADD('day', -7, CURRENT_TIMESTAMP());

    IF (:recent_change > 0 AND NOT :p_override) THEN
        RETURN 'GUARDRAIL_RECENT_CHANGE: Supplier ' || :p_supplier_id ||
               ' rating was changed in the last 7 days. Use override=TRUE to force.';
    END IF;

    -- Guardrail 3: Override audit (require reason for manual overrides)
    IF (:p_override AND (:p_reason IS NULL OR LENGTH(TRIM(:p_reason)) = 0)) THEN
        RETURN 'GUARDRAIL_OVERRIDE_AUDIT: Manual override requires a reason. Please provide one.';
    END IF;

    -- Execute the update
    UPDATE SUPPLIERS
    SET quality_rating = :p_new_rating
    WHERE supplier_id = :p_supplier_id;

    -- Log the change as an alert for audit trail
    -- (expressions like this are not allowed in VALUES, so build the reason first)
    LET audit_reason VARCHAR := 'Rating change: ' || :current_rating || ' → ' || :p_new_rating ||
        ' | Override: ' || :p_override || ' | Reason: ' || :p_reason;
    INSERT INTO SUPPLY_CHAIN_ALERTS (
        alert_type, record_type, record_id, priority, reason, status, created_by
    ) VALUES (
        'EXPEDITE',  -- reusing type; could be 'RATING_CHANGE' with schema extension
        'SHIPMENT',
        :p_supplier_id,
        'HIGH',
        :audit_reason,
        'RESOLVED',
        CURRENT_USER()
    );

    RETURN 'SUCCESS: Updated supplier ' || :p_supplier_id || ' rating from ' ||
           :current_rating || ' to ' || :p_new_rating ||
           '. Mode: ' || CASE WHEN :p_override THEN 'Manual override' ELSE 'Data-driven' END ||
           '. Reason: ' || :p_reason;
END;

-- Grant usage
GRANT USAGE ON PROCEDURE UPDATE_SUPPLIER_RATING(VARCHAR, VARCHAR, VARCHAR, BOOLEAN) TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON PROCEDURE UPDATE_SUPPLIER_RATING(VARCHAR, VARCHAR, VARCHAR, BOOLEAN) TO ROLE PROCUREMENT_ROLE;
