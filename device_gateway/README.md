# FastCat Device Gateway

Standalone device authorization gateway for XBoard-compatible APIs.

The gateway keeps the main business backend untouched. Clients log in through
this service, this service logs in to the business API, checks the user's
`device_limit`, and returns a gateway session token. Later client requests go
through this service and are proxied to the business API only when the device is
still authorized.

## Run

```bash
cd device_gateway
cp config.example.env .env
# edit .env
set -a && source .env && set +a
go run .
```

Health check:

```bash
curl http://127.0.0.1:8787/healthz
```

## Required client login payload

`POST /api/v1/passport/auth/login`

```json
{
  "email": "user@example.com",
  "password": "password",
  "device_id": "stable-installation-id",
  "device_name": "MacBook Pro",
  "platform": "macos",
  "app_version": "3.3.0",
  "os_version": "15.5"
}
```

The response stays XBoard-compatible. `data.auth_data` and `data.token` are
gateway tokens, not business tokens.

`/api/v1/user/getSubscribe` responses are rewritten too: `subscribe_url` and
subscription `token` point to the gateway, so revoking a device also blocks
future subscription refreshes.

Set `DG_PUBLIC_BASE_URL` to the public URL of this gateway. If it is empty, the
gateway infers the URL from the incoming request.

Business routes are normally read from the OSS `domains` array. Normal OSS
mirrors are requested concurrently; the emergency OSS is used only when every
normal mirror is unusable, followed by the last complete local OSS cache.
`DG_BUSINESS_BASE_URLS` and the legacy `DG_BUSINESS_BASE_URL` are startup seeds
for a new installation when no remote or cached configuration exists. Remote
configurations must increase `config_version` whenever their content changes.

The gateway promotes a successful business backend, opens its
circuit after `DG_BUSINESS_FAILURE_THRESHOLD` consecutive failures (default 2),
and retries it after `DG_BUSINESS_CIRCUIT_SECONDS` (default 90). Safe requests
are retried on the next healthy backend; state-changing requests are never
replayed after an HTTP response has been received.

While a backup is active, higher-priority backends are probed every
`DG_BUSINESS_HEALTH_INTERVAL_SECONDS` (default 30). A recovered backend becomes
active for new requests only after `DG_BUSINESS_RECOVERY_SUCCESSES` consecutive
successful probes (default 3) and after the backup has been held for at least
`DG_BUSINESS_BACKUP_MIN_HOLD_SECONDS` (default 180). In-flight requests are not
cancelled or replayed during failback.

## IP location database

Device IP location and ISP are resolved locally with an offline ip2region
database. Put the database file on the server and point the gateway to it:

```bash
DG_IP_REGION_DB=./data/ip2region.db
```

If the file is missing or unreadable, the gateway still records the raw IP but
leaves location and ISP empty.

## User device APIs

```text
GET    /api/v1/user/devices
POST   /api/v1/user/devices/heartbeat
DELETE /api/v1/user/devices/{device_record_id}
```

Use the gateway session token in `Authorization`.

## Admin APIs

Admin requests require either:

```text
X-Admin-Token: <DG_ADMIN_TOKEN>
```

or:

```text
Authorization: Bearer <DG_ADMIN_TOKEN>
```

Endpoints:

```text
GET    /api/v1/admin/users
GET    /api/v1/admin/users/{user}/devices
DELETE /api/v1/admin/users/{user}/devices/{device}
PATCH  /api/v1/admin/users/{user}/device-limit
GET    /api/v1/admin/audit-logs
```

`{user}` can be the gateway user id, business user id/uuid, or email.

Patch body:

```json
{
  "device_limit_override": 3
}
```

Clear override:

```json
{
  "device_limit_override": null
}
```

## Device policy

`DG_DEVICE_POLICY=strict`

Rejects new devices when the user's active device count reaches the effective
limit. Clients use a lower-frequency heartbeat randomized between 2 and 5
minutes.

`DG_DEVICE_POLICY=kick_oldest`

Revokes the oldest active device and allows the new device. Clients keep a
20–30 second heartbeat so replaced devices are signed out promptly.

## Production notes

Set `DG_POSTGRES_DSN` in production. PostgreSQL persistence uses incremental
upserts for changed users, devices, sessions, and audit records; it does not
rewrite the full dataset for heartbeats. The JSON file remains available as a
single-process fallback and initial migration source.

All gateway instances in one cluster must use the same `DG_POSTGRES_DSN` and
`DG_TOKEN_SECRET`. A local session miss triggers an immediate PostgreSQL reload,
so a client can switch gateways immediately instead of waiting for the periodic
sync interval.

The `deploy/` directory contains a systemd unit for the production path
`/www/wwwroot/get.fastcat.com`. Install it into `/etc/systemd/system/`, then
enable the service with `systemctl enable --now device-gateway`. Runtime logs
are available through `journalctl -u device-gateway` and rotated by journald.

Always set a strong `DG_TOKEN_SECRET`; it is used for session hashing and
business token encryption at rest.
