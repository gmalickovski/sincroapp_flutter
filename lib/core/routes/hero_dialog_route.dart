import 'package:flutter/material.dart';

/// A custom [PageRoute] that displays its content with a dimming barrier,
/// similar to a Dialog, but as a full PageRoute to support Hero animations.
class HeroDialogRoute<T> extends PageRoute<T> {
  HeroDialogRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  })  : _builder = builder,
        super(settings: settings, fullscreenDialog: fullscreenDialog);

  final WidgetBuilder _builder;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  bool get maintainState => true;

  @override
  Color get barrierColor => Colors.black54;

  @override
  String get barrierLabel => 'Fechar';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // We return the child directly.
    // The Hero widget will handle the transition of the shared element.
    // The barrier fades in automatically due to barrierColor.
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}
