# Remote configuration policy (Flutter and native tvOS)

This concerns the OSS application configuration (routes, features, update metadata),
not downloaded node subscriptions or the separate encrypted subscription vault.

## Selection and refresh

- Normal sources run concurrently. After the first valid response, allow up to
  350 ms for another source with a higher `config_version`.
- If every normal source fails validation or networking, retry the preferred
  normal source once, then try emergency sources concurrently with the same window.
- Each source request is bounded to at most 10 seconds. Flutter's startup deadline
  allows all three phases and disk fallback to finish; simultaneous refresh requests
  share one fetch operation. Invalid business/gateway routes do not count as success.
- Choose the highest version among valid disk snapshots and eligible live results.
  Numeric dotted versions compare numerically; missing versions sort below present
  versions. Other strings compare lexicographically. Equal versions prefer live data.
- A version arriving outside the settlement window may be discovered on the next
  refresh; this is a bounded startup strategy, not a guarantee of seeing every mirror.
- Flutter retains its explicit refresh / About → check updates entrance. Legacy
  `remote`, `redirect`, `gitee` refresh aliases now use the unified selection policy.
- tvOS: select the home-screen version label to refresh configuration and check updates.
  Explicit refresh bypasses memory reuse. Ordinary tvOS consumers reuse memory for
  up to five minutes, then the next read rechecks sources (no background polling timer).
  Refresh does not itself disconnect a running tunnel or log the user out.

## Disk cache

Both clients keep one record containing current and previous snapshots. Each contains
the original response content, successful online verification time, and source metadata.
The original content is not replaced by the parsed configuration. Signatures are checked
again with the current build's public key every time a signed disk snapshot is read.

| Age since successful online verification | Handling |
| --- | --- |
| 0–7 days | Valid cache, remote refresh still attempted |
| Over 7 through 30 days | Stale offline fallback; marked in manager status |
| Over 30 days, future or missing timestamp | Rejected for cache restoration |

Offline reads do not extend expiry. A successfully verified live response of the same
or higher version renews it. Invalid signatures, malformed data and unusable routes
are rejected independently for current and previous snapshots. Corrupt current data
must not overwrite a good previous snapshot on rotation. These are restoration rules,
not a timer that tears down an already running connection after 30 days.

When no acceptable live result or cache remains, refresh reports failure. Flutter no
longer reconstructs configuration from the unsigned legacy API-endpoint bootstrap cache;
initialization/SDK creation require configuration routes first. tvOS may still use an
explicit build-time fallback API (trusted application configuration, not an unsigned OSS
file). Existing update-hint caches remain advisory when offline.

## Compatibility and trust boundaries

- New clients accept **only fastcat-config-v2**: Ed25519 verification before XOR
  payload decoding, both online and on disk replay. Missing/wrong public keys, invalid
  signatures, missing/unknown format markers, algorithms or encodings fail closed.
- Bare XOR+Base64 and plaintext JSON are rejected, including from emergency sources
  and previously saved current/previous disk snapshots. Removing the envelope does not
  bypass verification. XOR remains the existing inner payload format, not strong secrecy.
- Old parsed Flutter caches and untimestamped tvOS v1 caches are not silently promoted
  to freshly verified snapshots. One successful online signed v2 fetch is needed
  after upgrade; old full-cache keys are removed after saving that replacement.
- Legacy-client compatibility remains on the publishing/backend side, not in new
  clients' decoders. Use HTTPS sources in production.
- The 30-day bound uses local receipt time, not a signed server expiry. It does not
  prevent a hostile local administrator changing the clock/cache metadata or replaying
  valid old signed payloads. Cache/version policy is operational rollback protection,
  not a tamper-proof monotonic counter.
- Cache-only configurations can display an optional update hint, but cannot newly
  enforce mandatory updating. Online confirmation is required for a forced update.

## Rollback and publishing

Maintain two separate publishing paths:

1. Keep existing legacy XOR+Base64 files and URLs for already-installed old clients.
   Do not replace them with v2. The old `encrypt_config.py` utility still produces only
   the legacy format; it is not a publishing tool for the new v2-only clients.
2. Generate signed v2 files using the backend signing facility and publish them to new
   URLs. Configure those URLs in new builds' shared `remote_config.sources` (or Flutter
   OSS_URL overrides). Ensure emergency sources also serve v2; a legacy emergency URL
   will be rejected, not silently accepted. This code change does not invent new URLs.
3. Inject the matching Base64-encoded 32-byte Ed25519 public key as
   `REMOTE_CONFIG_PUBLIC_KEY`; keep the private key only in the backend/publisher.
   Shared CI checks and Flutter packaging helpers reject missing verification keys.
4. Verify online loading and offline v2 cache restoration before releasing. Upgrading
   clients with only unsigned caches must get a valid signed configuration online once.

The backend must continue publishing the legacy file independently for old versions.
No backend deployment, OSS replacement or old-client format removal is performed here.

To revert business settings, publish the old desired content with a **new, higher**
`config_version`, then sign/encrypt it again and synchronize the same file to mirrors.
Do not decrease the version: a valid higher cache will intentionally win. Equal-version
live content is accepted for compatibility, but revision increments are strongly preferred
to avoid mirrors disagreeing. If current disk data is corrupt, a valid previous snapshot
may restore service; if all higher snapshots expire, a lower live version may be accepted.

The version is configuration revision, not app release version. No OSS content, signing
key, subscription key, or existing `config.yaml` setting is changed by this implementation.

## Offline regression verification

- Flutter: `flutter test test/xboard/config test/xboard/features/update_check`
- Native: compile `TVBuildConfiguration.swift`, `TVRemoteConfigManager.swift` and
  `test/tvos/remote_config_test.swift` together with `swiftc`, then run the executable.
  This test also runs in the tvOS CI job. Fixtures use generated signing keys and
  `.invalid` URLs; no production configuration is fetched.
