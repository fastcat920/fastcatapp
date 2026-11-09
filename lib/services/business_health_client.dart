import 'dart:io';

/// Business reachability must use the same HttpOverrides/proxy policy as API
/// requests. Raw TUN health is measured separately by the native VPN service.
HttpClient createBusinessHealthClient() =>
    HttpClient()..connectionTimeout = const Duration(seconds: 4);
