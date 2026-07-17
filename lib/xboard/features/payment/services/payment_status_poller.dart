import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/xboard/adapter/state/order_state.dart';
import 'package:fl_clash/xboard/domain/domain.dart';

typedef PaymentSuccessCallback = Future<void> Function();

Duration paymentPollingInterval(Duration elapsed, Duration initialInterval) {
  if (elapsed < const Duration(seconds: 30)) return initialInterval;
  if (elapsed < const Duration(minutes: 2)) return const Duration(seconds: 8);
  return const Duration(seconds: 15);
}

class PaymentStatusPoller {
  final String tradeNo;
  final WidgetRef ref;
  final PaymentSuccessCallback onSuccess;
  final VoidCallback? onCanceled;
  final Duration interval;
  final Duration maxDuration;

  Timer? _timer;
  bool _isPolling = false;
  bool _isChecking = false;
  bool _isDisposed = false;
  DateTime? _startedAt;

  PaymentStatusPoller({
    required this.tradeNo,
    required this.ref,
    required this.onSuccess,
    this.onCanceled,
    this.interval = const Duration(seconds: 4),
    this.maxDuration = const Duration(minutes: 5),
  });

  bool get isPolling => _isPolling;

  void start() {
    if (_isPolling || _isDisposed) return;
    _isPolling = true;
    _startedAt = DateTime.now();
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
    final startedAt = _startedAt;
    if (startedAt != null &&
        DateTime.now().difference(startedAt) >= maxDuration) {
      stop();
      return;
    }
    _timer?.cancel();
    _timer = Timer(initial ? const Duration(seconds: 3) : _nextInterval(), () {
      _checkStatus();
    });
  }

  Duration _nextInterval() {
    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    return paymentPollingInterval(elapsed, interval);
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

      final status = OrderStatus.fromCode(order.status ?? 0);
      if (status == OrderStatus.completed || status == OrderStatus.discounted) {
        stop();
        await onSuccess();
        return;
      }

      if (status == OrderStatus.canceled) {
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
