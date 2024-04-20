#!/bin/bash
set -e
warp_path="/var/lib/cloudflare-warp"

# settings from environment variables
warp_license=$WARP_LICENSE
warp_org_id=$WARP_ORG_ID
auth_client_id=$WARP_AUTH_CLIENT_ID
auth_client_secret=$WARP_AUTH_CLIENT_SECRET
unique_client_id=${WARP_UNIQUE_CLIENT_ID:-$(cat /proc/sys/kernel/random/uuid)}

# from secret file if exists
if [ -f "/run/secrets/WARP_LICENSE" ]; then
    warp_license=$(cat /run/secrets/WARP_LICENSE)
fi
if [ -f "/run/secrets/WARP_ORG_ID" ]; then
    warp_org_id=$(cat /run/secrets/WARP_ORG_ID)
fi
if [ -f "/run/secrets/WARP_AUTH_CLIENT_ID" ]; then
    auth_client_id=$(cat /run/secrets/WARP_AUTH_CLIENT_ID)
fi
if [ -f "/run/secrets/WARP_AUTH_CLIENT_SECRET" ]; then
    auth_client_secret=$(cat /run/secrets/WARP_AUTH_CLIENT_SECRET)
fi

# check parameters valid
if [ "$warp_license" ]; then
    if ! echo "$warp_license" | grep -qE '^[a-zA-Z0-9-]{26}$'; then
        echo "[!] Error: WARP_LICENSE invalid! (e.g.: 123456789-abcdef12-4567890a)"
        exit 1
    fi
fi
if [ "$warp_org_id" ]; then
    if ! echo "$warp_org_id" | grep -qE '^[a-z0-9-]{1,}$'; then
        echo "[!] Error: WARP_ORG_ID invalid! (e.g.: deepwn)"
        exit 1
    fi
fi
if [ "$auth_client_id" ]; then
    if ! echo "$auth_client_id" | grep -qE '^[a-z0-9]{32}.access$'; then
        echo "[!] Error: WARP_AUTH_CLIENT_ID invalid! (e.g.: 1234567890abcdef1234567890abcdef.access)"
        exit 1
    fi
fi
if [ "$auth_client_secret" ]; then
    if ! echo "$auth_client_secret" | grep -qE '^[a-z0-9]{64}$'; then
        echo "[!] Error: WARP_AUTH_CLIENT_SECRET invalid! (e.g.: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef)"
        exit 1
    fi
fi
if [ "$unique_client_id" ]; then
    if ! echo "$unique_client_id" | grep -qE '^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$'; then
        echo "[!] Error: WARP_UNIQUE_CLIENT_ID invalid! (e.g.: 12345678-1234-1234-1234-1234567890ab)"
        exit 1
    fi
fi

# start dbus
if [ -n "$(pgrep dbus-daemon)" ]; then
    echo "[+] dbus already running!"
else
    echo "[+] Starting dbus..."
    mkdir -p /run/dbus >/dev/null 2>&1
    rm -rf /run/dbus/pid >/dev/null 2>&1
    dbus-daemon --config-file=/usr/share/dbus-1/system.conf
fi

# bypass warp's TOS
if [ -f "/root/.local/share/warp/accepted-tos.txt" ]; then
    echo "[+] warp's TOS already accepted!"
else
    echo "[+] Bypassing warp's TOS..."
    mkdir -p /root/.local/share/warp
    echo -n 'yes' >/root/.local/share/warp/accepted-tos.txt
fi

# start warp-svc in background
if [ -n "$(pgrep warp-svc)" ]; then
    echo "[+] warp-svc already running!"
else
    echo "[+] Starting warp-svc..."
    nohup /usr/bin/warp-svc >/dev/null 2>&1 &
fi

# wait for warp-svc to start
while [ -z "$(/usr/bin/warp-cli status 2>/dev/null | grep 'Status')" ]; do
    sleep 1
done

# have warp_org_id, auth_client_id, auth_client_secret, but not registered
if [ -n "$warp_org_id" ] && [ -n "$auth_client_id" ] && [ -n "$auth_client_secret" ]; then
    # mdm file exists, but not registered
    sed -e "s/ORGANIZATION/$warp_org_id/g" \
        -e "s/AUTH_CLIENT_ID/$auth_client_id/g" \
        -e "s/AUTH_CLIENT_SECRET/$auth_client_secret/g" \
        -e "s/UNIQUE_CLIENT_ID/$unique_client_id/g" \
        $warp_path/mdm.xml.example >$warp_path/mdm.xml
    echo "[+] Registering mdm save to: $warp_path/mdm.xml"
    echo "[+] you should set policy from Zero Trust dashboard."
    echo "    documents: https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/"
    echo "[!] Careful: New service modes such as Proxy only are not supported as a value and must be configured in Zero Trust."
    echo "    (https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/parameters/#service_mode)"
else
    # license exsits, but not registered
    if [ -n "$warp_license" ]; then
        echo "[+] Set warp license to $warp_license ... $(/usr/bin/warp-cli registration license $warp_license)"
    fi
    # no license, but not registered
    echo "[+] New registration generated ... $(/usr/bin/warp-cli registration new)"

    # change the operation mode to warp and set the port (mdm is not needed in this case, should set tproxy mode in Zero Trust dashboard.)
    echo "[+] Set warp mode to warp ... $(/usr/bin/warp-cli mode warp)"
fi

# wait for warp to connect
echo "[+] Turn ON warp ... $(/usr/bin/warp-cli connect)"

# wait for warp status to be connecting
echo "[+] Waiting for warp to connect..."
while [ -z "$(/usr/bin/warp-cli status 2>/dev/null | grep 'Status' | grep 'Connected')" ]; do
    echo -n "."
    sleep 5
done

echo -e "\033[2K\r[+] warp connected!"

# logging output
echo "[+] All services started!"
echo "---"
echo "warp-svc config: $warp_path/conf.json"
echo "---"
echo "[+] warp status: $(/usr/bin/warp-cli status | grep 'Status')"
echo ""
# https://cloudflare.com/cdn-cgi/trace will show the warp ip
echo "[+] You can check it with warp local tproxy in container:"
echo "    E.g.:"
echo "      curl -x https://cloudflare.com/cdn-cgi/trace (inside container)"

# keep checking warp status
connect_lost=false
while true; do
    # loading print dots at same line
    if [ -z "$(/usr/bin/warp-cli status | grep 'Status' | grep 'Connected')" ]; then
        if [ "$connect_lost" = false ]; then
            #clear line and print new line
            echo -e "\033[2K\r[!] warp connection lost! retrying..."
            connect_lost=true
            /usr/bin/warp-cli registration delete >/dev/null 2>&1 &&
                /usr/bin/warp-cli registration new >/dev/null 2>&1 &&
                /usr/bin/warp-cli connect >/dev/null 2>&1
        fi
        /usr/bin/warp-cli connect >/dev/null 2>&1
        echo -n "."
    fi
    sleep 5
done
