# Kiosk AI
A voice-powered kiosk system for handling customer orders through natural language interaction.

## Features
- Voice-Activated Ordering - Hands-free customer interaction
- Natural Language Processing - Understands conversational requests
- Real-Time Confirmation - Instant receipt printing
- End-to-End Encryption - Secure communication throughout
- Windows Service Deployment - Run as background service for 24/7 operation
- Flexible Integration - Local apps via Named Pipes, remote systems via HTTP Callbacks

### Prerequisites
- Valid Gemini API key (create one at https://aistudio.google.com/api-keys)
- Valid SSL certificates (see Certificate Management section below)
- Raspberry PI 5 w/ microphone, speaker and monitor.

### Configuration

Before running the server, update the `core.xml` config file with:
- A valid `GoogleAPIKey`
- The `OrderConfirmationCallBackUrl` for order callbacks

### Running the Server as standalone program
```bash
kiosk-server-windows-amd64.exe 
```

**Note:** The server can be configured to run as a Windows service so it starts automatically on boot, you can execute "manager.bat install" on terminal.  Once the service is installed, you can create a custom program to listen to pipe called "KioskOrderConfirmation". The server will send order confirmation to the pipe. You can use the sample code "program.cs" as a reference.

### Certificate Management

Generate the required keys for server and client:

**Windows:**
```bash
generate-certs.bat
```

**Linux/Mac:**
```bash
bash generate-certs.sh
```

**Important:** 
- Update the OpenSSL path in the script before executing it
- You can use the stored keys in the config folder but its valid for 1 year only or generate your own key.

**For Client:**
- The client installer includes default keys, but you should update them manually for production use
- Client configuration and keys are located in `/opt/sysrefiners/config`
- Copy your generated keys to this directory after installation

## Client

Install on Raspberry Pi 5 device w/ microphone, speaker and monitor connected to it.  The user that will install the program must have root permission.

**Important:** The server must be running before installing and starting the client. 

### Pre-Installation

Before installation, update the `/etc/environment` file with the following values:
```bash
sudo nano /etc/environment
```

Add these lines:  (note that id will be populated during installation of debian file.)
```
PULSE_SERVER=/run/user/1000/pulse/native
XDG_RUNTIME_DIR=/run/user/1000
```

Save the file and apply the changes:
```bash
source /etc/environment
```

### Installation

Install the client package:
```bash
tmpfile=$(mktemp) && wget -4 -O "$tmpfile" https://raw.githubusercontent.com/ghostidentity/voice-ai-kiosk/main/client/kiosk-client_1.0.0_arm64.deb && sudo DEBIAN_FRONTEND=dialog dpkg -i "$tmpfile" && sudo apt-get install -f && rm -f "$tmpfile"
```

Follow the instructions during installation.

### Uninstall
```bash
sudo dpkg -r kiosk-client
```

## Order Callback Integration

You can register at https://www.make.com/en/register?pc=mtagab to create workflows. For instance, when the callback URL receives a new request, it can be chained to add the order to Airtable.

## Receipt Printing

The client can print order confirmation receipts, but this requires connecting the Raspberry Pi 5 device to a Bluetooth thermal printer first.

## Security

- Both the server and client communicate via gRPC protocol. Before they can establish a connection, the keys must be valid (e.g., `ca.crt`, `ca.key`, `server.key`, etc.).
- Incoming/outgoing audio data is encrypted using Post-Quantum Cryptography except for application updates.

## Runtime

- The server will persistently connect to the Google Live server. This prcoess will incur additional cost if u are using paid option.
- The client will run as a service, automatically connect to the server, and will attempt to reconnect if disconnected.

## Billing

- Gemini Live API offers a free tier that you can use. However, the paid options offer higher rate limits and lower latency.

## Support
-  You can send funds via paypal using the email provided below
-  Or subscribe to paid subscription at https://www.make.com/en/register?pc=mtagab

## Author

Mark Tagab  
mtagab@outlook.com
