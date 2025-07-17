#!/bin/bash
set -e

SERVICE=$1
COMMIT=$2
TARGET_BRANCH=${3:-main}
HEALTH_PATH="/actuator/health"

echo "🌟 Starting deploy-prod.sh for SERVICE=$SERVICE with commit=$COMMIT to branch=$TARGET_BRANCH"

if [ -z "$HEROKU_API_KEY" ]; then
  echo "❌ ERROR: HEROKU_API_KEY not set!"
  exit 1
fi

# Load local env if exists
if [ -f "./deploy.env" ]; then
  echo "📜 Loading local deploy.env..."
  source ./deploy.env
fi

echo "🔍 Determining AZ app names for $SERVICE..."

if [ "$SERVICE" = "event_driven" ]; then
  AZ1=$EVENT_DRIVEN_APP_AZ1
  AZ2=$EVENT_DRIVEN_APP_AZ2
  AZ3=$EVENT_DRIVEN_APP_AZ3
elif [ "$SERVICE" = "event_service" ]; then
  AZ1=$EVENT_SERVICE_APP_AZ1
  AZ2=$EVENT_SERVICE_APP_AZ2
  AZ3=$EVENT_SERVICE_APP_AZ3
elif [ "$SERVICE" = "tolerant_reader" ]; then
  AZ1=$TOLERANT_READER_APP_AZ1
  AZ2=$TOLERANT_READER_APP_AZ2
  AZ3=$TOLERANT_READER_APP_AZ3
else
  echo "❌ ERROR: Unknown SERVICE=$SERVICE"
  exit 1
fi

echo "✅ AZ Apps resolved: $AZ1, $AZ2, $AZ3"

echo "💾 Initializing rollback log..."
mkdir -p rollback
touch rollback/rollback.log

echo "✈️ Pushing to Heroku apps..."
#for APP in "$AZ1" "$AZ2" "$AZ3"
#do
#  echo "🚀 Deploying $SERVICE to Heroku app $APP..."
#  TARGET_BRANCH=${TARGET_BRANCH:-master}
 # git push  "https://heroku:${HEROKU_API_KEY}@git.heroku.com/${APP}.git" HEAD:${TARGET_BRANCH}
 # echo "✅ Finished push for $APP"
#done working code for deployments for all zones remove later ok

for AZ in "SAZ1" "SAZ2" "SAZ3"; do
  case "$AZ" in
    "SAZ1") APP="event-driven-prod-app-az1" ;;
    "SAZ2") APP="event-driven-prod-app-az2" ;;
    "SAZ3") APP="event-driven-prod-app-az3" ;;
    *) echo "Unknown AZ $AZ"; exit 1 ;;
  esac

  echo "🚀 Deploying $SERVICE to Heroku app $APP..."
  TARGET_BRANCH=${TARGET_BRANCH:-main}

  git push "https://heroku:${HEROKU_API_KEY}@git.heroku.com/${APP}.git" HEAD:${TARGET_BRANCH}
  echo "✅ Finished push for $APP"

  HEALTH_URL="https://${APP}.herokuapp.com${HEALTH_PATH:-/actuator/health}"
  echo "⏳ Waiting for service to warm up..."
  sleep 30
  echo "🔍 Beginning health checks for $APP at $HEALTH_URL..."

  for i in {1..5}; do
    echo "🔄 Health check attempt $i for $APP at $HEALTH_URL..."
    RESPONSE=$(curl -s "$HEALTH_URL")
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")

    echo "📡 HTTP $HTTP_STATUS - Response: $RESPONSE"

    if [[ "$HTTP_STATUS" -eq 200 && "$RESPONSE" == *"UP"* ]]; then
      echo "✅ Health check passed for $APP!"
      break
    else
      echo "❌ Health check failed (HTTP $HTTP_STATUS): Retrying in 10 seconds..."
      sleep 10
    fi
  done
done





