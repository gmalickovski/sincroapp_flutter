
import 'package:flutter/material.dart';

/// Shows a smart popup that anchors to the context's widget (usually a button).
/// Adjusts position to avoid going off-screen and adds scrolling if content is too tall.
Future<T?> showSmartPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Offset offset = const Offset(0, 4),
}) {
  final RenderBox? targetBox = context.findRenderObject() as RenderBox?;
  if (targetBox == null) return Future.value(null);

  final OverlayState? overlay = Overlay.of(context);
  if (overlay == null) return Future.value(null);
  
  final RenderBox overlayBox = overlay.context.findRenderObject() as RenderBox;

  final Size targetSize = targetBox.size;
  final Offset targetPos = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final Size overlaySize = overlayBox.size;

  return Navigator.push(
    context,
    _SmartPopupRoute<T>(
      builder: builder,
      targetPos: targetPos,
      targetSize: targetSize,
      overlaySize: overlaySize,
      offset: offset,
    ),
  );
}

class _SmartPopupRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final Offset targetPos;
  final Size targetSize;
  final Size overlaySize;
  final Offset offset;

  _SmartPopupRoute({
    required this.builder,
    required this.targetPos,
    required this.targetSize,
    required this.overlaySize,
    required this.offset,
  });

  @override
  Color? get barrierColor => Colors.transparent; // Validar se o usuario quer dimming. Geralmente menus nao tem.

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fechar menu';

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _SmartPopupLayout(
      targetPos: targetPos,
      targetSize: targetSize,
      overlaySize: overlaySize,
      offset: offset,
      child: FadeTransition(
        opacity: animation,
        child: builder(context),
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);
}

class _SmartPopupLayout extends StatelessWidget {
  final Offset targetPos;
  final Size targetSize;
  final Size overlaySize;
  final Offset offset;
  final Widget child;

  const _SmartPopupLayout({
    required this.targetPos,
    required this.targetSize,
    required this.overlaySize,
    required this.offset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate space below and above
    final double spaceBelow = overlaySize.height - (targetPos.dy + targetSize.height + offset.dy);
    final double spaceAbove = targetPos.dy - offset.dy;
    
    // 2. Decide Vertical Position
    // Prefer below if there's enough space (e.g., at least 200px or 40% of screen) or if it's larger than above.
    // However, if spaceBelow is very small (< 150), try above.
    bool showBelow = true;
    if (spaceBelow < 200 && spaceAbove > spaceBelow) {
      showBelow = false;
    }

    double? top;
    double? bottom;
    double maxHeight;

    if (showBelow) {
      top = targetPos.dy + targetSize.height + offset.dy;
      maxHeight = spaceBelow - 16; // Margin bottom
    } else {
      bottom = overlaySize.height - targetPos.dy + offset.dy;
      maxHeight = spaceAbove - 16; // Margin top
    }

    // 3. Horizontal Position
    // Align Right edge of popup with Right edge of Target
    // If it goes off-screen left, shift right.
    
    final double rightDistance = overlaySize.width - (targetPos.dx + targetSize.width);
    
    return Stack(
      children: [
        Positioned(
          top: top,
          bottom: bottom,
          right: rightDistance, // Align right edges
          child: Material(
            color: Colors.transparent,
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight > 0 ? maxHeight : 100,
                maxWidth: overlaySize.width - 32, // Padding 16 on each side
                minWidth: 200,
              ),
              child: IntrinsicWidth(
                 // IntrinsicWidth allows the child to define its width (up to maxWidth)
                child: child,
                // Removed SingleChildScrollView here because the Panels already have it.
                // WE MUST NOT NEST SingleChildScrollView(Column(children: [Expanded])) improperly.
                // The Panel SHOULD be responsible for scrolling if constrained.
              ),
            ),
          ),
        ),
      ],
    );
  }
}
