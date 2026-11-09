import 'package:flutter/cupertino.dart';

/// A real Cupertino route with an offstage parking place for its session UI.
/// Reparenting the keyed subtree in the pop-completion frame retains native
/// views, unsent text, scroll controllers and SDK subscriptions between opens.
class CachedCupertinoPage {
  CachedCupertinoPage({required Widget child, required this.onHidden})
      : _content = KeyedSubtree(key: GlobalKey(), child: child);

  final Widget _content;
  final VoidCallback onHidden;
  OverlayEntry? _parking;
  _SessionRoute? _route;
  bool _inRoute = false;
  bool _disposed = false;
  bool _closing = false;
  bool _popCommitted = false;
  BuildContext? _pendingContext;

  void show(BuildContext context) {
    if (_disposed) return;
    if (_route != null) {
      if (_closing) _pendingContext = context;
      return;
    }
    _parking ??= OverlayEntry(
        builder: (_) => Offstage(
              offstage: true,
              child: TickerMode(
                  enabled: false,
                  child: _disposed || _inRoute
                      ? const SizedBox.shrink()
                      : _content),
            ));
    if (!_parking!.mounted) {
      Overlay.of(context, rootOverlay: true).insert(_parking!);
    }
    _inRoute = true;
    _closing = false;
    _popCommitted = false;
    _parking!.markNeedsBuild();
    late final _SessionRoute route;
    route = _SessionRoute(
      builder: (_) => _content,
      onPopped: () {
        _closing = true;
        _popCommitted = true;
        FocusManager.instance.primaryFocus?.unfocus();
        onHidden();
      },
      onPark: () {
        if (_disposed || !identical(_route, route)) return;
        if (!_closing) onHidden();
        _route = null;
        _inRoute = false;
        _parking?.markNeedsBuild();
        final pending = _pendingContext;
        _pendingContext = null;
        if (pending != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_disposed && pending.mounted) show(pending);
          });
        }
      },
    );
    _route = route;
    Navigator.of(context, rootNavigator: true).push<void>(route);
  }

  void hide() {
    final route = _route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    navigator.popUntil(
        (candidate) => identical(candidate, route) || candidate.isFirst);
    if (route.isCurrent && !_closing) {
      _closing = true;
      navigator.maybePop().then((_) {
        if (!_disposed && identical(_route, route) && !_popCommitted) {
          _closing = false;
          _pendingContext = null;
        }
      });
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pendingContext = null;
    final route = _route;
    final navigator = route?.navigator;
    if (route != null && navigator != null && route.isActive) {
      navigator.popUntil(
          (candidate) => identical(candidate, route) || candidate.isFirst);
      navigator.removeRoute(route);
    }
    _route = null;
    _parking?.remove();
    _parking?.dispose();
    _parking = null;
  }
}

class _SessionRoute extends CupertinoPageRoute<void> {
  _SessionRoute(
      {required super.builder, required this.onPopped, required this.onPark});
  final VoidCallback onPopped;
  final VoidCallback onPark;

  @override
  void install() {
    super.install();
    animation!.addStatusListener(_statusChanged);
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) onPark();
  }

  @override
  bool didPop(void result) {
    final popped = super.didPop(result);
    if (popped) onPopped();
    return popped;
  }

  @override
  void dispose() {
    animation!.removeStatusListener(_statusChanged);
    onPark();
    super.dispose();
  }
}
