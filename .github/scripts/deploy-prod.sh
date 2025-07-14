#!/bin/bash
set -e

SERVICE=$1
COMMIT=$2
AZ1_APP=$3
AZ2_APP=$4
AZ3_APP=$5


echo "✅ Deploying $SERVICE with commit $COMMIT"

# Loop over availability zones
for AZ in az1 az2 az3
do
  # Dynamically resolve APP_NAME
  APP_NAME_VAR="${SERVICE^^}_APP_${AZ^^}"
  APP_NAME=${!APP_NAME_VAR}

  if [ -z "$APP_NAME" ]; then
    echo "❌ ERROR: APP_NAME is empty for AZ=$AZ (APP_NAME_VAR=$APP_NAME_VAR)"
    exit 1
  fi

  echo "🐾 DEBUG: Using APP_NAME_VAR=$APP_NAME_VAR"
  echo "🐾 DEBUG: Resolved APP_NAME=$APP_NAME"

  echo "🚀 Pushing to $APP_NAME..."
  git push "https://heroku:$HEROKU_API_KEY@git.heroku.com/$APP_NAME.git" "$COMMIT:master"

  echo "⏳ Waiting for deploy to finish..."
  sleep 10
done

# Health check all deployed apps
for AZ in az1 az2 az3
do
  APP_NAME_VAR="${SERVICE^^}_APP_${AZ^^}"
  APP_NAME=${!APP_NAME_VAR}

  if [ -z "$APP_NAME" ]; then
    echo "❌ ERROR: APP_NAME is empty for AZ=$AZ during health check!"
    exit 1
  fi

  echo "🔎 Running health check on $APP_NAME..."
  if ! curl -f "https://${APP_NAME}.herokuapp.com/health"; then
    echo "❌ Health check failed on $APP_NAME!"
    echo "⚠️ Rolling back all AZs for $SERVICE..."

    # Retrieve previous commit
    PREV_COMMIT=$(grep "^${SERVICE}=" rollback/rollback.log | cut -d= -f2)
    if [ -z "$PREV_COMMIT" ]; then
      echo "❌ ERROR: Could not find previous commit for $SERVICE in rollback log!"
      exit 1
    fi

    # Rollback all AZs
    for ROLL_AZ in az1 az2 az3
    do
      ROLL_APP_VAR="${SERVICE^^}_APP_${ROLL_AZ^^}"
      ROLL_APP=${!ROLL_APP_VAR}

      if [ -z "$ROLL_APP" ]; then
        echo "❌ ERROR: ROLL_APP is empty for ROLL_AZ=$ROLL_AZ (ROLL_APP_VAR=$ROLL_APP_VAR)"
        exit 1
      fi

      echo "↩️ Rolling back $ROLL_APP to $PREV_COMMIT"
      git push -f "https://heroku:$HEROKU_API_KEY@git.heroku.com/$ROLL_APP.git" "$PREV_COMMIT:master"
    done

    exit 1
  fi
done

echo "✅ All health checks passed!"

# Update rollback log on success
echo "📝 Updating rollback log..."
sed -i "s/^${SERVICE}=.*/${SERVICE}=${COMMIT}/" rollback/rollback.log

echo "✅ Deployment complete."