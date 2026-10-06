-- ============================================================
-- Phase 2: Base Tables — Operational Tables (Time Travel 90 days)
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

-- SHIPMENTS: inbound shipment headers
CREATE OR REPLACE TABLE SHIPMENTS (
    shipment_id         VARCHAR(10)   PRIMARY KEY,
    supplier_id         VARCHAR(10)   NOT NULL REFERENCES SUPPLIERS(supplier_id),
    plant_id            VARCHAR(10)   NOT NULL REFERENCES PLANTS(plant_id),
    ship_date           DATE          NOT NULL,
    expected_delivery   DATE          NOT NULL,
    actual_delivery     DATE,
    carrier             VARCHAR(50)   NOT NULL,
    freight_cost        NUMBER(10,2)  NOT NULL,
    priority            VARCHAR(20)   DEFAULT 'NORMAL',
    expedited_at        TIMESTAMP,
    jira_ticket_id      VARCHAR(20)
)
DATA_RETENTION_TIME_IN_DAYS = 90
CHANGE_TRACKING = TRUE
COMMENT = 'Shipment headers — Time Travel 90 days, stream-enabled for delay alerts';

-- SHIPMENT_LINES: shipment line items
CREATE OR REPLACE TABLE SHIPMENT_LINES (
    shipment_line_id    VARCHAR(10)   PRIMARY KEY,
    shipment_id         VARCHAR(10)   NOT NULL REFERENCES SHIPMENTS(shipment_id),
    part_id             VARCHAR(10)   NOT NULL REFERENCES PARTS(part_id),
    quantity            INT           NOT NULL,
    unit_cost           NUMBER(10,2)  NOT NULL
)
DATA_RETENTION_TIME_IN_DAYS = 90
COMMENT = 'Shipment line items — Time Travel 90 days';

-- ORDERS: customer order headers
CREATE OR REPLACE TABLE ORDERS (
    order_id            VARCHAR(10)   PRIMARY KEY,
    customer_id         VARCHAR(10)   NOT NULL REFERENCES CUSTOMERS(customer_id),
    plant_id            VARCHAR(10)   NOT NULL REFERENCES PLANTS(plant_id),
    order_date          DATE          NOT NULL,
    requested_date      DATE          NOT NULL,
    status              VARCHAR(20)   NOT NULL DEFAULT 'OPEN',
    priority            VARCHAR(20)   DEFAULT 'NORMAL',
    expedited_at        TIMESTAMP,
    jira_ticket_id      VARCHAR(20)
)
DATA_RETENTION_TIME_IN_DAYS = 90
COMMENT = 'Customer order headers — Time Travel 90 days';

-- ORDER_LINES: order line items
CREATE OR REPLACE TABLE ORDER_LINES (
    order_line_id       VARCHAR(10)   PRIMARY KEY,
    order_id            VARCHAR(10)   NOT NULL REFERENCES ORDERS(order_id),
    part_id             VARCHAR(10)   NOT NULL REFERENCES PARTS(part_id),
    quantity            INT           NOT NULL,
    unit_price          NUMBER(10,2)  NOT NULL,
    fulfilled_quantity  INT           DEFAULT 0
)
DATA_RETENTION_TIME_IN_DAYS = 90
COMMENT = 'Order line items — Time Travel 90 days';

-- INVENTORY: current stock positions
CREATE OR REPLACE TABLE INVENTORY (
    inventory_id        VARCHAR(10)   PRIMARY KEY,
    plant_id            VARCHAR(10)   NOT NULL REFERENCES PLANTS(plant_id),
    part_id             VARCHAR(10)   NOT NULL REFERENCES PARTS(part_id),
    on_hand_qty         INT           NOT NULL,
    safety_stock_qty    INT           NOT NULL,
    reorder_point       INT           NOT NULL,
    last_updated        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP()
)
DATA_RETENTION_TIME_IN_DAYS = 90
CHANGE_TRACKING = TRUE
COMMENT = 'Inventory positions — Time Travel 90 days, stream-enabled for low stock alerts';
