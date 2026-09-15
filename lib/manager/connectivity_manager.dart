import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityManager extends StatefulWidget {
  final Function(List<ConnectivityResult> results)? onConnectivityChanged;
  final ValueChanged<List<ConnectivityResult>>? onNetworkIdentityChanged;
  final Widget child;

  const ConnectivityManager({
    super.key,
    this.onConnectivityChanged,
    this.onNetworkIdentityChanged,
    required this.child,
  });

  @override
  State<ConnectivityManager> createState() => _ConnectivityManagerState();
}

class _ConnectivityManagerState extends State<ConnectivityManager>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? subscription;
  bool _disposed = false;
  Timer? _identityTimer;
  String? _identity;
  bool _checkingIdentity = false;

  Future<void> _checkIdentity() async {
    if (_disposed || _checkingIdentity) return;
    _checkingIdentity = true;
    try {
      final interfaces = await NetworkInterface.list();
      final addresses = interfaces
          .where((i) => !RegExp(r'^(tun|utun|tap|ppp|wg|ipsec)',
              caseSensitive: false).hasMatch(i.name))
          .expand((i) => i.addresses.map((a) => '${i.name}:${a.address}'))
          .toList()..sort();
      final identity = addresses.join(',');
      final results = await Connectivity().checkConnectivity();
      if (_disposed) return;
      final previous = _identity;
      _identity = identity;
      if (previous != null && previous != identity) {
        widget.onNetworkIdentityChanged?.call(results);
      }
    } on SocketException {
      // A failed interface read is not evidence of a network transition.
    } finally {
      _checkingIdentity = false;
    }
  }

  void _startIdentityTimer() {
    _identityTimer?.cancel();
    _identityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_checkIdentity());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkIdentity());
      _startIdentityTimer();
    } else {
      _identityTimer?.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkIdentity());
    _startIdentityTimer();
    unawaited(_startListening());
  }

  Future<void> _startListening() async {
    // Establish a baseline first. This prevents the first stream event after
    // startup from being mistaken for a network handoff.
    final initialResults = await Connectivity().checkConnectivity();
    if (_disposed) return;
    _notify(initialResults);
    subscription = Connectivity().onConnectivityChanged.listen(_notify);
  }

  void _notify(List<ConnectivityResult> results) {
    if (_disposed) return;
    if (widget.onConnectivityChanged != null) {
      widget.onConnectivityChanged!(results);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _identityTimer?.cancel();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
