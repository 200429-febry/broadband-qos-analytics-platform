#!/bin/bash
set -e

REGION="asia-southeast2"
SQL_INSTANCE="qos-db"

FRONTEND_SERVICE="qos-frontend"
API_SERVICE="qos-api"
ML_SERVICE="qos-ml-service"

mode="$1"

if [ -z "$mode" ]; then
  echo "Usage:"
  echo "  ./qos-power.sh on"
  echo "  ./qos-power.sh off"
  echo "  ./qos-power.sh status"
  exit 1
fi

case "$mode" in
  on)
    echo "=================================================="
    echo "TURNING ON QoS PLATFORM FOR PRESENTATION"
    echo "=================================================="

    echo "1. Start Cloud SQL..."
    gcloud sql instances patch "$SQL_INSTANCE" \
      --activation-policy=ALWAYS \
      --quiet || true

    echo "2. Warm up Cloud Run services..."
    gcloud run services update "$FRONTEND_SERVICE" \
      --region="$REGION" \
      --min-instances=1 \
      --quiet || true

    gcloud run services update "$API_SERVICE" \
      --region="$REGION" \
      --min-instances=1 \
      --quiet || true

    gcloud run services update "$ML_SERVICE" \
      --region="$REGION" \
      --min-instances=1 \
      --quiet || true

    echo "3. Service URLs:"
    gcloud run services list \
      --region="$REGION" \
      --filter="metadata.name~qos" \
      --format="table(metadata.name,status.url,spec.template.metadata.annotations.autoscaling.knative.dev/minScale)"

    echo "✅ Platform ON. Wait 1-3 minutes before presentation."
    ;;

  off)
    echo "=================================================="
    echo "TURNING OFF QoS PLATFORM TO SAVE CREDIT"
    echo "=================================================="

    echo "1. Set Cloud Run min instances to 0..."
    gcloud run services update "$FRONTEND_SERVICE" \
      --region="$REGION" \
      --min-instances=0 \
      --quiet || true

    gcloud run services update "$API_SERVICE" \
      --region="$REGION" \
      --min-instances=0 \
      --quiet || true

    gcloud run services update "$ML_SERVICE" \
      --region="$REGION" \
      --min-instances=0 \
      --quiet || true

    echo "2. Stop Cloud SQL..."
    gcloud sql instances patch "$SQL_INSTANCE" \
      --activation-policy=NEVER \
      --quiet || true

    echo "✅ Platform OFF. Cloud Run can still cold-start if accessed, but no standby instances."
    echo "⚠️ If Cloud SQL is OFF, database-dependent pages may fail until you run ./qos-power.sh on"
    ;;

  status)
    echo "=================================================="
    echo "QoS PLATFORM STATUS"
    echo "=================================================="

    echo ""
    echo "Cloud Run:"
    gcloud run services list \
      --region="$REGION" \
      --filter="metadata.name~qos" \
      --format="table(metadata.name,status.url,spec.template.metadata.annotations.autoscaling.knative.dev/minScale,status.conditions[0].status)"

    echo ""
    echo "Cloud SQL:"
    gcloud sql instances describe "$SQL_INSTANCE" \
      --format="table(name,state,settings.activationPolicy,settings.tier,region,gceZone)" || true
    ;;

  *)
    echo "Unknown mode: $mode"
    echo "Use: on | off | status"
    exit 1
    ;;
esac
