FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies required by iii install script + runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl ca-certificates jq tar && \
    rm -rf /var/lib/apt/lists/*

# Install iii engine binary to default location (~/.local/bin)
RUN curl -fsSL https://install.iii.dev/iii/main/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app

# Copy iii project files (config, lock, data dir)
COPY config.yaml iii.lock ./
COPY .iii ./.iii/
RUN mkdir -p ./data

# iii-http listens on 3111, RPC/WebSocket on 49134
EXPOSE 3111 49134

# Health check: hit the iii-http endpoint
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -s -o /dev/null http://localhost:3111/ || exit 1

CMD ["iii", "--config", "config.yaml"]
