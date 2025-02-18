#!/bin/bash

# Function to check if Xray is installed and install it if not
check_and_install_xray() {
  if ! command -v xray &> /dev/null; then
    echo "Xray not found. Installing Xray..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    echo "Xray installed successfully."
  else
    echo "Xray is already installed."
  fi
}

# Function to generate a random UUID
generate_uuid() {
  cat /proc/sys/kernel/random/uuid
}

# Function to generate a random port number avoiding common ports and checking if the port is free
generate_port() {
  while true; do
    PORT=$((RANDOM % 65535 + 1))
    if [[ $PORT -ne 80 && $PORT -ne 443 && $PORT -gt 1024 ]]; then
      if ! lsof -i:$PORT >/dev/null; then
        echo $PORT
        break
      fi
    fi
  done
}

# Function to pick a random server name from the list
generate_server_name() {
  SERVER_NAMES=("www.bing.com" "www.apple.com" "www.microsoft.com" "gateway.icloud.com" "itunes.apple.com" "swdist.apple.com" "mensura.cdn-apple.com" "aod.itunes.apple.com" "addons.mozilla.org")
  echo "${SERVER_NAMES[$RANDOM % ${#SERVER_NAMES[@]}]}"
}

# Function to generate a key pair using Xray
generate_keys() {
  xray x25519
}

check_and_install_xray

# Get server IP addresses
SERVER_IPS=$(hostname -I | tr ' ' '\n' | grep -v '^$')

# Separate IPv4 and IPv6 addresses
IPV4_ADDRESSES=()
IPV6_ADDRESSES=()

for IP in $SERVER_IPS; do
  if [[ $IP == *":"* ]]; then
    IPV6_ADDRESSES+=($IP)
  else
    IPV4_ADDRESSES+=($IP)
  fi
done

# Generate random UUID
UUID=$(generate_uuid)

# Create Xray configuration
cat > config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
EOF

# Create a file to store vless links
LINKS_FILE="vless_links.txt"
> $LINKS_FILE

# Function to generate inbound configuration for VLESS
generate_vless_inbound() {
  local IP=$1
  local TAG=$2
  local SHORT_TAG=$3
  local PORT=$(generate_port)
  local SERVER_NAME=$(generate_server_name)
  local KEYS=$(generate_keys)
  local PUBLIC_KEY=$(echo "$KEYS" | grep 'Public' | awk '{print $3}')
  local PRIVATE_KEY=$(echo "$KEYS" | grep 'Private' | awk '{print $3}')
  local SHORT_ID=$(head /dev/urandom | tr -dc a-f0-9 | head -c 8)

  cat >> config.json <<EOF
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision",
            "level": 0,
            "email": "user@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SERVER_NAME:443",
          "xver": 0,
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"],
          "serverNames": ["$SERVER_NAME"]
        }
      },
      "tag": "$TAG-$PORT"
    },
EOF

  # Generate VLESS link and append to the file
  if [[ $IP == *":"* ]]; then
    echo "vless://$UUID@[$IP]:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&type=tcp&sni=$SERVER_NAME&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&spx=0#${TAG}_${SHORT_TAG}" >> $LINKS_FILE
  else
    echo "vless://$UUID@$IP:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&type=tcp&sni=$SERVER_NAME&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&spx=0#${TAG}_${SHORT_TAG}" >> $LINKS_FILE
  fi

  # Return the generated tag
  echo "$TAG-$PORT"
}

# Function to generate inbound configuration for Shadowsocks
generate_shadowsocks_inbound() {
  local IP=$1
  local TAG=$2
  local SHORT_TAG=$3
  local PORT=$(generate_port)
  local PASSWORD=$(generate_uuid)
  local METHOD="aes-256-gcm"

  cat >> config.json <<EOF
    {
      "port": $PORT,
      "protocol": "shadowsocks",
      "settings": {
        "method": "$METHOD",
        "password": "$PASSWORD",
        "network": "tcp,udp",
        "level": 0
      },
      "tag": "$TAG-$PORT"
    },
EOF

  # Generate Shadowsocks link and append to the file
  if [[ $IP == *":"* ]]; then
    echo "ss://$(echo -n "$METHOD:$PASSWORD" | base64)@[$IP]:$PORT#${TAG}_${SHORT_TAG}" >> $LINKS_FILE
  else
    echo "ss://$(echo -n "$METHOD:$PASSWORD" | base64)@$IP:$PORT#${TAG}_${SHORT_TAG}" >> $LINKS_FILE
  fi

  # Return the generated tag
  echo "$TAG-$PORT"
}

# Add IPv4 inbounds for VLESS and Shadowsocks
declare -A IPV4_TAGS
for IPV4 in "${IPV4_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV4" | tr -d '.')
  VLESS_TAG=$(generate_vless_inbound $IPV4 "ipv4-vless-inbound" "$SHORT_TAG")
  SS_TAG=$(generate_shadowsocks_inbound $IPV4 "ipv4-ss-inbound" "$SHORT_TAG")
  IPV4_TAGS[$SHORT_TAG]="$VLESS_TAG $SS_TAG"
done

# Add IPv6 inbounds for VLESS and Shadowsocks
declare -A IPV6_TAGS
for IPV6 in "${IPV6_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV6" | tr -d ':' | head -c 8)
  VLESS_TAG=$(generate_vless_inbound $IPV6 "ipv6-vless-inbound" "$SHORT_TAG")
  SS_TAG=$(generate_shadowsocks_inbound $IPV6 "ipv6-ss-inbound" "$SHORT_TAG")
  IPV6_TAGS[$SHORT_TAG]="$VLESS_TAG $SS_TAG"
done

# Remove the last comma from the inbounds section
sed -i '$ s/,$//' config.json

cat >> config.json <<EOF
  ],
  "outbounds": [
EOF

# Add IPv4 outbounds
for IPV4 in "${IPV4_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV4" | tr -d '.')
  cat >> config.json <<EOF
    {
      "protocol": "freedom",
      "settings": {"domainStrategy":"ForceIPv4"},
      "tag": "ipv4-outbound-$SHORT_TAG"
    },
EOF
done

# Add IPv6 outbounds
for IPV6 in "${IPV6_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV6" | tr -dc ':' | head -c 8)
  cat >> config.json <<EOF
    {
      "protocol": "freedom",
      "settings": {"domainStrategy":"ForceIPv6"},
      "tag": "ipv6-outbound-$SHORT_TAG"
    },
EOF
done

# Remove the last comma from the outbounds section
sed -i '$ s/,$//' config.json

cat >> config.json <<EOF
  ],
  "routing": {
    "rules": [
EOF

# Add routing rules for IPv4
for IPV4 in "${IPV4_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV4" | tr -d '.')
  TAGS=${IPV4_TAGS[$SHORT_TAG]}
  for TAG in $TAGS; do
    cat >> config.json <<EOF
      {
        "type": "field",
        "inboundTag": ["$TAG"],
        "outboundTag": "ipv4-outbound-$SHORT_TAG"
      },
EOF
  done
done

# Add routing rules for IPv6
for IPV6 in "${IPV6_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV6" | tr -d ':' | head -c 8)
  TAGS=${IPV6_TAGS[$SHORT_TAG]}
  for TAG in $TAGS; do
    cat >> config.json <<EOF
      {
        "type": "field",
        "inboundTag": ["$TAG"],
        "outboundTag": "ipv6-outbound-$SHORT_TAG"
      },
EOF
  done
done

# Remove the last comma from the routing rules section
sed -i '$ s/,$//' config.json

cat >> config.json <<EOF
    ]
  }
}
EOF

echo "Xray configuration generated successfully!"
echo "UUID: $UUID"
echo "Server IPs: $SERVER_IPS"
echo "VLESS links have been saved to $LINKS_FILE"
cat $LINKS_FILE

# Copy the configuration file to the Xray directory
sudo mkdir -p /usr/local/etc/xray
sudo cp config.json /usr/local/etc/xray/config.json

# Start Xray with the generated configuration
# sudo xray -config /usr/local/etc/xray/config.json
systemctl restart xray
