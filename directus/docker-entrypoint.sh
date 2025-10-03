#!/bin/sh
set -e

DIRECTUS_URL="${PUBLIC_URL:-http://localhost:8055}"
INTERNAL_URL="http://0.0.0.0:8055"

echo "Starting Directus initialization..."

# Bootstrap Directus (create admin user, apply migrations)
npx directus bootstrap

# Start Directus in the background to check if template was already applied
npx directus start &
DIRECTUS_PID=$!

# Wait for Directus to be ready
echo "Waiting for Directus to start (max 120 seconds)..."
for i in $(seq 1 120); do
  if nc -z 0.0.0.0 8055 2>/dev/null; then
    echo "Directus is ready!"
    sleep 5  # Give it a few more seconds to fully initialize
    break
  fi
  if [ $i -eq 120 ]; then
    echo "ERROR: Directus did not start within 120 seconds"
    kill $DIRECTUS_PID 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

# Check if template has already been applied by checking for collections
echo "Checking if template is already applied..."
COLLECTIONS_RESPONSE=$(wget -q -O- "${INTERNAL_URL}/collections" 2>/dev/null || echo "")
COLLECTION_COUNT=$(echo "$COLLECTIONS_RESPONSE" | grep -o '"collection"' | wc -l || echo "0")

# If there are more than 10 collections (system collections + template collections), assume template is applied
if [ "$COLLECTION_COUNT" -gt 10 ]; then
  echo "Template already applied (found $COLLECTION_COUNT collections). Skipping template application."
  # Stop the background Directus instance
  kill $DIRECTUS_PID 2>/dev/null || true
  wait $DIRECTUS_PID 2>/dev/null || true
  
  # Start Directus normally
  echo "Starting Directus..."
  exec npx directus start
fi

TOKEN_RESPONSE=$(wget -q -O- --post-data="{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" \
  --header="Content-Type: application/json" \
  "${INTERNAL_URL}/auth/login" 2>/dev/null || echo "")

if [ -z "$TOKEN_RESPONSE" ]; then
  echo "ERROR: Failed to authenticate with Directus"
  echo "Trying with curl as fallback..."
  TOKEN_RESPONSE=$(curl -s -X POST "${INTERNAL_URL}/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null || echo "")
  
  if [ -z "$TOKEN_RESPONSE" ]; then
    echo "ERROR: Failed to authenticate with both wget and curl"
    kill $DIRECTUS_PID 2>/dev/null || true
    exit 1
  fi
fi

# Extract token from response (simple JSON parsing)
TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$TOKEN" ]; then
  echo "ERROR: Could not extract access token from response"
  kill $DIRECTUS_PID 2>/dev/null || true
  exit 1
fi

echo "Successfully authenticated. Applying template..."

# Apply the template (use internal URL for API calls)
npx directus-template-cli apply \
  -p \
  --directusUrl="${INTERNAL_URL}" \
  --directusToken="${TOKEN}" \
  --templateLocation=/directus/template \
  --templateType=local \
  --disableTelemetry

APPLY_EXIT_CODE=$?

if [ $APPLY_EXIT_CODE -eq 0 ]; then
  echo "Template applied successfully!"
else
  echo "ERROR: Template application failed with exit code $APPLY_EXIT_CODE"
  kill $DIRECTUS_PID 2>/dev/null || true
  exit 1
fi

# Stop the background Directus instance
echo "Stopping background Directus instance..."
kill $DIRECTUS_PID 2>/dev/null || true
wait $DIRECTUS_PID 2>/dev/null || true

echo "Template application complete. Starting Directus normally..."

# Start Directus normally
echo "Starting Directus..."
exec npx directus start
