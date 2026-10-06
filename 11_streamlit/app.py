"""
Supply Chain Analyst — Streamlit App
Persona-aware dashboards with NL query interface.
Deployed to SPCS (Snowpark Container Services) with public endpoint.
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import json
import os
from snowflake.snowpark import Session

# ============================================================
# SESSION & PERSONA SETUP
# ============================================================
@st.cache_resource
def get_session():
    if os.path.exists("/snowflake/session/token"):
        return Session.builder.configs({
            "account": os.environ["SNOWFLAKE_ACCOUNT"],
            "host": os.environ["SNOWFLAKE_HOST"],
            "authenticator": "oauth",
            "token": open("/snowflake/session/token").read(),
            "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
            "database": os.environ.get("SNOWFLAKE_DATABASE", "SUPPLY_CHAIN_DB"),
            "schema": os.environ.get("SNOWFLAKE_SCHEMA", "SCM"),
        }).create()
    else:
        from snowflake.snowpark.context import get_active_session
        return get_active_session()

session = get_session()

def detect_persona():
    role = session.sql("SELECT CURRENT_ROLE()").collect()[0][0]
    mapping = {
        'PROCUREMENT_ROLE': 'Procurement',
        'PLANNING_ROLE': 'Planning',
        'LOGISTICS_ROLE': 'Logistics',
        'SC_AGENT_ROLE': 'Admin',
        'SUPPLY_CHAIN_ADMIN': 'Admin',
        'ACCOUNTADMIN': 'Admin',
    }
    return mapping.get(role, 'Admin')

if 'persona' not in st.session_state:
    st.session_state.persona = detect_persona()
if 'chat_history' not in st.session_state:
    st.session_state.chat_history = []

# ============================================================
# HEADER
# ============================================================
col_title, col_persona = st.columns([3, 1])
with col_title:
    st.title("Supply Chain Analyst")
with col_persona:
    new_persona = st.selectbox(
        "Persona",
        ["Procurement", "Planning", "Logistics", "Admin"],
        index=["Procurement", "Planning", "Logistics", "Admin"].index(st.session_state.persona),
    )
    if new_persona != st.session_state.persona:
        st.session_state.persona = new_persona
        st.session_state.chat_history = []

persona = st.session_state.persona

# ============================================================
# DATA LOADING HELPERS
# ============================================================
@st.cache_data(ttl=300)
def load_delivery_perf():
    return session.sql("SELECT * FROM SUPPLY_CHAIN_DB.SCM.DT_DELIVERY_PERF").to_pandas()

@st.cache_data(ttl=300)
def load_order_fulfillment():
    return session.sql("SELECT * FROM SUPPLY_CHAIN_DB.SCM.V_ORDER_FULFILLMENT").to_pandas()

@st.cache_data(ttl=300)
def load_inventory_position():
    return session.sql("SELECT * FROM SUPPLY_CHAIN_DB.SCM.DT_INVENTORY_POSITION").to_pandas()

@st.cache_data(ttl=300)
def load_landed_cost():
    return session.sql("SELECT * FROM SUPPLY_CHAIN_DB.SCM.DT_LANDED_COST").to_pandas()

@st.cache_data(ttl=300)
def load_shipments():
    return session.sql("SELECT * FROM SUPPLY_CHAIN_DB.SCM.SHIPMENTS").to_pandas()

@st.cache_data(ttl=300)
def load_alerts():
    return session.sql("SELECT * FROM SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_ALERTS ORDER BY created_at DESC").to_pandas()

@st.cache_data(ttl=300)
def load_suppliers():
    return session.sql("SELECT * FROM SUPPLY_CHAIN_DB.SCM.SUPPLIERS").to_pandas()

# ============================================================
# SIDEBAR NAVIGATION
# ============================================================
page_map = {
    "Procurement": ["Overview", "Suppliers", "Costs", "Alerts"],
    "Planning": ["Overview", "Orders", "Inventory", "Demand", "Alerts"],
    "Logistics": ["Overview", "Shipments", "Orders", "Risk", "Alerts"],
    "Admin": ["Overview", "Suppliers", "Costs", "Orders", "Inventory", "Demand", "Shipments", "Risk", "Alerts"],
}

alerts_df = load_alerts()
open_alerts = len(alerts_df[alerts_df['STATUS'] == 'OPEN']) if len(alerts_df) > 0 else 0

pages = page_map.get(persona, page_map["Admin"])
sidebar_labels = [f"{p} ({open_alerts})" if p == "Alerts" and open_alerts > 0 else p for p in pages]

with st.sidebar:
    st.markdown(f"**Role:** {persona}")
    st.markdown(f"**Open Alerts:** {open_alerts}")
    selected_label = st.radio("Navigate", sidebar_labels, label_visibility="collapsed")
    selected_page = selected_label.split(" (")[0]  # strip alert count
    if st.button("Refresh Data"):
        st.cache_data.clear()
        st.rerun()

# ============================================================
# PAGE: OVERVIEW
# ============================================================
if selected_page == "Overview":
    col_h, col_r = st.columns([5, 1])
    col_h.header(f"{persona} Overview")
    if col_r.button("Refresh", key="refresh_overview"):
        st.cache_data.clear()
        st.rerun()

    if persona == "Procurement" or persona == "Admin":
        dp = load_delivery_perf()
        lc = load_landed_cost()
        suppliers = load_suppliers()

        c1, c2, c3, c4 = st.columns(4)
        otd = round(dp['ON_TIME_COUNT'].sum() * 100.0 / max(dp['TOTAL_SHIPMENTS'].sum(), 1), 1) if len(dp) > 0 else 0
        avg_landed = round(lc['LANDED_COST_PER_UNIT'].mean(), 2) if len(lc) > 0 else 0
        c1.metric("OTD %", f"{otd}%")
        c2.metric("Avg Landed Cost", f"${avg_landed}")
        c3.metric("Suppliers", len(suppliers))
        c4.metric("Open Alerts", open_alerts)

        if len(dp) > 0:
            fig = px.bar(dp, x='SUPPLIER_NAME', y='OTD_PERCENTAGE', color='CARRIER',
                        title='OTD% by Supplier & Carrier', barmode='group')
            st.plotly_chart(fig, use_container_width=True)

    elif persona == "Planning":
        of = load_order_fulfillment()
        ip = load_inventory_position()

        c1, c2, c3, c4 = st.columns(4)
        fill_rate = round(of['TOTAL_FULFILLED'].sum() * 100.0 / max(of['TOTAL_ORDERED'].sum(), 1), 1) if len(of) > 0 else 0
        avg_doi = round(ip[ip['DOI'] < 999]['DOI'].mean(), 1) if len(ip[ip['DOI'] < 999]) > 0 else 0
        reorder_count = len(ip[ip['REORDER_CANDIDATE'] == True]) if len(ip) > 0 else 0
        at_risk = len(of[of['RISK_LEVEL'].isin(['HIGH', 'CRITICAL'])]) if len(of) > 0 else 0
        c1.metric("Fill Rate %", f"{fill_rate}%")
        c2.metric("Avg DOI", f"{avg_doi} days")
        c3.metric("Reorder Needed", reorder_count)
        c4.metric("At-Risk Orders", at_risk)

        if len(of) > 0:
            fig = px.bar(of, x='PLANT_NAME', y='FULFILLMENT_RATIO', color='RISK_LEVEL',
                        title='Fill Rate & Risk by Plant',
                        color_discrete_map={'LOW': 'green', 'MEDIUM': 'orange', 'HIGH': 'red', 'CRITICAL': 'darkred'})
            st.plotly_chart(fig, use_container_width=True)

    elif persona == "Logistics":
        dp = load_delivery_perf()
        shipments = load_shipments()

        c1, c2, c3, c4 = st.columns(4)
        otd = round(dp['ON_TIME_COUNT'].sum() * 100.0 / max(dp['TOTAL_SHIPMENTS'].sum(), 1), 1) if len(dp) > 0 else 0
        in_transit = len(shipments[shipments['ACTUAL_DELIVERY'].isna()]) if len(shipments) > 0 else 0
        late = len(shipments[(shipments['ACTUAL_DELIVERY'].isna()) & (pd.to_datetime(shipments['EXPECTED_DELIVERY']) < pd.Timestamp.now())]) if len(shipments) > 0 else 0
        expedited = len(shipments[shipments['PRIORITY'] == 'EXPEDITED']) if len(shipments) > 0 else 0
        c1.metric("OTD %", f"{otd}%")
        c2.metric("In Transit", in_transit)
        c3.metric("Late", late)
        c4.metric("Expedited", expedited)

        if len(dp) > 0:
            fig = px.bar(dp, x='CARRIER', y='OTD_PERCENTAGE', title='OTD% by Carrier')
            st.plotly_chart(fig, use_container_width=True)

# ============================================================
# PAGE: SUPPLIERS (Procurement)
# ============================================================
elif selected_page == "Suppliers":
    col_h, col_r = st.columns([5, 1])
    col_h.header("Supplier Scorecard")
    if col_r.button("Refresh", key="refresh_suppliers"):
        st.cache_data.clear()
        st.rerun()
    dp = load_delivery_perf()
    suppliers = load_suppliers()

    if len(dp) > 0 and len(suppliers) > 0:
        merged = dp.groupby(['SUPPLIER_ID', 'SUPPLIER_NAME']).agg({
            'TOTAL_SHIPMENTS': 'sum', 'ON_TIME_COUNT': 'sum', 'LATE_COUNT': 'sum',
            'AVG_LEAD_TIME_DAYS': 'mean'
        }).reset_index()
        merged['OTD_PCT'] = round(merged['ON_TIME_COUNT'] * 100.0 / merged['TOTAL_SHIPMENTS'].clip(lower=1), 1)
        merged = merged.merge(suppliers[['SUPPLIER_ID', 'QUALITY_RATING', 'COUNTRY']], on='SUPPLIER_ID', how='left')

        fig = px.scatter(merged, x='OTD_PCT', y='AVG_LEAD_TIME_DAYS', size='TOTAL_SHIPMENTS',
                        color='QUALITY_RATING', hover_name='SUPPLIER_NAME',
                        title='Supplier Performance: OTD vs Lead Time',
                        labels={'OTD_PCT': 'OTD %', 'AVG_LEAD_TIME_DAYS': 'Avg Lead Time (days)'})
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Supplier Detail")
        st.dataframe(merged.sort_values('OTD_PCT', ascending=False), use_container_width=True)

# ============================================================
# PAGE: COSTS (Procurement)
# ============================================================
elif selected_page == "Costs":
    col_h, col_r = st.columns([5, 1])
    col_h.header("Landed Cost Analysis")
    if col_r.button("Refresh", key="refresh_costs"):
        st.cache_data.clear()
        st.rerun()
    lc = load_landed_cost()

    if len(lc) > 0:
        avg_by_supplier = lc.groupby('SUPPLIER_NAME').agg({
            'MATERIAL_COST': 'mean', 'FREIGHT_PER_UNIT': 'mean',
            'DUTY_PER_UNIT': 'mean', 'LANDED_COST_PER_UNIT': 'mean'
        }).reset_index().round(2)

        fig = go.Figure()
        fig.add_trace(go.Bar(name='Material', x=avg_by_supplier['SUPPLIER_NAME'], y=avg_by_supplier['MATERIAL_COST']))
        fig.add_trace(go.Bar(name='Freight', x=avg_by_supplier['SUPPLIER_NAME'], y=avg_by_supplier['FREIGHT_PER_UNIT']))
        fig.add_trace(go.Bar(name='Duty', x=avg_by_supplier['SUPPLIER_NAME'], y=avg_by_supplier['DUTY_PER_UNIT']))
        fig.update_layout(barmode='stack', title='Landed Cost Breakdown by Supplier')
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Cost Detail")
        st.dataframe(avg_by_supplier.sort_values('LANDED_COST_PER_UNIT'), use_container_width=True)

# ============================================================
# PAGE: ORDERS
# ============================================================
elif selected_page == "Orders":
    col_h, col_r = st.columns([5, 1])
    col_h.header("Order Fulfillment & Risk")
    if col_r.button("Refresh", key="refresh_orders"):
        st.cache_data.clear()
        st.rerun()
    of = load_order_fulfillment()

    if len(of) > 0:
        risk_counts = of['RISK_LEVEL'].value_counts().reset_index()
        risk_counts.columns = ['Risk Level', 'Count']
        fig = px.pie(risk_counts, values='Count', names='Risk Level', title='Order Risk Distribution',
                     color='Risk Level',
                     color_discrete_map={'LOW': 'green', 'MEDIUM': 'orange', 'HIGH': 'red', 'CRITICAL': 'darkred'})
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("At-Risk Orders")
        at_risk = of[of['RISK_LEVEL'].isin(['HIGH', 'CRITICAL'])].sort_values('RISK_SCORE', ascending=False)
        if len(at_risk) > 0:
            st.dataframe(at_risk[['ORDER_ID', 'CUSTOMER_NAME', 'PLANT_NAME', 'RISK_SCORE', 'RISK_LEVEL',
                                  'RISK_REASON', 'DAYS_REMAINING', 'FULFILLMENT_RATIO']], use_container_width=True)
        else:
            st.success("No at-risk orders.")

# ============================================================
# PAGE: INVENTORY
# ============================================================
elif selected_page == "Inventory":
    col_h, col_r = st.columns([5, 1])
    col_h.header("Inventory Position")
    if col_r.button("Refresh", key="refresh_inventory"):
        st.cache_data.clear()
        st.rerun()
    ip = load_inventory_position()

    if len(ip) > 0:
        fig = px.scatter(ip, x='PART_NAME', y='DOI', color='PLANT_NAME', size='ON_HAND_QTY',
                        title='Days of Inventory by Part & Plant',
                        labels={'DOI': 'Days of Inventory'})
        fig.add_hline(y=3, line_dash="dash", line_color="red", annotation_text="Critical (3 days)")
        fig.add_hline(y=7, line_dash="dash", line_color="orange", annotation_text="Warning (7 days)")
        st.plotly_chart(fig, use_container_width=True)

        st.subheader("Reorder Candidates")
        reorder = ip[ip['REORDER_CANDIDATE'] == True].sort_values('DOI')
        if len(reorder) > 0:
            st.dataframe(reorder[['PART_NAME', 'PLANT_NAME', 'ON_HAND_QTY', 'SAFETY_STOCK_QTY',
                                  'REORDER_POINT', 'DOI', 'AVG_DAILY_DEMAND']], use_container_width=True)
        else:
            st.success("No parts need reordering.")

# ============================================================
# PAGE: DEMAND
# ============================================================
elif selected_page == "Demand":
    col_h, col_r = st.columns([5, 1])
    col_h.header("Demand Forecast")
    if col_r.button("Refresh", key="refresh_demand"):
        st.cache_data.clear()
        st.rerun()
    st.info("Demand forecasts are generated by the ML FORECAST model (demand_planner skill). "
            "Use the chat interface below to ask: 'What is the demand forecast for Part P100 at Plant Chicago?'")

    ip = load_inventory_position()
    if len(ip) > 0:
        fig = px.bar(ip, x='PART_NAME', y='AVG_DAILY_DEMAND', color='PLANT_NAME',
                    title='Average Daily Demand by Part & Plant', barmode='group')
        st.plotly_chart(fig, use_container_width=True)

# ============================================================
# PAGE: SHIPMENTS
# ============================================================
elif selected_page == "Shipments":
    col_h, col_r = st.columns([5, 1])
    col_h.header("Shipment Tracking")
    if col_r.button("Refresh", key="refresh_shipments"):
        st.cache_data.clear()
        st.rerun()
    shipments = load_shipments()

    if len(shipments) > 0:
        in_transit = shipments[shipments['ACTUAL_DELIVERY'].isna()].copy()
        if len(in_transit) > 0:
            import datetime
            today = datetime.date.today()
            at_risk_cutoff = today + datetime.timedelta(days=3)
            in_transit['EXPECTED_DT'] = pd.to_datetime(in_transit['EXPECTED_DELIVERY']).dt.date
            in_transit['STATUS'] = in_transit['EXPECTED_DT'].apply(
                lambda d: 'DELAYED' if d < today else ('AT_RISK' if d <= at_risk_cutoff else 'ON_TRACK'))

            status_counts = in_transit['STATUS'].value_counts().reset_index()
            status_counts.columns = ['Status', 'Count']
            fig = px.pie(status_counts, values='Count', names='Status', title='In-Transit Shipment Status',
                        color='Status',
                        color_discrete_map={'ON_TRACK': 'green', 'AT_RISK': 'orange', 'DELAYED': 'red'})
            st.plotly_chart(fig, use_container_width=True)

            st.subheader("In-Transit Shipments")
            st.dataframe(in_transit[['SHIPMENT_ID', 'SUPPLIER_ID', 'PLANT_ID', 'CARRIER',
                                     'SHIP_DATE', 'EXPECTED_DELIVERY', 'STATUS', 'PRIORITY']].sort_values('EXPECTED_DELIVERY'),
                         use_container_width=True)

# ============================================================
# PAGE: RISK
# ============================================================
elif selected_page == "Risk":
    col_h, col_r = st.columns([5, 1])
    col_h.header("Risk Assessment")
    if col_r.button("Refresh", key="refresh_risk"):
        st.cache_data.clear()
        st.rerun()
    of = load_order_fulfillment()

    if len(of) > 0:
        fig = px.bar(of, x='PLANT_NAME', color='RISK_LEVEL', title='Order Risk by Plant',
                     color_discrete_map={'LOW': 'green', 'MEDIUM': 'orange', 'HIGH': 'red', 'CRITICAL': 'darkred'},
                     barmode='stack')
        st.plotly_chart(fig, use_container_width=True)

        critical = of[of['RISK_LEVEL'] == 'CRITICAL']
        if len(critical) > 0:
            st.error(f"{len(critical)} CRITICAL orders require immediate action:")
            st.dataframe(critical[['ORDER_ID', 'CUSTOMER_NAME', 'PLANT_NAME', 'RISK_SCORE',
                                   'RISK_REASON', 'DAYS_REMAINING']], use_container_width=True)

# ============================================================
# PAGE: ALERTS (Open + History tabs)
# ============================================================
elif selected_page == "Alerts":
    col_h, col_r = st.columns([5, 1])
    col_h.header("Supply Chain Alerts")
    if col_r.button("Refresh", key="refresh_alerts"):
        st.cache_data.clear()
        st.rerun()
    alerts = load_alerts()

    tab_open, tab_history = st.tabs(["Open", "History"])

    with tab_open:
        open_df = alerts[alerts['STATUS'] == 'OPEN'] if len(alerts) > 0 else alerts
        if len(open_df) > 0:
            alert_type_filter = st.multiselect("Filter by type", ['EXPEDITE', 'LOW_STOCK', 'ORDER_RISK'],
                                                default=['EXPEDITE', 'LOW_STOCK', 'ORDER_RISK'])
            filtered = open_df[open_df['ALERT_TYPE'].isin(alert_type_filter)]
            st.dataframe(filtered[['ALERT_ID', 'ALERT_TYPE', 'RECORD_TYPE', 'RECORD_ID',
                                   'PRIORITY', 'REASON', 'JIRA_TICKET_ID', 'CREATED_AT']],
                         use_container_width=True)
        else:
            st.success("No open alerts.")

    with tab_history:
        resolved_df = alerts[alerts['STATUS'] == 'RESOLVED'] if len(alerts) > 0 else alerts
        if len(resolved_df) > 0:
            st.dataframe(resolved_df[['ALERT_ID', 'ALERT_TYPE', 'RECORD_TYPE', 'RECORD_ID',
                                       'PRIORITY', 'REASON', 'JIRA_TICKET_ID', 'JIRA_TICKET_STATUS',
                                       'CREATED_AT', 'RESOLVED_AT']],
                         use_container_width=True)
        else:
            st.info("No resolved alerts yet.")

# ============================================================
# NL QUERY INTERFACE (bottom of every page)
# ============================================================
st.divider()
st.subheader("Ask anything about your supply chain")

for msg in st.session_state.chat_history:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

if prompt := st.chat_input("e.g., What is the OTD for Supplier Acme?"):
    st.session_state.chat_history.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Analyzing..."):
            try:
                MAX_HISTORY = 10  # keep last 10 messages (5 turns)
                recent_history = st.session_state.chat_history[-MAX_HISTORY:]
                messages = []
                # Prepend persona context so the router agent knows which sub-agent to favor
                persona_context = {
                    "Procurement": "I am a Procurement Manager. Focus on supplier performance, landed cost, and purchase orders.",
                    "Planning": "I am a Planning Analyst. Focus on inventory health, demand forecasts, and fulfillment risk.",
                    "Logistics": "I am a Logistics Coordinator. Focus on shipment tracking, delays, carrier OTD, and expedites.",
                    "Admin": "I am an Admin with full access to all supply chain data."
                }
                messages.append({
                    "role": "user",
                    "content": [{"type": "text", "text": persona_context.get(persona, persona_context["Admin"])}]
                })
                messages.append({
                    "role": "assistant",
                    "content": [{"type": "text", "text": f"Understood. I'll tailor my responses for your {persona} role."}]
                })
                for msg in recent_history:
                    messages.append({
                        "role": msg["role"],
                        "content": [{"type": "text", "text": msg["content"]}]
                    })
                messages_json = json.dumps({"messages": messages})
                # Escape $$ inside content to prevent breaking the SQL dollar-quoting
                messages_json = messages_json.replace("$$", "\\$\\$").replace("'", "''")

                result = session.sql(f"""
                    SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
                        'SUPPLY_CHAIN_DB.SCM.SUPPLY_CHAIN_AGENT',
                        $${messages_json}$$,
                        TRUE
                    ) AS response
                """).collect()[0]['RESPONSE']

                response_json = json.loads(result)
                # Handle both v1 (content at top level) and v2 (content nested) response formats
                content = response_json.get('content', [])
                if not content and 'message' in response_json:
                    content = response_json['message'].get('content', [])
                text_parts = []
                for item in content:
                    if isinstance(item, dict) and item.get('type') == 'text' and item.get('text'):
                        text_parts.append(item['text'])
                    elif isinstance(item, str):
                        text_parts.append(item)
                answer = "\n\n".join(text_parts).strip()

                if not answer:
                    answer = "I received a response but couldn't extract a text answer. Please try rephrasing your question."

                st.markdown(answer)
                st.session_state.chat_history.append({"role": "assistant", "content": answer})
            except Exception as e:
                error_msg = f"Error: {str(e)}"
                st.error(error_msg)
                st.session_state.chat_history.append({"role": "assistant", "content": error_msg})
