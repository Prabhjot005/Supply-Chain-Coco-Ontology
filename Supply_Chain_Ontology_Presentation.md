# Supply Chain Ontology & Governed Conversational Analytics
## CoCo CLI Hackathon GCC Edition — Prototype Presentation
**One Ontology. One Answer. Any Persona.**

---

## Executive Summary: The System Inventory

* Platform: Snowflake + CoCo CLI (Built 100% with CoCo)
* Author: Prabhjot Kaur (Solo)

### Core System Components:
* **52+** Snowflake Objects Deployed
* **4** Specialized Cortex Agents
* **5** Reusable Declarative Playbook Skills
* **3** Model Context Protocol (MCP) Servers
* **3** Automated Scheduled Production Engines
* **1** Centralized Supply Chain Semantic Ontology

---

## The Problem: Operational Chaos (Before CoCo)

* **Same Question, Different Answers:** Supply chain teams (procurement, planning, logistics) query the same underlying tables but calculate core metrics inconsistently.
* **Spreadsheet Silos:** Metrics like OTD%, Fill Rate, DOI, and Landed Cost get computed via localized spreadsheets, customized BI definitions, or disjointed ad-hoc SQL.
* **Standup Friction:** Conflicting analytics reports force alignment arguments during every operational standup meeting.
* **Manual Waste:** 30 to 60 minutes spent on manual report compilation every single morning per operational team.
* **Lack of Orchestration:** Zero enterprise-wide alerts and zero centralized governance rules.

---

## Target Audience Persona Needs

### 👔 Procurement Manager
Tracks supplier scorecards, long-term landed cost movements, critical material reorder points, and automated write-actions for purchase order logs with explicit justification parameters.

### 📊 Planning Analyst
Oversees system-wide inventory asset health, demand projection timelines driven by integrated ML forecasting code, fulfillment risk scoring matrices, and part gap logic charts.

### 🚚 Logistics Coordinator
Inspects transit tracking data feeds, routes delay flags, computes carrier on-time thresholds, and directly fires operational shipment expedite commands linked across Jira and Slack systems.

---

## Architecture Step 1: Base Tables & Modern Audit Design

### System Data Layer Composition (9 Functional Base Tables + 1 Alert Sink)
* **Master Reference Catalog (4 Tables):** SUPPLIERS, PARTS, PLANTS, CUSTOMERS.
* **Operational Tracking Layer (5 Tables):** SHIPMENTS, SHIPMENT_LINES, ORDERS, ORDER_LINES, INVENTORY.
* **Operational Alert Sink (1 Table):** SUPPLY_CHAIN_ALERTS (Tracks system-generated exceptions, alert types, execution states, upstream record links, and Jira reference IDs).

### Strategic Design Choice: Eliminating Over-Engineered Logging Overheads
* **Rejected Architecture Strategy:** Deploying 9 concurrent streams, 9 capture tasks, and 1 massive custom master audit table to parse change data loops universally across all tables. (Heavy, high-compute cost for slow-moving catalogs).
* **Selected Split Data Strategy:** Leverage native Snowflake cloud features directly based on data profile categories without writing custom pipelines.
* **Master Data Governance:** Managed automatically via built-in Access History tracking (365 days retention). Captures query and mutation logs without managing pipeline configurations.
* **Operational Data Governance:** Handled completely via standard 90-day Time Travel retention boundaries, covering the operational lifecycle of orders and shipments flawlessly.

---

## Architecture Step 2: Dynamic Tables & Refresh Modes

### The 4 Pre-Aggregated Analytical Dynamic Engines
1. **DT_DELIVERY_PERF:** Blends SHIPMENTS, SUPPLIERS, and PLANTS. Materializes OTD%, lead time metrics, and supplier late counts.
2. **DT_ORDER_FULFILLMENT:** Blends ORDERS, ORDER_LINES, INVENTORY, CUSTOMERS, and PLANTS. Exposes base fill rate patterns and raw coverage timelines.
3. **DT_INVENTORY_POSITION:** Integrates INVENTORY, PARTS, PLANTS, and ORDER_LINES. Exposes Days of Inventory (DOI), and highlights active reorder flags.
4. **DT_LANDED_COST:** Merges SHIPMENTS, SHIPMENT_LINES, PARTS, SUPPLIERS, and PLANTS. Resolves total cost (Material + Freight share + Duty estimations).

### Crucial Design Decision: Refresh Mode Optimization
* **The Trap:** Pushing time-dependent code like `CURRENT_DATE()` directly inside internal dynamic table definitions blocks `INCREMENTAL` refresh logic, defaulting to a heavy `FULL` refresh layout that prevents downstream stream deployment.
* **The Solution:** Extract time-dependent calculations out of the dynamic layer entirely. Standardize on `REFRESH_MODE = INCREMENTAL` with a 1-hour target lag constraint across all 4 dynamic engines.
* Live risk scoring calculations push up into an adjacent view layer (`V_ORDER_FULFILLMENT`). Rows evaluate on-the-fly at query time while the underlying tables refresh incrementally and support downstream change tracking streams.

---

## End-to-End Data Flow Diagram

```
[ DATA LAYER: 10 Base Tables ]
  (Suppliers, Parts, Plants, Customers, Inventory, Shipments, Orders, Alerts)
           │
           ▼
[ PIPELINE LAYER ]
  ├── 4 Incremental Dynamic Tables (1-Hour Lag: Perf, Position, Landed Cost, Fulfillment)
  ├── Live View Layer (V_ORDER_FULFILLMENT: Real-Time Multi-Factor Risk Scoring Engine)
  ├── 3 CDC Target Streams (STREAM_SHIPMENTS, STREAM_INVENTORY, STREAM_ORDER_RISK)
  └── 3 Scheduled Operational Alert Tasks (5-Min Stream Data Polling)
           │
           ▼
[ GOVERNANCE & SEMANTIC LAYER ]
  └── SUPPLY_CHAIN_ONTOLOGY (868-Line YAML definition / SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML)
           │
           ▼
[ ORCHESTRATION & AGENT LAYER ]
  └── SUPPLY_CHAIN_AGENT (Primary Orchestrator Router)
        ├── PROCUREMENT_AGENT (Sourcing, Cost, Reorders + 3 Custom Tools)
        ├── PLANNING_AGENT (ML Demand Forecasting, Inventory Health)
        └── LOGISTICS_AGENT (Transit Tracking, Remediation + 2 Custom Tools)
           │
           ▼
[ INTEGRATION & MCPS SURFACE ]
  └── Atlassian Jira Scrum Tickets  │  Gmail System Automation  │  Slack Channel Alerts
```

---

## View Architecture: Live Multi-Factor Risk Scoring Engine

### V_ORDER_FULFILLMENT Layer: Building the Composite 0-12 Risk Metric Matrix
* **Factor 1: Stock Coverage Days** ➔ Score 0 if >14 days | Score 1 if 7-14 days | Score 2 if 3-7 days | Score 3 if <3 days.
* **Factor 2: Fulfillment Ratio** ➔ Score 0 if ≥90% | Score 1 if 50-89% | Score 2 if 1-49% | Score 3 if 0%.
* **Factor 3: Inbound Shipment Transit Health** ➔ Score 0 if Early/On-Time | Score 1 if On-Schedule In-Transit | Score 2 if Late 1-3 days | Score 3 if Late 4+ days or missing upstream links.
* **Factor 4: Urgency Timeline** ➔ Score 0 if >14 days remaining | Score 1 if 7-14 days | Score 2 if 3-7 days | Score 3 if <3 days or past due status.

### Risk Level Classifications & Action Threshold Triggers
* **LOW RISK (Total Score 0-2):** Order execution tracks completely on schedule. Normal continuous tracking, no flags.
* **MEDIUM RISK (Total Score 3-5):** Early exception warning patterns detected. System registers warning flags and updates monitoring dashboard logs.
* **HIGH RISK (Total Score 6-8):** Delayed order resolution highly probable. Triggers manual validation request and flags immediate remediation path.
* **CRITICAL RISK (Total Score 9-12):** Material stockout certain without intervention. Triggers downstream multi-step task loops and automates alerting vectors.

---

## Architecture Step 3: Minimalist Event-Driven Alert Pipeline

### Operational Stream Strategy (Reduced from 9 Streams down to 3 Target Streams)
* **STREAM_SHIPMENTS (Deployed on SHIPMENTS):** Watches operational logistics changes; isolates route delays or carrier adjustments.
* **STREAM_INVENTORY (Deployed on INVENTORY):** Catches material drawdowns; fires instantly when stock levels breach localized safety bounds.
* **STREAM_ORDER_RISK (Deployed on DT_ORDER_FULFILLMENT):** Captures algorithmic calculations; logs changes when an order flips to High or Critical.

### Targeted Automation Task Strategy (3 Dedicated Operational Action Components)
* **TASK_SHIPMENT_DELAY_ALERT:** Consumes STREAM_SHIPMENTS data. Polls every 5 minutes using `SYSTEM$STREAM_HAS_DATA`. Pushes immediate exception summaries directly to Slack channel vectors and triggers the automated shipment expedite workflow.
* **TASK_INVENTORY_LOW_ALERT:** Consumes STREAM_INVENTORY data. Evaluates part constraints against reorder points and automatically signals the procurement agent to initialize material sourcing analysis playbooks.
* **TASK_ORDER_RISK_ALERT:** Consumes STREAM_ORDER_RISK records. Inspects live views to extract high-risk scores and inserts structured exceptions into SUPPLY_CHAIN_ALERTS to link downstream Jira tickets.

---

## The Governance Backbone: SUPPLY_CHAIN_ONTOLOGY

### Structural Integration: 11 Entities, 8 Strategic Relationships, and 4 Canonical Metrics
* **Metric 1: On-Time Delivery % (OTD%)** ➔ Formula: `SUM(on_time_count) * 100.0 / NULLIF(SUM(total_shipments), 0)` | Source: DT_DELIVERY_PERF
* **Metric 2: Fill Rate %** ➔ Formula: `SUM(fulfilled_quantity) / SUM(ordered_quantity) * 100.0` | Source: DT_ORDER_FULFILLMENT
* **Metric 3: Days of Inventory (DOI)** ➔ Formula: `on_hand_quantity / daily_demand_calculation` | Source: DT_INVENTORY_POSITION
* **Metric 4: Landed Cost per Unit** ➔ Formula: `material_cost_base + freight_allocation + estimated_duty_charges` | Source: DT_LANDED_COST

### Implementation Pattern: SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML (868 Lines)
* **Single Definition Lock:** Canonical metrics are compiled directly within the semantic layer framework. No client application or sub-agent can override calculation code dynamically.
* **Logical Routing Engine:** Translates standard text inputs directly into query constraints. Point queries for past data target structural base tables, while complex analytics route to dynamic tables.
* **Abstracted Business Vocabulary:** Completely strips out cryptic database column syntax. Translates underlying physical names into plain business concepts like 'Carrier Performance' or 'Landed Overheads'.

---

## Semantic Guardrails: 14 Verified Query Records (VQRs)

### Pre-Validated Question-to-SQL Mappings to Prevent Silent Calculation Hallucinations
* **Core Metric Group (1-4):** Explicit templates tracking supplier OTD lookups, plant fill rate percentages, precise double-filtering for part-plant DOI evaluations, and 3-component total landed cost math calculations.
* **Threshold Trigger Group (5-8):** Mappings protecting intent phrases like 'at risk orders' (maps to High/Critical states), 'parts needing reorder' (maps to reorder_point bounds), and complex mathematical filters like DOI values dropped below 3 days.
* **Time-Series Horizon Group (9-10):** Pre-built monthly grouping aggregations protecting trend timelines across moving multi-month horizons for both supplier delivery history and plant fulfillment lines.
* **Cross-Domain Group (11-14):** Validated schemas managing complex multi-table joins. Enforces exact join conditions for mixed questions like comparing supplier costs against delivery metrics, or matching late shipments to open orders.

### Cortex Analyst Resolution Priority Hierarchy
1. **Priority 1 ➔ Exact VQR Structure Match:** Emits pre-validated, hand-shake SQL code with absolute mathematical precision.
2. **Priority 2 ➔ Dynamic Semantic View Synthesis:** Generates dynamic SQL logic using defined dimensions, measures, and entity relationships.
3. **Priority 3 ➔ Out-of-Scope Safe Refusal:** If requests stray outside semantic boundaries, the engine returns a clean notification rather than inventing text.

---

## Multi-Agent Orchestration Architecture

```
                       [ USER QUERY INTERFACE ]
                                  │
                                  ▼
                     [ SUPPLY_CHAIN_AGENT ROUTER ]
                     (Central Orchestrator Mesh)
            ┌─────────────────────┼─────────────────────┐
            │                     │                     │
            ▼                     ▼                     ▼
    [ PROCUREMENT ]          [ PLANNING ]          [ LOGISTICS ]
    PROCUREMENT_AGENT       PLANNING_AGENT        LOGISTICS_AGENT
    ├── 3 Reusable Skills   ├── 2 Reusable Skills ├── 1 Reusable Skill
    ├── 3 Write Tools       └── Cortex Analyst    └── 2 Write Tools
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                                  │ (MCP Integrations)
                                  ▼
                   ┌──────────────┴──────────────┐
                   ▼                             ▼
           [ ATLASSIAN JIRA ]            [ SLACK CHANNEL ]
           Creates SCUM Tickets          Automated Stream Alerts
```

### Specialized Inter-Agent Handoff Scenarios
* **Logistics to Procurement Transition:** When a shipment risk assessment isolates an underlying stock shortage rather than an expected transit delay, the Logistics sub-agent hands off tracking data directly to the Procurement reorder workflow.
* **Procurement to Planning Transition:** When bulk reorder evaluations require forward-looking projections, the Procurement agent queries the Planning sub-agent to fetch ML demand forecast intervals.

---

## Domain-Specific Sub-Agents & Capability Profile

### 💳 PROCUREMENT_AGENT (Sourcing & Financial Guardrails)
Owns 3 specialized skills (`supplier_scorecard`, `cost_analyzer`, `reorder_advisor`) and executes 3 database write procedures (`GENERATE_SCORECARD`, `CREATE_PURCHASE_ORDER`, `UPDATE_SUPPLIER_RATING`). Tracks cost optimization metrics, validates supplier capacities, and routes directly to Jira, Gmail, and Slack systems.

### 📉 PLANNING_AGENT (Demand Forecasting & Inventory Optimization)
Analytics-focused specialist. Contains zero database write permissions. Evaluates inventory parameters using 2 core skills (`demand_planner`, `reorder_advisor`). Connects directly to Cortex Analyst and interacts externally via Slack channel connections.

### 📦 LOGISTICS_AGENT (In-Transit Tracking & Operational Remediation)
Logistics remediation engine. Tracks transport routes via the `shipment_tracker` skill. Calls 2 write-back procedures (`TRIGGER_EXPEDITE`, `UPDATE_ALERT_JIRA`) to update records, initialize tracking tickets via Jira, and send Slack notifications.

---

## Modular Architecture: Reusable Stage-Hosted Skills

### Declarative Playbook Strategy (Markdown Files Hosted Globally on SKILL_STAGE)
* **supplier_scorecard:** Instructs agents to evaluate vendor delivery histories. Pulls composite data structures from UDF, automatically ranks candidate vendors, and flags poor performers (score < 6.0 or OTD < 80%).
* **cost_analyzer:** Breaks unit costs into raw material, freight allocations, and destination country duties. Cross-references quality data to map a clear value-metric matrix. Rejects recommendations based on cost alone where hidden freight negates material discounts.
* **demand_planner:** Manages forecasting engine calls. Pulls statistics from the multi-series Snowflake ML model, extracts trend angles, detects seasonality, and implements strict training data anomaly filters (outlier caps at 5x median).
* **reorder_advisor:** Scans stock gaps, queries demand predictions, reviews vendor options, evaluates budget constraints, and compiles editable purchase order proposals. Enforces a $50K cap per PO.
* **shipment_tracker:** Monitors global logistics execution. Classifies moving shipments into 4 risk tiers, models delays using carrier history, and drives the system expedite pipeline for critical transit failures.

---

## Custom Tools & Writing Logic with Guardrails

### The 5 Stored Procedures & UDF Components
* **GENERATE_SCORECARD (UDF):** Read-only logic block. Computes a multi-factor vendor score (40% On-Time Delivery performance, 30% item quality rating, 30% landed cost positioning).
* **CREATE_PURCHASE_ORDER (Stored Procedure):** Validates part registries, checks vendor limits, runs quantity checks, enforces budget limits ($50K cap), and logs new orders into physical data rows.
* **TRIGGER_EXPEDITE (Stored Procedure):** Unified logistics tool. Modifies transport priority codes, populates tracking timestamps, logs alerts, enforces a 48-hour duplicate block and a 3-escalation limit constraint.
* **UPDATE_SUPPLIER_RATING (Stored Procedure):** Adjusts vendor tiers. Implements strict bounds (max 1-tier adjustment per execution) and logs manual overrides with text tracking fields.
* **UPDATE_ALERT_JIRA (Stored Procedure):** Database-to-ticket mapper. Matches fresh engineering issue keys back to active exceptions in SUPPLY_CHAIN_ALERTS to maintain complete lifecycle tracking.

---

## Deep Dive: End-to-End Transit Expedite Workflow Execution Mechanics

* **Step 1: System Identification** ➔ The agent runs the shipment_tracker skill to flag transport delays and isolate order risk impacts.
* **Step 2: Guardrail Evaluation** ➔ Validates record states, enforces a 48-hour duplicate block, and checks the 3-escalation limit constraint.
* **Step 3: Interface Confirmation** ➔ Presents the entire operational proposal to the user, blocking execution until receiving explicit approval.
* **Step 4: Database Update** ➔ Executes the stored procedure to update row priorities and log active rows into the internal exceptions database.
* **Step 5: Jira Issue Projection** ➔ Calls ATLASSIAN_MCP to construct an engineering tracking issue and routes it based on issue type.
* **Step 6: Real-Time Team Alerting** ➔ Links tracking metrics across Slack channels and auto-closes tickets when material deliveries are logged.

---

## Role-Based Access Control & Column Masking Matrix

### Security Split Design Choice: Base Masking over Fragmented Views
* **Rejected Security Design:** Constructing hundreds of individual role-specific views (e.g., 3 separate filtered views per table) to split user access boundaries, creating massive object overhead (~39 extra views).
* **Selected Security Design:** Standardize on 5 native column masking policies deployed directly onto physical base tables and analytical dynamic engines. The semantic model maps to the same central database for all users, maintaining consistency.

### The 5 Engine-Level Masking Policies & Persona Boundaries
* **COST_DATA_MASK:** Masks unit pricing, freight metrics, and landed costs. Restricts Planning and Logistics roles while granting full access to Procurement.
* **SUPPLIER_DETAIL_MASK:** Limits vendor health profiles and carrier details. Restricts the Planning analyst while allowing visibility for Procurement and Logistics.
* **CUSTOMER_DATA_MASK:** Protects client registries and geographic segments. Isolates the Planning analyst while masking data for Procurement and Logistics.
* **SAFETY_STOCK_MASK:** Protects buffer values. Restricts Procurement and Logistics roles while allowing visibility for Planning analysts.
* **REORDER_POINT_MASK:** Restricts access to reorder thresholds. Grants access to Procurement and Planning roles while masking data for Logistics coordinators.
* *Infrastructure Override Exemption:* The infrastructure role (`SC_AGENT_ROLE`) bypasses masking constraints to process multi-domain lookup queries safely without mutating row structures.

---

## CoCo Workspace Life-Cycle Milestones & Verification

* **1. Planning Phase Milestones:** Explored global supply chain behavior patterns inside CoCo workspaces. Drafted structural block-flows, mapped operational entities, and designed a 10-phase layout plan. Generated a comprehensive 2,100+ line architecture document.
* **2. Development Phase Milestones:** Compiled all 44 distinct system files through the CoCo engine interface. Generated 565+ rows of referentially consistent synthetic data to accelerate development testing. Configured the 868-line semantic view and built a persona-aware Streamlit interface.
* **3. Execution Phase Milestones:** Deployed 52 data layer objects down to active cloud instances via the CoCo CLI. Set up 3 scheduled cron tasks (Logistics at 7:30 AM, Planning at 8:00 AM, Procurement at 8:30 AM IST) using cortex automation commands to distribute daily updates via Slack and Gmail.
* **4. Testing & Validation Phase Milestones:** Executed functional unit-testing sweeps across different profiles. Verified metric consistency (ensuring OTD targets resolve exactly to 50.0% globally), tested security masking bounds, checked procedural validation logic, and resolved app parsing bugs.

---

## Live Execution Surfaces & Business Impact

### Production Interfaces & MCP Connections
* **Streamlit Application Layer:** Multi-view architecture deployed to SiS. Automatically detects active roles via `CURRENT_ROLE()`, loads persona-specific dashboards, and embeds natural language chat blocks at the bottom of every page.
* **Staggered Automated Briefs:** Automations execute sequentially on weekdays. Logistics feeds Planning, which feeds Procurement to provide highly contextual updates.
* **Model Context Protocol (MCP) Connectors:** Implements 3 external integration channels: ATLASSIAN_MCP for ticket management, GMAIL for scheduled summary delivery, and SLACK_MCP for continuous team channels.

### Measurable Architectural Value Metrics
* **100% Metric Calculation Alignment:** Strips out data calculation fragmentation across teams; every persona shares a single source of truth.
* **Sub-Minute Time to Strategic Insight:** Drastically cuts data lookups down from 30 to 60 minutes of manual gathering to instant answers.
* **Instant Turnaround Remediation:** Reduces operational resolution latency to a single step by nesting workflows within the conversational interface.
* **Scalable Enterprise Blueprint:** Adding new metrics or operational integrations is entirely modular. Update semantic configurations or connect additional MCP servers without re-writing basic code links.