#!/bin/bash
set -e

SERVICE=$1

if [ -z "$HEROKU_API_KEY" ]; then
  echo "❌ HEROKU_API_KEY not set"
  exit 1
fi

ROLLBACK_FILE="rollback/rollback.log"

if [ ! -f "$ROLLBACK_FILE" ]; then
  echo "❌ rollback.log not found"
  exit 1
fi

PREV_COMMIT=$(grep "^${SERVICE}=" "$ROLLBACK_FILE" | cut -d= -f2)

if [ -z "$PREV_COMMIT" ]; then
  echo "❌ No previous commit recorded for $SERVICE"
  exit 1
fi

echo "🔄 Rolling back $SERVICE to commit $PREV_COMMIT"

# Load AZ variables
AZ1_VAR="${SERVICE^^}_APP_AZ1"
AZ2_VAR="${SERVICE^^}_APP_AZ2"
AZ3_VAR="${SERVICE^^}_APP_AZ3"

AZ1="${!AZ1_VAR}"
AZ2="${!AZ2_VAR}"
AZ3="${!AZ3_VAR}"

for AZ in "$AZ1" "$AZ2" "$AZ3"; do
  if [ -z "$AZ" ]; then
    echo "❌ AZ app name is missing"
    exit 1
  fi

  echo "👉 Rolling back Heroku app: $AZ"
  git push -f "https://heroku:$HEROKU_API_KEY@git.heroku.com/$AZ.git" "$PREV_COMMIT:master"
done

echo "✅ Rollback complete for $SERVICE"
