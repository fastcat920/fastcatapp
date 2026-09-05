import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityManager extends StatefulWidget {
  final Function(List<ConnectivityResult> results)? onConnectivityChanged;
  final Widget child;

  const ConnectivityManager({
    super.key,
    this.onConnectivityChanged,
    required this.child,
  });

  @override
  State<ConnectivityManager> createState() => _ConnectivityManagerState();
}

class _ConnectivityManagerState extends State<ConnectivityManager> {
  StreamSubscription<List<ConnectivityResult>>? subscription;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
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
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
