# Multi-stage Docker build for Node.js application
# Optimized for production deployment with security best practices

# Stage 1: Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /usr/src/app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Install dependencies needed for native modules
RUN apk add --no-cache \
    libc6-compat \
    python3 \
    make \
    g++ \
    git

# Copy package files
COPY package*.json ./
COPY yarn.lock* ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Remove development dependencies and clean up
RUN npm prune --production && \
    rm -rf .git && \
    rm -rf src && \
    rm -rf docs && \
    rm -rf tests

# Stage 2: Production runtime
FROM node:18-alpine AS runner

# Install security updates
RUN apk upgrade --no-cache

# Create app directory
WORKDIR /usr/src/app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Copy built application from builder stage
COPY --from=builder --chown=appuser:nodejs /usr/src/app/dist ./dist
COPY --from=builder --chown=appuser:nodejs /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=appuser:nodejs /usr/src/app/package.json ./package.json

# Create logs directory
RUN mkdir -p /usr/src/app/logs && \
    chown -R appuser:nodejs /usr/src/app/logs

# Health check configuration
COPY --chown=appuser:nodejs healthcheck.js ./healthcheck.js
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node healthcheck.js

# Switch to non-root user
USER appuser

# Expose port (non-privileged port)
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV NPM_CONFIG_LOGLEVEL=warn

# Add labels for metadata
LABEL maintainer="devops@company.com"
LABEL version="1.0.0"
LABEL description="Production Node.js application"
LABEL org.opencontainers.image.source="https://github.com/company/app"

# Set resource limits
ENV NODE_OPTIONS="--max-old-space-size=1024"

# Start the application with dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/server.js"]

# Example docker-compose.yml for local development
# version: '3.8'
# services:
#   app:
#     build: 
#       context: .
#       dockerfile: Dockerfile
#       target: runner
#     ports:
#       - "3000:3000"
#     environment:
#       - NODE_ENV=production
#       - DATABASE_URL=mongodb://mongo:27017/myapp
#       - REDIS_URL=redis://redis:6379
#     depends_on:
#       - mongo
#       - redis
#     restart: unless-stopped
#     volumes:
#       - ./logs:/usr/src/app/logs
#     networks:
#       - app-network
#
#   mongo:
#     image: mongo:5
#     restart: unless-stopped
#     environment:
#       MONGO_INITDB_ROOT_USERNAME: admin
#       MONGO_INITDB_ROOT_PASSWORD: password
#     volumes:
#       - mongo-data:/data/db
#     networks:
#       - app-network
#
#   redis:
#     image: redis:7-alpine
#     restart: unless-stopped
#     command: redis-server --appendonly yes
#     volumes:
#       - redis-data:/data
#     networks:
#       - app-network
#
#   nginx:
#     image: nginx:alpine
#     ports:
#       - "80:80"
#       - "443:443"
#     volumes:
#       - ./nginx.conf:/etc/nginx/nginx.conf:ro
#       - ./ssl:/etc/ssl:ro
#     depends_on:
#       - app
#     restart: unless-stopped
#     networks:
#       - app-network
#
# volumes:
#   mongo-data:
#   redis-data:
#
# networks:
#   app-network:
#     driver: bridge

# Build optimization tips:
# 1. Use .dockerignore to exclude unnecessary files
# 2. Leverage Docker layer caching by copying package.json first
# 3. Use multi-stage builds to reduce final image size
# 4. Run as non-root user for security
# 5. Use specific version tags instead of 'latest'
# 6. Implement health checks for container orchestration
# 7. Set resource limits to prevent container from consuming all host resources
# 8. Use dumb-init for proper signal handling in containers

# Security best practices implemented:
# - Non-root user execution
# - Minimal base image (Alpine Linux)
# - Regular security updates
# - No secrets in Dockerfile
# - Proper file permissions
# - Health check implementation
# - Resource limitations

# Example build commands:
# docker build -t myapp:latest .
# docker build -t myapp:v1.0.0 --target=runner .
# docker run -d -p 3000:3000 --name myapp-container myapp:latest

# Example production deployment with secrets:
# docker run -d \
#   -p 3000:3000 \
#   --name myapp-prod \
#   --restart=unless-stopped \
#   --env-file .env.production \
#   --log-driver=json-file \
#   --log-opt max-size=10m \
#   --log-opt max-file=3 \
#   --memory=512m \
#   --cpus=0.5 \
#   myapp:v1.0.0 