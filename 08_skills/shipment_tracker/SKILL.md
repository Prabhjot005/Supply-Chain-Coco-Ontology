---
name: shipment_tracker
description: Track in-transit shipments, classify risk status, estimate revised ETAs using historical carrier performance, and recommend whether to expedite.
---
# Shipment Tracker

## Description
Track in-transit shipments, classify risk status (ON_TRACK / AT_RISK / DELAYED / CRITICAL), estimate revised ETAs using historical carrier performance, and recommend whether to expedite.

## When to Use
- User asks to track shipments or check shipment status
- User asks about late or delayed shipments
- User asks for a risk assessment of at-risk orders
- TASK_SHIPMENT_DELAY_ALERT fires (automated trigger)
- User asks to expedite a specific shipment

## Instructions

### Step 1: Query In-Transit Shipments
```sql
SELECT sh.*, s.name AS supplier_name, pl.name AS plant_name
FROM SHIPMENTS sh
JOIN SUPPLIERS s ON sh.supplier_id = s.supplier_id
JOIN PLANTS pl ON sh.plant_id = pl.plant_id
WHERE sh.actual_delivery IS NULL
ORDER BY sh.expected_delivery ASC;
```

### Step 2: Compute Carrier Performance (from historical data)
For each carrier, compute avg delay and late rate from delivered shipments:
```sql
SELECT carrier,
       COUNT(*) AS total_shipments,
       AVG(DATEDIFF('day', expected_delivery, actual_delivery)) AS avg_delay,
       SUM(CASE WHEN actual_delivery > expected_delivery THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS late_rate_pct
FROM SHIPMENTS
WHERE actual_delivery IS NOT NULL
GROUP BY carrier;
```

### Step 3: Classify Each Shipment
For each in-transit shipment, compute:
```
days_until_expected = DATEDIFF('day', CURRENT_DATE, expected_delivery)
carrier_avg_delay = from Step 2
revised_eta = expected_delivery + carrier_avg_delay (if carrier tends to be late)
```

Classification:
- **ON_TRACK**: days_until_expected > 3 AND carrier historically on time (avg_delay <= 0)
- **AT_RISK**: days_until_expected 1-3 OR carrier avg_delay > 0 on this route
- **DELAYED**: past expected_delivery, no actual_delivery recorded
- **CRITICAL**: DELAYED AND linked to HIGH/CRITICAL risk orders (check DT_ORDER_FULFILLMENT)

### Step 4: Identify Impact
For DELAYED and CRITICAL shipments, find affected orders:
```sql
SELECT dt.order_id, dt.customer_name, dt.risk_score, dt.risk_level
FROM DT_ORDER_FULFILLMENT dt
JOIN ORDER_LINES ol ON dt.order_id = ol.order_id
JOIN SHIPMENT_LINES sl ON ol.part_id = sl.part_id
WHERE sl.shipment_id = '<shipment_id>'
  AND dt.risk_level IN ('HIGH', 'CRITICAL');
```

### Step 5: Present Findings
For each shipment needing attention, show:
```
CRITICAL — Shipment SH011
  Supplier:  S01 - Acme Components
  Carrier:   FastFreight Co
  Route:     China → Chicago
  Expected:  Oct 2  |  Today: Oct 4  |  2 days late
  Revised ETA: Oct 5 (carrier avg delay: 1 day)
  Impact: Order O001 (RetailCorp) — risk score 9/12 CRITICAL
  Recommendation: Expedite this shipment
```

### Step 6: Expedite (if user confirms)
```sql
CALL TRIGGER_EXPEDITE('SHIPMENT', 'SH011', 'Shipment 2 days late, impacts Order O001 (CRITICAL risk)', 'CRITICAL');
```

After TRIGGER_EXPEDITE succeeds:
1. Create Jira ticket via ATLASSIAN_MCP (project: SCRUM, type: Task).
2. Call UPDATE_ALERT_JIRA with the record_id and Jira ticket key.
3. Send Slack alert via SLACK_MCP to **#supply-chain-alerts**:
```
[EXPEDITE] Shipment SH011 — Acme Components → Chicago
Priority: CRITICAL | Jira: SCRUM-123
Reason: 2 days late, impacts Order O001 (RetailCorp)
Affected orders: O001 (CRITICAL)
```
4. Report to user: "Expedited. Jira: SCRUM-123 (assigned to Logistics team). Slack alert sent to #supply-chain-alerts."

If Slack send fails, still confirm the expedite and Jira ticket. Note: "Slack notification failed — alert logged to database only."

If the root cause is low stock (not a late shipment), hand off to the reorder_advisor skill for the reorder workflow.

## Guardrails
- **Confidence level for revised ETA**:
  - HIGH: 50+ historical shipments for this carrier
  - MEDIUM: 10-49 historical shipments
  - LOW: fewer than 10 (disclose: "Limited carrier history — ETA estimate may be unreliable")
- **Duplicate expedite**: TRIGGER_EXPEDITE enforces 48-hour check
- **Escalation cap**: TRIGGER_EXPEDITE enforces max 3 expedites per shipment
- **Data freshness**: If SHIPMENTS data is stale, warn before presenting status

## Output Format
Group shipments by classification (CRITICAL first, then DELAYED, AT_RISK, ON_TRACK). Include revised ETA with confidence level. Show affected orders for DELAYED/CRITICAL shipments.
