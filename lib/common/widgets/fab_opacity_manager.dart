import 'dart:async';
import 'package:flutter/material.dart';

/// Controller to manage FAB opacity state
class FabOpacityController extends ValueNotifier<double> {
  FabOpacityController() : super(1.0);
  Timer? _timer;

  void onInteraction() {
    // Se já estiver transparente, apenas reinicia o timer
    if (value != 0.1) {
      value = 0.1; // Quase transparente
    }
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      value = 1.0; // Volta ao normal após inatividade
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Widget to listen for interactions (scroll/tap) and notify the controller
class ScreenInteractionListener extends StatelessWidget {
  final Widget child;
  final FabOpacityController controller;

  const ScreenInteractionListener({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll is ScrollUpdateNotification ||
            scroll is ScrollStartNotification) {
          controller.onInteraction();
        }
        return false; // Permite que o scroll continue propagando
      },
      child: Listener(
        onPointerDown: (_) => controller.onInteraction(),
        // Opcional: onPointerMove para detectar toques arrastados que não são scroll
        child: child,
      ),
    );
  }
}

/// Wrapper to animate the FAB opacity
class TransparentFabWrapper extends StatelessWidget {
  final FabOpacityController controller;
  final Widget child;

  const TransparentFabWrapper({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: controller,
      builder: (context, opacity, child) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          opacity: opacity,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Places the FAB 8dp above the bottom safe area instead of the default 16dp,
/// resulting in a slightly lower visual position while still respecting the
/// gesture navigation bar on both iOS (home indicator) and Android (gesture bar).
class BottomSafeFabLocation extends FloatingActionButtonLocation {
  const BottomSafeFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width
        - scaffoldGeometry.floatingActionButtonSize.width
        - 16.0;
    final double fabY = scaffoldGeometry.scaffoldSize.height
        - scaffoldGeometry.floatingActionButtonSize.height
        - 8.0 // 8dp margin (half the default 16dp) → FAB sits lower
        - scaffoldGeometry.minInsets.bottom; // respects safe area / gesture bar
    return Offset(fabX, fabY);
  }
}

/// Custom FloatingActionButtonAnimator to disable the scaling animation
class NoScalingAnimation extends FloatingActionButtonAnimator {
  @override
  Offset getOffset(
      {required Offset begin, required Offset end, required double progress}) {
    return end;
  }

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) {
    return Tween<double>(begin: 1.0, end: 1.0).animate(parent);
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) {
    return Tween<double>(begin: 1.0, end: 1.0).animate(parent);
  }
}
