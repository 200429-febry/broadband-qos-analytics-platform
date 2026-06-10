from sqlalchemy import Column, Integer, Float, String, Boolean, TIMESTAMP, ForeignKey
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class QoSMetrics(Base):
    __tablename__ = "qosmetrics"

    id = Column(Integer, primary_key=True, index=True)
    node_id = Column(String(100))
    throughput = Column(Float)
    latency = Column(Float)
    jitter = Column(Float)
    packet_loss = Column(Float)
    bandwidth_utilization = Column(Float)
    timestamp = Column(TIMESTAMP)


class Predictions(Base):
    __tablename__ = "predictions"

    id = Column(Integer, primary_key=True, index=True)
    metric_id = Column(Integer, ForeignKey("qosmetrics.id"))
    predicted_qos_score = Column(Float)
    anomaly_score = Column(Float)
    confidence = Column(Float)


class Alerts(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    severity = Column(String(50))
    message = Column(String)
    metric_value = Column(String(100))
    resolved = Column(Boolean)


class Users(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(100))
    hashed_password = Column(String(255))
    role = Column(String(50))