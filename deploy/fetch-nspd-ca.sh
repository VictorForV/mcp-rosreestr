#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
DESTINATION=${1:-"$PROJECT_DIR/certs/russian_trusted_root_ca.pem"}

# Official Russian Trusted Root CA (RSA 2022), currently used in the NSPD TLS chain.
CERTIFICATE_URL="http://nuc-cdp.digital.gov.ru/cdp/rootca_ssl_rsa2022.crt"
EXPECTED_SHA256="D26D2D0231B7C39F92CC738512BA54103519E4405D68B5BD703E9788CA8ECF31"

for command_name in curl openssl awk tr mkdir dirname mktemp chmod mv rm; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Required command is missing: $command_name" >&2
        exit 1
    fi
done

mkdir -p "$(dirname -- "$DESTINATION")"
download_file=$(mktemp)
pem_file=$(mktemp)
trap 'rm -f "$download_file" "$pem_file"' EXIT HUP INT TERM

echo "Downloading the NSPD trust anchor from $CERTIFICATE_URL"
curl --fail --silent --show-error --location --proto '=http' \
    "$CERTIFICATE_URL" --output "$download_file"

if ! openssl x509 -in "$download_file" -outform PEM -out "$pem_file" 2>/dev/null; then
    openssl x509 -inform DER -in "$download_file" -outform PEM -out "$pem_file"
fi

actual_sha256=$(
    openssl x509 -in "$pem_file" -outform DER \
        | openssl dgst -sha256 \
        | awk '{print $NF}' \
        | tr '[:lower:]' '[:upper:]'
)

if [ "$actual_sha256" != "$EXPECTED_SHA256" ]; then
    echo "Certificate fingerprint mismatch." >&2
    echo "Expected: $EXPECTED_SHA256" >&2
    echo "Actual:   $actual_sha256" >&2
    exit 1
fi

chmod 0644 "$pem_file"
mv "$pem_file" "$DESTINATION"
echo "Verified certificate written to $DESTINATION"
