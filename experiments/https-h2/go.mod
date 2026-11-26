module fastcat.local/https-h2

go 1.26.0

require fastcat/https-tcp v0.0.0

replace fastcat/https-tcp => ../https-tcp

require (
	github.com/metacubex/http v0.1.7
	github.com/metacubex/mihomo v0.0.0
	github.com/metacubex/quic-go v0.61.1-0.20260727080200-2548683b76f4
	github.com/metacubex/tls v0.1.8
)

require (
	github.com/metacubex/cpu v0.1.1 // indirect
	github.com/metacubex/hkdf v0.1.0 // indirect
	github.com/metacubex/hpke v0.1.0 // indirect
	github.com/metacubex/mlkem v0.1.0 // indirect
	github.com/metacubex/qpack v0.6.0 // indirect
	github.com/metacubex/randv2 v0.2.0 // indirect
	github.com/metacubex/sing v0.5.7 // indirect
	golang.org/x/crypto v0.33.0 // indirect
	golang.org/x/exp v0.0.0-20240904232852-e7e105dedf7e // indirect
	golang.org/x/net v0.35.0 // indirect
	golang.org/x/sys v0.30.0 // indirect
	golang.org/x/text v0.22.0 // indirect
)

replace github.com/metacubex/mihomo => ../../core/Clash.Meta
