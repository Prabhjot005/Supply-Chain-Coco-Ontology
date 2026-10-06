---
name: demand_planner
description: Forecast demand by part/plant using the pre-trained Snowflake ML FORECAST model. Returns projections with confidence intervals, trend direction, and seasonality detection.
---
# Demand Planner

## Description
Forecast demand by part/plant using the pre-trained Snowflake ML FORECAST model (multi-series). Returns projections with confidence intervals, trend direction, and seasonality detection. Does NOT retrain the model per query.

## When to Use
- User asks for demand forecast for a part or plant
- reorder_advisor skill delegates demand forecasting here
- User asks about demand trends or seasonality
- User asks what demand will be for a part next month

## Instructions

### Step 1: Check Model Freshness
Query when the model was last trained:
```sql
DESCRIBE SNOWFLAKE.ML.FORECAST DEMAND_FORECAST_MODEL;
```
If the model is older than 7 days and new orders have arrived, recommend rebuilding:
"Forecast model is N days old — M new orders since last build. Rebuild for a fresher projection?"

### Step 2: Generate Forecast (inference only, no retraining)
Call the pre-trained multi-series model:
```sql
CALL DEMAND_FORECAST_MODEL!FORECAST(FORECASTING_PERIODS => 30);
```
This returns rows for ALL series. Filter to the requested part/plant:
```
WHERE SERIES = 'P100_PL01'
```
Each row contains: ds (date), forecast (predicted demand), lower_bound, upper_bound.

### Step 3: Interpret Results
Calculate:
```
projected_30d_demand = SUM(forecast) over 30 days
avg_daily_demand = projected_30d_demand / 30
confidence_range = MIN(lower_bound) to MAX(upper_bound)
trend = compare AVG(forecast) for days 1-15 vs days 16-30
  > 10% increase → rising
  > 10% decrease → falling
  else → stable
```

### Step 4: Check for Anomalies in Training Data
Query recent order history for outliers:
```sql
SELECT order_date, SUM(quantity) AS daily_qty
FROM ORDERS o JOIN ORDER_LINES ol ON o.order_id = ol.order_id
WHERE ol.part_id = 'P100' AND o.plant_id = 'PL01'
  AND o.order_date >= DATEADD('day', -90, CURRENT_DATE())
GROUP BY order_date
HAVING daily_qty > (SELECT AVG(daily_qty) * 5 FROM (...));
```
If outliers found, flag: "Training data includes a spike on [date] ([qty] units vs median [N]). This may inflate the forecast."

### Step 5: Return Results
Return structured output:
```
Demand Forecast: Part P100 at Plant Chicago (next 30 days)
  Avg daily demand: 38 units/day
  Projected 30-day demand: 1,140 units
  Confidence range: 980 — 1,300 units
  Trend: Rising (+15%)
  Seasonality: None detected (insufficient history for seasonal patterns)
  Model age: 3 days (fresh)
```

## Guardrails
- **Minimum training data**: ML FORECAST needs at least 2 seasonal cycles (~60 days). If fewer than 60 days of order history for the requested part/plant, fall back to simple 30-day rolling average and disclose: "Insufficient data for ML forecast — using 30-day rolling average instead."
- **Confidence interval disclosure**: ALWAYS show the range, not just the point estimate. "Projected demand: 1,140 units (range: 980-1,300)."
- **Outlier detection**: If a single day's demand > 5x the median, flag it and let the user decide whether to exclude.
- **Zero demand warning**: If no orders in last 30 days, skip ML and say: "No demand recorded for this part/plant. Part may be discontinued or seasonal."
- **Model staleness**: If model > 7 days old, recommend rebuild but still return forecast from current model.
- **Forecast vs actual divergence**: If a previous forecast is available, compare against actuals and flag significant deviation.

## Output Format
Always include: avg_daily_demand, projected_30d_demand, confidence_range, trend_direction, seasonality flag, and model age. When called by reorder_advisor, return the structured data. When called standalone, present a human-readable summary.
