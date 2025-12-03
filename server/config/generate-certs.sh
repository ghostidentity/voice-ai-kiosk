#!/bin/bash

# SSL Certificate Generation Script for Windows
set -e

echo "=== SSL Certificate Generation ==="

# Check OpenSSL installation first
echo "Checking OpenSSL installation..."
if ! command -v openssl &> /dev/null; then
    echo "ERROR: OpenSSL not found in PATH"
    exit 1
fi

openssl version

# Try different OpenSSL config paths for Windows
declare -a config_paths=(
    "/c/Program Files/OpenSSL-Win64/bin/openssl.cfg"
    "/c/Program Files/OpenSSL-Win32/bin/openssl.cfg"
    "/c/OpenSSL-Win64/bin/openssl.cfg"
    "/c/OpenSSL-Win32/bin/openssl.cfg"
)

CONFIG_FOUND=0
for config_path in "${config_paths[@]}"; do
    if [[ -f "$config_path" ]]; then
        export OPENSSL_CONF="$config_path"
        echo "Using OpenSSL config: $OPENSSL_CONF"
        CONFIG_FOUND=1
        break
    fi
done

if [[ $CONFIG_FOUND -eq 0 ]]; then
    echo "WARNING: No OpenSSL config found, using default"
    # Try to find openssl.cfg in the same directory as openssl executable
    OPENSSL_PATH=$(which openssl)
    if [[ -n "$OPENSSL_PATH" ]]; then
        OPENSSL_DIR=$(dirname "$OPENSSL_PATH")
        if [[ -f "$OPENSSL_DIR/openssl.cfg" ]]; then
            export OPENSSL_CONF="$OPENSSL_DIR/openssl.cfg"
            echo "Using OpenSSL config from executable directory: $OPENSSL_CONF"
            CONFIG_FOUND=1
        fi
    fi
fi

# Create config directory if it doesn't exist
mkdir -p config
cd config

echo "1. Generating CA private key..."
openssl genrsa -out ca.key 4096

echo "2. Generating CA certificate..."
if openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/CN=MyCA/O=SysRefiners" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null; then
    echo "CA certificate generated successfully"
else
    echo "Using alternative method for CA certificate (without addext)"
    cat > ca_config.cnf << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
CN = MyCA
O = SysRefiners

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
EOF
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -config ca_config.cnf
    rm -f ca_config.cnf
fi

echo "3. Generating server private key..."
openssl genrsa -out server.key 4096

echo "4. Generating server certificate signing request..."
if openssl req -new -key server.key -out server.csr \
  -subj "/CN=localhost/O=SysRefiners" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:192.168.88.254" \
  -addext "extendedKeyUsage=serverAuth" 2>/dev/null; then
    echo "Server CSR generated successfully"
else
    echo "Using alternative method for server CSR (without addext)"
    cat > server_csr.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = localhost
O = SysRefiners

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
IP.2 = 192.168.88.254
EOF
    openssl req -new -key server.key -out server.csr -config server_csr.cnf
    rm -f server_csr.cnf
fi

echo "5. Creating server extension file..."
cat > extfile_server.cnf << EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1,IP:192.168.88.254
EOF

echo "6. Generating server certificate..."
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -sha256 -extfile extfile_server.cnf

echo "7. Generating client private key..."
openssl genrsa -out client.key 4096

echo "8. Generating client certificate signing request..."
if openssl req -new -key client.key -out client.csr \
  -subj "/CN=grpc-client/O=SysRefiners" \
  -addext "extendedKeyUsage=clientAuth" 2>/dev/null; then
    echo "Client CSR generated successfully"
else
    echo "Using alternative method for client CSR (without addext)"
    cat > client_csr.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = grpc-client
O = SysRefiners

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF
    openssl req -new -key client.key -out client.csr -config client_csr.cnf
    rm -f client_csr.cnf
fi

echo "9. Creating client extension file..."
cat > extfile_client.cnf << EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
EOF

echo "10. Generating client certificate..."
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -days 365 -sha256 -extfile extfile_client.cnf

echo "11. Cleaning up temporary files..."
rm -f server.csr client.csr ca.srl extfile_server.cnf extfile_client.cnf

echo "12. Verification - checking certificates..."
echo "=== Certificate Details ==="
if [[ -f "ca.crt" ]]; then
    echo "CA Certificate:"
    openssl x509 -in ca.crt -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After"
else
    echo "CA certificate not found"
fi

echo "---"

if [[ -f "server.crt" ]]; then
    echo "Server Certificate:"
    openssl x509 -in server.crt -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After|DNS:|IP Address:" || true
else
    echo "Server certificate not found"
fi

echo "---"

if [[ -f "client.crt" ]]; then
    echo "Client Certificate:"
    openssl x509 -in client.crt -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After"
else
    echo "Client certificate not found"
fi

echo ""
echo "=== SSL Certificate Generation Complete ==="
echo "Generated files in 'config' directory:"
ls -la *.crt *.key

echo ""
echo "File sizes:"
ls -la *.crt *.key | awk '{print $5 " bytes - " $9}'

echo ""
echo "=== Certificate Generation Summary ==="
echo "CA Certificate: $(if [ -f ca.crt ]; then echo '✓'; else echo '✗'; fi)"
echo "Server Certificate: $(if [ -f server.crt ]; then echo '✓'; else echo '✗'; fi)" 
echo "Client Certificate: $(if [ -f client.crt ]; then echo '✓'; else echo '✗'; fi)"
echo "Private Keys: $(if [ -f ca.key ] && [ -f server.key ] && [ -f client.key ]; then echo '✓'; else echo '✗'; fi)"