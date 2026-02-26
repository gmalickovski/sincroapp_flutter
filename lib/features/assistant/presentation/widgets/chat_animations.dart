import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'dart:math' as math;

/// A wrapper that animates the entry of a chat message (Size + Fade + Slide).
/// Perfect for reverse ListViews to push content smoothly.
class MessageEntryAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Duration delay;
  final bool isUser;
  final bool animate;

  const MessageEntryAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutQuad,
    this.delay = Duration.zero,
    this.isUser = false,
    this.animate = true,
  });

  @override
  State<MessageEntryAnimation> createState() => _MessageEntryAnimationState();
}

class _MessageEntryAnimationState extends State<MessageEntryAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  late Animation<double> _size;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );

    _offset = Tween<Offset>(
            begin: Offset(widget.isUser ? 0.2 : -0.2, 0.5), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _size = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    if (!widget.animate) {
      _controller.value = 1.0;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1.0, // Expand from bottom
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _offset,
          child: widget.child,
        ),
      ),
    );
  }
}

// Keep AnimatedMessageBubble for backward compatibility if needed, or redirect
class AnimatedMessageBubble extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const AnimatedMessageBubble(
      {super.key, required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    return MessageEntryAnimation(delay: delay, child: child);
  }
}

/// Alias for MessageEntryAnimation used in new panels
class ChatBubbleAnimation extends StatelessWidget {
  final Widget child;
  final bool isUser;

  const ChatBubbleAnimation(
      {super.key, required this.child, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return MessageEntryAnimation(isUser: isUser, child: child);
  }
}

/// An avatar that "pops" in with a scale animation.
class AnimatedAvatar extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool animate;

  const AnimatedAvatar({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.animate = true,
  });

  @override
  State<AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<AnimatedAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

/// A smooth typing indicator with 3 jumping dots.
class TypingIndicator extends StatefulWidget {
  final Color color;
  final double dotSize;

  const TypingIndicator({
    super.key,
    this.color = AppColors.primary,
    this.dotSize = 8.0,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.dotSize * 5, // Space for 3 dots + spacing
      height: widget.dotSize * 2, // Space for jump
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              // Calculate sine wave offset for each dot
              // Staggered by index
              final delay = index * 0.2;
              final value = _controller.value;
              final sineValue = math.sin((value * 2 * math.pi) - delay);

              // Only jump up (positive sine part), clamp negative to 0 for a "bounce" feel
              // or just use full sine wave. Let's use a smooth wave.
              final offset = sineValue * (widget.dotSize * 0.6);

              return Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  margin:
                      EdgeInsets.symmetric(horizontal: widget.dotSize * 0.2),
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(
                        alpha:
                            0.6 + (sineValue.abs() * 0.4)), // Pulse opacity too
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// A bubble that animates its size from "small" (typing size) to full size.
class MorphingMessageBubble extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const MorphingMessageBubble({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<MorphingMessageBubble> createState() => _MorphingMessageBubbleState();
}

class _MorphingMessageBubbleState extends State<MorphingMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthFactor;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    // Animate from a smaller size (simulating typing bubble) to full size
    // Note: AnimatedSize is easier for this specific "morph" effect
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use AnimatedSize for the morph effect
    return AnimatedSize(
      duration: widget.duration,
      curve: Curves.easeOutBack, // Slight bounce for "pop" effect
      alignment: Alignment.centerLeft,
      child: widget.child,
    );
  }
}
