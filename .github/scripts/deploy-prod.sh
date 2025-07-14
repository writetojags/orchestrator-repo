#!/bin/bash
set -e

SERVICE=$1
COMMIT=$2

echo "🔹 Deploying $SERVICE with commit $COMMIT"

# Loop over availability zones
for AZ in az1 az2 az3
do
  APP_NAME_VAR="${SERVICE^^}_APP_${AZ^^}"
  APP_NAME=${!APP_NAME_VAR}

  echo "✅ Pushing to $APP_NAME..."
  git push https://heroku:$HEROKU_API_KEY@git.heroku.com/$APP_NAME.git $COMMIT:master

  echo "⏳ Waiting for deploy to finish..."
  sleep 30

  echo "🔍 Running health check on $APP_NAME..."
  if ! curl -f "https://${APP_NAME}.herokuapp.com/health"; then
    echo "❌ Health check failed on $APP_NAME!"
    echo "🔁 Rolling back all AZs for $SERVICE..."

    # Retrieve previous commit
    PREV_COMMIT=$(grep "${SERVICE}=" rollback/rollback.log | cut -d= -f2)

    # Rollback all AZs
    for ROLL_AZ in az1 az2 az3
    do
      ROLL_APP_VAR="${SERVICE^^}_APP_${ROLL_AZ^^}"
      ROLL_APP=${!ROLL_APP_VAR}
      echo "↩️ Rolling back $ROLL_APP to $PREV_COMMIT"
      git push -f https://heroku:$HEROKU_API_KEY@git.heroku.com/$ROLL_APP.git $PREV_COMMIT:master
    done

    exit 1
  fi
done

# ✅ Update rollback log on success
echo "✅ Updating rollback log..."
sed -i "s/^${SERVICE}=.*/${SERVICE}=${COMMIT}/" rollback/rollback.log
