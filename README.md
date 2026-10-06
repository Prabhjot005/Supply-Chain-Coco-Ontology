# Supply Chain Ontology & Governed Conversational Analytics

A complete supply chain analytics platform on Snowflake that encodes business entities (Supplier → Part → Plant → Shipment → Order → Customer) as governed semantic views, so a natural-language agent layer returns consistent, trustworthy answers across procurement, planning, and logistics personas.

Built entirely with **Snowflake CoCo** (CLI) across planning, development, execution, and testing.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     STREAMLIT APP (SiS)                         │
│  Persona-aware dashboards │ NL Query Interface │ 9 pages        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│               SUPPLY_CHAIN_AGENT (Primary)                      │
│  Routes queries │ Cross-domain consistency │ 4 canonical metrics │
├──────────┬──────────────┬──────────────┬────────────────────────┤
│PROCUREMENT│  PLANNING    │  LOGISTICS   │  Direct Tools          │
│  AGENT    │  AGENT       │  AGENT       │  GENERATE_SCORECARD    │
│           │              │              │  CREATE_PURCHASE_ORDER  │
│ supplier_ │ demand_      │ shipment_    │  TRIGGER_EXPEDITE      │
│ scorecard │ planner      │ tracker      │  UPDATE_SUPPLIER_RATING│
│ cost_     │ reorder_     │              │                        │
│ analyzer  │ advisor      │              │                        │
│ reorder_  │              │              │                        │
│ advisor   │              │              │                        │
└──────────┴──────────────┴──────────────┴────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│            SUPPLY_CHAIN_ONTOLOGY (Semantic View)                │
│  11 entities │ 4 metrics │ 8 relationships │ 4 verified queries │
└──────────────────────────┬──────────────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│DT_DELIVERY_  │ │DT_ORDER_     │ │DT_INVENTORY_ │
│PERF          │ │FULFILLMENT   │ │POSITION      │
│ OTD%         │ │ Fill Rate%   │ │ DOI          │
│              │ │      │       │ │              │
│              │ │      ▼       │ │              │
│              │ │V_ORDER_      │ │              │
│              │ │FULFILLMENT   │ │              │
│              │ │ Risk Score   │ │              │
└──────────────┘ └──────────────┘ └──────────────┘
          │                │                │
          ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│STREAM_       │ │STREAM_       │ │STREAM_       │
│SHIPMENTS     │ │ORDER_RISK    │ │INVENTORY     │
│      │       │ │      │       │ │      │       │
│      ▼       │ │      ▼       │ │      ▼       │
│TASK_SHIPMENT │ │TASK_ORDER_   │ │TASK_INVENTORY│
│DELAY_ALERT   │ │RISK_ALERT    │ │LOW_ALERT     │
└──────────────┘ └──────────────┘ └──────────────┘
          │                │                │
          └────────────────┼────────────────┘
                           ▼
              ┌──────────────────────┐
              │ SUPPLY_CHAIN_ALERTS  │
              │ Jira │ Slack │ Status│
              └──────────────────────┘
```

---

## Canonical Metrics

| Metric | Definition | Source | Semantic View Entity |
|--------|-----------|--------|---------------------|
| **OTD %** | On-time shipments / total shipments × 100 | DT_DELIVERY_PERF | DELIVERY_PERFORMANCE |
| **Fill Rate %** | Fulfilled qty / ordered qty × 100 | V_ORDER_FULFILLMENT | ORDER_FULFILLMENT |
| **Days of Inventory** | On-hand qty / avg daily demand | DT_INVENTORY_POSITION | INVENTORY_POSITION |
| **Landed Cost/Unit** | Material + freight + duty per unit | DT_LANDED_COST | LANDED_COST |

These 4 metrics resolve identically regardless of which persona (Procurement, Planning, Logistics) asks the question.

---

## Object Inventory

| Category | Count | Objects |
|----------|-------|---------|
| Database + Schema | 2 | SUPPLY_CHAIN_DB, SCM |
| Roles | 5 | SUPPLY_CHAIN_ADMIN, SC_AGENT_ROLE, PROCUREMENT_ROLE, PLANNING_ROLE, LOGISTICS_ROLE |
| Base Tables | 10 | SUPPLIERS, PARTS, PLANTS, CUSTOMERS, SHIPMENTS, SHIPMENT_LINES, ORDERS, ORDER_LINES, INVENTORY, SUPPLY_CHAIN_ALERTS |
| Dynamic Tables | 4 | DT_DELIVERY_PERF, DT_ORDER_FULFILLMENT, DT_INVENTORY_POSITION, DT_LANDED_COST |
| Views | 2 | V_ORDER_FULFILLMENT (risk scoring), V_DEMAND_TRAINING_DATA (ML input) |
| Masking Policies | 5 | COST_DATA_MASK, SUPPLIER_DETAIL_MASK, CUSTOMER_DATA_MASK, SAFETY_STOCK_MASK, REORDER_POINT_MASK |
| Streams | 3 | STREAM_SHIPMENTS, STREAM_INVENTORY, STREAM_ORDER_RISK |
| Tasks | 3 | TASK_SHIPMENT_DELAY_ALERT, TASK_INVENTORY_LOW_ALERT, TASK_ORDER_RISK_ALERT |
| Custom Tools | 4 | GENERATE_SCORECARD (UDF), CREATE_PURCHASE_ORDER (SP), TRIGGER_EXPEDITE (SP), UPDATE_SUPPLIER_RATING (SP) |
| ML Model | 1 | DEMAND_FORECAST_MODEL (multi-series) |
| Stage + Skills | 6 | SKILL_STAGE + 5 SKILL.md files |
| Semantic View | 1 | SUPPLY_CHAIN_ONTOLOGY |
| Cortex Agents | 4 | SUPPLY_CHAIN_AGENT, PROCUREMENT_AGENT, PLANNING_AGENT, LOGISTICS_AGENT |
| Streamlit App | 1 | Supply Chain Analyst (9 pages, persona-aware) |
| CoCo Automations | 3 | LOGISTICS_DAILY_BRIEF, PLANNING_DAILY_BRIEF, PROCUREMENT_DAILY_BRIEF |

---

## Prerequisites

- Snowflake account with **ACCOUNTADMIN** access
- **COMPUTE_WH** warehouse (X-Small is sufficient for demo data)
- Snowflake features enabled: Cortex Agents, Semantic Views, Dynamic Tables, ML Functions, Streamlit in Snowflake
- **Snowflake CoCo** (CLI or Desktop) for automations

---

## Project Structure

```
CoCo Supply Chain/
├── deploy.sql                          # Master deployment guide (execution order)
├── supply_chain_design_decisions.html  # Design document with all SELECTED/REJECTED decisions
├── 01_foundation/
│   ├── 01_database_schema.sql          # CREATE DATABASE + SCHEMA
│   ├── 02_roles.sql                    # 5 roles with hierarchy
│   └── 03_grants.sql                   # All privileges and future grants
├── 02_base_tables/
│   ├── 01_master_tables.sql            # SUPPLIERS, PARTS, PLANTS, CUSTOMERS
│   ├── 02_operational_tables.sql       # SHIPMENTS, SHIPMENT_LINES, ORDERS, ORDER_LINES, INVENTORY
│   ├── 03_alerts_table.sql             # SUPPLY_CHAIN_ALERTS
│   └── 04_sample_data.sql             # Realistic sample data (121+ rows)
├── 03_masking_policies/
│   └── 01_masking_policies.sql         # 5 column-level masking policies
├── 04_dynamic_tables/
│   └── 01_dynamic_tables.sql           # 4 DTs (INCREMENTAL) + V_ORDER_FULFILLMENT view
├── 05_streams_tasks/
│   ├── 01_streams.sql                  # 3 CDC streams (2 on tables, 1 on DT)
│   └── 02_tasks.sql                    # 3 stream-triggered alert tasks
├── 06_custom_tools/
│   ├── 01_generate_scorecard.sql       # Supplier scoring UDF (read-only)
│   ├── 02_create_purchase_order.sql    # PO creation SP (5 guardrails)
│   ├── 03_trigger_expedite.sql         # Unified expedite SP (4 guardrails)
│   └── 04_update_supplier_rating.sql   # Rating update SP (5 guardrails)
├── 07_ml_model/
│   └── 01_demand_forecast_model.sql    # Multi-series ML FORECAST model
├── 08_skills/
│   ├── 00_create_stage.sql             # SKILL_STAGE creation
│   ├── supplier_scorecard/SKILL.md     # Supplier evaluation workflow
│   ├── reorder_advisor/SKILL.md        # Reorder recommendation workflow
│   ├── shipment_tracker/SKILL.md       # Shipment tracking + ETA workflow
│   ├── demand_planner/SKILL.md         # ML-based demand forecasting workflow
│   └── cost_analyzer/SKILL.md          # Landed cost analysis workflow
├── 09_semantic_view/
│   └── 01_supply_chain_ontology.sql    # Semantic view with YAML spec
├── 10_agents/
│   ├── 01_procurement_agent.sql        # Procurement sub-agent
│   ├── 02_planning_agent.sql           # Planning sub-agent
│   ├── 03_logistics_agent.sql          # Logistics sub-agent
│   └── 04_supply_chain_agent.sql       # Primary orchestrator agent
├── 11_streamlit/
│   └── app.py                          # Persona-aware Streamlit app (397 lines)
└── 12_automations/
    ├── 01_logistics_daily_brief.sql              # Deploy instructions
    ├── logistics_daily_brief_prompt.md           # Automation prompt
    ├── 02_planning_daily_brief.sql               # Deploy instructions
    ├── planning_daily_brief_prompt.md            # Automation prompt
    ├── 03_procurement_daily_brief.sql            # Deploy instructions
    └── procurement_daily_brief_prompt.md         # Automation prompt
```

---

## Setup Instructions

### Step 1: Foundation (Database, Schema, Roles, Grants)

Run these SQL files in your Snowflake SQL worksheet in order:

```sql
-- Connect as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- Run each file in sequence:
-- 01_foundation/01_database_schema.sql
-- 01_foundation/02_roles.sql
-- 01_foundation/03_grants.sql
```

**Important:** Edit `03_grants.sql` line 89 to replace `PRABHJOT` with your Snowflake username:
```sql
GRANT ROLE SUPPLY_CHAIN_ADMIN TO USER <YOUR_USERNAME>;
```

### Step 2: Base Tables + Sample Data

```sql
USE ROLE SUPPLY_CHAIN_ADMIN;
USE DATABASE SUPPLY_CHAIN_DB;
USE SCHEMA SCM;

-- Run each file in sequence:
-- 02_base_tables/01_master_tables.sql
-- 02_base_tables/02_operational_tables.sql
-- 02_base_tables/03_alerts_table.sql
-- 02_base_tables/04_sample_data.sql
```

**Verify:** `SELECT COUNT(*) FROM SUPPLIERS;` should return 10.

### Step 3: Masking Policies

```sql
-- Run: 03_masking_policies/01_masking_policies.sql
```

**Verify:** Switch to `LOGISTICS_ROLE` and query `SELECT freight_cost FROM SHIPMENTS LIMIT 1;` — should return NULL (masked).

### Step 4: Dynamic Tables + View

```sql
-- Run: 04_dynamic_tables/01_dynamic_tables.sql
```

This creates 4 INCREMENTAL dynamic tables and the V_ORDER_FULFILLMENT view. Wait a few seconds for the initial refresh, then verify:

```sql
SELECT order_id, risk_score, risk_level FROM V_ORDER_FULFILLMENT ORDER BY risk_score DESC LIMIT 5;
```

**Verify:** You should see CRITICAL orders with risk scores of 9-11.

### Step 5: Streams + Tasks

```sql
-- Run: 05_streams_tasks/01_streams.sql
-- Run: 05_streams_tasks/02_tasks.sql
```

**Verify:** `SHOW TASKS IN SCHEMA SCM;` should show 3 tasks in `started` state.

### Step 6: Custom Tools + ML Model

```sql
-- Run: 06_custom_tools/01_generate_scorecard.sql
-- Run: 06_custom_tools/02_create_purchase_order.sql
-- Run: 06_custom_tools/03_trigger_expedite.sql
-- Run: 06_custom_tools/04_update_supplier_rating.sql
-- Run: 07_ml_model/01_demand_forecast_model.sql
```

**Verify:** `SELECT GENERATE_SCORECARD('S01');` should return a JSON object with composite_score.

**Note:** The ML model requires at least 2 unique timestamps per series. If it fails with "At least two unique timestamps required", ensure sample data includes enough historical orders (the sample data in `04_sample_data.sql` includes orders from May-October 2026).

### Step 7: Stage + Skills

```sql
-- Run: 08_skills/00_create_stage.sql
```

Then upload the 5 SKILL.md files to the stage. In a SQL worksheet:

```sql
PUT 'file://<LOCAL_PATH>/08_skills/supplier_scorecard/SKILL.md' '@SKILL_STAGE/skills/supplier_scorecard/' AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://<LOCAL_PATH>/08_skills/reorder_advisor/SKILL.md' '@SKILL_STAGE/skills/reorder_advisor/' AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://<LOCAL_PATH>/08_skills/shipment_tracker/SKILL.md' '@SKILL_STAGE/skills/shipment_tracker/' AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://<LOCAL_PATH>/08_skills/demand_planner/SKILL.md' '@SKILL_STAGE/skills/demand_planner/' AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT 'file://<LOCAL_PATH>/08_skills/cost_analyzer/SKILL.md' '@SKILL_STAGE/skills/cost_analyzer/' AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
```

Replace `<LOCAL_PATH>` with your actual project path. Paths with spaces need single quotes.

**Verify:** `LIST @SKILL_STAGE/skills/;` should show 5 files.

### Step 8: Semantic View + Agents

```sql
-- Run: 09_semantic_view/01_supply_chain_ontology.sql
-- Run: 10_agents/01_procurement_agent.sql
-- Run: 10_agents/02_planning_agent.sql
-- Run: 10_agents/03_logistics_agent.sql
-- Run: 10_agents/04_supply_chain_agent.sql
```

**Note:** The `verified_at` field in the semantic view YAML must be a Unix epoch integer (e.g., `1791100800`), not a date string.

**Verify:** `SHOW AGENTS IN SCHEMA SCM;` should show 4 agents.

### Step 9: Streamlit App

1. In Snowsight, go to **Projects > Streamlit**
2. Click **+ Streamlit App**
3. Configure:
   - **Name:** `SUPPLY_CHAIN_ANALYST`
   - **Database:** `SUPPLY_CHAIN_DB`
   - **Schema:** `SCM`
   - **Warehouse:** `COMPUTE_WH`
   - **Owner role:** `SUPPLY_CHAIN_ADMIN`
4. Replace the default code with the content from `11_streamlit/app.py`
5. Click **Run**

The app auto-detects the user's Snowflake role and shows persona-appropriate pages.

### Step 10: CoCo Automations

Requires **Snowflake CoCo** (CLI or Desktop). Run from the project root directory:

```bash
# Logistics: fires weekdays at 7:30 AM IST
cortex automation create \
  --name LOGISTICS_DAILY_BRIEF \
  --schedule "weekdays at 7:30am" \
  --timezone "Asia/Kolkata" \
  --prompt-file "12_automations/logistics_daily_brief_prompt.md" \
  --no-workspace

# Planning: fires weekdays at 8:00 AM IST
cortex automation create \
  --name PLANNING_DAILY_BRIEF \
  --schedule "weekdays at 8:00am" \
  --timezone "Asia/Kolkata" \
  --prompt-file "12_automations/planning_daily_brief_prompt.md" \
  --no-workspace

# Procurement: fires weekdays at 8:30 AM IST
cortex automation create \
  --name PROCUREMENT_DAILY_BRIEF \
  --schedule "weekdays at 8:30am" \
  --timezone "Asia/Kolkata" \
  --prompt-file "12_automations/procurement_daily_brief_prompt.md" \
  --no-workspace
```

**Note:** Adjust `--timezone` to your local timezone. Automations live in `USER$<username>.PUBLIC` (not configurable).

**Verify:** `cortex automation list` should show 3 automations in `started` state.

---

## RBAC and Masking Matrix

| Data | PROCUREMENT | PLANNING | LOGISTICS | SC_AGENT / ADMIN |
|------|:-----------:|:--------:|:---------:|:----------------:|
| Freight cost, unit cost, unit price | Visible | Masked | Masked | Visible |
| Quality rating, carrier | Visible | Masked | Visible | Visible |
| Customer name, segment, region | Masked | Visible | Masked | Visible |
| Safety stock qty | Masked | Visible | Masked | Visible |
| Reorder point | Visible | Visible | Masked | Visible |

All roles have SELECT on all tables — masking policies enforce column-level restrictions transparently.

---

## Guardrails Summary

| Tool | Guardrails |
|------|-----------|
| CREATE_PURCHASE_ORDER | Input validation (part/supplier/plant exist, qty > 0), duplicate check (7 days), quantity sanity (3x avg), budget limit ($50K) |
| TRIGGER_EXPEDITE | Type validation, record exists, 48-hour duplicate check, 3x escalation cap |
| UPDATE_SUPPLIER_RATING | Value validation, exists check, 1-tier cap, 7-day recent change check, override audit |
| GENERATE_SCORECARD | Read-only (no guardrails needed) |
| Agent-level | Confirmation before all writes, data freshness disclosure, confidence intervals, scope restriction |

---

## Risk Scoring (DT_ORDER_FULFILLMENT → V_ORDER_FULFILLMENT)

Composite score 0-12 from 4 factors (3 points each):

| Factor | 0 (Safe) | 1 (Watch) | 2 (Warning) | 3 (Critical) |
|--------|----------|-----------|-------------|---------------|
| Stock Coverage (days) | > 14 | 7-14 | 3-7 | < 3 |
| Fulfillment Ratio | >= 90% | 50-89% | 1-49% | 0% |
| Shipment Risk | Proxy from stock coverage | | | |
| Days to Requested Date | > 14 | 7-14 | 3-7 | < 3 or past |

| Score | Level | Action |
|-------|-------|--------|
| 0-2 | LOW | No action |
| 3-5 | MEDIUM | Monitor |
| 6-8 | HIGH | Action needed |
| 9-12 | CRITICAL | Escalate immediately |

**Architecture note:** Risk scoring uses `CURRENT_DATE()` which blocks INCREMENTAL refresh on DTs. The solution splits responsibility: DT_ORDER_FULFILLMENT stores time-independent raw data (INCREMENTAL refresh, supports streams), and V_ORDER_FULFILLMENT view computes risk scores at query time. This gives both incremental efficiency and live risk scores.

---

## Key Design Decisions

The full design decision log with SELECTED/REJECTED rationale for every component is in `supply_chain_design_decisions.html` (2100+ lines). Key decisions:

1. **Audit strategy:** Access History (master tables) + Time Travel 90d (operational) — eliminated 19 custom audit objects
2. **DT refresh mode:** INCREMENTAL with view layer for time-dependent calculations — enables streams on DTs
3. **Stream/task architecture:** 3 streams + 3 tasks (stream-triggered, not polling) — minimum set for event-driven alerts
4. **Agent architecture:** 1 primary + 3 domain sub-agents with domain-specific skills — skills never on primary agent
5. **Risk scoring split:** DT (raw data, INCREMENTAL) + View (risk scores, CURRENT_DATE) — best of both worlds
6. **Automations:** Team-based daily briefs with staggered timing (Logistics 7:30 → Planning 8:00 → Procurement 8:30) — information cascade

---

## Testing the Solution

### Test cross-persona metric consistency

Run as different roles and verify the same metric returns the same value:

```sql
-- As PROCUREMENT_ROLE
USE ROLE PROCUREMENT_ROLE;
SELECT SUM(ON_TIME_COUNT) * 100.0 / SUM(TOTAL_SHIPMENTS) AS otd
FROM SUPPLY_CHAIN_DB.SCM.DT_DELIVERY_PERF;

-- As LOGISTICS_ROLE
USE ROLE LOGISTICS_ROLE;
SELECT SUM(ON_TIME_COUNT) * 100.0 / SUM(TOTAL_SHIPMENTS) AS otd
FROM SUPPLY_CHAIN_DB.SCM.DT_DELIVERY_PERF;

-- Both should return the same OTD% value
```

### Test masking enforcement

```sql
USE ROLE LOGISTICS_ROLE;
SELECT shipment_id, carrier, freight_cost FROM SUPPLY_CHAIN_DB.SCM.SHIPMENTS LIMIT 3;
-- carrier: visible | freight_cost: NULL (masked)

USE ROLE PROCUREMENT_ROLE;
SELECT shipment_id, carrier, freight_cost FROM SUPPLY_CHAIN_DB.SCM.SHIPMENTS LIMIT 3;
-- carrier: visible | freight_cost: visible
```

### Test guardrails

```sql
-- Test duplicate check
CALL SUPPLY_CHAIN_DB.SCM.CREATE_PURCHASE_ORDER('P100', 'S01', 'PL01', 100, 'test');
-- First call: SUCCESS
CALL SUPPLY_CHAIN_DB.SCM.CREATE_PURCHASE_ORDER('P100', 'S01', 'PL01', 100, 'test');
-- Second call: GUARDRAIL_DUPLICATE

-- Test input validation
CALL SUPPLY_CHAIN_DB.SCM.CREATE_PURCHASE_ORDER('INVALID', 'S01', 'PL01', 100, 'test');
-- Returns: ERROR: Part INVALID not found.

-- Test rating cap
CALL SUPPLY_CHAIN_DB.SCM.UPDATE_SUPPLIER_RATING('S05', 'A', 'test upgrade', FALSE);
-- Returns: GUARDRAIL_RATING_CAP (C to A is 2 tiers, max 1 allowed)
```

### Test the agent

In Snowsight, navigate to the SUPPLY_CHAIN_AGENT in AI & ML > Cortex Agents, or use the Streamlit app's NL interface:

- "What is the OTD for Supplier Acme?"
- "Which orders are at risk?"
- "Show parts with less than 3 days of inventory"
- "Compare suppliers for Part P100 by cost and OTD"

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| ML model fails: "At least two unique timestamps required" | Insufficient historical orders for some part/plant combos | Add more historical orders or filter training view to series with >= 2 timestamps |
| `CHANGE_TRACKING = TRUE` error on CREATE DYNAMIC TABLE | Not a valid property in CREATE syntax | Remove it; INCREMENTAL DTs support streams automatically |
| Correlated subquery error in DT | Dynamic tables don't support correlated subqueries | Rewrite using CTEs and JOINs |
| Stream on DT fails | DT uses FULL refresh (no change tracking) | Ensure DT uses REFRESH_MODE = INCREMENTAL |
| `verified_at` error in semantic view YAML | Field expects Unix epoch integer, not date string | Use epoch seconds (e.g., 1791100800) |
| Streamlit date comparison TypeError | Comparing datetime.date with string | Use `pd.to_datetime()` for proper type conversion |
| Agent spec "invalid" error | `agent_toolset` resource uses wrong key | Use `agent_name: DB.SCHEMA.AGENT` not `agent: DB.SCHEMA.AGENT` |
| UDF returns OBJECT not VARIANT | OBJECT_CONSTRUCT returns OBJECT type | Declare return type as OBJECT, not VARIANT |

---

## CoCo Usage Across the Lifecycle

| Phase | How CoCo Was Used |
|-------|-------------------|
| **Planning** | Explored data model, drafted ontology design, outlined workflow, created design decisions document |
| **Development** | Built all SQL scripts, SKILL.md files, Streamlit app, agent specs, and automation prompts |
| **Execution** | Deployed all objects phase-by-phase with validation, created automations via `cortex automation create` |
| **Testing** | Validated masking by switching roles, tested guardrails, verified DT refresh modes, confirmed risk scoring |

---

## License

This project was built for the Snowflake CoCo Hackathon 2026. All code is provided as-is for demonstration purposes.
