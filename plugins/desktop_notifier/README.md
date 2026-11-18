Based on leanflutter/local_notifier 0.1.6 (MIT, see LICENSE).

Only the Windows plugin is registered. FastCat uses UserNotifications on macOS
and freedesktop D-Bus on Linux. Windows changes honor `silent`, replace existing
toasts, report failed delivery, and retain the existing Dart click callbacks.
