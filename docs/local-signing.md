[English](local-signing.md) | [Русский](local-signing.ru.md)

# Stable local signing

*Optional. Only worth doing if you rebuild MacYaD yourself.*

Xcode signs local builds ad-hoc. The code hash changes on every rebuild, so macOS treats each build as a different application and asks for folder access again — every time. A one-time self-signed certificate gives the build a stable designated requirement, and the permissions you grant survive rebuilds.

This is a local development certificate. It is not an Apple Developer identity, it does not notarize anything, and it means nothing on any other Mac.

## Create the certificate

```bash
CERT_NAME="MacYaD Local Development"
WORK="$(mktemp -d)"

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name=req_distinguished_name
x509_extensions=v3_codesign
prompt=no
[req_distinguished_name]
CN=$CERT_NAME
[v3_codesign]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
subjectKeyIdentifier=hash
EOF

openssl req -new -newkey rsa:2048 -nodes -x509 -days 7300 \
  -keyout "$WORK/cert.key" -out "$WORK/cert.crt" -config "$WORK/cert.cnf"
openssl pkcs12 -export -legacy -macalg sha1 \
  -inkey "$WORK/cert.key" -in "$WORK/cert.crt" -name "$CERT_NAME" \
  -out "$WORK/cert.p12" -passout pass:macyad
security import "$WORK/cert.p12" -k ~/Library/Keychains/login.keychain-db \
  -P macyad -A -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$(read -rs -p 'login keychain password: ' p && echo "$p")" \
  ~/Library/Keychains/login.keychain-db
rm -rf "$WORK"
```

The last command grants `codesign` access to the private key without a prompt on every build.

## How the build uses it

`script/build_and_run.sh` re-signs the bundle with this identity automatically, and `script/test.sh` picks it up for test builds so the designated requirement matches the deployed copy — otherwise macOS re-asks for folder access in the middle of a UI test run.

The identity is overridable through `MACYAD_CODESIGN_IDENTITY`, which is also how you pass it to a bare `xcodebuild`:

```bash
MACYAD_CODESIGN_IDENTITY="MacYaD Local Development" ./script/test.sh unit
```

Without the certificate nothing breaks: the scripts print a warning and fall back to an ad-hoc signature.

## Verify

```bash
codesign -dvvv ~/Applications/MacYaD.app 2>&1 | grep -E 'Authority|Signature'
codesign -dr - ~/Applications/MacYaD.app
```

`Authority=MacYaD Local Development` instead of `Signature=adhoc` means the designated requirement is stable and granted permissions will stick.
