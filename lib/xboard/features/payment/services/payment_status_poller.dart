import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';


typedef PaymentSuccessCallback = Future<void> Function();

class PaymentStatusPoller {
  final String tradeNo;
  final WidgetRef ref;
  final PaymentSuccessCallback onSuccess;
  final VoidCallback? onCanceled;
  final Duration interval;

  Timer? _timer;
  bool _isPolling = false;
  bool _isChecking = false;
  bool _isDisposed = false;

  PaymentStatusPoller({
    required this.tradeNo,
    required this.ref,
    required this.onSuccess,
    this.onCanceled,
    this.interval = const Duration(seconds: 4),
  });

  bool get isPolling => _isPolling;

  void start() {
    if (_isPolling || _isDisposed) return;
    _isPolling = true;
    _scheduleNext(initial: true);
  }

  void stop() {
    _isPolling = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkNow() async {
    if (_isDisposed) return;
    await _checkStatus();
  }

  void dispose() {
    _isDisposed = true;
    stop();
  }

  void _scheduleNext({bool initial = false}) {
    if (!_isPolling || _isDisposed) return;
    _timer?.cancel();
    _timer = Timer(initial ? const Duration(seconds: 3) : interval, () {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    if (_isDisposed || _isChecking) return;
    _isChecking = true;

    try {
      clearGetOrderCache(tradeNo);
      ref.invalidate(getOrderProvider(tradeNo));
      final order = await ref.read(getOrderProvider(tradeNo).future);

      if (_isDisposed) return;
      if (order == null) {
        _scheduleNext();
        return;
      }

      if (order.status == 3 || order.status == 4) {
        stop();
        await onSuccess();
        return;
      }

      if (order.status == 2) {
        stop();
        onCanceled?.call();
        return;
      }

      _scheduleNext();
    } catch (e) {
      if (!_isDisposed) _scheduleNext();
    } finally {
      _isChecking = false;
    }
  }
}
