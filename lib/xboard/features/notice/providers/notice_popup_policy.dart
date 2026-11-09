/// Do not present while the first home frame is still being replaced.
class NoticePopupPolicy {
  NoticePopupPolicy({this.settleTime = const Duration(milliseconds: 400)});
  final Duration settleTime;
  DateTime? _readySince;
  void reset() => _readySince = null;
  bool canPresent({required bool environmentReady, required DateTime now}) {
    if (!environmentReady) {
      reset();
      return false;
    }
    _readySince ??= now;
    return now.difference(_readySince!) >= settleTime;
  }
}
