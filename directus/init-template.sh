#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Wait for Directus to be available
echo "Waiting for Directus to be up..."
until curl --output /dev/null --silent --head --fail http://directus:8055/server/ping; do
  printf '.'
  sleep 5
done
echo "Directus is up!"

# 1. Get the Access Token
echo "Getting Directus access token..."
RESPONSE=$(curl -s -X POST "${DIRECTUS_URL}/auth/login" \
  -H "Content-Type: application/json" \
  --data-raw '{
    "email": "'"${ADMIN_EMAIL}"'",
    "password": "'"${ADMIN_PASSWORD}"'"
  }')

TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d '"' -f 4)

if [ -z "$TOKEN" ]; then
  echo "Error: Failed to get access token."
  echo "Response: $RESPONSE"
  exit 1
fi

echo "Access token obtained successfully."

# 2. Check for an existing collection or item to avoid re-applying the template
echo "Checking for existing template data..."
CHECK_ENDPOINT="${DIRECTUS_URL}/collections/website"

if curl --output /dev/null --silent --head --fail -H "Authorization: Bearer ${TOKEN}" "${CHECK_ENDPOINT}"; then
  echo "Template has already been applied. Exiting."
  exit 0
else
  echo "Template not found. Proceeding with application."
fi

# 3. Apply the template using the obtained token
echo "Applying template..."
npm install -g directus-template-cli
directus-template-cli apply -p \
  --directusUrl="${DIRECTUS_URL}" \
  --directusToken="${TOKEN}" \
  --templateLocation="./directus/template" \
  --templateType="local" \
  --disableTelemetry

echo "Template applied successfully!"