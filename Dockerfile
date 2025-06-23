# Multi-stage build for Ball Scout
# Stage 1: Build backend (Deno)
FROM denoland/deno:2.0.0 AS backend-builder

WORKDIR /app/backend

# Copy backend source
COPY backend/ .

# Check and cache dependencies
RUN deno cache --unstable-temporal-api mod.ts

# Stage 2: Production image
FROM denoland/deno:2.0.0

# Install nginx for serving static files
USER root
RUN apt-get update && apt-get install -y nginx && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy backend from builder stage
COPY --from=backend-builder /app/backend ./backend

# Copy pre-built web files (from CI)
COPY build/web ./web

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Create startup script
RUN echo '#!/bin/bash\n\
# Start nginx in background\n\
nginx &\n\
\n\
# Start Deno backend\n\
cd /app/backend\n\
exec deno run --allow-net --allow-read --allow-env --unstable-temporal-api mod.ts\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose ports
EXPOSE 80 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/api/health || exit 1

# Start services
CMD ["/app/start.sh"] 