---
name: reorder_advisor
description: Analyze inventory positions, calculate optimal reorder quantity and timing, recommend supplier, and create purchase orders after user approval.
---
# Reorder Advisor

## Description
Analyze inventory positions, calculate optimal reorder quantity and timing, recommend supplier, and create purchase orders after user approval. User can edit quantity and supplier before confirming.

## When to Use
- User asks to analyze low-stock parts and create reorders
- User asks what parts need reordering
- TASK_INVENTORY_LOW_ALERT fires (automated trigger)
- User asks to create a purchase order for a specific part

## Instructions

### Step 1: Identify Low-Stock Parts
Query DT_INVENTORY_POSITION for parts below reorder point:
```sql
SELECT * FROM DT_INVENTORY_POSITION
WHERE reorder_candidate = TRUE
ORDER BY doi ASC;
```

### Step 2: Get Demand Forecast
**Delegate to the demand_planner skill** for each low-stock part. Do NOT compute demand trends manually.
The demand_planner uses the pre-trained ML FORECAST model (multi-series, no retraining per query):
```sql
CALL DEMAND_FORECAST_MODEL!FORECAST(FORECASTING_PERIODS => 30);
```
It returns: projected_30d_demand, confidence_range (lower/upper bounds), trend_direction, seasonality_detected.

### Step 3: Score Suppliers
Call GENERATE_SCORECARD for each supplier that provides the part:
```sql
SELECT GENERATE_SCORECARD('S01') AS scorecard;
```
Also query DT_LANDED_COST for cost comparison:
```sql
SELECT supplier_id, supplier_name, AVG(landed_cost_per_unit) AS avg_cost
FROM DT_LANDED_COST
WHERE part_id = 'P100'
GROUP BY supplier_id, supplier_name
ORDER BY avg_cost ASC;
```

### Step 4: Calculate Reorder Quantity
```
reorder_qty = (projected_30d_demand + safety_stock) - on_hand_qty
```
Pick the best supplier based on: highest composite score among those with score >= 7.0 and OTD >= 80%.

### Step 5: Present Recommendation (Editable)
Present a summary for EACH part needing reorder:
```
Part: P100 (Bearing Assembly 50mm) at Plant Chicago
  Current stock: 80 units (DOI: 2.1 days)
  Projected 30-day demand: 1,140 units (range: 980-1,300, rising 15%)
  Safety stock: 200 units

  Recommended order:
    Quantity:  1,260 units
    Supplier:  S01 - Acme Components (score: 8.7/10)
    Lead time: 14 days  |  Est. cost: $14,490

  Alternative suppliers:
    S02 - GlobalParts Inc (score: 7.9, 10 days, $14,860)
    S03 - Pacific Supply Co (score: 7.2, 7 days, $15,080)

  You can adjust the quantity or choose a different supplier.
```

### Step 6: Handle User Edits
If the user changes the quantity or supplier:
1. Recalculate estimated cost with the new values
2. Re-run guardrail checks (sanity, budget) on the edited values
3. Present the updated summary and ask for final confirmation:
```
Updated: 1,000 units from S02 - GlobalParts Inc
Lead time: 10 days  |  Est. cost: $14,000
Confirm?
```

### Step 7: Execute (after confirmation only)
```sql
CALL CREATE_PURCHASE_ORDER('P100', 'S01', 'PL01', 1260, 'Low stock: DOI 2.1 days, demand rising 15%');
```
Report the result: "Created PO O021 for 1,260 units of P100. Est. cost: $14,490."

### Step 8: Slack Notification
After successful PO creation, send a Slack alert via SLACK_MCP to **#supply-chain-alerts**:
```
[PO CREATED] P100 (Bearing Assembly 50mm) from Acme Components — Qty: 1,260
Plant: Chicago | Est. cost: $14,490
DOI was 2.1 days | Demand trend: rising 15%
```
If Slack send fails, still confirm the PO to the user. Note: "Slack notification failed — PO created successfully."

## Guardrails
- **Data freshness**: Check INVENTORY.last_updated. If >24 hours old, warn: "Inventory data is N hours old — recommendation may not reflect current stock."
- **Quantity sanity**: CREATE_PURCHASE_ORDER enforces >3x avg check. If triggered after user edit, show the warning and ask to proceed.
- **Duplicate check**: CREATE_PURCHASE_ORDER checks for similar PO in last 7 days.
- **Budget limit**: CREATE_PURCHASE_ORDER enforces $50,000 per PO limit.
- **Confidence disclosure**: If demand_planner returns low confidence, pass that through: "Forecast confidence is LOW — only 12 days of history."
- **Fallback**: If no demand data exists for a part, state: "No order history to forecast demand. Manual quantity required."
