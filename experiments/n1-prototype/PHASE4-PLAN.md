# Phase 4 predeclared study

This is an implementation-specific lab study, not a GFW detector evaluation.

- Same Android device, Wi-Fi, endpoint, certificate and TLS stack.
- Modes: N1, cookie-bearing streaming HTTPS GET, ordinary server-streaming RPC with an early acknowledgment. Control cookies have the same encoded length as this fixture's N1 capability. Controls are synthetic and do not represent all web applications.
- Train sizes: 512, 8192, 65536 bytes. Held-out sizes: 1024, 16384, 131072 bytes. Held-out sizes are not used to choose a threshold.
- Two source patterns: burst (16KiB chunks, no deliberate gaps), paced push (4KiB chunks, 30ms between chunks). Payloads smaller than one chunk have no deliberate gap. This is not a full interactive chat/game workload.
- Two repetitions per size/pattern/mode: 36 training flows and 36 later held-out flows. Randomized order within each batch. No silent retries or dropping failed cases.
- Payload pattern and bounded pacing use one shared source implementation. N1's HTTP workload keeps its sending direction open until the target response is complete, matching normal HTTP connection use; closing it early can cancel a Go HTTP target's request context and invalidate the paced source.
- All modes check exact payload and message completion, and use a 30-second case deadline. RPC acknowledgment headers have a different meaning from target response headers; compare first_payload_ms, not acknowledgment latency.
- Fixed classifier: one-level decision stump, threshold/polarity selected using training balanced accuracy only. Features: client/server encrypted TLS record counts, client/server counts of encrypted records <=256 bytes, log(client/server unique TCP payload bytes). No ports, addresses, workload labels, true payload sizes or wall-clock timestamps are model features.
- Two predefined evaluations: train N1 vs GET, then test held-out GET and unseen RPC negatives; train N1 vs GET+RPC, then test all held-out sizes. Report confusion counts and control-specific false positives, not a censorship probability.
- Capture readiness must be observed. Refuse analysis on extra/missing flows, incomplete reassembly, payload failures or unparsed TLS tails. Sequential sessions supply chronological label matching.
- Diagnostic RPC and variable public samples are enabled only during this experiment and disabled afterward. The N1 wire format, authentication, TLS policy, padding and active emission profile are unchanged.

Any proposed wire change must use a separate subsequent evaluation; the held-out batch cannot be reused to select that change and then called independent validation.
