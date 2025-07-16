#!/bin/bash
set -e

SERVICE=$1
COMMIT=$2
AZ_LIST="az1 az2 az3"

if [ ! -f rollback/rollback.log ]; then
  echo "Initializing rollback log..."
  mkdir -p rollback
  touch rollback/rollback.log
fi

for AZ in $AZ_LIST; do
  APP_NAME_VAR="${SERVICE^^}_APP_${AZ^^}"
  APP_NAME="${!APP_NAME_VAR}"

  if [ -z "$APP_NAME" ]; then
    echo "ERROR: App name for $APP_NAME_VAR is not set!"
    exit 1
  fi

  echo "Pushing $SERVICE to Heroku app $APP_NAME at commit $COMMIT..."
  git push -f "https://heroku:${HEROKU_API_KEY}@git.heroku.com/${APP_NAME}.git" "$COMMIT:master"

  echo "Waiting for deploy to finish for $AZ..."
  sleep 10
done

for AZ in $AZ_LIST; do
  APP_NAME_VAR="${SERVICE^^}_APP_${AZ^^}"
  APP_NAME="${!APP_NAME_VAR}"

  HEALTH_URL="https://${APP_NAME}.herokuapp.com/actuator/health"
  echo "Checking health: $HEALTH_URL"

  if ! curl -f "$HEALTH_URL"; then
    echo "Health check failed on $APP_NAME! Rolling back..."
    PREV_COMMIT=$(grep "^${SERVICE}=" rollback/rollback.log | cut -d= -f2)

    if [ -z "$PREV_COMMIT" ]; then
      echo "No previous commit found to rollback!"
      exit 1
    fi

    for ROLL_AZ in $AZ_LIST; do
      ROLL_APP_VAR="${SERVICE^^}_APP_${ROLL_AZ^^}"
      ROLL_APP="${!ROLL_APP_VAR}"

      echo "Rolling back $ROLL_APP to $PREV_COMMIT..."
      git push -f "https://heroku:${HEROKU_API_KEY}@git.heroku.com/${ROLL_APP}.git" "$PREV_COMMIT:master"
    done

    exit 1
  fi
done

echo "✅ All health checks passed!"
sed -i "s/^${SERVICE}=.*/${SERVICE}=${COMMIT}/" rollback/rollback.log || echo "${SERVICE}=${COMMIT}" >> rollback/rollback.log
echo "✅ Deployment complete."
