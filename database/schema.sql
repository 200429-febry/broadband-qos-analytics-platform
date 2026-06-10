CREATE TABLE IF NOT EXISTS Users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'Viewer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS QoSMetrics (
    id SERIAL PRIMARY KEY,
    node_id VARCHAR(100) NOT NULL,
    throughput FLOAT NOT NULL,
    latency FLOAT NOT NULL,
    jitter FLOAT NOT NULL,
    packet_loss FLOAT NOT NULL,
    bandwidth_utilization FLOAT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Predictions (
    id SERIAL PRIMARY KEY,
    metric_id INT REFERENCES QoSMetrics(id),
    predicted_qos_score FLOAT NOT NULL,
    anomaly_score FLOAT NOT NULL,
    confidence FLOAT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Alerts (
    id SERIAL PRIMARY KEY,
    severity VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    metric_value VARCHAR(100),
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
