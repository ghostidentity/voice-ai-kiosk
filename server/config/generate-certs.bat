@echo off
setlocal enabledelayedexpansion

echo === SSL Certificate Generation for Windows ===

:: Set the correct OpenSSL configuration path
set OPENSSL_CONF=C:\Program Files\OpenSSL-Win64\bin\openssl.cfg
echo Using OpenSSL config: %OPENSSL_CONF%

:: Check if the config file exists
if not exist "%OPENSSL_CONF%" (
    echo ERROR: OpenSSL config file not found at: %OPENSSL_CONF%
    echo Please check your OpenSSL installation
    pause
    exit /b 1
)

:: Check if OpenSSL is available
openssl version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: OpenSSL not found in PATH
    echo Please ensure OpenSSL is installed and available in system PATH
    pause
    exit /b 1
)

echo OpenSSL found, continuing...

:: Create config directory if it doesn't exist
if not exist config mkdir config
cd config

echo 1. Generating CA private key...
openssl genrsa -out ca.key 4096
if %errorlevel% neq 0 (
    echo ERROR: Failed to generate CA private key
    pause
    exit /b 1
)

echo 2. Generating CA certificate...
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=MyCA/O=SysRefiners" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"
if %errorlevel% neq 0 (
    echo ERROR: Failed to generate CA certificate
    echo Trying alternative method without addext...
    goto :alternative_method
)

echo 3. Generating server private key...
openssl genrsa -out server.key 4096

echo 4. Generating server certificate signing request...
openssl req -new -key server.key -out server.csr -subj "/CN=localhost/O=SysRefiners" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:192.168.88.254" -addext "extendedKeyUsage=serverAuth"
if %errorlevel% neq 0 (
    echo ERROR: Failed to generate server CSR
    echo Trying alternative method...
    goto :alternative_method
)

echo 5. Creating server extension file...
(
echo basicConstraints=CA:FALSE
echo keyUsage=digitalSignature,keyEncipherment
echo extendedKeyUsage=serverAuth
echo subjectAltName=DNS:localhost,IP:127.0.0.1,IP:192.168.88.254
) > extfile_server.cnf

echo 6. Generating server certificate...
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256 -extfile extfile_server.cnf

echo 7. Generating client private key...
openssl genrsa -out client.key 4096

echo 8. Generating client certificate signing request...
openssl req -new -key client.key -out client.csr -subj "/CN=grpc-client/O=SysRefiners" -addext "extendedKeyUsage=clientAuth"

echo 9. Creating client extension file...
(
echo basicConstraints=CA:FALSE
echo keyUsage=digitalSignature,keyEncipherment
echo extendedKeyUsage=clientAuth
) > extfile_client.cnf

echo 10. Generating client certificate...
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256 -extfile extfile_client.cnf

echo 11. Cleaning up temporary files...
del server.csr client.csr ca.srl extfile_server.cnf extfile_client.cnf 2>nul

goto :verification

:alternative_method
echo Using alternative method with config files...

echo Creating CA config file...
(
echo [req]
echo distinguished_name = req_distinguished_name
echo x509_extensions = v3_ca
echo prompt = no
echo.
echo [req_distinguished_name]
echo CN = MyCA
echo O = SysRefiners
echo.
echo [v3_ca]
echo basicConstraints = critical,CA:TRUE
echo keyUsage = critical,keyCertSign,cRLSign
) > ca_config.cnf

echo Generating CA certificate...
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -config ca_config.cnf

echo Creating server CSR config...
(
echo [req]
echo distinguished_name = req_distinguished_name
echo req_extensions = v3_req
echo prompt = no
echo.
echo [req_distinguished_name]
echo CN = localhost
echo O = SysRefiners
echo.
echo [v3_req]
echo basicConstraints = CA:FALSE
echo keyUsage = digitalSignature, keyEncipherment
echo extendedKeyUsage = serverAuth
echo subjectAltName = @alt_names
echo.
echo [alt_names]
echo DNS.1 = localhost
echo IP.1 = 127.0.0.1
echo IP.2 = 192.168.88.254
) > server_csr.cnf

echo Generating server certificate signing request...
openssl req -new -key server.key -out server.csr -config server_csr.cnf

echo Creating server extension file...
(
echo basicConstraints=CA:FALSE
echo keyUsage=digitalSignature,keyEncipherment
echo extendedKeyUsage=serverAuth
echo subjectAltName=DNS:localhost,IP:127.0.0.1,IP:192.168.88.254
) > extfile_server.cnf

echo Generating server certificate...
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256 -extfile extfile_server.cnf

echo Creating client CSR config...
(
echo [req]
echo distinguished_name = req_distinguished_name
echo req_extensions = v3_req
echo prompt = no
echo.
echo [req_distinguished_name]
echo CN = grpc-client
echo O = SysRefiners
echo.
echo [v3_req]
echo basicConstraints = CA:FALSE
echo keyUsage = digitalSignature, keyEncipherment
echo extendedKeyUsage = clientAuth
) > client_csr.cnf

echo Generating client certificate signing request...
openssl req -new -key client.key -out client.csr -config client_csr.cnf

echo Creating client extension file...
(
echo basicConstraints=CA:FALSE
echo keyUsage=digitalSignature,keyEncipherment
echo extendedKeyUsage=clientAuth
) > extfile_client.cnf

echo Generating client certificate...
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -sha256 -extfile extfile_client.cnf

echo Cleaning up temporary files...
del *.csr *.srl *.cnf 2>nul

:verification
echo 12. Verification - checking certificates...
echo === Certificate Details ===
if exist ca.crt (
    openssl x509 -in ca.crt -text -noout | findstr "Subject: Issuer: Not Before Not After"
) else (
    echo CA certificate not found
)
echo ---
if exist server.crt (
    openssl x509 -in server.crt -text -noout | findstr "Subject: Issuer: Not Before Not After DNS: IP Address:"
) else (
    echo Server certificate not found
)
echo ---
if exist client.crt (
    openssl x509 -in client.crt -text -noout | findstr "Subject: Issuer: Not Before Not After"
) else (
    echo Client certificate not found
)

echo.
echo === SSL Certificate Generation Complete ===
echo Generated files in 'config' directory:
dir *.crt *.key /b

echo.
echo Files created:
if exist ca.crt echo   - ca.crt     (Certificate Authority)
if exist server.key echo   - server.key (Server private key)
if exist server.crt echo   - server.crt (Server certificate)
if exist client.key echo   - client.key (Client private key)
if exist client.crt echo   - client.crt (Client certificate)

pause