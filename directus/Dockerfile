# Use the official Directus image as base
FROM directus/directus:latest

# Switch to root to install additional packages
USER root

# Install necessary utilities (using apk for Alpine Linux)
RUN apk add --no-cache netcat-openbsd wget curl

# Install directus-template-cli globally
RUN npm install -g directus-template-cli@latest

# Copy the custom entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Switch back to node user
USER node

# Use our custom entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
