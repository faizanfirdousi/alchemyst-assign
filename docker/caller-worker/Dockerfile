FROM node:20-slim

WORKDIR /app

# Copy package files first for better Docker layer caching
COPY workers/caller-worker/package.json workers/caller-worker/package-lock.json* ./

# Install dependencies
RUN npm install

# Copy application source
COPY workers/caller-worker/tsconfig.json ./
COPY workers/caller-worker/src ./src/

# III_URL is injected at runtime via docker-compose env
ENV III_URL=ws://localhost:49134

CMD ["npx", "tsx", "src/worker.ts"]
