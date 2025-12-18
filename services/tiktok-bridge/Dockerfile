# TikTok Bridge Service for Railway
# Connects to TikTok Live and forwards events to Elixir

FROM node:20-slim

WORKDIR /app

# Install dependencies for tiktok-live-connector (may need some native deps)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy package files
COPY package*.json ./

# Install dependencies (production only)
RUN npm install --omit=dev

# Copy application code
COPY *.js ./

# Create non-root user for security
RUN groupadd -r bridge && useradd -r -g bridge bridge
RUN chown -R bridge:bridge /app
USER bridge

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD node -e "fetch('http://localhost:8080/health').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Start server
CMD ["node", "server.js"]
