-- ============================================================
-- Phase 2: Sample Data — realistic supply chain scenarios
-- ============================================================

USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

-- ===================== SUPPLIERS =====================
INSERT INTO SUPPLIERS (supplier_id, name, country, lead_time_days, quality_rating) VALUES
('S01', 'Acme Components',      'China',   14, 'A'),
('S02', 'GlobalParts Inc',      'Germany', 10, 'B'),
('S03', 'Pacific Supply Co',    'Japan',    7, 'A'),
('S04', 'Rhine Electronics',    'Germany', 12, 'B'),
('S05', 'Shenzhen Micro',       'China',   16, 'C'),
('S06', 'MexiParts SA',         'Mexico',   5, 'B'),
('S07', 'Chennai Components',   'India',   18, 'B'),
('S08', 'Nordic Precision',     'Sweden',  11, 'A'),
('S09', 'Sao Paulo Metals',     'Brazil',  20, 'C'),
('S10', 'Detroit Auto Parts',   'USA',      3, 'A');

-- ===================== PARTS =====================
INSERT INTO PARTS (part_id, description, category, unit_cost, weight_kg) VALUES
('P100', 'Bearing Assembly 50mm',     'Bearings',      12.00, 0.45),
('P101', 'Hydraulic Pump HX-200',     'Hydraulics',    85.00, 3.20),
('P102', 'Steel Plate 10mm',          'Raw Materials', 22.50, 12.00),
('P103', 'Control Board CB-X1',       'Electronics',   145.00, 0.18),
('P104', 'Gasket Set GK-Standard',    'Seals',         8.50, 0.05),
('P105', 'Motor Drive MD-500',        'Electronics',   210.00, 2.80),
('P106', 'Aluminum Tube AL-25',       'Raw Materials', 15.00, 1.50),
('P107', 'Sensor Module SM-Pro',      'Electronics',   175.00, 0.12),
('P108', 'Rubber Hose RH-10',        'Seals',         6.00, 0.30),
('P109', 'Precision Gear PG-44',      'Bearings',      35.00, 0.90);

-- ===================== PLANTS =====================
INSERT INTO PLANTS (plant_id, name, city, country, capacity) VALUES
('PL01', 'Chicago Manufacturing',  'Chicago',    'USA',     50000),
('PL02', 'Detroit Assembly',       'Detroit',    'USA',     35000),
('PL03', 'Munich Production',      'Munich',     'Germany', 40000),
('PL04', 'Shanghai Hub',           'Shanghai',   'China',   60000),
('PL05', 'Monterrey Plant',        'Monterrey',  'Mexico',  25000);

-- ===================== CUSTOMERS =====================
INSERT INTO CUSTOMERS (customer_id, name, segment, region) VALUES
('C01', 'RetailCorp International', 'Retail',        'North America'),
('C02', 'AutoMakers Ltd',          'Automotive',    'Europe'),
('C03', 'TechBuild Systems',       'Technology',    'Asia Pacific'),
('C04', 'Infrastructure Global',   'Construction',  'North America'),
('C05', 'MediDevice Corp',         'Healthcare',    'Europe'),
('C06', 'EnergyFirst Inc',         'Energy',        'North America'),
('C07', 'AgriMech Solutions',      'Agriculture',   'South America'),
('C08', 'AeroSpace Dynamics',      'Aerospace',     'North America');

-- ===================== SHIPMENTS =====================
-- Mix of on-time, late, and in-transit shipments
INSERT INTO SHIPMENTS (shipment_id, supplier_id, plant_id, ship_date, expected_delivery, actual_delivery, carrier, freight_cost, priority) VALUES
-- Delivered on time
('SH001', 'S01', 'PL01', '2026-08-15', '2026-08-29', '2026-08-28', 'FastFreight Co',    1200.00, 'NORMAL'),
('SH002', 'S02', 'PL03', '2026-08-20', '2026-08-30', '2026-08-30', 'EuroExpress',        800.00, 'NORMAL'),
('SH003', 'S03', 'PL04', '2026-08-22', '2026-08-29', '2026-08-27', 'PacificLine',        650.00, 'NORMAL'),
('SH004', 'S10', 'PL02', '2026-09-01', '2026-09-04', '2026-09-03', 'USGround',           200.00, 'NORMAL'),
('SH005', 'S06', 'PL05', '2026-09-05', '2026-09-10', '2026-09-09', 'MexTransport',       350.00, 'NORMAL'),
-- Delivered LATE
('SH006', 'S01', 'PL01', '2026-09-01', '2026-09-15', '2026-09-20', 'FastFreight Co',    1350.00, 'NORMAL'),
('SH007', 'S05', 'PL04', '2026-09-03', '2026-09-19', '2026-09-25', 'OceanLine',         1800.00, 'NORMAL'),
('SH008', 'S07', 'PL01', '2026-09-05', '2026-09-23', '2026-09-28', 'IndiaExpress',      2100.00, 'NORMAL'),
('SH009', 'S09', 'PL05', '2026-09-08', '2026-09-28', '2026-10-03', 'LatAmFreight',      2500.00, 'NORMAL'),
('SH010', 'S04', 'PL03', '2026-09-10', '2026-09-22', '2026-09-26', 'EuroExpress',        950.00, 'NORMAL'),
-- In-transit (no actual_delivery) — some past expected date (DELAYED)
('SH011', 'S01', 'PL01', '2026-09-18', '2026-10-02', NULL,          'FastFreight Co',    1400.00, 'NORMAL'),
('SH012', 'S05', 'PL04', '2026-09-20', '2026-10-06', NULL,          'OceanLine',         1900.00, 'NORMAL'),
('SH013', 'S02', 'PL03', '2026-09-22', '2026-10-02', NULL,          'EuroExpress',        850.00, 'NORMAL'),
-- In-transit, expected soon (AT_RISK)
('SH014', 'S03', 'PL02', '2026-09-28', '2026-10-05', NULL,          'PacificLine',        700.00, 'NORMAL'),
('SH015', 'S08', 'PL03', '2026-09-25', '2026-10-06', NULL,          'NordicShip',         920.00, 'NORMAL'),
-- In-transit, plenty of time (ON_TRACK)
('SH016', 'S10', 'PL02', '2026-10-01', '2026-10-04', NULL,          'USGround',           180.00, 'NORMAL'),
('SH017', 'S06', 'PL05', '2026-10-01', '2026-10-06', NULL,          'MexTransport',       400.00, 'NORMAL'),
('SH018', 'S08', 'PL01', '2026-09-28', '2026-10-09', NULL,          'NordicShip',        1050.00, 'NORMAL'),
-- Historical shipments for carrier performance baseline
('SH019', 'S01', 'PL01', '2026-07-01', '2026-07-15', '2026-07-14', 'FastFreight Co',    1150.00, 'NORMAL'),
('SH020', 'S01', 'PL01', '2026-07-15', '2026-07-29', '2026-07-31', 'FastFreight Co',    1250.00, 'NORMAL'),
('SH021', 'S02', 'PL03', '2026-07-10', '2026-07-20', '2026-07-19', 'EuroExpress',        780.00, 'NORMAL'),
('SH022', 'S02', 'PL03', '2026-07-25', '2026-08-04', '2026-08-04', 'EuroExpress',        810.00, 'NORMAL'),
('SH023', 'S05', 'PL04', '2026-07-05', '2026-07-21', '2026-07-26', 'OceanLine',         1750.00, 'NORMAL'),
('SH024', 'S05', 'PL04', '2026-07-20', '2026-08-05', '2026-08-09', 'OceanLine',         1820.00, 'NORMAL'),
('SH025', 'S03', 'PL02', '2026-07-12', '2026-07-19', '2026-07-18', 'PacificLine',        620.00, 'NORMAL');

-- ===================== SHIPMENT_LINES =====================
INSERT INTO SHIPMENT_LINES (shipment_line_id, shipment_id, part_id, quantity, unit_cost) VALUES
('SL001', 'SH001', 'P100',  500, 11.50),
('SL002', 'SH001', 'P104', 1000,  8.00),
('SL003', 'SH002', 'P103',  200, 140.00),
('SL004', 'SH003', 'P107',  300, 170.00),
('SL005', 'SH004', 'P109',  400, 33.00),
('SL006', 'SH005', 'P108',  800,  5.50),
('SL007', 'SH006', 'P100',  600, 12.00),
('SL008', 'SH006', 'P106',  350, 14.50),
('SL009', 'SH007', 'P105',  150, 205.00),
('SL010', 'SH008', 'P102',  200, 21.00),
('SL011', 'SH009', 'P106',  500, 14.00),
('SL012', 'SH010', 'P103',  180, 142.00),
('SL013', 'SH011', 'P100',  700, 11.80),
('SL014', 'SH012', 'P105',  250, 208.00),
('SL015', 'SH013', 'P107',  400, 172.00),
('SL016', 'SH014', 'P109',  350, 34.00),
('SL017', 'SH015', 'P103',  220, 143.00),
('SL018', 'SH016', 'P100',  300, 11.50),
('SL019', 'SH017', 'P108',  600,  5.80),
('SL020', 'SH018', 'P102',  150, 22.00),
('SL021', 'SH019', 'P100',  450, 11.20),
('SL022', 'SH020', 'P100',  500, 11.40),
('SL023', 'SH021', 'P103',  190, 139.00),
('SL024', 'SH022', 'P107',  210, 168.00),
('SL025', 'SH023', 'P105',  180, 202.00),
('SL026', 'SH024', 'P105',  200, 207.00),
('SL027', 'SH025', 'P109',  320, 32.50);

-- ===================== ORDERS =====================
-- Mix of open, partial, fulfilled orders with varying risk profiles
INSERT INTO ORDERS (order_id, customer_id, plant_id, order_date, requested_date, status) VALUES
-- OPEN orders (not yet fulfilled — some at risk)
('O001', 'C01', 'PL01', '2026-09-15', '2026-10-05', 'OPEN'),
('O002', 'C02', 'PL03', '2026-09-18', '2026-10-08', 'OPEN'),
('O003', 'C03', 'PL04', '2026-09-20', '2026-10-03', 'OPEN'),
('O004', 'C04', 'PL02', '2026-09-22', '2026-10-10', 'OPEN'),
('O005', 'C05', 'PL03', '2026-09-25', '2026-10-06', 'OPEN'),
('O006', 'C06', 'PL01', '2026-09-28', '2026-10-15', 'OPEN'),
('O007', 'C07', 'PL05', '2026-09-28', '2026-10-12', 'OPEN'),
('O008', 'C08', 'PL02', '2026-10-01', '2026-10-20', 'OPEN'),
-- PARTIAL fulfillment
('O009', 'C01', 'PL01', '2026-09-10', '2026-10-01', 'PARTIAL'),
('O010', 'C03', 'PL04', '2026-09-12', '2026-10-02', 'PARTIAL'),
-- FULFILLED (historical)
('O011', 'C02', 'PL03', '2026-08-01', '2026-08-20', 'FULFILLED'),
('O012', 'C04', 'PL02', '2026-08-05', '2026-08-25', 'FULFILLED'),
('O013', 'C01', 'PL01', '2026-08-10', '2026-08-30', 'FULFILLED'),
('O014', 'C06', 'PL01', '2026-08-15', '2026-09-05', 'FULFILLED'),
('O015', 'C05', 'PL03', '2026-08-20', '2026-09-10', 'FULFILLED'),
-- Historical orders for demand baseline (Jul-Aug)
('O016', 'C01', 'PL01', '2026-07-05', '2026-07-25', 'FULFILLED'),
('O017', 'C02', 'PL03', '2026-07-10', '2026-07-30', 'FULFILLED'),
('O018', 'C03', 'PL04', '2026-07-15', '2026-08-05', 'FULFILLED'),
('O019', 'C04', 'PL02', '2026-07-20', '2026-08-10', 'FULFILLED'),
('O020', 'C08', 'PL02', '2026-07-25', '2026-08-15', 'FULFILLED');

-- ===================== ORDER_LINES =====================
INSERT INTO ORDER_LINES (order_line_id, order_id, part_id, quantity, unit_price, fulfilled_quantity) VALUES
-- O001: needs P100 at PL01 — low stock scenario
('OL001', 'O001', 'P100', 400, 15.00, 0),
('OL002', 'O001', 'P104', 200, 11.00, 0),
-- O002: needs P103 at PL03
('OL003', 'O002', 'P103', 150, 180.00, 0),
('OL004', 'O002', 'P107', 100, 220.00, 0),
-- O003: needs P105 at PL04 — supplier late
('OL005', 'O003', 'P105', 200, 260.00, 0),
-- O004: needs P109 at PL02
('OL006', 'O004', 'P109', 300, 45.00, 0),
('OL007', 'O004', 'P100', 250, 15.00, 0),
-- O005: needs P103 at PL03
('OL008', 'O005', 'P103', 120, 180.00, 0),
-- O006: needs P100, P102 at PL01
('OL009', 'O006', 'P100', 500, 15.00, 0),
('OL010', 'O006', 'P102', 300, 28.00, 0),
-- O007: needs P108, P106 at PL05
('OL011', 'O007', 'P108', 400, 8.00, 0),
('OL012', 'O007', 'P106', 200, 19.00, 0),
-- O008: needs P109, P100 at PL02 (plenty of time)
('OL013', 'O008', 'P109', 200, 45.00, 0),
('OL014', 'O008', 'P100', 150, 15.00, 0),
-- O009: partially fulfilled
('OL015', 'O009', 'P100', 300, 15.00, 180),
('OL016', 'O009', 'P106', 150, 19.00, 150),
-- O010: partially fulfilled
('OL017', 'O010', 'P105', 100, 260.00, 40),
-- Fulfilled orders
('OL018', 'O011', 'P103', 200, 180.00, 200),
('OL019', 'O012', 'P109', 250, 45.00, 250),
('OL020', 'O013', 'P100', 400, 15.00, 400),
('OL021', 'O014', 'P102', 300, 28.00, 300),
('OL022', 'O015', 'P107', 180, 220.00, 180),
-- Historical
('OL023', 'O016', 'P100', 350, 15.00, 350),
('OL024', 'O017', 'P103', 160, 180.00, 160),
('OL025', 'O018', 'P105', 120, 260.00, 120),
('OL026', 'O019', 'P109', 280, 45.00, 280),
('OL027', 'O020', 'P100', 200, 15.00, 200);

-- ===================== INVENTORY =====================
-- Deliberate scenarios: some critically low, some healthy
INSERT INTO INVENTORY (inventory_id, plant_id, part_id, on_hand_qty, safety_stock_qty, reorder_point, last_updated) VALUES
-- PL01 Chicago
('INV001', 'PL01', 'P100',   80,  200, 300, '2026-10-03 08:00:00'),  -- CRITICAL: below safety stock
('INV002', 'PL01', 'P102',  450,  100, 200, '2026-10-03 08:00:00'),  -- Healthy
('INV003', 'PL01', 'P104', 1200,  300, 500, '2026-10-03 08:00:00'),  -- Healthy
('INV004', 'PL01', 'P106',  120,  100, 180, '2026-10-03 08:00:00'),  -- Below reorder point
-- PL02 Detroit
('INV005', 'PL02', 'P100',  350,  150, 250, '2026-10-03 08:00:00'),  -- Healthy
('INV006', 'PL02', 'P109',   40,  100, 150, '2026-10-03 08:00:00'),  -- CRITICAL: below safety stock
-- PL03 Munich
('INV007', 'PL03', 'P103',  280,  100, 200, '2026-10-03 08:00:00'),  -- Healthy
('INV008', 'PL03', 'P107',   90,  150, 200, '2026-10-03 08:00:00'),  -- Below safety stock
-- PL04 Shanghai
('INV009', 'PL04', 'P105',   30,  100, 150, '2026-10-03 08:00:00'),  -- CRITICAL: nearly zero
('INV010', 'PL04', 'P107',  500,  100, 200, '2026-10-03 08:00:00'),  -- Healthy
-- PL05 Monterrey
('INV011', 'PL05', 'P108',  600,  200, 350, '2026-10-03 08:00:00'),  -- Healthy
('INV012', 'PL05', 'P106',  180,  100, 200, '2026-10-03 08:00:00');  -- Below reorder point
