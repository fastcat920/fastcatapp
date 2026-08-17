class SensitiveMasker {
  const SensitiveMasker._();

  static final RegExp _urlPattern = RegExp(r'https?://[^\s<>"\]\)]+');
  static final RegExp _hostPortPattern = RegExp(
    r'(?<![A-Za-z0-9_.-])((?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}|(?:\d{1,3}\.){3}\d{1,3}|localhost):(\d{1,5})(?!\d)',
    caseSensitive: false,
  );
  static final RegExp _ipv4Pattern = RegExp(
    r'(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])',
  );
  static final RegExp _ipv6CandidatePattern = RegExp(
    r'(?<![A-Fa-f0-9:])(?:[A-Fa-f0-9]{0,4}:){2,7}[A-Fa-f0-9]{0,4}(?![A-Fa-f0-9:])',
  );
  static final RegExp _domainPattern = RegExp(
    r'(?<![A-Za-z0-9_.-])(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}(?![A-Za-z0-9_.-])',
    caseSensitive: false,
  );
  static final RegExp _namedPortPattern = RegExp(
    r'\b((?:target[_-]?port|remote[_-]?port|server[_-]?port)\s*[:=]\s*)(\d{1,5})\b',
    caseSensitive: false,
  );
  static final RegExp _emailPattern = RegExp(
    r'\b([A-Za-z0-9._%+\-])([A-Za-z0-9._%+\-]*)(@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})\b',
  );
  static final RegExp _bearerPattern = RegExp(
    r'\b(Bearer|Token)\s+[A-Za-z0-9._\-+/=]{12,}',
    caseSensitive: false,
  );
  static final RegExp _longTokenPattern = RegExp(
    r'(?<![A-Za-z0-9])[A-Za-z0-9_\-]{32,}(?![A-Za-z0-9])',
  );
  static final Set<String> _sensitiveQueryKeys = {
    'token',
    'auth',
    'key',
    'secret',
    'password',
    'passwd',
    'pwd',
    'email',
    'code',
    'uuid',
  };

  static String maskText(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return text;

    var masked = text.replaceAllMapped(_urlPattern, (match) {
      return _maskUrl(match.group(0)!);
    });
    masked = masked.replaceAllMapped(_namedPortPattern, (match) {
      return '${match.group(1)}${maskPort(match.group(2)!)}';
    });
    masked = masked.replaceAllMapped(_hostPortPattern, (match) {
      return '${_maskHost(match.group(1)!)}:[redacted-port]';
    });
    masked = masked.replaceAllMapped(_emailPattern, (match) {
      final first = match.group(1)!;
      final rest = match.group(2)!;
      final domain = match.group(3)!;
      return rest.isEmpty ? '$first***$domain' : '$first***$domain';
    });
    masked = masked.replaceAllMapped(_ipv6CandidatePattern, (match) {
      final address = match.group(0)!;
      final colonCount = ':'.allMatches(address).length;
      if (!address.contains('::') && colonCount < 3) return address;
      return '[redacted-ipv6]';
    });
    masked = masked.replaceAllMapped(_ipv4Pattern, (match) {
      final address = match.group(0)!;
      final octets = address.split('.').map(int.tryParse).toList();
      if (octets.any((octet) => octet == null || octet > 255)) {
        return address;
      }
      return _maskHost(address);
    });
    masked = masked.replaceAllMapped(_domainPattern, (match) {
      return _maskHost(match.group(0)!);
    });
    masked = masked.replaceAllMapped(_bearerPattern, (match) {
      final prefix = match.group(1) ?? 'Token';
      return '$prefix [redacted]';
    });
    return masked.replaceAllMapped(_longTokenPattern, (match) {
      final token = match.group(0)!;
      if (_looksLikeHash(token)) {
        return token;
      }
      return '${token.substring(0, 6)}...[redacted]';
    });
  }

  static String maskUrl(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    return _maskUrl(value.trim());
  }

  static String maskPort(String value) {
    if (value.isEmpty) return '*';
    if (!RegExp(r'^\d+$').hasMatch(value)) return value;
    if (value.length == 1) return '*';
    if (value.length == 2) return '${value[0]}*';
    return '${value[0]}${'*' * (value.length - 2)}${value[value.length - 1]}';
  }

  static String _maskUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      return '[redacted-url]';
    }

    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    final host = _maskHost(uri.host);
    final port = uri.hasPort ? ':${uri.port}' : '';
    final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    final firstSegment =
        segments.isEmpty ? '' : _safePathSegment(segments.first);
    final path = firstSegment.isEmpty ? '' : '/$firstSegment/...';
    final query = uri.query.isEmpty ? '' : '?[redacted]';

    return '$scheme://$host$port$path$query';
  }

  static String _safePathSegment(String segment) {
    final lower = segment.toLowerCase();
    if (segment.length > 16 ||
        lower.contains('token') ||
        lower.contains('subscribe') ||
        lower.contains('auth') ||
        lower.contains('key')) {
      return '[redacted]';
    }
    return segment;
  }

  static String _maskHost(String host) {
    if (host.isEmpty) return '*';
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
    if (ipv4.hasMatch(host)) {
      final parts = host.split('.');
      return '${parts.first}.***.***.${parts.last}';
    }

    final parts = host.split('.');
    return parts.map(_maskPart).join('.');
  }

  static String _maskPart(String value) {
    if (value.isEmpty) return '*';
    if (value.length == 1) return '*';
    if (value.length == 2) return '${value[0]}*';
    return '${value[0]}***${value[value.length - 1]}';
  }

  static bool _looksLikeHash(String value) {
    final isHex = RegExp(r'^[a-fA-F0-9]+$').hasMatch(value);
    return isHex &&
        (value.length == 32 || value.length == 40 || value.length == 64);
  }

  static bool hasSensitiveQuery(Uri uri) {
    return uri.queryParameters.keys.any(
      (key) => _sensitiveQueryKeys.contains(key.toLowerCase()),
    );
  }
}
