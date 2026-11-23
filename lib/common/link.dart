import 'dart:async';

import 'package:app_links/app_links.dart';

import 'print.dart';

typedef InstallConfigCallBack = Future<void> Function(String url);

class LinkManager {
  static LinkManager? _instance;
  late AppLinks _appLinks;
  StreamSubscription? subscription;

  LinkManager._internal() {
    _appLinks = AppLinks();
  }

  initAppLinksListen(InstallConfigCallBack installConfigCallBack) async {
    commonPrint.log("initAppLinksListen");
    destroy();
    subscription = _appLinks.uriLinkStream
        .where((uri) => uri.host == 'install-config')
        .asyncMap((uri) async {
      final url = uri.queryParameters['url'];
      if (url != null) await installConfigCallBack(url);
    }).listen((_) {});
  }

  destroy() {
    if (subscription != null) {
      subscription?.cancel();
      subscription = null;
    }
  }

  factory LinkManager() {
    _instance ??= LinkManager._internal();
    return _instance!;
  }
}

final linkManager = LinkManager();
