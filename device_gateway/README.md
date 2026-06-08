# Apex Device Gateway

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
limit.

`DG_DEVICE_POLICY=kick_oldest`

Revokes the oldest active device and allows the new device.

## Production notes

This MVP uses a local JSON file for storage to keep the service dependency-free.
For production, keep the API surface and replace the store with MySQL/Postgres
plus a lock around login device admission.

Always set a strong `DG_TOKEN_SECRET`; it is used for session hashing and
business token encryption at rest.
