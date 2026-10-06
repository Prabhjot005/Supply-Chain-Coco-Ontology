---
name: cost_analyzer
description: Break down landed cost per unit into components (material, freight, duty), compare suppliers on total cost, cross-reference cost vs quality, and identify savings opportunities.
---
# Cost Analyzer

## Description
Break down landed cost per unit into components (material, freight, duty), compare suppliers on total cost, cross-reference cost vs quality, analyze cost trends, and identify savings opportunities.

## When to Use
- User asks about landed cost for a part or supplier
- User asks to compare suppliers by cost
- User asks why costs are rising
- User asks for cost-saving opportunities
- User asks for a cost breakdown

## Instructions

### Step 1: Gather Raw Cost Data
Query DT_LANDED_COST for the requested part/supplier:
```sql
SELECT supplier_id, supplier_name, supplier_country, part_id, part_name,
       material_cost, freight_per_unit, duty_per_unit, landed_cost_per_unit,
       freight_share_pct, ship_date
FROM DT_LANDED_COST
WHERE part_id = 'P100'  -- filter as appropriate
ORDER BY ship_date DESC;
```

### Step 2: Cost Breakdown (per supplier per part, last 90 days)
Aggregate by supplier:
```sql
SELECT supplier_id, supplier_name,
       ROUND(AVG(material_cost), 2) AS avg_material,
       ROUND(AVG(freight_per_unit), 2) AS avg_freight,
       ROUND(AVG(duty_per_unit), 2) AS avg_duty,
       ROUND(AVG(landed_cost_per_unit), 2) AS avg_landed,
       COUNT(*) AS shipment_count
FROM DT_LANDED_COST
WHERE part_id = 'P100'
  AND ship_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY supplier_id, supplier_name
ORDER BY avg_landed ASC;
```
Present as a comparison table showing all cost components.

### Step 3: Cross-Reference with Quality
For each supplier in the comparison, call GENERATE_SCORECARD:
```sql
SELECT GENERATE_SCORECARD('S01') AS scorecard;
```
Also pull OTD% from DT_DELIVERY_PERF.

Build a cost-quality matrix:
```
Supplier         Landed   Score  OTD%   Verdict
S01 Acme         $14.70   8.7    92%    Best overall
S02 GlobalParts  $14.86   7.9    85%    Lower reliability
S03 Pacific      $15.08   7.2    78%    Cheapest freight, worst OTD
```

**NEVER recommend a cheaper supplier without showing OTD% and quality score alongside.** If the cheaper option has OTD < 80% or score < 7.0, explicitly flag: "This supplier is cheaper but below quality thresholds."

### Step 4: Trend Analysis
Compare current month vs prior 3 months:
```sql
SELECT
    CASE WHEN ship_date >= DATEADD('month', -1, CURRENT_DATE()) THEN 'current' ELSE 'prior_3mo' END AS period,
    ROUND(AVG(material_cost), 2) AS avg_material,
    ROUND(AVG(freight_per_unit), 2) AS avg_freight,
    ROUND(AVG(duty_per_unit), 2) AS avg_duty,
    ROUND(AVG(landed_cost_per_unit), 2) AS avg_landed
FROM DT_LANDED_COST
WHERE part_id = 'P100' AND supplier_id = 'S01'
  AND ship_date >= DATEADD('month', -4, CURRENT_DATE())
GROUP BY period;
```
Identify which component is driving changes and flag significant increases:
"Landed cost rose 6.1% — primary driver: freight +20% (carrier rate hike)."

### Step 5: Savings Opportunities
Compare all suppliers per part. Filter alternatives: score >= 7.0 AND OTD >= 80%.
```
annual_savings = (current_landed - alt_landed) * estimated_annual_volume
```
Rank by annual savings. Flag misleading savings where material is cheaper but landed is not (freight kills the saving).

Present:
```
Top Savings Opportunities:
1. Part P100: Switch from S03 ($15.08) to S01 ($14.70). Save $0.38/unit.
   Annual volume: 12,000 → Annual savings: $4,560.
   S01 score: 8.7, OTD: 92% (better on all metrics).
```

## Guardrails
- **Incomplete cost data**: If freight_cost is NULL for some shipments, exclude from averages and disclose: "Excludes N of M shipments (missing freight data). Averages may be skewed."
- **Small sample warning**: If fewer than 5 shipments for a supplier/part combo, warn: "Only N shipments — cost estimate may not be representative."
- **Cost vs quality mandatory**: ALWAYS show supplier quality score alongside cost. Never recommend based on cost alone.
- **Duty rate transparency**: Disclose: "Duty rates are estimates by country of origin — consult trade compliance for exact rates."
- **Stale data**: If DT_LANDED_COST hasn't refreshed in 24+ hours, warn.
- **Misleading savings flag**: If a "saving" disappears when freight is included, explicitly call it out.
- **Currency consistency**: Verify all costs are in the same currency before comparing.

## Output Format
Present results as structured tables with all cost components visible. Include the cost-quality matrix for any supplier comparison. For trend analysis, show the breakdown of which component changed and by how much.
