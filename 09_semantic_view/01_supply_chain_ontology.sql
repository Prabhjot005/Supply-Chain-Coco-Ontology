-- ============================================================
-- Phase 7: Semantic View — SUPPLY_CHAIN_ONTOLOGY
-- 11 entities (base + DT), 4 canonical metrics, 8 dimensions,
-- relationships, 14 verified queries
-- Created via SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'SUPPLY_CHAIN_DB.SCM',
  $$
  name: SUPPLY_CHAIN_ONTOLOGY
  description: >
    Supply chain ontology and governed analytics. Encodes business meaning over
    the Supplier → Part → Plant → Shipment → Order → Customer entity chain.
    4 canonical metrics: OTD%, Fill Rate%, Days of Inventory, Landed Cost per Unit.
    Ensures consistent answers across procurement, planning, and logistics personas.

  tables:
    # ===== MASTER TABLES =====
    - name: SUPPLIERS
      description: Supplier master data
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: SUPPLIERS
      primary_key:
        columns:
          - SUPPLIER_ID
      dimensions:
        - name: SUPPLIER_ID
          expr: SUPPLIER_ID
          data_type: VARCHAR
        - name: SUPPLIER_NAME
          synonyms:
            - supplier
            - vendor
            - vendor name
          description: Name of the supplier
          expr: NAME
          data_type: VARCHAR
        - name: SUPPLIER_COUNTRY
          synonyms:
            - supplier country
            - origin country
          description: Country where the supplier is based
          expr: COUNTRY
          data_type: VARCHAR
        - name: LEAD_TIME_DAYS
          description: Supplier standard lead time in days
          expr: LEAD_TIME_DAYS
          data_type: NUMBER
        - name: QUALITY_RATING
          description: Supplier quality rating (A/B/C/D/F)
          expr: QUALITY_RATING
          data_type: VARCHAR

    - name: PARTS
      description: Part and SKU catalog
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: PARTS
      primary_key:
        columns:
          - PART_ID
      dimensions:
        - name: PART_ID
          expr: PART_ID
          data_type: VARCHAR
        - name: PART_NAME
          synonyms:
            - part
            - SKU
            - product
            - component
          description: Description of the part
          expr: DESCRIPTION
          data_type: VARCHAR
        - name: CATEGORY
          synonyms:
            - part category
            - product category
          description: Part category (Bearings, Electronics, etc.)
          expr: CATEGORY
          data_type: VARCHAR
      facts:
        - name: UNIT_COST
          description: Standard unit cost of the part
          expr: UNIT_COST
          data_type: "NUMBER(10,2)"
        - name: WEIGHT_KG
          description: Part weight in kilograms
          expr: WEIGHT_KG
          data_type: "NUMBER(8,2)"

    - name: PLANTS
      description: Manufacturing and warehouse locations
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: PLANTS
      primary_key:
        columns:
          - PLANT_ID
      dimensions:
        - name: PLANT_ID
          expr: PLANT_ID
          data_type: VARCHAR
        - name: PLANT_NAME
          synonyms:
            - plant
            - facility
            - warehouse
            - location
          description: Name of the plant or warehouse
          expr: NAME
          data_type: VARCHAR
        - name: PLANT_CITY
          synonyms:
            - city
          description: City where the plant is located
          expr: CITY
          data_type: VARCHAR
        - name: PLANT_COUNTRY
          synonyms:
            - plant country
          description: Country where the plant is located
          expr: COUNTRY
          data_type: VARCHAR
      facts:
        - name: PLANT_CAPACITY
          description: Plant production capacity
          expr: CAPACITY
          data_type: NUMBER

    - name: CUSTOMERS
      description: Customer master data
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: CUSTOMERS
      primary_key:
        columns:
          - CUSTOMER_ID
      dimensions:
        - name: CUSTOMER_ID
          expr: CUSTOMER_ID
          data_type: VARCHAR
        - name: CUSTOMER_NAME
          synonyms:
            - customer
            - client
            - buyer
          description: Name of the customer
          expr: NAME
          data_type: VARCHAR
        - name: CUSTOMER_SEGMENT
          synonyms:
            - segment
            - industry
          description: Customer business segment
          expr: SEGMENT
          data_type: VARCHAR
        - name: CUSTOMER_REGION
          synonyms:
            - region
          description: Customer geographic region
          expr: REGION
          data_type: VARCHAR

    # ===== OPERATIONAL TABLES =====
    - name: SHIPMENTS
      description: Inbound shipment headers — delivery tracking
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: SHIPMENTS
      primary_key:
        columns:
          - SHIPMENT_ID
      dimensions:
        - name: SHIPMENT_ID
          expr: SHIPMENT_ID
          data_type: VARCHAR
        - name: CARRIER
          synonyms:
            - shipping company
            - freight carrier
          description: Carrier handling the shipment
          expr: CARRIER
          data_type: VARCHAR
        - name: SHIPMENT_PRIORITY
          description: Shipment priority (NORMAL or EXPEDITED)
          expr: PRIORITY
          data_type: VARCHAR
      time_dimensions:
        - name: SHIP_DATE
          synonyms:
            - shipped date
            - dispatch date
          description: Date the shipment was dispatched
          expr: SHIP_DATE
          data_type: DATE
        - name: EXPECTED_DELIVERY
          synonyms:
            - expected date
            - ETA
          description: Expected delivery date
          expr: EXPECTED_DELIVERY
          data_type: DATE
        - name: ACTUAL_DELIVERY
          synonyms:
            - delivered date
            - arrival date
          description: Actual delivery date (NULL if in transit)
          expr: ACTUAL_DELIVERY
          data_type: DATE
      facts:
        - name: FREIGHT_COST
          description: Total freight cost for the shipment
          expr: FREIGHT_COST
          data_type: "NUMBER(10,2)"

    - name: ORDERS
      description: Customer order headers
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: ORDERS
      primary_key:
        columns:
          - ORDER_ID
      dimensions:
        - name: ORDER_ID
          expr: ORDER_ID
          data_type: VARCHAR
        - name: ORDER_STATUS
          synonyms:
            - status
          description: Order status (OPEN, PARTIAL, FULFILLED)
          expr: STATUS
          data_type: VARCHAR
        - name: ORDER_PRIORITY
          description: Order priority (NORMAL or EXPEDITED)
          expr: PRIORITY
          data_type: VARCHAR
      time_dimensions:
        - name: ORDER_DATE
          synonyms:
            - ordered date
            - placed date
          description: Date the order was placed
          expr: ORDER_DATE
          data_type: DATE
        - name: REQUESTED_DATE
          synonyms:
            - due date
            - delivery date
          description: Customer requested delivery date
          expr: REQUESTED_DATE
          data_type: DATE

    - name: ORDER_LINES
      description: Order line items with fulfillment status
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: ORDER_LINES
      primary_key:
        columns:
          - ORDER_LINE_ID
      dimensions:
        - name: ORDER_LINE_ID
          expr: ORDER_LINE_ID
          data_type: VARCHAR
      facts:
        - name: ORDERED_QUANTITY
          description: Quantity ordered
          expr: QUANTITY
          data_type: NUMBER
        - name: UNIT_PRICE
          description: Unit price for the order line
          expr: UNIT_PRICE
          data_type: "NUMBER(10,2)"
        - name: FULFILLED_QUANTITY
          description: Quantity fulfilled so far
          expr: FULFILLED_QUANTITY
          data_type: NUMBER

    - name: INVENTORY
      description: Current inventory positions by part and plant
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: INVENTORY
      primary_key:
        columns:
          - INVENTORY_ID
      dimensions:
        - name: INVENTORY_ID
          expr: INVENTORY_ID
          data_type: VARCHAR
      facts:
        - name: ON_HAND_QTY
          synonyms:
            - stock
            - quantity on hand
            - available stock
          description: Current quantity on hand
          expr: ON_HAND_QTY
          data_type: NUMBER
        - name: SAFETY_STOCK_QTY
          description: Safety stock threshold
          expr: SAFETY_STOCK_QTY
          data_type: NUMBER
        - name: REORDER_POINT
          description: Reorder trigger point
          expr: REORDER_POINT
          data_type: NUMBER

    # ===== ANALYTICAL TABLES (Dynamic Tables) =====
    - name: DELIVERY_PERFORMANCE
      description: >
        Delivery performance metrics by supplier, carrier, and plant.
        Canonical metric: On-Time Delivery % (OTD).
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: DT_DELIVERY_PERF
      primary_key:
        columns:
          - SUPPLIER_ID
          - PLANT_ID
          - CARRIER
      dimensions:
        - name: DP_SUPPLIER_ID
          expr: SUPPLIER_ID
          data_type: VARCHAR
        - name: DP_SUPPLIER_NAME
          expr: SUPPLIER_NAME
          data_type: VARCHAR
        - name: DP_PLANT_ID
          expr: PLANT_ID
          data_type: VARCHAR
        - name: DP_PLANT_NAME
          expr: PLANT_NAME
          data_type: VARCHAR
        - name: DP_CARRIER
          expr: CARRIER
          data_type: VARCHAR
      metrics:
        - name: OTD_PERCENTAGE
          synonyms:
            - OTD
            - on time delivery
            - on-time delivery rate
            - delivery rate
          description: >
            On-Time Delivery percentage. Calculated as the count of shipments
            where actual_delivery <= expected_delivery divided by total shipments,
            times 100. This is the canonical OTD metric.
          expr: "SUM(ON_TIME_COUNT) * 100.0 / NULLIF(SUM(TOTAL_SHIPMENTS), 0)"
          default_aggregation: avg
        - name: AVG_LEAD_TIME
          synonyms:
            - lead time
            - average lead time
            - delivery time
          description: Average lead time in days from ship date to actual delivery
          expr: "AVG(AVG_LEAD_TIME_DAYS)"
          default_aggregation: avg
        - name: LATE_SHIPMENT_COUNT
          synonyms:
            - late shipments
            - delayed shipments
          description: Count of shipments that arrived after the expected delivery date
          expr: "SUM(LATE_COUNT)"
          default_aggregation: sum
      facts:
        - name: TOTAL_SHIPMENTS
          expr: TOTAL_SHIPMENTS
          data_type: NUMBER
        - name: ON_TIME_COUNT
          expr: ON_TIME_COUNT
          data_type: NUMBER
        - name: LATE_COUNT
          expr: LATE_COUNT
          data_type: NUMBER
        - name: AVG_LEAD_TIME_DAYS
          expr: AVG_LEAD_TIME_DAYS
          data_type: "NUMBER(10,1)"
        - name: AVG_DELAY_DAYS
          expr: AVG_DELAY_DAYS
          data_type: "NUMBER(10,1)"

    - name: ORDER_FULFILLMENT
      description: >
        Order fulfillment metrics with risk scoring.
        Canonical metric: Fill Rate %.
        Risk score 0-12 from 4 factors: stock coverage, fulfillment ratio,
        inbound shipment health, days to requested date.
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: V_ORDER_FULFILLMENT
      primary_key:
        columns:
          - ORDER_ID
      dimensions:
        - name: OF_ORDER_ID
          expr: ORDER_ID
          data_type: VARCHAR
        - name: OF_CUSTOMER_ID
          expr: CUSTOMER_ID
          data_type: VARCHAR
        - name: OF_CUSTOMER_NAME
          expr: CUSTOMER_NAME
          data_type: VARCHAR
        - name: OF_PLANT_ID
          expr: PLANT_ID
          data_type: VARCHAR
        - name: OF_PLANT_NAME
          expr: PLANT_NAME
          data_type: VARCHAR
        - name: RISK_LEVEL
          synonyms:
            - risk
            - risk status
            - at risk
          description: "Order risk level: LOW, MEDIUM, HIGH, or CRITICAL"
          expr: RISK_LEVEL
          data_type: VARCHAR
        - name: RISK_REASON
          description: Human-readable explanation of why the order is at risk
          expr: RISK_REASON
          data_type: VARCHAR
      metrics:
        - name: FILL_RATE_PCT
          synonyms:
            - fill rate
            - fulfillment rate
            - order fill rate
          description: >
            Fill Rate percentage. Calculated as SUM(fulfilled_quantity) /
            SUM(total_ordered) * 100. This is the canonical Fill Rate metric.
          expr: "SUM(TOTAL_FULFILLED) * 100.0 / NULLIF(SUM(TOTAL_ORDERED), 0)"
          default_aggregation: avg
      facts:
        - name: TOTAL_ORDERED
          expr: TOTAL_ORDERED
          data_type: NUMBER
        - name: TOTAL_FULFILLED
          expr: TOTAL_FULFILLED
          data_type: NUMBER
        - name: FULFILLMENT_RATIO
          expr: FULFILLMENT_RATIO
          data_type: "NUMBER(10,2)"
        - name: RISK_SCORE
          description: Composite risk score 0-12
          expr: RISK_SCORE
          data_type: NUMBER
        - name: DAYS_REMAINING
          expr: DAYS_REMAINING
          data_type: NUMBER
        - name: STOCK_COVERAGE_DAYS
          expr: STOCK_COVERAGE_DAYS
          data_type: "NUMBER(10,1)"

    - name: INVENTORY_POSITION
      description: >
        Inventory position metrics by part and plant.
        Canonical metric: Days of Inventory (DOI).
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: DT_INVENTORY_POSITION
      primary_key:
        columns:
          - INVENTORY_ID
      dimensions:
        - name: IP_PLANT_ID
          expr: PLANT_ID
          data_type: VARCHAR
        - name: IP_PLANT_NAME
          expr: PLANT_NAME
          data_type: VARCHAR
        - name: IP_PART_ID
          expr: PART_ID
          data_type: VARCHAR
        - name: IP_PART_NAME
          expr: PART_NAME
          data_type: VARCHAR
        - name: IP_CATEGORY
          expr: CATEGORY
          data_type: VARCHAR
        - name: STOCKOUT_RISK
          synonyms:
            - stockout
            - out of stock risk
          description: TRUE if on_hand_qty is below safety_stock_qty
          expr: STOCKOUT_RISK
          data_type: BOOLEAN
        - name: REORDER_CANDIDATE
          synonyms:
            - needs reorder
            - reorder needed
          description: TRUE if on_hand_qty is below reorder_point
          expr: REORDER_CANDIDATE
          data_type: BOOLEAN
      metrics:
        - name: DAYS_OF_INVENTORY
          synonyms:
            - DOI
            - days of inventory
            - inventory days
            - days of stock
          description: >
            Days of Inventory. Calculated as on_hand_qty / avg_daily_demand.
            This is the canonical DOI metric. Returns 999 if no demand data.
          expr: "AVG(DOI)"
          default_aggregation: avg
      facts:
        - name: IP_ON_HAND_QTY
          expr: ON_HAND_QTY
          data_type: NUMBER
        - name: IP_SAFETY_STOCK_QTY
          expr: SAFETY_STOCK_QTY
          data_type: NUMBER
        - name: IP_REORDER_POINT
          expr: REORDER_POINT
          data_type: NUMBER
        - name: IP_AVG_DAILY_DEMAND
          expr: AVG_DAILY_DEMAND
          data_type: "NUMBER(10,2)"
        - name: DOI_VALUE
          expr: DOI
          data_type: "NUMBER(10,1)"

    - name: LANDED_COST
      description: >
        Landed cost breakdown by part, supplier, and plant.
        Canonical metric: Landed Cost per Unit = material + freight + duty.
      base_table:
        database: SUPPLY_CHAIN_DB
        schema: SCM
        table: DT_LANDED_COST
      primary_key:
        columns:
          - SUPPLIER_ID
          - PART_ID
          - PLANT_ID
          - SHIP_DATE
      dimensions:
        - name: LC_SUPPLIER_ID
          expr: SUPPLIER_ID
          data_type: VARCHAR
        - name: LC_SUPPLIER_NAME
          expr: SUPPLIER_NAME
          data_type: VARCHAR
        - name: LC_SUPPLIER_COUNTRY
          expr: SUPPLIER_COUNTRY
          data_type: VARCHAR
        - name: LC_PART_ID
          expr: PART_ID
          data_type: VARCHAR
        - name: LC_PART_NAME
          expr: PART_NAME
          data_type: VARCHAR
        - name: LC_PLANT_ID
          expr: PLANT_ID
          data_type: VARCHAR
        - name: LC_PLANT_NAME
          expr: PLANT_NAME
          data_type: VARCHAR
      time_dimensions:
        - name: LC_SHIP_DATE
          description: Date of the shipment for this cost record
          expr: SHIP_DATE
          data_type: DATE
      metrics:
        # Named AVG_* so it does not shadow the physical LANDED_COST_PER_UNIT column
        # (a same-named metric makes the LC_LANDED_COST_PER_UNIT fact resolve to the metric)
        - name: AVG_LANDED_COST_PER_UNIT
          synonyms:
            - landed cost
            - landed cost per unit
            - total cost per unit
            - unit landed cost
          description: >
            Landed Cost per Unit. Calculated as material_cost + freight_per_unit + duty_per_unit.
            This is the canonical Landed Cost metric.
          expr: "AVG(LANDED_COST_PER_UNIT)"
          default_aggregation: avg
      facts:
        - name: MATERIAL_COST
          description: Material/purchase cost per unit
          expr: MATERIAL_COST
          data_type: "NUMBER(10,2)"
        - name: FREIGHT_PER_UNIT
          description: Freight cost allocated per unit
          expr: FREIGHT_PER_UNIT
          data_type: "NUMBER(10,2)"
        - name: DUTY_PER_UNIT
          description: Estimated duty/tariff per unit based on origin country
          expr: DUTY_PER_UNIT
          data_type: "NUMBER(10,2)"
        - name: LC_LANDED_COST_PER_UNIT
          expr: LANDED_COST_PER_UNIT
          data_type: "NUMBER(10,2)"
        - name: FREIGHT_SHARE_PCT
          description: Freight as a percentage of total landed cost
          expr: FREIGHT_SHARE_PCT
          data_type: "NUMBER(10,2)"

  # ===== RELATIONSHIPS =====
  relationships:
    - name: SHIPMENTS_TO_SUPPLIERS
      left_table: SHIPMENTS
      right_table: SUPPLIERS
      relationship_columns:
        - left_column: SUPPLIER_ID
          right_column: SUPPLIER_ID
      relationship_type: many_to_one

    - name: SHIPMENTS_TO_PLANTS
      left_table: SHIPMENTS
      right_table: PLANTS
      relationship_columns:
        - left_column: PLANT_ID
          right_column: PLANT_ID
      relationship_type: many_to_one

    - name: ORDERS_TO_CUSTOMERS
      left_table: ORDERS
      right_table: CUSTOMERS
      relationship_columns:
        - left_column: CUSTOMER_ID
          right_column: CUSTOMER_ID
      relationship_type: many_to_one

    - name: ORDERS_TO_PLANTS
      left_table: ORDERS
      right_table: PLANTS
      relationship_columns:
        - left_column: PLANT_ID
          right_column: PLANT_ID
      relationship_type: many_to_one

    - name: ORDER_LINES_TO_ORDERS
      left_table: ORDER_LINES
      right_table: ORDERS
      relationship_columns:
        - left_column: ORDER_ID
          right_column: ORDER_ID
      relationship_type: many_to_one

    - name: ORDER_LINES_TO_PARTS
      left_table: ORDER_LINES
      right_table: PARTS
      relationship_columns:
        - left_column: PART_ID
          right_column: PART_ID
      relationship_type: many_to_one

    - name: INVENTORY_TO_PARTS
      left_table: INVENTORY
      right_table: PARTS
      relationship_columns:
        - left_column: PART_ID
          right_column: PART_ID
      relationship_type: many_to_one

    - name: INVENTORY_TO_PLANTS
      left_table: INVENTORY
      right_table: PLANTS
      relationship_columns:
        - left_column: PLANT_ID
          right_column: PLANT_ID
      relationship_type: many_to_one

  # ===== VERIFIED QUERIES (14) =====
  verified_queries:
    # Core Metric Queries (4)
    - name: OTD_BY_SUPPLIER
      question: What is the on-time delivery rate for a supplier?
      sql: >
        SELECT dp_supplier_name, otd_percentage
        FROM DELIVERY_PERFORMANCE
        GROUP BY dp_supplier_name
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: FILL_RATE_BY_PLANT
      question: What is the fill rate at a plant?
      sql: >
        SELECT of_plant_name, fill_rate_pct
        FROM ORDER_FULFILLMENT
        GROUP BY of_plant_name
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: DOI_BY_PART_PLANT
      question: What is the days of inventory for a part at a plant?
      sql: >
        SELECT ip_part_name, ip_plant_name, doi_value, ip_on_hand_qty, ip_avg_daily_demand
        FROM INVENTORY_POSITION
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: LANDED_COST_BY_PART_SUPPLIER
      question: What is the landed cost for a part from a supplier?
      sql: >
        SELECT lc_part_name, lc_supplier_name,
               AVG(material_cost) AS avg_material,
               AVG(freight_per_unit) AS avg_freight,
               AVG(duty_per_unit) AS avg_duty,
               AVG(lc_landed_cost_per_unit) AS avg_landed
        FROM LANDED_COST
        GROUP BY lc_part_name, lc_supplier_name
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    # Threshold and Logic Queries (4)
    - name: AT_RISK_ORDERS
      question: Which orders are at risk?
      sql: >
        SELECT of_order_id, of_customer_name, of_plant_name,
               risk_score, risk_level, risk_reason, days_remaining
        FROM ORDER_FULFILLMENT
        WHERE risk_level IN ('HIGH', 'CRITICAL')
        ORDER BY risk_score DESC
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: REORDER_CANDIDATES
      question: Which parts need reordering?
      sql: >
        SELECT ip_part_name, ip_plant_name, ip_on_hand_qty,
               ip_reorder_point, doi_value
        FROM INVENTORY_POSITION
        WHERE reorder_candidate = TRUE
        ORDER BY doi_value ASC
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: LOW_DOI_PARTS
      question: Show all parts with less than 3 days of inventory
      sql: >
        SELECT ip_part_name, ip_plant_name, doi_value,
               ip_on_hand_qty, ip_avg_daily_demand
        FROM INVENTORY_POSITION
        WHERE doi_value < 3
        ORDER BY doi_value ASC
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: COST_BREAKDOWN
      question: Show the cost breakdown for a part
      sql: >
        SELECT lc_part_name, lc_supplier_name,
               AVG(material_cost) AS material,
               AVG(freight_per_unit) AS freight,
               AVG(duty_per_unit) AS duty,
               AVG(lc_landed_cost_per_unit) AS landed_total
        FROM LANDED_COST
        GROUP BY lc_part_name, lc_supplier_name
        ORDER BY landed_total ASC
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    # Time-Series Trend Queries (2)
    - name: OTD_TREND
      question: What is the OTD trend for a supplier over the last 3 months?
      sql: >
        SELECT dp_supplier_name,
               DATE_TRUNC('month', s.ship_date) AS month,
               COUNT(CASE WHEN s.actual_delivery <= s.expected_delivery THEN 1 END) * 100.0
               / NULLIF(COUNT(*), 0) AS monthly_otd
        FROM SUPPLY_CHAIN_DB.SCM.SHIPMENTS s
        JOIN SUPPLY_CHAIN_DB.SCM.SUPPLIERS sup ON s.supplier_id = sup.supplier_id
        WHERE s.actual_delivery IS NOT NULL
          AND s.ship_date >= DATEADD('month', -3, CURRENT_DATE())
        GROUP BY sup.name, DATE_TRUNC('month', s.ship_date)
        ORDER BY month
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: FILL_RATE_TREND
      question: What is the fill rate trend over the last 3 months?
      sql: >
        SELECT DATE_TRUNC('month', o.order_date) AS month,
               SUM(ol.fulfilled_quantity) * 100.0 / NULLIF(SUM(ol.quantity), 0) AS monthly_fill_rate
        FROM SUPPLY_CHAIN_DB.SCM.ORDERS o
        JOIN SUPPLY_CHAIN_DB.SCM.ORDER_LINES ol ON o.order_id = ol.order_id
        WHERE o.order_date >= DATEADD('month', -3, CURRENT_DATE())
        GROUP BY DATE_TRUNC('month', o.order_date)
        ORDER BY month
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    # Cross-Metric Queries (4)
    - name: SUPPLIER_COST_VS_OTD
      question: Compare suppliers for a part by cost and OTD
      sql: >
        SELECT lc.lc_supplier_name,
               AVG(lc.lc_landed_cost_per_unit) AS avg_landed_cost,
               dp.otd_pct
        FROM LANDED_COST lc
        JOIN (
            SELECT dp_supplier_name, 
                   SUM(on_time_count) * 100.0 / NULLIF(SUM(total_shipments), 0) AS otd_pct
            FROM DELIVERY_PERFORMANCE
            GROUP BY dp_supplier_name
        ) dp ON lc.lc_supplier_name = dp.dp_supplier_name
        GROUP BY lc.lc_supplier_name, dp.otd_pct
        ORDER BY avg_landed_cost ASC
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: AT_RISK_ORDERS_WITH_LATE_SHIPMENTS
      question: Which at-risk orders have late inbound shipments?
      sql: >
        SELECT of.of_order_id, of.of_customer_name, of.risk_level, of.risk_score,
               sh.shipment_id, sh.carrier,
               DATEDIFF('day', sh.expected_delivery, COALESCE(sh.actual_delivery, CURRENT_DATE())) AS days_late
        FROM ORDER_FULFILLMENT of
        JOIN SUPPLY_CHAIN_DB.SCM.ORDER_LINES ol ON of.of_order_id = ol.order_id
        JOIN SUPPLY_CHAIN_DB.SCM.SHIPMENT_LINES sl ON ol.part_id = sl.part_id
        JOIN SUPPLY_CHAIN_DB.SCM.SHIPMENTS sh ON sl.shipment_id = sh.shipment_id
        WHERE of.risk_level IN ('HIGH', 'CRITICAL')
          AND (sh.actual_delivery > sh.expected_delivery
               OR (sh.actual_delivery IS NULL AND CURRENT_DATE() > sh.expected_delivery))
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: REORDER_WITH_CHEAPEST_SUPPLIER
      question: Which parts need reordering and who is the cheapest supplier?
      sql: >
        SELECT ip.ip_part_name, ip.ip_plant_name, ip.doi_value, ip.ip_on_hand_qty,
               lc.lc_supplier_name, AVG(lc.lc_landed_cost_per_unit) AS avg_landed
        FROM INVENTORY_POSITION ip
        JOIN LANDED_COST lc ON ip.ip_part_id = lc.lc_part_id
        WHERE ip.reorder_candidate = TRUE
        GROUP BY ip.ip_part_name, ip.ip_plant_name, ip.doi_value, ip.ip_on_hand_qty, lc.lc_supplier_name
        ORDER BY ip.doi_value ASC, avg_landed ASC
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)

    - name: LOW_OTD_HIGH_COST_SUPPLIERS
      question: Show suppliers with low OTD and high landed cost
      sql: >
        SELECT dp.dp_supplier_name,
               SUM(dp.on_time_count) * 100.0 / NULLIF(SUM(dp.total_shipments), 0) AS otd_pct,
               AVG(lc.lc_landed_cost_per_unit) AS avg_landed
        FROM DELIVERY_PERFORMANCE dp
        JOIN LANDED_COST lc ON dp.dp_supplier_id = lc.lc_supplier_id
        GROUP BY dp.dp_supplier_name
        HAVING otd_pct < 80
        ORDER BY avg_landed DESC
      verified_by: SUPPLY_CHAIN_ADMIN
      verified_at: 1791072000  # 2026-10-04 UTC (must be epoch seconds)
  $$
);
