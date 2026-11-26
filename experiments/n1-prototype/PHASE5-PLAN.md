# Phase 5 predeclared validation

No Phase 4 held-out sizes reused. One Android/Wi-Fi/18461 endpoint and unchanged Phase 4 server binary. Client legacy vs opt-in coalesced vs ordinary synthetic streaming RPC; two repeats per size/pattern/mode.

- Train sizes 1536/12288/98304 B; unseen-size test 3072/24576/196608 B.
- Burst chunks 16384 B, gap 0; paced chunks 8192 B, gap 15 ms. Payload shorter than a chunk has no deliberate gap.
- 36 train + 36 held-out cases, same source bytes and validation. Sequential sessions, randomized order within split, seed 20261125 + split index. All cold connections. Stop on first failure and preserve it; any repeat must be a whole fresh run, reported separately.
- Observe 72 new handshakes, chronological match with complete capture; require exact payload, outer ending, TLS EOF observation, contiguous TCP and fully parsed TLS records. Record RST separately.
- Fixed one-level decision stump chosen on training balanced accuracy. Evaluate legacy vs RPC and coalesced vs RPC independently. Report two predeclared feature sets: counts-only (client/server encrypted record count and <=256-byte count); all (counts plus log unique client/server TCP payload bytes). Include confusion matrices, not real-world detection probabilities. No cutoff tuning on held-out data.
- Primary implementation expectation: legacy request writes header, DATA, FIN, outer HTTP ending separately; coalesced joins FIN+outer ending in one TLS Write, without timers or changes to N1 messages. Public capture tests whether total encrypted client records drop by one. A record may contain encrypted handshake/alert, not necessarily business data.
- Record first actual payload and full lifecycle times, P50/P95 nearest-rank. Pooling sizes is descriptive; paired same-size/pattern repeats are too few for performance superiority claims.
- No App/APK/panel/production service changes. Enable bounded synthetic RPC only during collection, then disable. Keep legacy CLI/config default until explicit separate production acceptance. Merge implementation is experimental opt-in.
