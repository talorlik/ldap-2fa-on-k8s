# Stage 1: Build stage (for any potential future build steps like minification)
FROM node:20-alpine AS builder

WORKDIR /app

# Copy source files
COPY src/ ./src/

# In a real-world scenario, you might add build steps here:
# - npm install
# - npm run build (minify, bundle, etc.)

# For now, we just copy the files as-is since we're using vanilla HTML/CSS/JS

# Stage 2: Production stage with nginx
FROM nginx:1.27-alpine

# Remove default nginx configuration
RUN rm -rf /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static files from builder
COPY --from=builder /app/src/ /usr/share/nginx/html/

# Create non-root user and set permissions
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup && \
    chown -R appuser:appgroup /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    chown -R appuser:appgroup /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
