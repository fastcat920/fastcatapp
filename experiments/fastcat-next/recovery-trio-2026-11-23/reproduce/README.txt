Frozen comparison, 2026-11-23.
Primary: run.py + runtime_lab.py + base_lab.py, frozen comparator in compare-source. Requires authorized VPS SSH control socket and attached Android adb. Private credentials/configurations are intentionally omitted; use isolated test credentials. Do not run against occupied production ports.
Primary analysis: analyze.py, uncertainty.py, then report.py.
Supplement: steady-load/run.py uses the measurement-only receive-readiness callback in steady-load/compare-source; both background streams receive 256KiB before foreground. Analyze with steady-load/analyze.py; then finish_report.py after report.py. Paths in scripts reflect original workspace and require adjustment for relocation.
Plans contain binary SHA256 and settings. Server and protocol core unchanged between cohorts. Cohorts must not be pooled. CatNode source revision/hashes and Go dependency locks included; no executables/private keys are distributed.
