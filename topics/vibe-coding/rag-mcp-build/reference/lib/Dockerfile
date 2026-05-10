FROM python:3.13-slim
RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY src/ ./src/
COPY pyproject.toml ./
RUN pip install --no-cache-dir .
CMD ["python", "-m", "lib.ingest"]
