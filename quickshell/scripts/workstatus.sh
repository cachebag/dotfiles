#!/usr/bin/env bash
# Emits "TUNNEL:<state> PROXY:<region> KRB:<seconds-left>" for WorkStatus.qml.
# Mirrors what vpnfix/whichproxy check, so the bar and the shell agree.

# --- VPN tunnel -------------------------------------------------------------
if ip link show tun0 >/dev/null 2>&1; then
    tunnel=up
else
    tunnel=down
fi

# --- Proxy upstream ---------------------------------------------------------
# The proxy pins its upstream at startup, so the region only changes on restart.
proxy=off
pid=$(systemctl --user show proxy.service -p MainPID --value 2>/dev/null)
if [[ -n $pid && $pid != 0 ]]; then
    ip=$(ss -tnp 2>/dev/null | grep "pid=$pid," | awk '{print $5}' | grep -v '^127' \
        | cut -d: -f1 | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    case $ip in
        10.224.200.25) proxy=NA ;;
        10.171.234.13) proxy=INDIA ;;
        10.4.103.143)  proxy=GERMANY ;;
        10.187.197.9)  proxy=APAC ;;
        "")            proxy=idle ;;
        *)             proxy=unknown ;;
    esac
fi

# --- Kerberos ticket --------------------------------------------------------
# -1 means no valid ticket at all.
krb=-1
if klist -s 2>/dev/null; then
    exp=$(klist 2>/dev/null | awk '/krbtgt/{print $3" "$4; exit}')
    if [[ -n $exp ]]; then
        exp_epoch=$(date -d "$exp" +%s 2>/dev/null)
        if [[ -n $exp_epoch ]]; then
            krb=$((exp_epoch - $(date +%s)))
            ((krb < 0)) && krb=-1
        fi
    fi
fi

printf 'TUNNEL:%s PROXY:%s KRB:%s\n' "$tunnel" "$proxy" "$krb"
