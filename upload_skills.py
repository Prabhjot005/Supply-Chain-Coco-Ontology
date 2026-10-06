import snowflake.connector, os

conn = snowflake.connector.connect(
    account='ZPLORYA-FW23180',
    user='PRABHJOT',
    authenticator='externalbrowser',
    role='SUPPLY_CHAIN_ADMIN',
    database='SUPPLY_CHAIN_DB',
    schema='SCM',
    warehouse='COMPUTE_WH'
)
cur = conn.cursor()

base = r'C:\Users\prabhjot.kaur\IdeaProjects\personal\CoCo Supply Chain\08_skills'
skills = ['supplier_scorecard', 'reorder_advisor', 'shipment_tracker', 'demand_planner', 'cost_analyzer']

for s in skills:
    path = os.path.join(base, s, 'SKILL.md').replace('\\', '/')
    stage_path = f'@SKILL_STAGE/skills/{s}/'
    sql = f"PUT 'file://{path}' '{stage_path}' AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
    cur.execute(sql)
    row = cur.fetchone()
    print(f'Uploaded {s}: {row}')

cur.close()
conn.close()
print('All 5 skills uploaded.')
