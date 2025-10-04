# Custom Directus Docker Setup with Template Application

## Overview
This setup uses a custom Dockerfile that extends the official Directus image to automatically apply a Directus template on first startup using `directus-template-cli`.

## How It Works

### First Start
1. Container starts and runs `docker-entrypoint.sh`
2. Directus bootstraps (creates admin user, runs migrations)
3. Directus starts in the background
4. Script waits for Directus to be ready (max 120 seconds)
5. Script checks if template is already applied by counting collections
6. If few collections exist (fresh install), it proceeds with template application
7. Script authenticates with admin credentials
8. `directus-template-cli apply` is executed to import schema and data
9. Background Directus instance is stopped
10. Directus starts normally

### Subsequent Restarts
- Script checks the number of collections in the database
- If more than 10 collections exist, template application is skipped
- Directus starts normally immediately

## Files Modified/Created

- **`Dockerfile`** - Custom image based on `directus/directus:latest`
  - Installs `netcat-openbsd`, `wget`, `curl` utilities
  - Installs `directus-template-cli` globally
  - Sets custom entrypoint script

- **`docker-entrypoint.sh`** - Custom entrypoint script
  - Handles one-time template application
  - Checks database collections count to detect if template was applied
  - Authenticates and applies template using internal URL

- **`docker-compose.yaml`** - Updated to build custom image
  - Changed from `image:` to `build:` directive

- **`scripts/docker-init/01-create-s3-bucket.sh`** - LocalStack initialization script
  - Creates the `directus-uploads` S3 bucket automatically
  - Runs when LocalStack starts up

## Important Notes

### S3 Bucket Warnings
You may see warnings like:
```
WARN: Couldn't save file xxx.png
WARN: The specified bucket does not exist
```

**These are expected and non-fatal.** The template contains file references, but LocalStack's S3 bucket may not be initialized when the template applies. The schema and data will still be imported correctly into the database.

### Template Application Time
The template application can take several minutes depending on:
- Amount of data in the template
- Number of files
- System performance

Be patient during the first startup. You can monitor progress with:
```bash
docker compose logs -f directus
```

### Resetting Everything
To start fresh and reapply the template:
```bash
docker compose down -v  # This removes ALL volumes including the database
docker compose up --build
```

Note: The script automatically detects if the template needs to be applied by checking the database state, so a simple `docker compose down -v` followed by `docker compose up` will trigger template reapplication.

## Usage

### First Time Setup
```bash
cd directus
docker compose up --build
```

Wait for the template to be applied (watch the logs for "Template applied successfully!" and "Marker file created").

### Subsequent Starts
```bash
docker compose up
```

The template won't be reapplied.

### Rebuild Image Only
```bash
docker compose build directus
```

## Troubleshooting

### "Directus did not start within 120 seconds"
- Increase the timeout in `docker-entrypoint.sh`
- Check if database/cache services are healthy
- Ensure sufficient system resources

### Template Not Applied
Check the logs:
```bash
docker compose logs directus | grep -E "(Template|Error|ERROR)"
```

### Reset Template Application
To reapply the template without removing everything:
```bash
# Stop containers
docker compose down

# Remove only the database volume (keeps LocalStack, pgAdmin data)
docker volume rm directus-extension-development-sandbox_database-data

# Restart
docker compose up -d
```

The script will detect the empty database and automatically reapply the template.

## Environment Variables Required

Make sure your `.env` file has:
- `ADMIN_EMAIL` - Admin email for authentication
- `ADMIN_PASSWORD` - Admin password for authentication
- `PUBLIC_URL` (optional) - External URL for Directus

## Technical Details

- **Wait Strategy**: Uses `netcat` to check if port 8055 is open
- **Template Detection**: Counts collections via `/collections` endpoint (>10 = template already applied)
- **Authentication**: Gets access token via `/auth/login` endpoint
- **Internal URL**: Uses `http://0.0.0.0:8055` for API calls (not PUBLIC_URL)
- **LocalStack S3**: Automatically creates `directus-uploads` bucket on startup
- **No Persistent State**: Uses database content instead of marker files to detect applied templates
