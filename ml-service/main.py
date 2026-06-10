from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import numpy as np

app = FastAPI(title="ML Prediction Service")

class QoSInput(BaseModel):
    throughput: float
    latency: float
    jitter: float
    packet_loss: float
    bandwidth: float

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/predict")
def predict_qos(data: QoSInput):
    # Mock ML prediction logic using pre-trained model concepts
    base_score = 100 - (data.latency * 0.2) - (data.jitter * 0.5) - (data.packet_loss * 5)
    qos_score = max(0, min(100, base_score))
    
    anomaly_score = 0.0
    if data.latency > 100 or data.packet_loss > 2.0:
        anomaly_score = 0.85
        
    return {
        "predicted_throughput": data.throughput * 1.05,
        "predicted_latency": max(10, data.latency * 0.95),
        "predicted_packet_loss": max(0, data.packet_loss * 0.9),
        "qos_score": round(qos_score, 2),
        "anomaly_score": anomaly_score,
        "confidence": 0.92
    }
