[English](local-signing.md) | [Русский](local-signing.ru.md)

# Стабильная локальная подпись

*Опционально. Имеет смысл, только если вы сами пересобираете MacYaD.*

Xcode подписывает локальные сборки ad-hoc. Хеш кода меняется при каждой пересборке, поэтому macOS считает каждую сборку новым приложением и заново спрашивает доступ к папкам — каждый раз. Одноразовый self-signed сертификат даёт сборке стабильный designated requirement, и выданные разрешения переживают пересборки.

Это локальный сертификат для разработки. Он не является Apple Developer identity, ничего не нотаризует и не значит ничего на любом другом Mac.

## Создание сертификата

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

Последняя команда выдаёт `codesign` доступ к приватному ключу, чтобы он не спрашивал пароль при каждой сборке.

## Как её использует сборка

`script/build_and_run.sh` автоматически переподписывает бандл этим сертификатом, а `script/test.sh` подставляет его для тестовых сборок, чтобы designated requirement совпадал с задеплоенной копией — иначе macOS переспросит доступ к папкам прямо посреди прогона UI-тестов.

Identity переопределяется через `MACYAD_CODESIGN_IDENTITY` — так же она передаётся и в «голый» `xcodebuild`:

```bash
MACYAD_CODESIGN_IDENTITY="MacYaD Local Development" ./script/test.sh unit
```

Без сертификата ничего не ломается: скрипты печатают предупреждение и оставляют ad-hoc подпись.

## Проверка

```bash
codesign -dvvv ~/Applications/MacYaD.app 2>&1 | grep -E 'Authority|Signature'
codesign -dr - ~/Applications/MacYaD.app
```

`Authority=MacYaD Local Development` вместо `Signature=adhoc` означает, что designated requirement больше не меняется между сборками и выданные разрешения сохранятся.
