#!/bin/bash
# init-firewall.sh — Restrict outbound network to essential services only
set -e

echo "🔒 Initialising sandbox firewall..."

ALLOWED_DOMAINS=(
    "api.anthropic.com"
    "claude.ai"
    "console.anthropic.com"
    "statsig.anthropic.com"
    "sentry.io"
    "github.com"
    "api.github.com"
    "registry.npmjs.org"
    "objects.githubusercontent.com"
)

iptables -F OUTPUT 2>/dev/null || true
iptables -F INPUT 2>/dev/null || true

iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

for domain in "${ALLOWED_DOMAINS[@]}"; do
    ips=$(dig +short "$domain" 2>/dev/null | grep -E '^[0-9]' || true)
    for ip in $ips; do
        iptables -A OUTPUT -d "$ip" -j ACCEPT
        echo "  ✅ Allowed: $domain → $ip"
    done
done

iptables -A OUTPUT -d 169.254.0.0/16 -j ACCEPT
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT

iptables -A OUTPUT -j DROP
echo "🔒 Firewall active."
