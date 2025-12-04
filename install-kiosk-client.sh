#!/bin/bash
set -e

# Get the current user ID
USER_ID=$(id -u)
echo "Detected current user ID: $USER_ID"

# Add environment variables if not already present
ENV_FILE="/etc/environment"
if ! grep -q "PULSE_SERVER" "$ENV_FILE"; then
    echo "Adding environment variables to $ENV_FILE..."
    echo "PULSE_SERVER=/run/user/$USER_ID/pulse/native" | sudo tee -a "$ENV_FILE"
    echo "XDG_RUNTIME_DIR=/run/user/$USER_ID" | sudo tee -a "$ENV_FILE"
fi

# Reload environment variables
echo "Reloading environment variables..."
source "$ENV_FILE"

# Download and install the .deb package
echo "Downloading and installing kiosk-client..."
tmpfile=$(mktemp)
wget -4 -O "$tmpfile" https://raw.githubusercontent.com/ghostidentity/voice-ai-kiosk/main/client/kiosk-client_1.0.0_arm64.deb
sudo DEBIAN_FRONTEND=dialog dpkg -i "$tmpfile"
sudo apt-get install -f
rm -f "$tmpfile"

echo "Installation complete!"
