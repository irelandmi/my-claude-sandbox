FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    dnsutils \
    iptables \
    iproute2 \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Configure sshd
RUN mkdir -p /run/sshd

# Create claude config directory owned by vscode user
RUN mkdir -p /home/vscode/.claude && chown -R vscode:vscode /home/vscode/.claude

COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh
