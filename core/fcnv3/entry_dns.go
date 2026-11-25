package fcnv3

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
	"io"
	"mime"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/fastcat920/fcnv3/internal/echparser"
	D "github.com/miekg/dns"
)

const (
	entryDNSMessageType = "application/dns-message"
	entryDNSMaxMessage  = 65535
	entryDNSLookupLimit = 4 * time.Second
	entryDNSMaxTTL      = 5 * time.Minute
	entryDNSCacheSize   = 64
)

type EntryDNSConfig struct {
	URL         string
	BootstrapIP string // Required when URL has a DNS hostname.
	RootCAs     *x509.CertPool
	DialContext func(context.Context, string, string) (net.Conn, error)
}

type EntryDNSResult struct {
	ECHConfigList []byte
	Addresses     []netip.Addr
}

type EntryDNSResolver interface {
	Resolve(context.Context, string) (EntryDNSResult, error)
	Refresh(context.Context, string) (EntryDNSResult, error)
}

type DoHEntryDNSResolver struct {
	endpoint *url.URL
	client   *http.Client
	now      func() time.Time
	mu       sync.Mutex
	cache    map[string]cachedEntryDNS
	pending  map[string]*entryDNSRequest
}

type cachedEntryDNS struct {
	result  EntryDNSResult
	expires time.Time
}

type entryDNSRequest struct {
	done   chan struct{}
	cancel context.CancelFunc
	result EntryDNSResult
	err    error
}

func NewEntryDNSResolver(config EntryDNSConfig) (*DoHEntryDNSResolver, error) {
	endpoint, err := url.Parse(config.URL)
	if err != nil || endpoint.Scheme != "https" || endpoint.Hostname() == "" || endpoint.User != nil ||
		endpoint.ForceQuery || endpoint.RawQuery != "" || endpoint.Fragment != "" || strings.Contains(config.URL, "#") || strings.HasSuffix(endpoint.Host, ":") {
		return nil, errors.New("FCN v3 entry DoH requires an HTTPS URL without credentials, query or fragment")
	}
	host := endpoint.Hostname()
	if _, err := netip.ParseAddr(host); err != nil {
		if _, err = normalizeEntryDNSName(host); err != nil {
			return nil, errors.New("invalid FCN v3 entry DoH hostname")
		}
	} else if strings.Contains(host, "%") {
		return nil, errors.New("invalid FCN v3 entry DoH IP address")
	}
	port := endpoint.Port()
	if port == "" {
		port = "443"
	}
	if number, err := strconv.ParseUint(port, 10, 16); err != nil || number == 0 {
		return nil, errors.New("invalid FCN v3 entry DoH port")
	}
	bootstrap := config.BootstrapIP
	if bootstrap == "" {
		bootstrap = host
	}
	ip, err := netip.ParseAddr(bootstrap)
	if err != nil || ip.Zone() != "" || ip.IsUnspecified() || ip.IsMulticast() {
		return nil, errors.New("FCN v3 entry DoH requires a literal bootstrap IP")
	}
	socket := net.JoinHostPort(ip.Unmap().String(), port)
	roots := config.RootCAs
	if roots != nil {
		roots = roots.Clone()
	}
	dial := config.DialContext
	if dial == nil {
		dial = (&net.Dialer{}).DialContext
	}
	transport := &http.Transport{
		TLSClientConfig:        &tls.Config{MinVersion: tls.VersionTLS12, RootCAs: roots, ServerName: host},
		ForceAttemptHTTP2:      true,
		DisableCompression:     true,
		MaxResponseHeaderBytes: 8192,
		IdleConnTimeout:        30 * time.Second,
		DialContext: func(ctx context.Context, network, _ string) (net.Conn, error) {
			return dial(ctx, network, socket)
		},
	}
	return &DoHEntryDNSResolver{
		endpoint: endpoint,
		client: &http.Client{
			Transport: transport,
			CheckRedirect: func(*http.Request, []*http.Request) error {
				return http.ErrUseLastResponse
			},
		},
		now:     time.Now,
		cache:   make(map[string]cachedEntryDNS),
		pending: make(map[string]*entryDNSRequest),
	}, nil
}

func normalizeEntryDNSName(name string) (string, error) {
	name = strings.TrimSuffix(name, ".")
	invalid := errors.New("invalid FCN v3 entry DNS name")
	if len(name) > 253 || !strings.Contains(name, ".") {
		return "", invalid
	}
	if _, err := netip.ParseAddr(name); err == nil {
		return "", invalid
	}
	for label := range strings.SplitSeq(name, ".") {
		if label == "" || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return "", invalid
		}
		for _, c := range label {
			if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-') {
				return "", invalid
			}
		}
	}
	return strings.ToLower(name), nil
}

func (r *DoHEntryDNSResolver) Resolve(ctx context.Context, name string) (EntryDNSResult, error) {
	return r.resolve(ctx, name, false)
}

// Refresh bypasses a cached result and shares any active lookup for the name.
func (r *DoHEntryDNSResolver) Refresh(ctx context.Context, name string) (EntryDNSResult, error) {
	return r.resolve(ctx, name, true)
}

// Invalidate discards the result and prevents a pending lookup from caching it.
func (r *DoHEntryDNSResolver) Invalidate(name string) {
	name, err := normalizeEntryDNSName(name)
	if err != nil {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.cache, name)
	if pending := r.pending[name]; pending != nil {
		delete(r.pending, name)
		pending.cancel()
	}
}

// ResetNetwork retires the DoH socket pool along with cached and in-flight
// DNS answers when the caller observes a different default network.
func (r *DoHEntryDNSResolver) ResetNetwork() {
	r.mu.Lock()
	old := r.client
	transport := old.Transport.(*http.Transport).Clone()
	next := *old
	next.Transport = transport
	r.client = &next
	clear(r.cache)
	for name, pending := range r.pending {
		delete(r.pending, name)
		pending.cancel()
	}
	r.mu.Unlock()
	old.CloseIdleConnections()
}

func (r *DoHEntryDNSResolver) resolve(ctx context.Context, name string, refresh bool) (EntryDNSResult, error) {
	if err := ctx.Err(); err != nil {
		return EntryDNSResult{}, err
	}
	name, err := normalizeEntryDNSName(name)
	if err != nil {
		return EntryDNSResult{}, err
	}
	if strings.EqualFold(name, strings.TrimSuffix(r.endpoint.Hostname(), ".")) {
		return EntryDNSResult{}, errors.New("FCN v3 entry DoH hostname matches the private TLS name")
	}
	r.mu.Lock()
	request := r.pending[name]
	if request == nil {
		started := r.now()
		if cached, ok := r.cache[name]; ok && !refresh && started.Before(cached.expires) {
			r.mu.Unlock()
			return cached.result.clone(), nil
		}
		delete(r.cache, name)
		// Each waiter owns its cancellation. The shared lookup has a bounded lifetime.
		lookup, cancel := context.WithTimeout(context.WithoutCancel(ctx), entryDNSLookupLimit)
		request = &entryDNSRequest{done: make(chan struct{}), cancel: cancel}
		r.pending[name] = request
		go r.complete(lookup, name, started, request)
	}
	r.mu.Unlock()
	select {
	case <-ctx.Done():
		return EntryDNSResult{}, ctx.Err()
	case <-request.done:
		return request.result.clone(), request.err
	}
}

func (result EntryDNSResult) clone() EntryDNSResult {
	return EntryDNSResult{ECHConfigList: bytes.Clone(result.ECHConfigList), Addresses: slices.Clone(result.Addresses)}
}

func (r *DoHEntryDNSResolver) complete(ctx context.Context, name string, started time.Time, request *entryDNSRequest) {
	defer request.cancel()
	result, ttl, err := r.lookup(ctx, name)
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.pending[name] == request {
		delete(r.pending, name)
		expires := started.Add(ttl)
		if err == nil && r.now().Before(expires) {
			if len(r.cache) >= entryDNSCacheSize {
				var oldest string
				for key, entry := range r.cache {
					if oldest == "" || entry.expires.Before(r.cache[oldest].expires) {
						oldest = key
					}
				}
				delete(r.cache, oldest)
			}
			r.cache[name] = cachedEntryDNS{result: result, expires: expires}
		}
	} else {
		result, err = EntryDNSResult{}, context.Canceled
	}
	request.result, request.err = result, err
	close(request.done)
}

func (r *DoHEntryDNSResolver) lookup(ctx context.Context, name string) (EntryDNSResult, time.Duration, error) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	type addressResult struct {
		ips []netip.Addr
		ttl time.Duration
	}
	var addressAnswers [2]chan addressResult
	for i, typ := range []uint16{D.TypeA, D.TypeAAAA} {
		addressAnswers[i] = make(chan addressResult, 1)
		go func(out chan<- addressResult) {
			addresses, ttl := r.lookupAddresses(ctx, name, typ)
			out <- addressResult{addresses, ttl}
		}(addressAnswers[i])
	}
	answers, ttl, err := r.query(ctx, name, D.TypeHTTPS)
	if err != nil {
		return EntryDNSResult{}, 0, err
	}
	var best *D.HTTPS
	var ech []byte
	for _, rr := range answers {
		record, ok := rr.(*D.HTTPS)
		// The FCN endpoint supplies the port and uses the entry's own A/AAAA records.
		if !ok || record.Priority == 0 || best != nil && record.Priority >= best.Priority ||
			(record.Target != "." && !strings.EqualFold(record.Target, record.Hdr.Name)) {
			continue
		}
		for _, param := range record.Value {
			if config, ok := param.(*D.SVCBECHConfig); ok && usableEntryECH(config.ECH, name) {
				ech, best = config.ECH, record
				break
			}
		}
	}
	if best == nil {
		return EntryDNSResult{}, 0, errors.New("FCN v3 entry HTTPS record has no usable ECH configuration")
	}
	result := EntryDNSResult{ECHConfigList: ech}
	for _, answer := range addressAnswers {
		select {
		case family := <-answer:
			if len(family.ips) != 0 {
				result.Addresses = append(result.Addresses, family.ips...)
				ttl = min(ttl, family.ttl)
			}
		case <-ctx.Done():
			return EntryDNSResult{}, 0, ctx.Err()
		}
	}
	if len(result.Addresses) == 0 {
		return EntryDNSResult{}, 0, errors.New("FCN v3 entry DoH returned no usable address")
	}
	return result, ttl, nil
}

func usableEntryECH(list []byte, privateName string) bool {
	configs, err := echparser.ParseECHConfigList(list)
	if err != nil || len(configs) == 0 {
		return false
	}
	for _, config := range configs {
		name, err := normalizeEntryDNSName(string(config.PublicName))
		if err != nil || name == privateName || len(config.PublicKey) == 0 || len(config.SymmetricCipherSuite) == 0 {
			return false
		}
	}
	return true
}

func (r *DoHEntryDNSResolver) lookupAddresses(ctx context.Context, name string, typ uint16) ([]netip.Addr, time.Duration) {
	answers, ttl, err := r.query(ctx, name, typ)
	if err != nil {
		return nil, 0
	}
	var addresses []netip.Addr
	seen := make(map[netip.Addr]struct{})
	for _, rr := range answers {
		var ip net.IP
		switch value := rr.(type) {
		case *D.A:
			ip = value.A
		case *D.AAAA:
			ip = value.AAAA
		}
		address, ok := netip.AddrFromSlice(ip)
		if _, found := seen[address]; ok && !found && !address.Is4In6() && !address.IsUnspecified() && !address.IsMulticast() {
			seen[address] = struct{}{}
			addresses = append(addresses, address)
		}
	}
	return addresses, ttl
}

func (r *DoHEntryDNSResolver) query(ctx context.Context, name string, typ uint16) ([]D.RR, time.Duration, error) {
	query := new(D.Msg).SetQuestion(D.Fqdn(name), typ)
	query.Id = 0
	wire, err := query.Pack()
	if err != nil {
		return nil, 0, errors.New("could not encode FCN v3 entry DNS query")
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, r.endpoint.String(), bytes.NewReader(wire))
	if err != nil {
		return nil, 0, errors.New("could not create FCN v3 entry DoH request")
	}
	request.Header.Set("Accept", entryDNSMessageType)
	request.Header.Set("Content-Type", entryDNSMessageType)
	request.Header.Set("Cache-Control", "no-cache")
	r.mu.Lock()
	client := r.client
	r.mu.Unlock()
	response, err := client.Do(request)
	if err != nil {
		if ctx.Err() != nil {
			return nil, 0, ctx.Err()
		}
		return nil, 0, errors.New("FCN v3 entry DoH HTTPS request failed")
	}
	defer response.Body.Close()
	media, _, err := mime.ParseMediaType(response.Header.Get("Content-Type"))
	if response.StatusCode != http.StatusOK || err != nil || media != entryDNSMessageType {
		return nil, 0, errors.New("invalid FCN v3 entry DoH HTTP response")
	}
	body, err := io.ReadAll(io.LimitReader(response.Body, entryDNSMaxMessage+1))
	if err != nil || len(body) > entryDNSMaxMessage {
		return nil, 0, errors.New("could not read FCN v3 entry DoH response")
	}
	var message D.Msg
	if err = message.Unpack(body); err != nil || !message.Response || message.Truncated || message.Id != query.Id ||
		message.Opcode != D.OpcodeQuery || message.Rcode != D.RcodeSuccess || len(message.Question) != 1 ||
		message.Question[0].Qtype != typ || message.Question[0].Qclass != D.ClassINET ||
		!strings.EqualFold(message.Question[0].Name, query.Question[0].Name) {
		return nil, 0, errors.New("invalid FCN v3 entry DoH DNS response")
	}
	answers, ttl := entryAnswerSet(message.Answer, query.Question[0].Name, typ)
	age, _ := strconv.ParseUint(response.Header.Get("Age"), 10, 32)
	return answers, min(entryDNSMaxTTL, max(0, ttl-time.Duration(age)*time.Second)), nil
}

func entryAnswerSet(records []D.RR, owner string, typ uint16) ([]D.RR, time.Duration) {
	ttl := time.Duration(^uint32(0)) * time.Second
	for range 8 {
		var answers []D.RR
		var alias string
		for _, record := range records {
			header := record.Header()
			if header.Class != D.ClassINET || !strings.EqualFold(header.Name, owner) {
				continue
			}
			if header.Rrtype == typ {
				answers = append(answers, record)
				ttl = min(ttl, time.Duration(header.Ttl)*time.Second)
			}
			if cname, ok := record.(*D.CNAME); ok {
				if alias != "" && !strings.EqualFold(alias, cname.Target) {
					return nil, 0
				}
				alias = cname.Target
				ttl = min(ttl, time.Duration(header.Ttl)*time.Second)
			}
		}
		if alias == "" {
			return answers, ttl
		}
		if len(answers) != 0 {
			break // A CNAME and its requested type cannot coexist at one owner.
		}
		name, err := normalizeEntryDNSName(alias)
		if err != nil {
			break
		}
		owner = D.Fqdn(name)
	}
	return nil, 0
}
