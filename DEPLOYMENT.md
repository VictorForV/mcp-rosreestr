# Развёртывание mcp-rosreestr

В репозитории есть два варианта: безопасный локальный HTTP endpoint и подключение
к уже существующему reverse proxy через общую Docker-сеть.

## Требования

- Docker Engine с Compose v2;
- `curl` и `openssl` для получения и проверки сертификата НСПД;
- исходящие HTTPS-соединения к `nspd.gov.ru`.

## Быстрый локальный запуск

```bash
git clone https://github.com/VictorForV/mcp-rosreestr.git
cd mcp-rosreestr
./deploy/fetch-nspd-ca.sh
docker compose up -d --build
docker compose ps
```

Сервис будет доступен только локально:

```text
http://127.0.0.1:8000/mcp
```

Адрес и порт можно переопределить в `.env`:

```dotenv
MCP_ROSREESTR_BIND_ADDRESS=127.0.0.1
MCP_ROSREESTR_BIND_PORT=8000
MCP_ROSREESTR_HTTP_TIMEOUT=20
MCP_ROSREESTR_LOG_LEVEL=INFO
```

Не выставляйте порт напрямую в интернет: MCP-сервер не содержит собственной
аутентификации.

## Проверка

Клиент использует тот же MCP-протокол, что Cursor, Claude Desktop и другие агенты:

```bash
python3 -m venv .venv
.venv/bin/pip install -e .
.venv/bin/python query_mcp.py \
  --url http://127.0.0.1:8000/mcp \
  77:08:0005003:1031
```

Для получения только стоимости укажите `--tool get_cadastral_value`.

## Existing Caddy + общая сеть `edge`

Создайте сеть, если она ещё не существует, и запустите Compose с override:

```bash
docker network inspect edge >/dev/null 2>&1 || docker network create edge
docker compose -f compose.yaml -f deploy/compose.edge.yaml up -d --build
```

Сервис получит сетевой alias `rosreestr-mcp`. Добавьте блок из
`deploy/Caddyfile.example` в конфигурацию Caddy и задайте:

```bash
ROSREESTR_MCP_DOMAIN=rosreestr.example.com
ROSREESTR_MCP_PATH_TOKEN="$(openssl rand -hex 24)"
```

Итоговый endpoint:

```text
https://rosreestr.example.com/<ROSREESTR_MCP_PATH_TOKEN>/mcp
```

Секретный path-token скрывается из access log в примере Caddy. Для более строгой
модели доступа используйте VPN, mTLS или отдельный authentication gateway.

## Обслуживание

```bash
# Состояние и последние логи
docker compose ps
docker compose logs --tail=100 mcp

# Пересборка после git pull
docker compose up -d --build

# Остановка без удаления кэша
docker compose down

# Удаление вместе с кэшем (необратимо)
docker compose down -v
```

SQLite-кэш хранится в named volume `mcp-rosreestr_rosreestr_data`.

## Почему нужен отдельный CA-файл

В цепочке TLS НСПД может использоваться российский доверенный корневой сертификат,
которого нет в стандартном образе Python. Скрипт получает его с официального домена
Минцифры и сверяет SHA-256 до установки. Проверка TLS при этом не отключается:
дополнительный сертификат добавляется к системному trust store только для процесса
MCP через `MCP_ROSREESTR_CA_FILE`.
