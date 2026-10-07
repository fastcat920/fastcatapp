/// Shares one in-flight operation across callers, including recreated pages.
/// Errors release the flight too, so a later explicit retry is possible.
class SingleFlight<T> {
  Future<T>? _pending;

  bool get isRunning => _pending != null;

  Future<T> run(Future<T> Function() operation) {
    if (_pending != null) return _pending!;
    final result = Future<T>.sync(operation);
    final pending = result.whenComplete(() => _pending = null);
    _pending = pending;
    return pending;
  }
}
