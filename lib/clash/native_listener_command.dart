import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';

const nativeListenerTimeout = Duration(seconds: 10);
int _listenerCommandSequence = 0;

/// Uses the existing asynchronous Action reply, never the legacy void FFI call.
Future<bool> invokeNativeListenerCommand(
  ActionMethod method,
  Future<String> Function(String message) send, {
  Duration timeout = nativeListenerTimeout,
}) async {
  if (method != ActionMethod.startListener &&
      method != ActionMethod.stopListener) {
    throw ArgumentError.value(method, 'method', 'Not a listener command');
  }
  final action = Action(
    id: '${method.name}#native-${_listenerCommandSequence++}',
    method: method,
    data: null,
  );
  final response = await send(json.encode(action)).timeout(timeout);
  final result = ActionResult.fromJson(json.decode(response));
  if (result.id != action.id ||
      result.method != method ||
      result.code != ResultType.success ||
      result.data is! bool) {
    throw StateError('Invalid acknowledgement for ${method.name}');
  }
  return result.data as bool;
}
