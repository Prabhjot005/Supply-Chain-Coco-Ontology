-- ============================================================
-- Phase 5: Custom Tool — CREATE_PURCHASE_ORDER (SP, write)
-- Inserts PO into ORDERS + ORDER_LINES
-- Guardrails: duplicate check (7 days), quantity sanity (3x avg), budget limit
-- Requires user confirmation (enforced by agent, not by SP)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CREATE OR REPLACE PROCEDURE CREATE_PURCHASE_ORDER(
    p_part_id VARCHAR,
    p_supplier_id VARCHAR,
    p_plant_id VARCHAR,
    p_quantity INT,
    p_reason VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Creates a purchase order. Guardrails: duplicate check, quantity sanity, budget limit.'
EXECUTE AS OWNER  -- persona roles stay read-only; writes only via guardrailed tools
AS
BEGIN
    -- Guardrail 0: Validate input references exist
    LET part_exists INT;
    SELECT COUNT(*) INTO :part_exists FROM PARTS WHERE part_id = :p_part_id;
    IF (:part_exists = 0) THEN
        RETURN 'ERROR: Part ' || :p_part_id || ' not found.';
    END IF;

    LET supplier_exists INT;
    SELECT COUNT(*) INTO :supplier_exists FROM SUPPLIERS WHERE supplier_id = :p_supplier_id;
    IF (:supplier_exists = 0) THEN
        RETURN 'ERROR: Supplier ' || :p_supplier_id || ' not found.';
    END IF;

    LET plant_exists INT;
    SELECT COUNT(*) INTO :plant_exists FROM PLANTS WHERE plant_id = :p_plant_id;
    IF (:plant_exists = 0) THEN
        RETURN 'ERROR: Plant ' || :p_plant_id || ' not found.';
    END IF;

    IF (:p_quantity <= 0) THEN
        RETURN 'ERROR: Quantity must be positive. Got: ' || :p_quantity;
    END IF;

    -- Guardrail 1: Duplicate order check (same part/supplier/plant in last 7 days)
    LET duplicate_count INT;
    SELECT COUNT(*) INTO :duplicate_count
    FROM ORDERS o
    JOIN ORDER_LINES ol ON o.order_id = ol.order_id
    WHERE ol.part_id = :p_part_id
      AND o.plant_id = :p_plant_id
      AND o.order_date >= DATEADD('day', -7, CURRENT_DATE())
      AND o.status IN ('OPEN', 'PARTIAL');

    IF (:duplicate_count > 0) THEN
        RETURN 'GUARDRAIL_DUPLICATE: A similar order for part ' || :p_part_id ||
               ' at plant ' || :p_plant_id || ' was placed in the last 7 days. ' ||
               'Found ' || :duplicate_count || ' existing order(s).';
    END IF;

    -- Guardrail 2: Quantity sanity check (>3x average order size for this part)
    LET avg_qty FLOAT;
    SELECT COALESCE(AVG(ol.quantity), 0) INTO :avg_qty
    FROM ORDER_LINES ol
    JOIN ORDERS o ON ol.order_id = o.order_id
    WHERE ol.part_id = :p_part_id
      AND o.order_date >= DATEADD('day', -90, CURRENT_DATE());

    IF (:avg_qty > 0 AND :p_quantity > :avg_qty * 3) THEN
        RETURN 'GUARDRAIL_SANITY: Requested quantity ' || :p_quantity ||
               ' is ' || ROUND(:p_quantity / :avg_qty, 1) || 'x the 90-day average (' ||
               ROUND(:avg_qty, 0) || '). This may indicate a demand spike or data anomaly.';
    END IF;

    -- Guardrail 3: Budget limit (max 50,000 per single PO)
    LET unit_price FLOAT;
    SELECT COALESCE(unit_cost, 0) INTO :unit_price FROM PARTS WHERE part_id = :p_part_id;
    LET total_cost FLOAT := :p_quantity * :unit_price;

    IF (:total_cost > 50000) THEN
        RETURN 'GUARDRAIL_BUDGET: Estimated cost $' || ROUND(:total_cost, 2) ||
               ' exceeds single PO limit of $50,000.';
    END IF;

    -- Generate order ID
    LET new_order_id VARCHAR;
    SELECT 'O' || LPAD(COALESCE(MAX(CAST(SUBSTR(order_id, 2) AS INT)), 0) + 1, 3, '0')
    INTO :new_order_id FROM ORDERS;

    LET new_ol_id VARCHAR;
    SELECT 'OL' || LPAD(COALESCE(MAX(CAST(SUBSTR(order_line_id, 3) AS INT)), 0) + 1, 3, '0')
    INTO :new_ol_id FROM ORDER_LINES;

    -- Insert order (subqueries are not allowed in VALUES, so resolve lead time first)
    LET lead_time INT;
    SELECT lead_time_days INTO :lead_time FROM SUPPLIERS WHERE supplier_id = :p_supplier_id;

    INSERT INTO ORDERS (order_id, customer_id, plant_id, order_date, requested_date, status)
    VALUES (
        :new_order_id,
        'C01',  -- default customer for system-generated POs
        :p_plant_id,
        CURRENT_DATE(),
        DATEADD('day', :lead_time, CURRENT_DATE()),
        'OPEN'
    );

    -- Insert order line
    INSERT INTO ORDER_LINES (order_line_id, order_id, part_id, quantity, unit_price, fulfilled_quantity)
    VALUES (
        :new_ol_id,
        :new_order_id,
        :p_part_id,
        :p_quantity,
        :unit_price,
        0
    );

    RETURN 'SUCCESS: Created PO ' || :new_order_id || ' for ' || :p_quantity ||
           ' units of ' || :p_part_id || ' from supplier ' || :p_supplier_id ||
           ' at plant ' || :p_plant_id || '. Estimated cost: $' || ROUND(:total_cost, 2) ||
           '. Reason: ' || :p_reason;
END;

-- Grant usage
GRANT USAGE ON PROCEDURE CREATE_PURCHASE_ORDER(VARCHAR, VARCHAR, VARCHAR, INT, VARCHAR) TO ROLE SC_AGENT_ROLE;
GRANT USAGE ON PROCEDURE CREATE_PURCHASE_ORDER(VARCHAR, VARCHAR, VARCHAR, INT, VARCHAR) TO ROLE PROCUREMENT_ROLE;
