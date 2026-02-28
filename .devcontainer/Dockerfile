FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/vscode/.claude && chown -R vscode:vscode /home/vscode/.claude
