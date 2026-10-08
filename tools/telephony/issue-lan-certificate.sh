#!/bin/sh
# Run as root inside the gateway VM. Creates a separate leaf; never overwrites
# the current trusted pilot certificate or expands trust in its CA.
set -eu
TASK_CERT_IP=${1:-192.168.1.109}
case "$TASK_CERT_IP" in *[!0-9.]*|'') exit 2;; esac
TASK_CERT_DIR=/etc/asterisk/keys
umask 077
openssl req -new -newkey rsa:2048 -nodes -keyout "$TASK_CERT_DIR/telephony-lan.key" -out "$TASK_CERT_DIR/telephony-lan.csr" -subj /CN=ais-telephony-gateway
TASK_CERT_EXT=$(mktemp)
trap 'rm -f "$TASK_CERT_EXT"' EXIT
cat > "$TASK_CERT_EXT" <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1,IP:$TASK_CERT_IP
EOF
openssl x509 -req -in "$TASK_CERT_DIR/telephony-lan.csr" -CA /root/ais-pilot-ca/ca.crt -CAkey /root/ais-pilot-ca/ca.key -CAcreateserial -out "$TASK_CERT_DIR/telephony-lan.crt" -days 90 -sha256 -extfile "$TASK_CERT_EXT"
chown root:asterisk "$TASK_CERT_DIR/telephony-lan.key" "$TASK_CERT_DIR/telephony-lan.crt"
chmod 640 "$TASK_CERT_DIR/telephony-lan.key"
chmod 644 "$TASK_CERT_DIR/telephony-lan.crt"
# Trust only this CA:FALSE leaf on each workstation, following local OS prompts.
