# Performance/resource stage, frozen before collection

TCP web only. Same connected Android. Preserve all payload, FIN and strict lifecycle failures, raw setup attempts and cache state. Independent new same-binary lab servers18466 baseline /18467 writecap16384; server TLS/header budget15 vs clientTLS12, auth5, totalcase30 (4MiB case60). Keep original production services/defaults unchanged. Both layout arms use same opt-in max2 PRE-auth attempts, default curve, no cache.

Primary cellular matrix randomized seed20261130: 7001/49157/131119/1048576 bytes x2 repeats/arm;4194304 bytes x3 repeats/arm,16KiB source chunks, no gap.22requests. Per-arm concurrency4 x16requests of131119 bytes. Independent8sequential32KiB/block cache comparison on capped only,2blocks cacheoff/2blocks cache8, randomized blockorder; first full handshakes retained and separately report tls_resumed. Cache max1min/profile,8tickets,16profiles; endpoint/verifiedname/CA/curve/networkepoch isolation. No0RTT or persistenttickets.

Ten-minute soak: both arms concurrently one worker/process,8192B/case, up to200requests, startspacing4s, startwindow600s; already-started cases may finish up to30s later. Runtime metrics1s for server+client (heap,GC,goroutines,RSS,FDs,jobs/sessions); no public pprof or secret dumps. Bounded0600 local files. Client process persists throughout soak; not one new process per request.

Wi-Fi confirmation afterward:8small32KiB +2large1MiB requests/arm, record failures rather than force same success count. Cellular data budget for this stage approximately40MiB, including matrix/concurrency/cache/soak. Larger network impairment is a limit, not automatically a protocol bug.

Candidate gates: exact content/FIN semantics; capped complete datawrites<=16384; no reproducible >15% bulkmedian slowdown (3paired4MiB cases only, no significance claim); seek>=99%full lifecycle success on cellular sustained path, while report body-success separately; no continuing idle-FD/goroutine growth (allow bounded caches/replaytable and allocator retention). Failure of a gate requires diagnosis before recommending a default; do not hide failedsamples, silently extend budgets or replay requests.

Capture matrix and cache separately if needed; only labports, private rawpcaps. Profile changes (cache, retry, cap) reported separately rather than attributing combined gain to cap. Internal results do not establish censorship evasion or long-term production reliability.
