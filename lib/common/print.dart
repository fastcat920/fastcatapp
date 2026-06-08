import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/models/models.dart';
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
    final payload = "[$appName] $text";
    debugPrint(payload);
    if (!globalState.isInit) {
      return;
    }
    Future<void>(() {
      if (!globalState.isInit) return;
      globalState.appController.addLog(
        Log.app(payload),
      );
    });
  }
}

final commonPrint = CommonPrint();
