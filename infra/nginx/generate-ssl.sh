#!/bin/bash

# Generate self-signed SSL certificates for local development
# Run this script to create SSL certificates for nginx

# Detect if we're running on macOS or Pi and set appropriate path
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    SSL_DIR="$BASE_DIR/nginx/ssl"
else
    # Linux (Raspberry Pi)
    SSL_DIR="/home/giorgiocaizzi/rp5-homeserver/infra/nginx/ssl"
fi

echo "Creating SSL certificates in: $SSL_DIR"

# Create directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Generate private key
openssl genrsa -out "$SSL_DIR/key.pem" 2048

# Generate certificate signing request
openssl req -new -key "$SSL_DIR/key.pem" -out "$SSL_DIR/cert.csr" -subj "/C=IT/ST=Lombardy/L=Milan/O=HomeServer/OU=IT/CN=*.local"

# Generate self-signed certificate
openssl x509 -req -days 365 -in "$SSL_DIR/cert.csr" -signkey "$SSL_DIR/key.pem" -out "$SSL_DIR/cert.pem"

# Set proper permissions
chmod 600 "$SSL_DIR/key.pem"
chmod 644 "$SSL_DIR/cert.pem"

# Clean up CSR
rm "$SSL_DIR/cert.csr"

echo "SSL certificates generated in $SSL_DIR"