import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/common/print.dart';
import 'package:fl_clash/state.dart';
import 'package:proxy/proxy.dart';

final proxy = system.isDesktop
    ? Proxy(onDiagnostic: (message) {
        if (globalState.isInit && globalState.config.appSetting.logCapture) {
          commonPrint.log(message);
        }
      })
    : null;
