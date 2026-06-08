import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
// import 'package:fl_clash/views/views.dart';
import 'package:fl_clash/xboard/features/payment/pages/plans.dart';
import 'package:fl_clash/xboard/features/subscription/pages/xboard_home_page.dart';
import 'package:fl_clash/xboard/features/invite/pages/invite_page.dart';
import 'package:flutter/material.dart';

class Navigation {
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) {
    return [
      const NavigationItem(
        icon: Icon(Icons.home),
        label: PageLabel.xboard,
        view: XBoardHomePage(
          key: GlobalObjectKey(
            PageLabel.xboard,
          ),
        ),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      const NavigationItem(
        icon: Icon(Icons.shopping_cart),
        label: PageLabel.plans,
        view: PlansView(
          key: GlobalObjectKey(
            PageLabel.plans,
          ),
        ),
        modes: [NavigationItemMode.desktop],
      ),
      const NavigationItem(
        icon: Icon(Icons.people),
        label: PageLabel.invite,
        view: InvitePage(
          key: GlobalObjectKey(
            PageLabel.invite,
          ),
        ),
        modes: [
          NavigationItemMode.desktop,
          NavigationItemMode.mobile
        ], // 桌面端和手机端都显示
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
