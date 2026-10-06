---
name: supplier_scorecard
description: Evaluate and rank suppliers by composite performance score. Flag underperformers. Recommend the best supplier for a given part based on OTD, quality, and cost.
---
# Supplier Scorecard

## Description
Evaluate and rank suppliers by composite performance score. Flag underperformers. Recommend the best supplier for a given part based on OTD, quality, and cost.

## When to Use
- User asks to evaluate a supplier's performance
- User asks to compare suppliers for a part
- User asks which supplier is best/worst
- User asks to re-rate underperforming suppliers

## Instructions

### Step 1: Compute Scores
Call the `GENERATE_SCORECARD` UDF for each supplier being evaluated:
```sql
SELECT GENERATE_SCORECARD('S01') AS scorecard;
```
The UDF returns a VARIANT with: composite_score (0-10), otd_score, quality_score, cost_score, and the weights (OTD: 40%, Quality: 30%, Cost: 30%).

### Step 2: Rank and Compare
If comparing multiple suppliers for a part:
1. Query DT_LANDED_COST for landed cost by supplier for that part
2. Call GENERATE_SCORECARD for each supplier
3. Rank by composite_score descending
4. Present a comparison table: supplier name, composite score, OTD%, quality rating, landed cost

### Step 3: Flag Underperformers
A supplier is underperforming if:
- Composite score < 6.0, OR
- OTD percentage < 80%, OR
- Quality rating is C or below

For flagged suppliers, show:
- Current score breakdown (which factor is pulling them down)
- Trend: is their OTD getting better or worse? (compare last 30 days vs prior 60 days from DT_DELIVERY_PERF)
- Recommendation: maintain, watchlist, or downgrade rating

### Step 4: Rating Change (if requested)
If the user agrees to change a supplier's rating, call `UPDATE_SUPPLIER_RATING`:
```sql
CALL UPDATE_SUPPLIER_RATING('S05', 'C', 'OTD declined to 72%, below 80% threshold', FALSE);
```
Always show the impact before executing: "Supplier S05 is preferred for 3 parts. Downgrading to C will cause reorder_advisor to recommend alternate suppliers."

### Step 5: Slack Notification (after rating change)
After UPDATE_SUPPLIER_RATING succeeds, send a Slack alert via SLACK_MCP to **#supply-chain-alerts**:
```
[RATING CHANGE] S05 - Pacific Supply Co — B → C
Reason: OTD declined to 72%, below 80% threshold
Impact: Preferred for 3 parts — reorder_advisor will recommend alternates
```
If Slack send fails, still confirm the rating change to the user.

## Guardrails
- **Confidence disclosure**: If a supplier has fewer than 5 historical shipments, state: "Low confidence — only N shipments in history."
- **Data freshness**: Check DT_DELIVERY_PERF refresh timestamp. If stale (>24 hours), warn before presenting.
- **Cost vs quality mandatory**: Never recommend a supplier based on cost alone without showing OTD% and quality rating.
- **Rating change cap**: UPDATE_SUPPLIER_RATING enforces max 1 tier change per update.

## Output Format
Present results as a clear comparison table with all score components visible. Always include the composite score formula weights so the user understands how the score is derived.
