import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class ScrollableChipsRow extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const ScrollableChipsRow({
    super.key,
    required this.children,
    this.padding,
  });

  @override
  State<ScrollableChipsRow> createState() => _ScrollableChipsRowState();
}

class _ScrollableChipsRowState extends State<ScrollableChipsRow> {
  final ScrollController _controller = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false; // Initially assume false until measured

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void didUpdateWidget(ScrollableChipsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check when children change/update
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void dispose() {
    _controller.removeListener(_checkScroll);
    _controller.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!_controller.hasClients) return;
    final maxScroll = _controller.position.maxScrollExtent;
    final currentScroll = _controller.offset;

    // Check availability
    // Use a small tolerance for floating point comparisons
    final bool canLeft = currentScroll > 0.5;
    final bool canRight = currentScroll < maxScroll - 0.5;

    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canLeft;
          _canScrollRight = canRight;
        });
      }
    }
  }

  void _scrollLeft() {
    _controller.animateTo(
      (_controller.offset - 150)
          .clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    _controller.animateTo(
      (_controller.offset + 150)
          .clamp(0.0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (_canScrollLeft) ...[
          IconButton(
            icon:
                const Icon(Icons.chevron_left, color: AppColors.secondaryText),
            onPressed: _scrollLeft,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4), // Added spacing as requested
        ],
        Expanded(
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            child: Row(
              children: widget.children,
            ),
          ),
        ),
        if (_canScrollRight) ...[
          const SizedBox(width: 4), // Added spacing as requested
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: AppColors.secondaryText),
            onPressed: _scrollRight,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}
