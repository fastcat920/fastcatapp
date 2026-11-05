/// Keep native configuration applications ordered, including their failure.
/// A caller must not wrap this future with an earlier, non-cancelling timeout.
class SerialOperationQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
