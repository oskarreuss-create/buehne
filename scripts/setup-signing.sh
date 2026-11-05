#!/bin/bash
# One-time: create a local self-signed code-signing identity in its own keychain, so rebuilt
# copies keep their macOS privacy permissions (Downloads, Movies, ...). Local use only.
set -euo pipefail
KC="$HOME/Library/Keychains/buehne-signing.keychain-db"
PF="$HOME/Library/Keychains/.buehne-signing-pass"
[ -f "$KC" ] && { echo "already set up: $KC"; exit 0; }
T="$(mktemp -d)"; trap 'rm -r "$T"' EXIT
cat > "$T/c.cnf" <<'EOF'
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=BUEHNE Local Signing
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF
(umask 077; head -c 24 /dev/urandom | base64 > "$PF")
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$T/k.pem" -out "$T/c.pem" -days 3650 -config "$T/c.cnf"
openssl pkcs12 -export -inkey "$T/k.pem" -in "$T/c.pem" -out "$T/c.p12" -passout pass:buehne -legacy
security create-keychain -p "$(cat "$PF")" "$KC"
security set-keychain-settings "$KC"
security unlock-keychain -p "$(cat "$PF")" "$KC"
security import "$T/c.p12" -k "$KC" -P buehne -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$(cat "$PF")" "$KC" >/dev/null
echo "done: $KC"
