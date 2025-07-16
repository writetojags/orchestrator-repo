#!/bin/bash
set -e

SERVICE=$1
COMMIT=$2
AZ1=$3
AZ2=$4
AZ3=$5

echo "🚀 Starting deploy for $SERVICE with commit $COMMIT"
echo "🔎 AZ apps: $AZ1, $AZ2, $AZ3"

if [ -z "$HEROKU_API_KEY" ]; then
  echo "❌ HEROKU_API_KEY not set"
  exit 1
fi

# Default context path and health endpoint
CONTEXT_PATH=${CONTEXT_PATH:-""}
HEALTH_PATH=${HEALTH_PATH:-"/actuator/health"}

for AZ in "$AZ1" "$AZ2" "$AZ3"; do
  if [ -z "$AZ" ]; then
    echo "❌ AZ app name is missing for $SERVICE"
    exit 1
  fi

  echo "👉 Deploying to Heroku app: $AZ"

  # Push to Heroku
  git push -f "https://heroku:$HEROKU_API_KEY@git.heroku.com/$AZ.git"
"$COMMIT:master"

  echo "⏳ Waiting for deployment to finish..."
  sleep 10

  HEALTH_URL="https://${AZ}.herokuapp.com${CONTEXT_PATH}${HEALTH_PATH}"
  echo "🌐 Health check URL: $HEALTH_URL"

  if ! curl --silent --fail --location "$HEALTH_URL"; then
    echo "❌ Health check FAILED on $AZ"
    echo "⚡ Rolling back all AZs for $SERVICE..."
    bash ./rollback.sh "$SERVICE"
    exit 1
  else
    echo "✅ Health check PASSED on $AZ"
  fi
done

# Update rollback log with successful commit
ROLLBACK_FILE="rollback/rollback.log"
mkdir -p rollback
touch "$ROLLBACK_FILE"

if grep -q "^${SERVICE}=" "$ROLLBACK_FILE"; then
  sed -i.bak "s|^${SERVICE}=.*|${SERVICE}=${COMMIT}|" "$ROLLBACK_FILE"
else
  echo "${SERVICE}=${COMMIT}" >> "$ROLLBACK_FILE"
fi

echo "✅ Deployment complete for $SERVICE"
