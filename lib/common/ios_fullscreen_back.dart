import 'package:flutter/cupertino.dart';

/// Interactive iOS back transition. Child horizontal controls compete normally
/// in Flutter's gesture arena; routes with pop interception remain protected.
class IOSFullscreenBackTransitionsBuilder extends PageTransitionsBuilder {
  const IOSFullscreenBackTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    return _BackGesture(
      route: route,
      child: CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: route.navigator?.userGestureInProgress ?? false,
        child: child,
      ),
    );
  }
}

class _BackGesture extends StatefulWidget {
  const _BackGesture({required this.route, required this.child});
  final PageRoute<dynamic> route;
  final Widget child;
  @override
  State<_BackGesture> createState() => _BackGestureState();
}

class _BackGestureState extends State<_BackGesture> {
  NavigatorState? _navigator;
  AnimationController? _animation;

  void _update(DragUpdateDetails details) {
    if (_navigator == null) {
      if ((details.primaryDelta ?? 0) <= 0 || !widget.route.popGestureEnabled) {
        return;
      }
      // TransitionRoute exposes its controller for interactive transitions.
      // ignore: invalid_use_of_protected_member
      _animation = widget.route.controller;
      if (_animation == null) return;
      _navigator = widget.route.navigator;
      _navigator?.didStartUserGesture();
    }
    final width = MediaQuery.sizeOf(context).width;
    _animation!.value -= (details.primaryDelta ?? 0) / width;
  }

  Future<void> _finish(double velocity, {bool cancelled = false}) async {
    final navigator = _navigator;
    final animation = _animation;
    if (navigator == null || animation == null) return;
    _navigator = null;
    _animation = null;
    final pop = !cancelled &&
        (velocity.abs() >= 700 ? velocity > 0 : animation.value < 0.5);
    final completing = pop && widget.route.isCurrent;
    final remaining = completing ? animation.value : 1 - animation.value;
    final width = MediaQuery.sizeOf(context).width;
    final towardTarget = completing ? velocity : -velocity;
    // Small remaining distances and fast flicks should settle immediately.
    final distanceMs = 180 * remaining;
    final velocityMs =
        towardTarget > 0 ? remaining * width / towardTarget * 1000 : distanceMs;
    final duration = Duration(
      milliseconds: (velocityMs < distanceMs ? velocityMs : distanceMs)
          .clamp(40, 180)
          .round(),
    );
    try {
      if (completing) {
        navigator.pop();
        await animation
            .animateBack(0, duration: duration, curve: Curves.easeOutCubic)
            .orCancel;
      } else {
        await animation
            .animateTo(1, duration: duration, curve: Curves.easeOutCubic)
            .orCancel;
      }
    } on TickerCanceled {
      // Route disposal can cancel the transition.
    } finally {
      navigator.didStopUserGesture();
    }
  }

  @override
  void dispose() {
    _navigator?.didStopUserGesture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: (details) => _finish(details.primaryVelocity ?? 0),
        onHorizontalDragCancel: () => _finish(0, cancelled: true),
        child: widget.child,
      );
}
