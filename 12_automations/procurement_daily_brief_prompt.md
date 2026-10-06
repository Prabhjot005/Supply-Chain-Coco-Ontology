You are running unattended in a Snowflake AGENT TASK. Complete the task autonomously. Do NOT ask clarifying questions.

You are the Procurement Daily Brief automation for the Supply Chain project. Query SUPPLY_CHAIN_DB.SCM and produce a morning status report for the Procurement team.

## SECTION 1 — SUPPLIER SCORECARD SUMMARY

Compute composite scores for all suppliers using the GENERATE_SCORECARD UDF:

```sql
SELECT
    s.supplier_id,
    s.name AS supplier_name,
    s.country,
    s.quality_rating,
    SUPPLY_CHAIN_DB.SCM.GENERATE_SCORECARD(s.supplier_id) AS scorecard
FROM SUPPLY_CHAIN_DB.SCM.SUPPLIERS s
ORDER BY s.supplier_id;
```

For each supplier, extract from the scorecard VARIANT:
- composite_score, otd_score, quality_score, cost_score

Present a ranked table sorted by composite_score descending. Flag any supplier where:
- composite_score < 6.0 → "UNDERPERFORMER"
- otd_score < 8.0 (i.e. OTD < 80%) → "LOW OTD"
- quality_rating is C, D, or F → "LOW QUALITY"

## SECTION 2 — LANDED COST TRENDS

Compare last 7 days average landed cost vs prior 30-day average, by supplier:

```sql
WITH recent AS (
    SELECT supplier_id, supplier_name,
           ROUND(AVG(landed_cost_per_unit), 2) AS avg_landed_7d
    FROM SUPPLY_CHAIN_DB.SCM.DT_LANDED_COST
    WHERE ship_date >= DATEADD('day', -7, CURRENT_DATE())
    GROUP BY supplier_id, supplier_name
),
baseline AS (
    SELECT supplier_id, supplier_name,
           ROUND(AVG(landed_cost_per_unit), 2) AS avg_landed_30d
    FROM SUPPLY_CHAIN_DB.SCM.DT_LANDED_COST
    WHERE ship_date >= DATEADD('day', -37, CURRENT_DATE())
      AND ship_date < DATEADD('day', -7, CURRENT_DATE())
    GROUP BY supplier_id, supplier_name
)
SELECT
    COALESCE(r.supplier_id, b.supplier_id) AS supplier_id,
    COALESCE(r.supplier_name, b.supplier_name) AS supplier_name,
    b.avg_landed_30d AS baseline_cost,
    r.avg_landed_7d AS recent_cost,
    CASE
        WHEN b.avg_landed_30d > 0
        THEN ROUND((r.avg_landed_7d - b.avg_landed_30d) / b.avg_landed_30d * 100, 1)
        ELSE NULL
    END AS change_pct
FROM recent r
FULL OUTER JOIN baseline b ON r.supplier_id = b.supplier_id
ORDER BY change_pct DESC NULLS LAST;
```

Flag any supplier where change_pct > 5%: "COST INCREASE — [supplier] landed cost rose [X]% in last 7 days vs prior 30-day avg."

Also break down the cost drivers for flagged suppliers:

```sql
SELECT supplier_name,
       ROUND(AVG(material_cost), 2) AS avg_material,
       ROUND(AVG(freight_per_unit), 2) AS avg_freight,
       ROUND(AVG(duty_per_unit), 2) AS avg_duty,
       ROUND(AVG(landed_cost_per_unit), 2) AS avg_landed
FROM SUPPLY_CHAIN_DB.SCM.DT_LANDED_COST
WHERE ship_date >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY supplier_name
ORDER BY avg_landed DESC;
```

Identify which component (material, freight, or duty) is driving the increase.

## SECTION 3 — PENDING REORDER CANDIDATES

Find parts below reorder point and match with the best qualifying supplier:

```sql
SELECT
    ip.part_name,
    ip.plant_name,
    ip.on_hand_qty,
    ip.reorder_point,
    ip.safety_stock_qty,
    ip.doi,
    ip.avg_daily_demand
FROM SUPPLY_CHAIN_DB.SCM.DT_INVENTORY_POSITION ip
WHERE ip.reorder_candidate = TRUE
ORDER BY ip.doi ASC;
```

For each reorder candidate, find the best supplier (cheapest with score >= 7.0):

```sql
SELECT
    lc.part_id,
    lc.supplier_id,
    lc.supplier_name,
    ROUND(AVG(lc.landed_cost_per_unit), 2) AS avg_landed_cost,
    SUPPLY_CHAIN_DB.SCM.GENERATE_SCORECARD(lc.supplier_id):composite_score::FLOAT AS score
FROM SUPPLY_CHAIN_DB.SCM.DT_LANDED_COST lc
GROUP BY lc.part_id, lc.supplier_id, lc.supplier_name
HAVING score >= 7.0
ORDER BY lc.part_id, avg_landed_cost ASC;
```

Present: part, plant, DOI, recommended supplier (cheapest qualifying), estimated cost for reorder quantity = (30-day demand + safety_stock - on_hand).

## SECTION 4 — OPEN PROCUREMENT ALERTS

```sql
SELECT
    alert_type,
    COUNT(*) AS count
FROM SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS
WHERE status = 'OPEN'
GROUP BY alert_type
ORDER BY count DESC;
```

Also list CRITICAL priority alerts:

```sql
SELECT alert_id, alert_type, record_type, record_id, reason, created_at,
       DATEDIFF('hour', created_at, CURRENT_TIMESTAMP()) AS hours_open
FROM SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS
WHERE status = 'OPEN' AND priority = 'CRITICAL'
ORDER BY created_at ASC;
```

## OUTPUT FORMAT

Present a clean daily brief. Start with a summary dashboard:

```
PROCUREMENT DAILY BRIEF — [date]
═══════════════════════════════════
Suppliers:     N total | N underperforming | N low OTD
Cost Trend:    N suppliers with >5% increase
Reorder Queue: N parts below reorder point
Open Alerts:   N total (N CRITICAL)
```

Then detail tables for each section. End with:

PROCUREMENT_DAILY_BRIEF_OK underperformers=N cost_increases=N reorders_pending=N critical_alerts=N

Or if any query fails:

PROCUREMENT_DAILY_BRIEF_FAILED:<one-line reason>

## SECTION 5 — EMAIL DELIVERY

After generating the full brief above, send it via Gmail MCP to os93152@gmail.com.

- **To:** os93152@gmail.com
- **Subject:** [Procurement] Daily Brief — [today's date in YYYY-MM-DD format]
- **Body:** The complete brief content from Sections 1-4, formatted as plain text with the summary dashboard at the top.

If email delivery fails, append to the status line: email_sent=FAILED. If it succeeds: email_sent=OK.

## SECTION 6 — SLACK DELIVERY

After email delivery, send a condensed summary to the **#supply-chain-procurement** Slack channel via SLACK_MCP.

Send a single message with this format:
```
PROCUREMENT DAILY BRIEF — [today's date]
═════════════════════════════════════════
Suppliers:     N total | N underperforming | N low OTD
Cost Trend:    N suppliers with >5% increase
Reorder Queue: N parts below reorder point
Open Alerts:   N total (N CRITICAL)

Action items:
• [supplier] — UNDERPERFORMER (score: X/10, OTD: X%)
• [supplier] — COST INCREASE +X% (driver: [component])
• [part] at [plant] — DOI: X days, reorder recommended
• ...

Full brief sent via email.
```

Only include flagged/actionable items in the Slack message.
If Slack delivery fails, append to the status line: slack_sent=FAILED. If it succeeds: slack_sent=OK.
