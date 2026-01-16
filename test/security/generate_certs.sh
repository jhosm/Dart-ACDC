#!/bin/bash
set -e

# Directory for certificates
CERT_DIR="test/security/certs"
mkdir -p "$CERT_DIR"

# Cleanup old certs
rm -f "$CERT_DIR/server.key" "$CERT_DIR/server.crt" "$CERT_DIR/server.pem"

# 1. Generate Private Key
openssl genrsa -out "$CERT_DIR/server.key" 2048

# 2. Generate Certificate Signing Request (CSR)
# Subject: CN=localhost
openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# 3. Generate Self-Signed Certificate (valid for 365 days)
# Add Subject Alternative Name (SAN) for localhost to ensure it validates correctly
echo "subjectAltName=DNS:localhost,IP:127.0.0.1" > "$CERT_DIR/extfile.cnf"

openssl x509 -req -days 365 \
    -in "$CERT_DIR/server.csr" \
    -signkey "$CERT_DIR/server.key" \
    -out "$CERT_DIR/server.crt" \
    -extfile "$CERT_DIR/extfile.cnf"

# 4. Extract Public Key in SPKI format (for pinning)
# We need the SHA256 hash of the Subject Public Key Info (SPKI)
# Step 4a: Extract public key
openssl x509 -in "$CERT_DIR/server.crt" -pubkey -noout > "$CERT_DIR/server.pub.pem"

# Step 4b: Convert to DER format (binary) -> Calculate SHA256 -> Base64 encode
# Note: openssl x509 -pubkey outputs PEM. checking pin usually involves hashing the DER-encoded SubjectPublicKeyInfo.
SPKI_HASH=$(openssl x509 -in "$CERT_DIR/server.crt" -pubkey -noout | \
    openssl pkey -pubin -outform der | \
    openssl dgst -sha256 -binary | \
    openssl base64)

echo "Generated Certificate in $CERT_DIR"
echo "SPKI SHA-256 Pin: SHA256:$SPKI_HASH"
echo "SHA256:$SPKI_HASH" > "$CERT_DIR/pin.txt"

# Cleanup temp files
rm "$CERT_DIR/server.csr" "$CERT_DIR/extfile.cnf" "$CERT_DIR/server.pub.pem"
