FROM python:3.9-slim

WORKDIR /app
COPY kopia_exporter.py .

RUN pip install prometheus_client

CMD ["python", "kopia_exporter.py"] 