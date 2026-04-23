# Updated xrayvless.sh

# Other existing content

# Key extraction with new x25519 format
local PUBLIC_KEY=$(echo "$KEYS" | grep 'Password' | awk -F ': ' '{print $2}')
local PRIVATE_KEY=$(echo "$KEYS" | grep 'PrivateKey' | awk -F ': ' '{print $2}')
local HASH32=$(echo "$KEYS" | grep 'Hash32' | awk -F ': ' '{print $2}')

# Continue with existing logic
