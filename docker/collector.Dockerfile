FROM python:3.12-slim

WORKDIR /app

COPY collector-service/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY collector-service/ .

CMD ["python", "main.py"]
