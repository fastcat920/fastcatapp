import 'dart:io';

class DnsServerValidationError {
  const DnsServerValidationError(this.line, this.value);

  final int line;
  final String value;
}

/// Validates the DNS endpoint forms accepted by Mihomo's nameserver fields.
/// Keep protocols in sync with core/Clash.Meta/config/config.go.
DnsServerValidationError? validateDnsServerEntries(
  List<String> entries, {
  bool ipOnly = false,
}) {
  for (var index = 0; index < entries.length; index++) {
    if (!_isValidDnsServer(entries[index], ipOnly: ipOnly)) {
      return DnsServerValidationError(index + 1, entries[index]);
    }
  }
  return null;
}

bool _isValidDnsServer(String raw, {required bool ipOnly}) {
  final value = raw.trim();
  if (value.isEmpty || value.contains(RegExp(r'\s'))) return false;
  if (InternetAddress.tryParse(value) != null) return true;

  if (_isIpWithPort(value)) return true;
  if (ipOnly) return false;

  if (value == 'system' || value == 'system://') return true;

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) return false;
  const allowedSchemes = {'http', 'https', 'tls', 'quic', 'udp', 'tcp', 'dhcp'};
  if (!allowedSchemes.contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return false;
  }
  try {
    final port = uri.hasPort ? uri.port : null;
    if (port != null && (port < 1 || port > 65535)) return false;
  } on FormatException {
    return false;
  }
  if (uri.scheme.toLowerCase() == 'https' &&
      uri.path.isNotEmpty &&
      !uri.path.startsWith('/')) {
    return false;
  }
  return InternetAddress.tryParse(uri.host) != null ||
      _isValidHostname(uri.host);
}

bool _isIpWithPort(String value) {
  final uri = Uri.tryParse('udp://$value');
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      InternetAddress.tryParse(uri.host) == null) {
    return false;
  }
  try {
    return uri.hasPort && uri.port >= 1 && uri.port <= 65535;
  } on FormatException {
    return false;
  }
}

bool _isValidHostname(String value) {
  if (value.length > 253 || value.startsWith('.') || value.endsWith('.')) {
    return false;
  }
  return value.split('.').every(
        (label) =>
            label.isNotEmpty &&
            label.length <= 63 &&
            RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$')
                .hasMatch(label),
      );
}
