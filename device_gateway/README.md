# FastCat Device Gateway

Standalone device authorization gateway for XBoard-compatible APIs.

The gateway keeps the main business backend untouched. Clients log in through
this service, this service logs in to the business API, checks the user's
`device_limit`, and returns a gateway session token. Later client requests go
through this service and are proxied to the business API only when the device is
still authorized.

Authenticated clients can inspect a sanitized, read-only backend health
snapshot at `GET /api/v1/user/service-status`. The response marks the active,
primary, and backup business APIs, but masks every domain, IP address, and
explicit port. These probes never change failover counters or the active
backend.

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

## Production deployment

The repository keeps the production deployment script at
`device_gateway/deploy-device-gateway.sh`. Install it once on the server and
run it from the fixed deployment directory:

```bash
sudo install -m 755 \
  device_gateway/deploy-device-gateway.sh \
  /www/wwwroot/get.fastcat.com/deploy-device-gateway.sh

cd /www/wwwroot/get.fastcat.com
sudo ./deploy-device-gateway.sh
```

The script defaults to the `main` branch, checks out only `device_gateway`,
backs up the live binary and configuration, tests and builds the new binary,
then automatically restores and restarts the previous version if startup or
the health check fails. `DEPLOY_BRANCH` may be set for an intentional one-off
branch deployment.

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
Legacy XOR+Base64 configurations use `DG_OSS_XOR_KEY`. When the Catboard
client configuration center publishes the signed v2 envelope, also set
`DG_OSS_SIGNING_PUBLIC_KEY` to the Base64 Ed25519 public key shown in the
admin page. The gateway rejects signed envelopes when the signature or public
key is invalid.

### Remote configuration cache and rollback

`DG_OSS_CACHE_FILE` now stores the **current and previous original envelopes**,
not decrypted/parsed business addresses. Every load decrypts and, for v2,
re-verifies the signature against the currently configured public key. The
file is atomically replaced with owner-only permissions. Use a separate cache
file per process/instance; it is not a shared cluster database.

Existing plaintext/parsed caches cannot be re-authenticated and are ignored;
upgrade while at least one original OSS source is reachable (or configure an
explicit business startup seed). Do not wrap an old parsed cache in a new
format. Legacy **XOR+Base64** sources and raw caches remain compatible, but XOR
does not authenticate content: host them on trusted HTTPS. Unsigned plaintext
JSON is no longer a valid source. After a verified v2 cache has been accepted,
an unsigned legacy response cannot silently replace it.

The default fresh age is 72 hours (`DG_OSS_CACHE_TTL_HOURS`), with an additional
168-hour offline grace (`DG_OSS_OFFLINE_GRACE_HOURS`, 0 disables grace). Cache
age is based on the last successful **online** verification; merely loading
the cache does not extend it. Future-dated records are rejected. After grace
expires the cache cannot supply startup/refresh routes, but a still-verifiable
record remains a revision floor. A corrupt current record may fall back to an
independently verified previous record within its own lifetime.

Lower `config_version` values, and changed content with the same revision,
cannot replace a verified cache. To roll back business addresses, publish the
desired old content under a **new higher** `config_version`. An online copy of
the same verified content renews its verification time. If all refresh sources
fail, a running gateway keeps its already applied in-memory route rather than
disconnecting users; this does not renew or make expired disk caches eligible
after restart. Key rotation may invalidate both disk records until a new
envelope verifies. The gateway does not rotate keys or alter existing secrets.

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

## QR device login

PC and TV clients create a short-lived login challenge, render `qr_data`, and
poll it with the returned `poll_token`. A signed-in phone scans the QR code and
confirms the device before the gateway creates a separate device session. The
QR contains no account or session token and expires after two minutes.

```text
POST /api/v1/auth/qr/sessions              target creates a challenge
GET  /api/v1/auth/qr/sessions/{id}         target polls with ?poll_token=
POST /api/v1/auth/qr/sessions/{id}         signed-in phone approves it
DELETE /api/v1/auth/qr/sessions/{id}       target cancels it with ?poll_token=
POST /api/v1/auth/qr/sessions/{id}/ack     target confirms an opted-in delivery
```

New targets send `delivery_ack: true` in the create body and enable this mode
only when the create response also contains `data.delivery_ack: true`. In that
mode, an approved poll includes `data.login` and `data.delivery_id`; subsequent
polls return the same credentials until expiry or acknowledgement. After local
login succeeds, the target posts `{ "poll_token": "...", "delivery_id": "..." }`
to `/ack`. Repeating the same acknowledgement is safe. It clears the stored
login response and later polls return `consumed`. Failed acknowledgement does
not invalidate a successfully installed device session.

Old targets, including the existing native tvOS client, do not opt in and keep
the original single-consumption poll behavior. These challenge-authenticated
routes do not need an account token; phone approval still requires one. The
challenge ID alone can neither retrieve credentials nor acknowledge delivery.

With PostgreSQL enabled, QR state is shared in `dg_qr_login_sessions`. The
complete payload (including poll secret and temporary login response) is
encrypted with the key derived from `DG_TOKEN_SECRET`. Approval and device
admission commit in one transaction. Expired responses are not returned;
expired rows are reclaimed by a later create or a poll of that row. JSON mode
keeps QR state in memory and remains single-process only.

QR payloads are also reclaimed every minute, even when no further create/poll
request arrives. `DG_QR_MAX_ACTIVE_SESSIONS` defaults to 10,000 unexpired rows
(including consumed challenges until expiry). PostgreSQL count-and-create uses
a shared transaction lock so concurrent gateways cannot exceed this total;
JSON mode applies it to the one process. All instances must set the same cap.
Exhaustion returns HTTP 429 with `Retry-After`, without creating a login/device.

Upgrade **all gateway instances** before relying on shared QR sessions: older
gateways still keep their own in-memory challenges and will return 404 for a
challenge created elsewhere. Do not mix old and new admission implementations
when relying on concurrent device-limit enforcement. All instances must use
the same database, secret and device policy. Existing in-memory QR challenges
are lost on restart and need refreshing. This change does not add login-time
automatic gateway failover to the native tvOS client.

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

Authorization also verifies the shared session/device status on each request,
even on a local cache hit. Database unavailability returns 503 rather than a
misleading 401. Device admission serializes the account with transaction-scoped
locks, reads current limits/devices, applies `strict` or `kick_oldest`, and
commits revocations plus the new session before publishing the local cache.
Stale business snapshots cannot overwrite an administrator's device-limit
override; only explicit administrator updates may change or clear it. Existing
duplicate records are not automatically deleted by this migration.

The additive `last_login_at` and `override_updated_at` columns distinguish
login/admin operations from ordinary heartbeats and profile refreshes. A delayed
old revocation cannot revoke a later login, and a delayed old administrator
write cannot overwrite a later override. Retries retain the original operation
time; session revocation is also bounded by that time. Keep the clocks of all
gateway hosts synchronized. These guards require the updated implementation
on every writer; old gateway binaries do not enforce them.

The `deploy/` directory contains a systemd unit for the production path
`/www/wwwroot/get.fastcat.com`. Install it into `/etc/systemd/system/`, then
enable the service with `systemctl enable --now device-gateway`. Runtime logs
are available through `journalctl -u device-gateway` and rotated by journald.

Always set a strong `DG_TOKEN_SECRET`; it is used for session hashing and
business token encryption at rest.

## Consistency tests

`go test ./...`, `go test -race ./...` and `go vet ./...` run without a live
database by default. The isolated SQL drivers verify gateway sequencing and
failure handling, not PostgreSQL's actual SQL/locking behavior.

The opt-in `TestPostgresAdmissionIntegration` requires a disposable **local**
PostgreSQL database named `fastcat_test_*`, passed explicitly as a PostgreSQL
URI in `FASTCAT_TEST_POSTGRES_DSN`. It creates and drops only its own random
schema. Never pass a production database or `DG_POSTGRES_DSN`. Run this
integration test before deploying the multi-instance changes; a skipped test
does not constitute a successful real-database check.

## Request bounds and retention

The inbound HTTP server defaults to a 5-second header timeout, 30-second read
timeout, 90-second write timeout, 60-second keep-alive idle timeout and 32 KiB
headers. `DG_SERVER_*_TIMEOUT_SECONDS` can tune them; leave sufficient write
time for upstream failover. They are separate from the existing outbound
`DG_HTTP_TIMEOUT_SECONDS`.

Bounded per-IP token buckets protect login (60/minute), public registration /
verification / password reset (30/minute), QR creation (60/minute), QR polling /
approval / ACK (2,400/minute) and admin APIs (600/minute). Each class has its own
budget; ordinary device heartbeats and subscription requests are not throttled
by these login budgets. Initial bursts equal one minute's quota. Rejections
return 429 + `Retry-After`. Tune the `DG_*_RATE_PER_MINUTE` values for large NAT
deployments. Limiter memory is capped at `DG_RATE_LIMIT_MAX_KEYS` (4,096), and
idle keys are recycled. These are **per-process** rates, not distributed
quotas: apply an additional shared edge limit if a cluster-wide rate is needed.
Keep `DG_TRUST_FORWARDED_FOR=false` for direct public exposure; enabling it is
safe only when network access is restricted to a trusted proxy that overwrites
the forwarding headers. TLS termination, firewall rules and edge limits remain
deployment requirements, not features that application code can verify.

Expired/revoked login sessions are independently removed hourly, 30 days after
their effective `expires_at` (`DG_SESSION_RETENTION_DAYS`), even while their
device is still active. Still-valid sessions and recent expired records remain.
PostgreSQL cleanup predicates run against authoritative rows, not a stale
instance's snapshot. Ordinary heartbeat updates cannot re-insert a deleted
session ID. The existing 30-day offline-device / 90-day revoked-device policy
remains; PostgreSQL device deletion additionally protects valid active sessions.
All instances must be upgraded before relying on these concurrency safeguards.
