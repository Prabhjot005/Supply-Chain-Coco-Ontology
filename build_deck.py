"""Build hackathon submission deck from template."""
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from copy import deepcopy
import io

TEMPLATE = r'C:\Users\prabhjot.kaur\Downloads\Prototype Submission Template _ CoCo CLI Hackathon GCC Edition.pptx'
OUTPUT = r'C:\Users\prabhjot.kaur\IdeaProjects\personal\CoCo Supply Chain\hackathon_submission.pptx'

WHITE = RGBColor(0xFF, 0xFF, 0xFF)
CYAN = RGBColor(0x29, 0xB5, 0xE8)
LIGHT_GRAY = RGBColor(0xCC, 0xCC, 0xCC)
DARK_BG = RGBColor(0x1A, 0x1A, 0x2E)
ACCENT = RGBColor(0x00, 0xD4, 0xFF)
GREEN = RGBColor(0x4E, 0xC9, 0xB0)
YELLOW = RGBColor(0xFF, 0xD7, 0x00)
ORANGE = RGBColor(0xFF, 0xA5, 0x00)

prs = Presentation(TEMPLATE)

# Extract the background image bytes from slide 3 (content slide template)
bg_image_bytes = None
for shape in prs.slides[2].shapes:
    if shape.shape_type == 13:  # PICTURE
        bg_image_bytes = shape.image.blob
        bg_content_type = shape.image.content_type
        bg_width = shape.width
        bg_height = shape.height
        break

def add_content_slide():
    """Add a new slide with the branded background."""
    slide_layout = prs.slide_layouts[0]  # BLANK
    slide = prs.slides.add_slide(slide_layout)
    if bg_image_bytes:
        slide.shapes.add_picture(io.BytesIO(bg_image_bytes), 0, 0, bg_width, bg_height)
    return slide

def add_title(slide, text, top=Inches(0.25), left=Inches(0.4), width=Inches(8.8), font_size=28):
    txBox = slide.shapes.add_textbox(left, top, width, Inches(0.6))
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(font_size)
    p.font.color.rgb = CYAN
    p.font.bold = True
    return txBox

def add_subtitle(slide, text, top=Inches(0.75), left=Inches(0.4)):
    txBox = slide.shapes.add_textbox(left, top, Inches(8.8), Inches(0.4))
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(14)
    p.font.color.rgb = LIGHT_GRAY
    p.font.italic = True

def add_body(slide, lines, top=Inches(1.2), left=Inches(0.5), width=Inches(8.6), font_size=12, line_spacing=1.3):
    txBox = slide.shapes.add_textbox(left, top, width, Inches(3.5))
    tf = txBox.text_frame
    tf.word_wrap = True
    for i, (text, level, color, bold, size_override) in enumerate(lines):
        if i == 0:
            p = tf.paragraphs[0]
        else:
            p = tf.add_paragraph()
        p.text = text
        p.font.size = Pt(size_override if size_override else font_size)
        p.font.color.rgb = color if color else WHITE
        p.font.bold = bold
        p.level = level
        p.space_after = Pt(2)
        p.line_spacing = Pt(font_size * line_spacing)
    return txBox

def bullet(text, level=0, color=None, bold=False, size=None):
    return (text, level, color, bold, size)

# ============================================================
# SLIDE 1: TITLE (update existing text boxes)
# ============================================================
slide1 = prs.slides[0]
for shape in slide1.shapes:
    if hasattr(shape, 'text'):
        if 'Team Name' in shape.text:
            shape.text_frame.paragraphs[0].text = "Team Name : Prabhjot Kaur"
            shape.text_frame.paragraphs[0].font.size = Pt(16)
            shape.text_frame.paragraphs[0].font.color.rgb = WHITE
            shape.text_frame.paragraphs[0].font.bold = True
        elif 'Team Leader' in shape.text:
            shape.text_frame.paragraphs[0].text = "Team Leader Name : Prabhjot Kaur"
            shape.text_frame.paragraphs[0].font.size = Pt(16)
            shape.text_frame.paragraphs[0].font.color.rgb = WHITE
            shape.text_frame.paragraphs[0].font.bold = True
        elif 'Team Size' in shape.text:
            shape.text_frame.paragraphs[0].text = "Team Size : 1 (Solo)"
            shape.text_frame.paragraphs[0].font.size = Pt(16)
            shape.text_frame.paragraphs[0].font.color.rgb = WHITE
            shape.text_frame.paragraphs[0].font.bold = True
        elif 'Problem Statement' in shape.text:
            shape.text_frame.paragraphs[0].text = "Problem Statement : Supply Chain Ontology & Governed Conversational Analytics"
            shape.text_frame.paragraphs[0].font.size = Pt(14)
            shape.text_frame.paragraphs[0].font.color.rgb = WHITE
            shape.text_frame.paragraphs[0].font.bold = True

# ============================================================
# SLIDE 2: PROBLEM BRIEF (replace guidelines text)
# ============================================================
slide2 = prs.slides[1]
for shape in slide2.shapes:
    if hasattr(shape, 'text') and 'Submission Guidelines' in shape.text:
        tf = shape.text_frame
        tf.clear()
        # Title
        p = tf.paragraphs[0]
        p.text = "Problem Brief"
        p.font.size = Pt(26)
        p.font.color.rgb = CYAN
        p.font.bold = True
        p.space_after = Pt(8)

        lines = [
            ("THE BUSINESS PROBLEM", WHITE, True, 14),
            ("Supply chain teams — procurement, planning, logistics — each query the same data but define metrics differently. OTD%, fill rate, DOI, and landed cost get calculated inconsistently across spreadsheets, BI tools, and ad-hoc SQL. This leads to conflicting reports, slow decisions, and zero trust in the numbers.", WHITE, False, 11),
            ("", WHITE, False, 8),
            ("TARGET PERSONAS", CYAN, True, 14),
            ("• Procurement Manager — needs supplier scorecards, cost trends, reorder decisions", WHITE, False, 11),
            ("• Planning Analyst — needs inventory health, demand forecasts, fulfillment risk", WHITE, False, 11),
            ("• Logistics Coordinator — needs shipment tracking, delay detection, expedite actions", WHITE, False, 11),
            ("", WHITE, False, 8),
            ("THE PAIN POINT", WHITE, True, 14),
            ("Each persona manually pulls data, applies their own metric formulas, and reconciles with other teams. An OTD% from logistics doesn't match procurement's version. No governed single source of truth exists.", WHITE, False, 11),
            ("", WHITE, False, 8),
            ("OUR SOLUTION", GREEN, True, 14),
            ("A governed semantic ontology on Snowflake with CoCo-built agents that enforce canonical metric definitions across all personas. Natural language queries return consistent, trustworthy answers — and agents can ACT (create POs, expedite shipments, file Jira tickets, send emails) with full guardrails.", WHITE, False, 11),
        ]
        for text, color, bold, size in lines:
            p2 = tf.add_paragraph()
            p2.text = text
            p2.font.size = Pt(size)
            p2.font.color.rgb = color
            p2.font.bold = bold
            p2.space_after = Pt(1)

# ============================================================
# SLIDE 3: SOLUTION OVERVIEW (use existing slide 3)
# ============================================================
slide3 = prs.slides[2]
add_title(slide3, "Solution Overview")
add_subtitle(slide3, "End-to-end governed conversational analytics on Snowflake, built entirely with CoCo")
add_body(slide3, [
    bullet("WHAT WE BUILT", color=CYAN, bold=True, size=14),
    bullet(""),
    bullet("Data Layer          10 base tables, 565+ rows of synthetic supply chain data", size=11),
    bullet("Pipeline Layer      4 INCREMENTAL Dynamic Tables + 1 risk-scoring View", size=11),
    bullet("Semantic Layer      Semantic View with 4 canonical metrics (OTD%, Fill Rate%, DOI, Landed Cost)", size=11),
    bullet("Agent Layer         4 Cortex Agents (1 primary router + 3 domain specialists)", size=11),
    bullet("Skills Layer        5 reusable SKILL.md files on internal stage", size=11),
    bullet("Custom Tools        5 SPs/UDFs (scorecard, PO creation, expedite, rating, alert-jira link)", size=11),
    bullet("MCP Integration     Atlassian Jira (ticket creation) + Gmail (email delivery)", size=11),
    bullet("Automations         3 CoCo scheduled daily briefs with Gmail MCP", size=11),
    bullet("Streamlit App       Real-time supply chain dashboard deployed on Snowflake", size=11),
    bullet("Governance          Column masking policies, 5-role RBAC, agent guardrails", size=11),
    bullet(""),
    bullet("TOTAL: 52+ Snowflake objects deployed", color=GREEN, bold=True, size=13),
], top=Inches(1.0))

# ============================================================
# SLIDE 4: ARCHITECTURE DIAGRAM (use existing slide 4)
# ============================================================
slide4 = prs.slides[3]
add_title(slide4, "Architecture Diagram")
add_subtitle(slide4, "Data flow from source tables through governed semantic layer to multi-agent conversational interface")

arch_text = """
┌─────────────────────────────────────────────────────────────────────────┐
│  DATA SOURCES (10 Tables)                                              │
│  Suppliers │ Parts │ Plants │ Customers │ Inventory                    │
│  Shipments │ Shipment_Lines │ Orders │ Order_Lines │ Alerts            │
└────────────────────────────┬────────────────────────────────────────────┘
                             │  INCREMENTAL Refresh
┌────────────────────────────▼────────────────────────────────────────────┐
│  DYNAMIC TABLES (Pipeline Layer)                                       │
│  DT_Delivery_Perf │ DT_Inventory_Position │ DT_Landed_Cost            │
│  DT_Order_Fulfillment ──► V_Order_Fulfillment (risk scoring view)     │
└────────────────────────────┬────────────────────────────────────────────┘
                             │  Stream + Task (triggered alerts)
┌────────────────────────────▼────────────────────────────────────────────┐
│  SEMANTIC VIEW  (SUPPLY_CHAIN_ONTOLOGY)                                │
│  Canonical Metrics: OTD% │ Fill Rate% │ DOI │ Landed Cost             │
│  + Verified Queries for each persona                                   │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────────┐
│  CORTEX AGENTS (Multi-Agent)                 ┌─────────────────────┐   │
│  SUPPLY_CHAIN_AGENT (Router)  ◄──────────────┤ MCP: Jira + Gmail   │   │
│    ├── PROCUREMENT_AGENT + 3 skills          └─────────────────────┘   │
│    ├── PLANNING_AGENT + 2 skills                                       │
│    └── LOGISTICS_AGENT + 1 skill + expedite tools                     │
└────────────────────────────┬────────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────────┐
│  SURFACES: Snowsight Cloud Agents │ Streamlit Dashboard │ CoCo CLI    │
│  CoCo Automations (3 daily briefs, weekday schedule, Gmail delivery)  │
└─────────────────────────────────────────────────────────────────────────┘
"""

txBox = slide4.shapes.add_textbox(Inches(0.2), Inches(0.95), Inches(9.2), Inches(3.7))
tf = txBox.text_frame
tf.word_wrap = True
p = tf.paragraphs[0]
p.text = arch_text.strip()
p.font.size = Pt(7)
p.font.color.rgb = WHITE
p.font.name = "Consolas"

# ============================================================
# SLIDE 5: DATA FOUNDATION & PIPELINES
# ============================================================
slide5 = prs.slides[4]
# Remove "Additional Slide" text
for shape in list(slide5.shapes):
    if hasattr(shape, 'text') and 'Additional Slide' in shape.text:
        shape.text_frame.clear()
        shape.text_frame.paragraphs[0].text = ""

add_title(slide5, "Data Foundation & Pipeline Creation")
add_subtitle(slide5, "Synthetic data generation + INCREMENTAL Dynamic Tables + Stream-triggered alerts")
add_body(slide5, [
    bullet("SYNTHETIC DATA GENERATION (built entirely with CoCo)", color=CYAN, bold=True, size=13),
    bullet("• 565+ rows across 10 referentially consistent tables", size=11),
    bullet("• 25 suppliers (15 countries), 30 parts (12 categories), 10 plants (8 countries)", size=11),
    bullet("• 80 shipments spanning Jul-Oct 2026 with realistic carrier/freight data", size=11),
    bullet("• 80 orders, 150 order lines with partial fulfillment for risk scenarios", size=11),
    bullet("• Historical data for ML FORECAST model training (DEMAND_FORECAST_MODEL)", size=11),
    bullet(""),
    bullet("INCREMENTAL DYNAMIC TABLES", color=CYAN, bold=True, size=13),
    bullet("• 4 DTs with explicit REFRESH_MODE = INCREMENTAL (not FULL)", size=11),
    bullet("• Challenge: CURRENT_DATE() blocks incremental refresh", size=11),
    bullet("• Solution: DT stores raw data, V_ORDER_FULFILLMENT view computes risk scores at query time", size=11),
    bullet("• Stream on DT_ORDER_FULFILLMENT triggers TASK_ORDER_RISK_ALERT for real-time monitoring", size=11),
    bullet(""),
    bullet("PIPELINE: Tables → DTs (incremental) → View (live risk) → Stream → Task → Alerts", color=GREEN, bold=True, size=11),
], top=Inches(1.0))

# ============================================================
# SLIDE 6: SEMANTIC ONTOLOGY
# ============================================================
slide6 = prs.slides[5]
add_title(slide6, "Semantic Model & Ontology Authoring")
add_subtitle(slide6, "Single source of truth: 4 canonical metrics enforced across all personas")
add_body(slide6, [
    bullet("SEMANTIC VIEW: SUPPLY_CHAIN_ONTOLOGY", color=CYAN, bold=True, size=13),
    bullet("• Built with CoCo using SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML", size=11),
    bullet("• References 4 Dynamic Tables + 1 View as logical tables", size=11),
    bullet("• Cortex Analyst generates SQL from natural language questions", size=11),
    bullet(""),
    bullet("4 CANONICAL METRICS (consistent across all personas)", color=CYAN, bold=True, size=13),
    bullet("  OTD%        = on_time_count / total_shipments × 100  (delivery performance)", size=11),
    bullet("  Fill Rate%  = fulfilled_qty / ordered_qty × 100  (order fulfillment)", size=11),
    bullet("  DOI         = on_hand_qty / avg_daily_demand  (inventory coverage)", size=11),
    bullet("  Landed Cost = material + freight_per_unit + duty_per_unit  (total cost)", size=11),
    bullet(""),
    bullet("VERIFIED QUERIES", color=CYAN, bold=True, size=13),
    bullet("• Pre-validated SQL for common questions per persona", size=11),
    bullet("• Verified at epoch timestamp for audit trail", size=11),
    bullet("• Agent always returns the same answer for the same question — no metric drift", size=11),
    bullet(""),
    bullet("Cross-persona consistency: Procurement, Planning, and Logistics see identical numbers", color=GREEN, bold=True, size=11),
], top=Inches(1.0))

# ============================================================
# SLIDE 7: MULTI-AGENT ORCHESTRATION
# ============================================================
slide7 = add_content_slide()
add_title(slide7, "Multi-Agent Orchestration")
add_subtitle(slide7, "4 Cortex Agents with intelligent routing, shared semantic view, and domain skills")
add_body(slide7, [
    bullet("AGENT ARCHITECTURE", color=CYAN, bold=True, size=13),
    bullet(""),
    bullet("SUPPLY_CHAIN_AGENT (Primary Router)", color=ACCENT, bold=True, size=12),
    bullet("  • Routes by domain: procurement → PROCUREMENT_TOOLS, planning → PLANNING_TOOLS,", size=10),
    bullet("    logistics → LOGISTICS_TOOLS (via agent_toolset references)", size=10),
    bullet("  • Direct access to all 5 custom tools + Cortex Analyst + data_to_chart", size=10),
    bullet("  • Both MCP servers (Jira + Gmail) for cross-cutting actions", size=10),
    bullet(""),
    bullet("PROCUREMENT_AGENT", color=ACCENT, bold=True, size=12),
    bullet("  Skills: supplier_scorecard, cost_analyzer, reorder_advisor", size=10),
    bullet("  Tools: GENERATE_SCORECARD, CREATE_PURCHASE_ORDER, UPDATE_SUPPLIER_RATING", size=10),
    bullet(""),
    bullet("PLANNING_AGENT", color=ACCENT, bold=True, size=12),
    bullet("  Skills: demand_planner, reorder_advisor    Tools: Cortex Analyst only", size=10),
    bullet(""),
    bullet("LOGISTICS_AGENT", color=ACCENT, bold=True, size=12),
    bullet("  Skills: shipment_tracker    Tools: TRIGGER_EXPEDITE, UPDATE_ALERT_JIRA", size=10),
    bullet("  Workflow: Guardrails → DB write → Jira MCP → Link ticket → Confirm", size=10),
], top=Inches(1.0))

# ============================================================
# SLIDE 8: CUSTOM TOOLS & GUARDRAILS
# ============================================================
slide8 = add_content_slide()
add_title(slide8, "Custom Tools & Guardrails")
add_subtitle(slide8, "5 registered tools with input validation, confirmation gates, and governed write paths")
add_body(slide8, [
    bullet("CUSTOM TOOLS (type: generic + input_schema + execution_environment)", color=CYAN, bold=True, size=13),
    bullet(""),
    bullet("GENERATE_SCORECARD (UDF, read-only)", size=11),
    bullet("  Computes composite supplier score (0-10) from OTD, quality, cost", size=10),
    bullet("CREATE_PURCHASE_ORDER (SP, write)", size=11),
    bullet("  Validates part/supplier exist, generates PO-XXXX ID, inserts to PO table", size=10),
    bullet("UPDATE_SUPPLIER_RATING (SP, write)", size=11),
    bullet("  Max 1-tier change, requires reason, audit trail", size=10),
    bullet("TRIGGER_EXPEDITE (SP, write)", size=11),
    bullet("  48h duplicate check, 3x escalation cap, updates source + inserts alert", size=10),
    bullet("UPDATE_ALERT_JIRA (SP, write)", size=11),
    bullet("  Links real Jira ticket key (e.g. SCRUM-123) to alert after MCP call", size=10),
    bullet(""),
    bullet("GUARDRAIL CHAIN (every write action)", color=YELLOW, bold=True, size=13),
    bullet("  1. Input validation (type, existence, range)", size=11),
    bullet("  2. Business rule check (duplicates, caps, tier limits)", size=11),
    bullet("  3. User confirmation required (agent presents proposal first)", size=11),
    bullet("  4. Structured return message (SUCCESS/ERROR/GUARDRAIL prefix)", size=11),
    bullet("  5. If stale or insufficient data → agent discloses, does NOT guess", size=11),
], top=Inches(1.0))

# ============================================================
# SLIDE 9: MCP INTEGRATION
# ============================================================
slide9 = add_content_slide()
add_title(slide9, "MCP Connectors: Jira & Gmail")
add_subtitle(slide9, "Agents read from and act across external tools — not just text responses")
add_body(slide9, [
    bullet("ATLASSIAN MCP (SUPPLY_CHAIN_DB.SCM.ATLASSIAN_MCP)", color=CYAN, bold=True, size=13),
    bullet("• Connected to Jira project: SCRUM (os93152.atlassian.net)", size=11),
    bullet("• Agent creates real Jira tickets after expedites and PO creation", size=11),
    bullet("• Ticket key stored back in Snowflake via UPDATE_ALERT_JIRA SP", size=11),
    bullet(""),
    bullet("EXPEDITE WORKFLOW (end-to-end with MCP)", color=CYAN, bold=True, size=13),
    bullet("  User: \"Expedite shipment SH011\"", size=11),
    bullet("  1. Agent calls TRIGGER_EXPEDITE → guardrails pass → DB updated", size=11),
    bullet("  2. Agent calls ATLASSIAN_MCP → creates Jira ticket SCRUM-XXX", size=11),
    bullet("  3. Agent calls UPDATE_ALERT_JIRA(SH011, SCRUM-XXX) → links ticket", size=11),
    bullet("  4. Agent confirms: \"Expedited. Jira SCRUM-XXX created and linked.\"", size=11),
    bullet(""),
    bullet("GMAIL MCP (SUPPLY_CHAIN_DB.SCM.GMAIL)", color=CYAN, bold=True, size=13),
    bullet("• Attached to all 3 CoCo automations for daily brief email delivery", size=11),
    bullet("• Sends formatted reports to os93152@gmail.com each weekday morning", size=11),
    bullet("• Also available on SUPPLY_CHAIN_AGENT for ad-hoc email notifications", size=11),
    bullet(""),
    bullet("Clean separation: SPs handle guardrails + DB writes, Agents handle MCP calls", color=GREEN, bold=True, size=11),
], top=Inches(1.0))

# ============================================================
# SLIDE 10: AUTOMATIONS
# ============================================================
slide10 = add_content_slide()
add_title(slide10, "CoCo Automations & Scheduled Runs")
add_subtitle(slide10, "3 unattended daily briefs with Gmail delivery — the solution operates on autopilot")
add_body(slide10, [
    bullet("3 TEAM-BASED DAILY BRIEFS", color=CYAN, bold=True, size=13),
    bullet(""),
    bullet("LOGISTICS DAILY BRIEF — Weekdays 7:30 AM IST", color=ACCENT, bold=True, size=12),
    bullet("  Shipment status (ON_TRACK/AT_RISK/DELAYED), carrier OTD%, expedite tracker", size=10),
    bullet("  Order impact from delayed shipments, risk escalation", size=10),
    bullet(""),
    bullet("PLANNING DAILY BRIEF — Weekdays 8:00 AM IST", color=ACCENT, bold=True, size=12),
    bullet("  Inventory health (CRITICAL/WARNING/WATCH/HEALTHY), fulfillment status", size=10),
    bullet("  Demand vs stock gap analysis, forecast model staleness check", size=10),
    bullet(""),
    bullet("PROCUREMENT DAILY BRIEF — Weekdays 8:30 AM IST", color=ACCENT, bold=True, size=12),
    bullet("  Supplier scorecards, landed cost trends (7d vs 30d), reorder candidates", size=10),
    bullet("  Open procurement alerts, cost driver breakdown", size=10),
    bullet(""),
    bullet("DELIVERY & MONITORING", color=CYAN, bold=True, size=13),
    bullet("• Each brief sent via Gmail MCP to team inbox (--mcp SUPPLY_CHAIN_DB.SCM.GMAIL)", size=11),
    bullet("• Machine-parseable status line: LOGISTICS_DAILY_BRIEF_OK delayed=N ...", size=11),
    bullet("• Unattended: no clarifying questions, autonomous SQL + report generation", size=11),
    bullet("• Created via: cortex automation create --schedule \"weekdays at 7:30am\" --timezone Asia/Kolkata", size=10),
], top=Inches(1.0))

# ============================================================
# SLIDE 11: STREAMLIT + SKILLS
# ============================================================
slide11 = add_content_slide()
add_title(slide11, "Streamlit Dashboard & Reusable Skills")
add_subtitle(slide11, "Interactive monitoring app + 5 published skills for agent specialization")
add_body(slide11, [
    bullet("STREAMLIT DASHBOARD (deployed on Snowflake)", color=CYAN, bold=True, size=13),
    bullet("• 4 tabs: Executive Summary, Inventory, Logistics, Procurement", size=11),
    bullet("• Real-time data from V_ORDER_FULFILLMENT (live risk scores)", size=11),
    bullet("• Color-coded risk indicators, shipment classification, cost trends", size=11),
    bullet("• Dynamic filtering by plant, supplier, time range", size=11),
    bullet(""),
    bullet("5 REUSABLE SKILLS (YAML frontmatter, stage-hosted)", color=CYAN, bold=True, size=13),
    bullet(""),
    bullet("supplier_scorecard    → Evaluate and rank suppliers by composite score", size=11),
    bullet("cost_analyzer         → Break down landed cost drivers per supplier", size=11),
    bullet("reorder_advisor       → Identify reorder candidates and recommend suppliers", size=11),
    bullet("demand_planner        → Forecast demand using ML FORECAST model", size=11),
    bullet("shipment_tracker      → Classify shipments and detect delays", size=11),
    bullet(""),
    bullet("Each skill has YAML frontmatter (name, description) and is uploaded to", size=10),
    bullet("@SUPPLY_CHAIN_DB.SCM.SKILL_STAGE/skills/<name>/SKILL.md", size=10),
    bullet("Referenced in agent specs via: skills: [{name: X, source: {type: STAGE, path: ...}}]", size=10),
], top=Inches(1.0))

# ============================================================
# SLIDE 12: GOVERNANCE & RBAC
# ============================================================
slide12 = add_content_slide()
add_title(slide12, "Data Governance & RBAC")
add_subtitle(slide12, "Column masking, role hierarchy, and agent-safe access controls")
add_body(slide12, [
    bullet("5-ROLE HIERARCHY", color=CYAN, bold=True, size=13),
    bullet("  SUPPLY_CHAIN_ADMIN — full access, DDL, policy management", size=11),
    bullet("  SC_AGENT_ROLE — agent execution role, all tools and semantic view", size=11),
    bullet("  PROCUREMENT_ROLE — procurement agent + scorecard + PO tools", size=11),
    bullet("  PLANNING_ROLE — planning agent + forecast model", size=11),
    bullet("  LOGISTICS_ROLE — logistics agent + expedite tools", size=11),
    bullet(""),
    bullet("COLUMN MASKING POLICIES", color=CYAN, bold=True, size=13),
    bullet("• Sensitive columns (freight_cost, unit_cost, unit_price) masked by role", size=11),
    bullet("• CASE on CURRENT_ROLE() — ADMIN and AGENT roles see real values", size=11),
    bullet("• Domain roles see their own data, masked for others", size=11),
    bullet(""),
    bullet("AGENT GUARDRAILS (governed behavior)", color=CYAN, bold=True, size=13),
    bullet("• All write operations require user confirmation before execution", size=11),
    bullet("• Structured error returns: ERROR / GUARDRAIL_DUPLICATE / GUARDRAIL_ESCALATION", size=11),
    bullet("• Stale or insufficient data → agent discloses limitation, does not fabricate", size=11),
    bullet("• Budget limits: 60s timeout, 32K token cap per agent interaction", size=11),
    bullet("• tool_not_accessible: accept — graceful fallback when tools unavailable", size=11),
], top=Inches(1.0))

# ============================================================
# SLIDE 13: IMPACT & SCALABILITY
# ============================================================
slide13 = add_content_slide()
add_title(slide13, "Impact Statement")
add_subtitle(slide13, "Measurable outcomes, scalability, and real-world deployment path")
add_body(slide13, [
    bullet("MEASURABLE OUTCOMES", color=CYAN, bold=True, size=13),
    bullet("• Metric consistency: 100% — all 3 teams now use identical OTD%, Fill Rate%, DOI, Landed Cost", size=11),
    bullet("• Time to insight: Minutes (natural language) vs hours (manual SQL + spreadsheet reconciliation)", size=11),
    bullet("• Action latency: Expedite + Jira ticket + DB update in one conversation turn", size=11),
    bullet("• Report delivery: Automated daily briefs replace manual morning standup prep", size=11),
    bullet("• Governance coverage: Every write action has guardrails; no unvalidated data mutation", size=11),
    bullet(""),
    bullet("SCALABILITY", color=CYAN, bold=True, size=13),
    bullet("• Add new personas: Create a new sub-agent + skill, register as agent_toolset", size=11),
    bullet("• Add data sources: New tables feed into DTs automatically (INCREMENTAL refresh)", size=11),
    bullet("• Add metrics: Extend semantic view YAML — all agents pick up changes immediately", size=11),
    bullet("• Add integrations: Attach new MCP servers (Slack, ServiceNow, SAP) to agents", size=11),
    bullet(""),
    bullet("BEYOND THE DEMO", color=CYAN, bold=True, size=13),
    bullet("• Production: Replace synthetic data with real ERP/WMS feeds via Snowpipe", size=11),
    bullet("• Enterprise: Connect to SAP, Oracle, or NetSuite via MCP for live data", size=11),
    bullet("• Cross-surface: Same agents work in CoCo CLI, Snowsight, Desktop, and Slackbot", size=11),
], top=Inches(1.0))

# ============================================================
# SLIDE 14: OBJECT INVENTORY & CoCo FEATURES
# ============================================================
slide14 = add_content_slide()
add_title(slide14, "Solution Completeness: 52+ Objects Deployed")
add_subtitle(slide14, "Every CoCo capability demonstrated — from data generation to cross-tool action")

add_body(slide14, [
    bullet("SNOWFLAKE OBJECTS", color=CYAN, bold=True, size=13),
    bullet("  10 Base Tables          4 Dynamic Tables (INCREMENTAL)    1 View", size=10),
    bullet("  1 Semantic View         4 Cortex Agents                   5 Skills", size=10),
    bullet("  4 Stored Procedures     1 UDF                             3 Automations", size=10),
    bullet("  1 Stream + 1 Task       2 MCP Servers                     5 Roles", size=10),
    bullet("  3 Masking Policies      3 Stages                          1 Streamlit App", size=10),
    bullet("  1 ML FORECAST Model", size=10),
    bullet(""),
    bullet("CoCo FEATURES DEMONSTRATED", color=YELLOW, bold=True, size=13),
    bullet("  ✓  Synthetic data generation (565+ rows, referentially consistent)", size=11),
    bullet("  ✓  Data pipeline creation (INCREMENTAL DTs, streams, tasks)", size=11),
    bullet("  ✓  Semantic model & ontology authoring (verified queries, canonical metrics)", size=11),
    bullet("  ✓  Streamlit report generation (4-tab dashboard)", size=11),
    bullet("  ✓  MCP connectors (Jira + Gmail — read AND write actions)", size=11),
    bullet("  ✓  Reusable & shareable skills (5 skills with YAML frontmatter)", size=11),
    bullet("  ✓  Automations & scheduled runs (3 daily briefs, weekday cadence)", size=11),
    bullet("  ✓  Custom tools & function calling (5 SPs/UDFs with input schemas)", size=11),
    bullet("  ✓  Multi-agent orchestration (4 agents, agent_toolset routing)", size=11),
    bullet("  ✓  Guardrails & graceful fallback (48h dedup, escalation caps, disclosure)", size=11),
], top=Inches(1.0))

# ============================================================
# SLIDE 15: THANK YOU
# ============================================================
slide15 = add_content_slide()
add_title(slide15, "Thank You", top=Inches(1.5), font_size=36)
txBox = slide15.shapes.add_textbox(Inches(0.4), Inches(2.3), Inches(8.8), Inches(2.0))
tf = txBox.text_frame
tf.word_wrap = True

lines = [
    ("Supply Chain Ontology & Governed Conversational Analytics", CYAN, True, 18),
    ("", WHITE, False, 12),
    ("Built entirely with Snowflake CoCo CLI", WHITE, False, 16),
    ("", WHITE, False, 12),
    ("Prabhjot Kaur  •  Solo Team  •  GCC Edition", LIGHT_GRAY, False, 14),
    ("", WHITE, False, 12),
    ("52+ Snowflake objects  •  4 Cortex Agents  •  2 MCP Servers", GREEN, True, 14),
    ("5 Reusable Skills  •  3 Automations  •  1 Semantic Ontology", GREEN, True, 14),
]

for i, (text, color, bold, size) in enumerate(lines):
    if i == 0:
        p = tf.paragraphs[0]
    else:
        p = tf.add_paragraph()
    p.text = text
    p.font.size = Pt(size)
    p.font.color.rgb = color
    p.font.bold = bold
    p.alignment = PP_ALIGN.CENTER

# ============================================================
# SAVE
# ============================================================
prs.save(OUTPUT)
print(f"Saved to: {OUTPUT}")
print(f"Total slides: {len(prs.slides)}")
