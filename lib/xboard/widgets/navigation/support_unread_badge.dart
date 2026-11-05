import 'package:flutter/material.dart';
import 'package:fl_clash/xboard/features/auth/utils/customer_service_helper.dart';

/// Shares the support button's source; navigation never clears unread messages.
class SupportUnreadBadge extends StatelessWidget {
  const SupportUnreadBadge(
      {super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return StreamBuilder<int>(
      stream: CustomerServiceHelper.supportUnreadCountStream,
      initialData: CustomerServiceHelper.supportUnreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(clipBehavior: Clip.none, children: [
          child,
          if (count > 0)
            Positioned(
                top: -6,
                right: -8,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 15, minHeight: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w600)),
                )),
        ]);
      },
    );
  }
}
