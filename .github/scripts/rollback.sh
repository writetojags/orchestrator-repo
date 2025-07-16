#!/bin/bash
set -e

SERVICE=$1
PREV_COMMIT=$2
TARGET_BRANCH=${3:-main}

echo "🌟 Starting rollback for $SERVICE to commit $PREV_COMMIT on branch $TARGET_BRANCH"

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

echo "⏪ Rolling back to $PREV_COMMIT..."
for APP in "$AZ1" "$AZ2" "$AZ3"
do
  echo "🚀 Rolling back $SERVICE to Heroku app $APP..."
  git push -f "https://heroku:${HEROKU_API_KEY}@git.heroku.com/${APP}.git"
$PREV_COMMIT:$TARGET_BRANCH
  echo "✅ Finished rollback for $APP"
done

echo "✅ Rollback complete!"
