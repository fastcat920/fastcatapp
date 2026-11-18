# Desktop support notifications

Windows, macOS and Linux keep the application's message feed independent of
the chat view. Process exit stops delivery; no background daemon is installed.

* Focused app, other page: application sound, respecting the chat sound switch.
* Focused chat: chat owns the sound; no desktop banner.
* Unfocused, hidden or minimized window: one desktop notification, with system
  sound unless muted. The application does not play a second sound.
* Replies within 700 ms are combined. Message IDs are deduplicated per session.
* Notification clicks show/focus the window and open the current account's
  conversation. Only the chat's visibility/read acknowledgement marks it read.
* Zero unread clears the support notification and unread indicator. Account
  changes dispose notification callbacks. Foregrounding reconciles messages.

macOS uses UserNotifications and a numeric Dock badge. Windows uses the vendored
MIT local_notifier/WinToast implementation with silent/replacement fixes and a
taskbar overlay; its tooltip and tray menu show the exact count. Linux uses
org.freedesktop.Notifications with a default click action and suppress-sound
hint, plus Unity LauncherEntry count updates for application://com.fastcat.app.desktop.
Linux launchers that do not implement this protocol still have the in-app count
and tray menu entry when the desktop exposes a tray.

Desktop notification permission, do-not-disturb and sound-hint support remain
controlled by the operating system. Windows needs its application shortcut
(created by notifier setup). Linux needs a user session D-Bus notification server.
No message content is included in the desktop banner.

Validation on macOS: native build and mocked-channel regression for foreground
sound, background batching, mute, deduplication and read cancellation. Windows
and Linux require their own build and runtime acceptance on those systems.
