# Phase 7 predeclared write-cap A/B

No classifier tuning or censorship probability claim. New workload sizes 5003/33331/131101/1048576 bytes (non-block-aligned plus 1MiB bulk), burst (16384-byte source writes) and paced (4096-byte source writes,8ms gaps), two repetitions per cell per arm = 32 requests.

- Same Android/coalesced client, Wi-Fi, host, certificate, origin and new server binary; baseline 18461 has no cap, candidate 18463 uses data-write-limit=16384.
- Randomize the two arms within each same-size/pattern/repeat pair, then shuffle pairs; seed 20261127. This is small-sample A/B, no speed superiority/significance claims.
- Candidate uses outgoing DATA payload <=16337 (16384 minus worst-case 8B N1 header,31B padding,8B HTTP chunk framing), asserts full chunk Write <=16384. Retain wire maximum accepted payload 16384, all bytes, per-record random padding, immediate forwarding, FIN/HTTP ending and TLS shutdown. No waiting or added filling.
- Compare exact successful payload and lifecycle; SYN, contiguous TCP, complete TLS parsing and RST; server plaintext writes aligned to encrypted TLS records with the Phase6 method.
- Primary acceptance: capped complete body writes never exceed16384; no small fragment caused by a >16384 write. Also report small fragments from early adaptive TLS sizes, natural small DATA/FIN/header/handshake and overall bytes/records; do not equate a reduction in one cause with fewer total packets or lower detectability.
- Record first payload/full lifecycle P50/P95. payload_read_ms measures response-body read+verification after target HTTP headers, includes waiting and buffered data, excludes entry setup, is not a wire-rate measurement. Report 1MiB burst body-read rate and total transaction rate per sample; only two bulk repeats/arm, repeat more only if anomalous.
- Stop and preserve on first failure, no silent retries. Pilots excluded. No holdout model is fitted in this implementation A/B. Restore old main server binary/service, stop candidate, disable controls+traces; no APK/panel/production changes or default promotion.
