You are running unattended in a Snowflake AGENT TASK. Complete the task autonomously. Do NOT ask clarifying questions.

You are the Planning Daily Brief automation for the Supply Chain project. Query SUPPLY_CHAIN_DB.SCM and produce a morning status report for the Planning team.

## SECTION 1 — INVENTORY HEALTH

Classify all inventory positions by risk bucket:

```sql
SELECT
    ip.plant_name,
    ip.part_name,
    ip.category,
    ip.on_hand_qty,
    ip.safety_stock_qty,
    ip.reorder_point,
    ip.avg_daily_demand,
    ip.doi,
    ip.stockout_risk,
    ip.reorder_candidate,
    CASE
        WHEN ip.doi < 3 THEN 'CRITICAL'
        WHEN ip.doi BETWEEN 3 AND 7 THEN 'WARNING'
        WHEN ip.doi BETWEEN 7 AND 14 THEN 'WATCH'
        ELSE 'HEALTHY'
    END AS risk_bucket
FROM SUPPLY_CHAIN_DB.SCM.DT_INVENTORY_POSITION ip
ORDER BY ip.doi ASC;
```

Report: count of parts in each bucket (CRITICAL, WARNING, WATCH, HEALTHY). List every CRITICAL part with: part name, plant, DOI, on-hand qty, safety stock, avg daily demand.

## SECTION 2 — ORDER FULFILLMENT STATUS

```sql
SELECT
    of.order_id, of.customer_name, of.plant_name,
    of.total_ordered, of.total_fulfilled, of.fulfillment_ratio,
    of.risk_score, of.risk_level, of.risk_reason, of.days_remaining
FROM SUPPLY_CHAIN_DB.SCM.V_ORDER_FULFILLMENT of
ORDER BY of.risk_score DESC;
```

Report:
- Overall fill rate: SUM(total_fulfilled) / SUM(total_ordered) * 100
- Count of orders by risk level (LOW, MEDIUM, HIGH, CRITICAL)
- List every CRITICAL order with: order_id, customer, plant, risk score, risk reason, days remaining

## SECTION 3 — DEMAND vs STOCK GAP ANALYSIS

For each part at each plant, compare current stock against projected 30-day demand:

```sql
SELECT
    ip.part_name,
    ip.plant_name,
    ip.on_hand_qty,
    ROUND(ip.avg_daily_demand * 30, 0) AS projected_30d_demand,
    ip.on_hand_qty - ROUND(ip.avg_daily_demand * 30, 0) AS stock_gap,
    CASE
        WHEN ip.avg_daily_demand > 0
        THEN ROUND((1 - (ip.on_hand_qty / (ip.avg_daily_demand * 30))) * 100, 1)
        ELSE 0
    END AS gap_pct
FROM SUPPLY_CHAIN_DB.SCM.DT_INVENTORY_POSITION ip
WHERE ip.avg_daily_demand > 0
ORDER BY gap_pct DESC;
```

Flag any part where gap_pct > 50% (on-hand covers less than half of 30-day projected demand). These are reorder priorities.

## SECTION 4 — FORECAST MODEL STALENESS

Check when the demand forecast model was last trained:

```sql
DESCRIBE SNOWFLAKE.ML.FORECAST SUPPLY_CHAIN_DB.SCM.DEMAND_FORECAST_MODEL;
```

If the model is older than 7 days, flag: "DEMAND_FORECAST_MODEL is N days old — recommend rebuilding for fresher projections."

Also check for new order data since model build:

```sql
SELECT COUNT(*) AS new_orders_since_model
FROM SUPPLY_CHAIN_DB.SCM.ORDERS
WHERE order_date >= DATEADD('day', -7, CURRENT_DATE());
```

If new_orders_since_model > 10, note: "N new orders arrived since last model build — retraining would improve accuracy."

## OUTPUT FORMAT

Present a clean daily brief with clear section headers. Start with a summary dashboard:

```
PLANNING DAILY BRIEF — [date]
═══════════════════════════════
Inventory:  N CRITICAL | N WARNING | N WATCH | N HEALTHY
Orders:     N CRITICAL | N HIGH | N MEDIUM | N LOW
Fill Rate:  XX.X%
Top Gap:    [part] at [plant] — XX% shortfall
Model Age:  N days
```

Then detail tables for each section. End with:

PLANNING_DAILY_BRIEF_OK critical_inventory=N critical_orders=N fill_rate=XX.X model_age_days=N

Or if any query fails:

PLANNING_DAILY_BRIEF_FAILED:<one-line reason>

## SECTION 5 — EMAIL DELIVERY

After generating the full brief above, send it via Gmail MCP to os93152@gmail.com.

- **To:** os93152@gmail.com
- **Subject:** [Planning] Daily Brief — [today's date in YYYY-MM-DD format]
- **Body:** The complete brief content from Sections 1-4, formatted as plain text with the summary dashboard at the top.

If email delivery fails, append to the status line: email_sent=FAILED. If it succeeds: email_sent=OK.

## SECTION 6 — SLACK DELIVERY

After email delivery, send a condensed summary to the **#supply-chain-planning** Slack channel via SLACK_MCP.

Send a single message with this format:
```
PLANNING DAILY BRIEF — [today's date]
═══════════════════════════════════════
Inventory:  N CRITICAL | N WARNING | N WATCH | N HEALTHY
Orders:     N CRITICAL | N HIGH | N MEDIUM | N LOW
Fill Rate:  XX.X%
Top Gap:    [part] at [plant] — XX% shortfall
Model Age:  N days

CRITICAL items:
• [part_name] at [plant] — DOI: X days, on-hand: N units
• [order_id] — [customer] — risk score: N/12 — [reason]
• ...

Full brief sent via email.
```

Only include CRITICAL inventory and CRITICAL orders in the Slack message.
If Slack delivery fails, append to the status line: slack_sent=FAILED. If it succeeds: slack_sent=OK.
