#!/bin/bash

# Generate self-signed SSL certificates for local development and Cloudflare Tunnel
# Supports wildcards for scalability across multiple services
# 
# Environment variables:
#   CERT_DOMAIN - Root domain (default: example.com)

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSL_DIR="$BASE_DIR/nginx/ssl"
CERT_DOMAIN="${CERT_DOMAIN}"

if [ -z "$CERT_DOMAIN" ]; then
  echo "Error: CERT_DOMAIN environment variable is not set."
  echo "Please set CERT_DOMAIN to your desired root domain (e.g., example.com)."
  exit 1
fi

echo "Creating SSL certificates in: $SSL_DIR"
echo "Domain: $CERT_DOMAIN (covers *.$CERT_DOMAIN and *.local)"

# Create directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Create OpenSSL config file with SAN
cat > "$SSL_DIR/openssl.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[dn]
C = IT
ST = Lombardy
L = Milan
O = HomeServer
OU = IT
CN = ${CERT_DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${CERT_DOMAIN}
DNS.2 = *.local
EOF

# Generate private key
openssl genrsa -out "$SSL_DIR/key.pem" 2048

# Generate certificate signing request with SAN
openssl req -new -key "$SSL_DIR/key.pem" -out "$SSL_DIR/cert.csr" -config "$SSL_DIR/openssl.cnf"

# Generate self-signed certificate with SAN
openssl x509 -req -days 365 -in "$SSL_DIR/cert.csr" -signkey "$SSL_DIR/key.pem" -out "$SSL_DIR/cert.pem" -extensions req_ext -extfile "$SSL_DIR/openssl.cnf"

# Set proper permissions
chmod 600 "$SSL_DIR/key.pem"
chmod 644 "$SSL_DIR/cert.pem"

# Clean up
rm "$SSL_DIR/cert.csr" "$SSL_DIR/openssl.cnf"

echo "SSL certificates generated in $SSL_DIR"
echo "SANs: *.${CERT_DOMAIN}, *.local"