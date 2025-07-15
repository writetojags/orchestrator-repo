#!/bin/bash
set -e

SERVICE=$1
COMMIT=$2

echo "✅ Starting deploy-prod.sh for $SERVICE with commit $COMMIT"

# Optional: Load local environment variables if deploy.env exists
if [ -f "./deploy.env" ]; then
  echo "🔄 Loading local deploy.env..."
  source ./deploy.env
fi

# Print all _APP_ variables for debugging
echo "ℹ️ Current environment APP variables:"
printenv | grep _APP_

# Check if HEROKU_API_KEY is set
if [ -z "$HEROKU_API_KEY" ]; then
  echo "❌ ERROR: HEROKU_API_KEY is not set!"
  exit 1
fi

# --- Push to Heroku for all AZs ---
for AZ in az1 az2 az3
do
  APP_NAME_VAR="${SERVICE^^}_APP_${AZ^^}"
  APP_NAME="${!APP_NAME_VAR}"

  if [ -z "$APP_NAME" ]; then
    echo "❌ ERROR: App name for $APP_NAME_VAR is not set!"
    exit 1
  fi

  echo "🚀 AZ=$AZ -> Pushing $SERVICE to Heroku app $APP_NAME at commit $COMMIT"
  git push -f "https://heroku:${HEROKU_API_KEY}@git.heroku.com/${APP_NAME}.git" HEAD:master

  echo "✅ APP_NAME used: '$APP_NAME'"
  echo "⏳ Waiting for deploy to finish for AZ=$AZ..."
  sleep 10
done

# ✅ 👉 SKIP health check if SERVICE is event_driven
if [ "$SERVICE" = "event_driven" ]; then
  echo "⚠️ Skipping health check for $SERVICE..."
  echo "✅ Deployment complete (health check skipped)."
  exit 0
fi

# --- Health check for all AZs ---
for AZ in az1 az2 az3
do
  APP_NAME_VAR="${SERVICE^^}_APP_${AZ^^}"
  APP_NAME="${!APP_NAME_VAR}"

  if [ -z "$APP_NAME" ]; then
    echo "❌ ERROR: App name for $APP_NAME_VAR is not set during health check!"
    exit 1
  fi

  echo "🔎 Running health check on $APP_NAME (AZ=$AZ)..."
  HEALTH_URL="https://${APP_NAME}.herokuapp.com/actuator/health"
  echo "📍 Health check URL: $HEALTH_URL"

  if ! curl -f "$HEALTH_URL"; then
    echo "❌ Health check failed on $APP_NAME!"
    echo "⚠️ Rolling back all AZs for $SERVICE..."

    # --- Rollback ---
    PREV_COMMIT=$(grep "^${SERVICE}=" rollback/rollback.log | cut -d= -f2)
    if [ -z "$PREV_COMMIT" ]; then
      echo "❌ ERROR: Could not find previous commit for $SERVICE in rollback log!"
      exit 1
    fi

    for ROLL_AZ in az1 az2 az3
    do
      ROLL_APP_VAR="${SERVICE^^}_APP_${ROLL_AZ^^}"
      ROLL_APP="${!ROLL_APP_VAR}"

      if [ -z "$ROLL_APP" ]; then
        echo "❌ ERROR: Rollback app name for $ROLL_APP_VAR is not set!"
        exit 1
      fi

      echo "↩️ Rolling back $ROLL_APP to $PREV_COMMIT"
      git push -f "https://heroku:${HEROKU_API_KEY}@git.heroku.com/${ROLL_APP}.git"
"$PREV_COMMIT:master"
    done

    exit 1
  fi
done

echo "✅ All health checks passed!"

# --- Update rollback log ---
echo "📝 Updating rollback log..."
sed -i "s/^${SERVICE}=.*/${SERVICE}=${COMMIT}/" rollback/rollback.log

echo "✅ Deployment complete."
