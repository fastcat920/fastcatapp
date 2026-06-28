import 'dart:io';

import 'package:fl_clash/common/common.dart';

class SingleInstanceLock {
  static SingleInstanceLock? _instance;
  RandomAccessFile? _accessFile;

  SingleInstanceLock._internal();

  factory SingleInstanceLock() {
    _instance ??= SingleInstanceLock._internal();
    return _instance!;
  }

  Future<bool> acquire() async {
    try {
      final lockFilePath = await appPath.lockFilePath;
      final lockFile = File(lockFilePath);
      await lockFile.create();
      _accessFile = await lockFile.open(mode: FileMode.write);
      await _accessFile?.lock();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> release() async {
    final accessFile = _accessFile;
    if (accessFile == null) return;
    _accessFile = null;
    try {
      await accessFile.unlock();
    } catch (_) {}
    try {
      await accessFile.close();
    } catch (_) {}
  }
}

final singleInstanceLock = SingleInstanceLock();
