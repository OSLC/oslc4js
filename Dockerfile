# Stage 1: Build
FROM node:22-slim AS builder

WORKDIR /usr/src/app

# Copy package files for workspaces dependency resolution
COPY package*.json ./
COPY storage-service/package*.json ./storage-service/
COPY jena-storage-service/package*.json ./jena-storage-service/
COPY ldp-service/package*.json ./ldp-service/
COPY oslc-service/package*.json ./oslc-service/
COPY oslc-client/package*.json ./oslc-client/
COPY oslc-browser/package*.json ./oslc-browser/
COPY bmm-server/package*.json ./bmm-server/
COPY bmm-server/ui/package*.json ./bmm-server/ui/

# Install workspaces dependencies
RUN npm install

# Copy the entire monorepo source code
COPY . .

# Build workspaces in dependency order
RUN npm run build --workspace=storage-service && \
    npm run build --workspace=jena-storage-service && \
    npm run build --workspace=ldp-service && \
    npm run build --workspace=oslc-service && \
    npm run build --workspace=oslc-browser && \
    npm run build --workspace=bmm-server

# Build the BMM Web UI assets
WORKDIR /usr/src/app/bmm-server/ui
RUN npm install && npm run build

# Stage 2: Runtime
FROM node:22-slim

# Install curl (required for startup checks and population script)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# Copy built workspace and node_modules from builder
COPY --from=builder /usr/src/app /usr/src/app

EXPOSE 3005

WORKDIR /usr/src/app/bmm-server
RUN chmod +x start.sh testing/populate-eurent.sh

CMD ["./start.sh"]
