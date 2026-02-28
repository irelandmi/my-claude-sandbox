FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    dnsutils \
    iptables \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Create task directories
RUN mkdir -p /workspace/tasks /workspace/results /workspace/logs

# Create claude config directory owned by vscode user
RUN mkdir -p /home/vscode/.claude && chown -R vscode:vscode /home/vscode/.claude

# Copy scripts
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh
