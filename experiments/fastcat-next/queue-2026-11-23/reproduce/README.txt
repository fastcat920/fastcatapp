All stages are isolated lab tests; credentials and binary executables are not archived.
Client Go1.26.2 / Android arm64; Linux amd64 server Go1.27.3.
Each main stage: 6 mixed pairs, 6 parallel pairs, 6 rolling pairs, 3 latency pairs = 42 performance cases; 6 traced mechanism cases separate.
Stage12 core contains bounded downstream budgeting and forwarding wait observers; failed rolling throughput gate.
Stage3 core adds opt-in recovery-aware scheduling; local main gate passed. It directly observes local outbound losses and RTT, not a new server downlink feedback protocol.
Stage4 core adds explicitly requested kind2 prefix copies; baseline is stage3 recovery-aware, candidate adds prefix. Gate evaluated incrementally.
Web comparator adds independent --mixed-foreground-target; mixed_summary wire counters are sampled before closing clients. Server is identical to stage4.
remote-web-invalid-tls-name preserves the failed background-name harness run; excluded from load acceptance.
Cold confirm preserves original cold regression, adds fixed LOCAL UDP port cohort. No assertion of identical public mapping or intermediate route.
Scripts retain original paths and target ports. Review and adapt output directories and device serial before reproducing; do not overwrite historical results.
Frozen source snapshots and per-plan SHA256 record tested versions. Snapshot paths differ from build paths; byte-for-byte executable reproduction may require original source paths/toolchain build environment.
Raw packet metadata does not contain payloads, keys or actual QUIC CIDs. Live wire usage is a snapshot before client close, not a total across removed sessions.
