import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class HoverableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderRadius;

  const HoverableCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
    this.borderRadius = 12.0,
  });

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _isHovered
                    ? (widget.borderColor ?? AppColors.primary)
                        .withValues(alpha: 1.0)
                    : (widget.borderColor ?? AppColors.primary)
                        .withValues(alpha: 0.5),
                width: 1.5,
              ),
              color: Colors.transparent, // Ensures child content is visible
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
