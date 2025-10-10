import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class CustomTextButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;

  const CustomTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.icon,
  });

  @override
  State<CustomTextButton> createState() => _CustomTextButtonState();
}

class _CustomTextButtonState extends State<CustomTextButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppColors.secondaryAccent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null)
              Icon(
                widget.icon,
                size: 16,
                color: AppColors.secondaryText,
              ),
            if (widget.icon != null) const SizedBox(width: 4),
            Text(
              widget.text,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: effectiveColor,
                decoration: _isHovering
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
