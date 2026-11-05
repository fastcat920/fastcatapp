import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/common/sensitive_masker.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/cupertino.dart';

class CommonPrint {
  static CommonPrint? _instance;

  CommonPrint._internal();

  factory CommonPrint() {
    _instance ??= CommonPrint._internal();
    return _instance!;
  }

  log(String? text) {
    final payload = "[$appName] ${SensitiveMasker.maskText(text)}";
    debugPrint(payload);
    if (!globalState.isInit) {
      return;
    }
    Future<void>(() {
      if (!globalState.isInit) return;
      globalState.appController.addLog(
        // The buffer computes a private repetition identity before redaction,
        // then stores only masked text. Console output above is already masked.
        Log.app('[$appName] ${text ?? ''}'),
      );
    });
  }
}

final commonPrint = CommonPrint();
