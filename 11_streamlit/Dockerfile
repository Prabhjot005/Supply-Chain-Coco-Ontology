FROM python:3.11-slim

RUN pip install --no-cache-dir \
    streamlit==1.41.1 \
    snowflake-snowpark-python[pandas]==1.24.0 \
    plotly==5.24.1

WORKDIR /app
COPY app.py .

EXPOSE 8501

HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health || exit 1

ENTRYPOINT ["streamlit", "run", "app.py", \
    "--server.port=8501", \
    "--server.address=0.0.0.0", \
    "--server.headless=true", \
    "--browser.gatherUsageStats=false"]
