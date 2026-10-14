import 'dart:async';
import 'dart:math' as math;

/// Normalized camera zoom, with one native request at a time and latest-wins
/// coalescing. No preview transforms: recognition sees the same camera image.
class ScannerZoom {
  ScannerZoom({required this.readZoom, required this.applyZoom});

  final double Function() readZoom;
  final Future<void> Function(double) applyZoom;
  bool _active = false;
  bool _disposed = false;
  double? _desired;
  double? _pending;
  double? _anchorScale;
  double _anchorZoom = 0;
  Timer? _timer;
  Future<void>? _inFlight;

  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;
    endGesture();
    if (!active) {
      _timer?.cancel();
      _timer = null;
      _pending = null;
    } else if (_desired != null) {
      _queue(_desired!); // Restore this page's zoom after camera restart.
    }
  }

  void update(double scale, int pointers) {
    if (!_active ||
        _disposed ||
        pointers != 2 ||
        !scale.isFinite ||
        scale <= 0) {
      endGesture();
      return;
    }
    if (_anchorScale == null) {
      _anchorScale = scale;
      final current = _desired ?? readZoom();
      _anchorZoom = current.isFinite ? current.clamp(0.0, 1.0) : 0;
      return;
    }
    final value =
        (_anchorZoom + math.log(scale / _anchorScale!) * 0.35).clamp(0.0, 1.0);
    _desired = value;
    _queue(value);
  }

  void endGesture() => _anchorScale = null;

  void _queue(double value) {
    _pending = value;
    if (_timer != null || _inFlight != null) return;
    _timer = Timer(const Duration(milliseconds: 40), () {
      _timer = null;
      if (!_active || _disposed || _pending == null) return;
      final next = _pending!;
      _pending = null;
      _inFlight = _apply(next);
      unawaited(_inFlight!.whenComplete(() {
        _inFlight = null;
        if (_active && !_disposed && _pending != null) _queue(_pending!);
      }));
    });
  }

  Future<void> _apply(double value) async {
    try {
      await applyZoom(value);
    } catch (_) {
      // Unsupported/temporarily unavailable zoom must not interrupt scanning.
    }
  }

  Future<void> pause() async {
    setActive(false);
    // A lost platform reply must not hold the authorization flow indefinitely.
    await _inFlight?.timeout(const Duration(seconds: 1), onTimeout: () {});
  }

  void dispose() {
    setActive(false);
    _disposed = true;
  }
}
