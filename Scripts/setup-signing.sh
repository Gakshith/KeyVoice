#!/usr/bin/env bash
# Create a STABLE local code-signing identity for KeyVoice development.
#
# Why: KeyVoice needs Input Monitoring + Accessibility, which macOS ties to the app's code-signing
# identity. Ad-hoc signing (`codesign -s -`) derives that identity from the executable's CDHash, so
# EVERY rebuild changes it and macOS drops the permissions you granted. A real certificate gives a
# stable "designated requirement" that survives rebuilds, so grants stick.
#
# If you already have an Apple Development certificate (from Xcode → Settings → Accounts → Manage
# Certificates, or an Apple Developer account), you DON'T need this script — just:
#     export KEYVOICE_CODESIGN_IDENTITY="Apple Development: you@example.com (TEAMID)"
#     ./Scripts/bundle.sh
#
# Otherwise this creates a self-signed Code Signing certificate in a DEDICATED keychain (it never
# touches your login keychain) and adds that keychain to your user search list so codesign finds it.
# It does NOT modify any macOS privacy/TCC records.
set -euo pipefail

IDENTITY_NAME="${KEYVOICE_CODESIGN_IDENTITY:-KeyVoice Dev Signing}"
KEYCHAIN="${KEYVOICE_SIGNING_KEYCHAIN:-$HOME/Library/Keychains/keyvoice-signing.keychain-db}"
KC_PASS="keyvoice-local"   # password for this dedicated signing keychain only — not your login keychain

# Note: a self-signed cert is "not trusted", so it never appears under `find-identity -v` (valid
# only) — we list without -v. codesign still signs with it fine, and the resulting designated
# requirement is anchored to the certificate (stable across rebuilds), which is the whole point.
if security find-identity -p codesigning 2>/dev/null | grep -qF "$IDENTITY_NAME"; then
  echo "Signing identity '$IDENTITY_NAME' already exists — nothing to do."
  echo "Build with:  export KEYVOICE_CODESIGN_IDENTITY=\"$IDENTITY_NAME\" && ./Scripts/bundle.sh"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A self-signed code-signing cert. Config file (not -addext) for portability across openssl/libressl.
cat > "$TMP/req.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $IDENTITY_NAME
[v3]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/req.cnf" 2>/dev/null
# -legacy + SHA1 MAC/PBE so macOS's (older) PKCS#12 importer can verify it — OpenSSL 3's modern
# defaults fail with "MAC verification failed" on import.
openssl pkcs12 -export -name "$IDENTITY_NAME" -legacy -macalg sha1 \
  -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -out "$TMP/identity.p12" -passout pass:"$KC_PASS"

# Dedicated keychain (recreated if present so the script is idempotent).
security delete-keychain "$KEYCHAIN" 2>/dev/null || true
security create-keychain -p "$KC_PASS" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"                       # no auto-lock
security unlock-keychain -p "$KC_PASS" "$KEYCHAIN"
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$KC_PASS" -A -T /usr/bin/codesign >/dev/null
# Let codesign use the key without an interactive prompt (partition list, unlocked with our password).
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KEYCHAIN" >/dev/null 2>&1

# Add our keychain to the user search list WITHOUT dropping the existing ones (login etc.).
EXISTING="$(security list-keychains -d user | sed -e 's/^[[:space:]]*//' -e 's/"//g')"
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN" $EXISTING

echo "Created a stable signing identity:"
security find-identity -p codesigning | grep -F "$IDENTITY_NAME" || {
  echo "  (warning) identity was created but codesign can't see it yet — check the keychain search list." >&2
  exit 1
}
cat <<EOF

Next:
  export KEYVOICE_CODESIGN_IDENTITY="$IDENTITY_NAME"
  ./Scripts/bundle.sh

One-time cleanup — because the signing identity just changed, macOS still holds KeyVoice's OLD
identity in its permission records, so grants won't apply until you clear them once:
  • System Settings → Privacy & Security → Input Monitoring → select KeyVoice → click "–", then
    do the same under Accessibility. Relaunch KeyVoice and grant again.
  • Or, in a terminal:  tccutil reset Accessibility com.keyvoice.app ; tccutil reset ListenEvent com.keyvoice.app
KeyVoice never changes these records for you.
EOF
