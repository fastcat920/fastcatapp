# FastCat tvOS

Native tvOS 17+ client. It deliberately does not depend on Flutter: Flutter's
stable toolchain has no tvOS application target. The app shares FastCat's QR
authorization protocol and uses a tvOS Packet Tunnel extension to host mihomo.

## First build

1. Copy `Config.xcconfig.example` to `Config.xcconfig` and set the production
   API gateway, bundle ID, team and App Group.
2. Run `scripts/build_tvos_core.sh` to create the tvOS arm64 libclash framework.
3. Run `ruby scripts/setup_tvos.rb` and open `tvos/FastCatTV.xcodeproj`.
4. In Xcode, choose the same development team for `FastCatTV` and
   `PacketTunnel`, then enable **Network Extensions / Packet Tunnel** and
   **App Groups** for both identifiers in the Apple Developer portal.
5. Test on an Apple TV running tvOS 17 or later. Archive the `FastCatTV`
   scheme and upload it to the tvOS platform of the existing App Store record.

The App Store product page still needs tvOS screenshots, app icon, privacy
policy and VPN review notes. The TV app must be submitted as an independent
tvOS build even when it shares the iOS bundle identifier and purchase record.
