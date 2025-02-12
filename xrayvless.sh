#!/bin/bash

# Function to generate a random UUID
generate_uuid() {
  cat /proc/sys/kernel/random/uuid
}

# Function to generate a random port number avoiding common ports
generate_port() {
  while true; do
    PORT=$((RANDOM % 65535 + 1))
    if [[ $PORT -ne 80 && $PORT -ne 443 && $PORT -gt 1024 ]]; then
      echo $PORT
      break
    fi
  done
}

# Function to pick a random server name from the list
generate_server_name() {
  SERVER_NAMES=("www.bing.com" "www.apple.com" "www.microsoft.com")
  echo "${SERVER_NAMES[$RANDOM % ${#SERVER_NAMES[@]}]}"
}

# Function to generate a key pair using Xray
generate_keys() {
  xray x25519
}

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
  "inbounds": [
EOF

# Create a file to store vless links
LINKS_FILE="vless_links.txt"
> $LINKS_FILE

# Function to generate inbound configuration
generate_inbound() {
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
    echo "vless://$UUID@[$IP]:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_NAME&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&spx=0#${TAG}_${SHORT_TAG}" >> $LINKS_FILE
  else
    echo "vless://$UUID@$IP:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_NAME&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&spx=0#${TAG}_${SHORT_TAG}" >> $LINKS_FILE
  fi
}

# Add IPv4 inbounds
for IPV4 in "${IPV4_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV4" | tr -d '.')
  generate_inbound $IPV4 "ipv4-inbound" "$SHORT_TAG"
done

# Add IPv6 inbounds
for IPV6 in "${IPV6_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV6" | tr -d ':' | head -c 8)
  generate_inbound $IPV6 "ipv6-inbound" "$SHORT_TAG"
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
      "settings": {},
      "tag": "ipv4-outbound-$SHORT_TAG"
    },
EOF
done

# Add IPv6 outbounds
for IPV6 in "${IPV6_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV6" | tr -d ':' | head -c 8)
  cat >> config.json <<EOF
    {
      "protocol": "freedom",
      "settings": {},
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
  PORT=$(generate_port)
  cat >> config.json <<EOF
      {
        "type": "field",
        "inboundTag": ["ipv4-inbound-$PORT"],
        "outboundTag": "ipv4-outbound-$SHORT_TAG"
      },
EOF
done

# Add routing rules for IPv6
for IPV6 in "${IPV6_ADDRESSES[@]}"; do
  SHORT_TAG=$(echo "$IPV6" | tr -d ':' | head -c 8)
  PORT=$(generate_port)
  cat >> config.json <<EOF
      {
        "type": "field",
        "inboundTag": ["ipv6-inbound-$PORT"],
        "outboundTag": "ipv6-outbound-$SHORT_TAG"
      },
EOF
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
