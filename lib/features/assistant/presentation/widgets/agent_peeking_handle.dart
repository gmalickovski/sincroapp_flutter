import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';

class AgentPeekingHandle extends StatefulWidget {
  final double opacity; // Controlled by parent scrolling

  const AgentPeekingHandle({
    super.key,
    this.opacity = 1.0,
  });

  @override
  State<AgentPeekingHandle> createState() => _AgentPeekingHandleState();
}

class _AgentPeekingHandleState extends State<AgentPeekingHandle> with TickerProviderStateMixin {
  late AnimationController _peekController;
  late AnimationController _tabController;

  late Animation<double> _handsAnim;
  late Animation<double> _headAnim;
  late Animation<double> _blinkAnim; // Now "Wink"
  late Animation<double> _lookAnim; // New "Look at User"

  // Tab State
  // We use a controller to animate the tab exiting/entering smoothly
  // 0.0 = Tab Visible, 1.0 = Tab Hidden (Offscreen)

  Timer? _idleTimer;
  // "tempo bem alto" = 45 seconds
  static const Duration _idleInterval = Duration(seconds: 45); 

  @override
  void initState() {
    super.initState();
    
    // 1. Tab Controller (Quick toggle)
    _tabController = AnimationController(
        vsync: this, 
        duration: const Duration(milliseconds: 400),
        value: 0.0, // Start Visible
    );

    // 2. Peek Controller (Complex Sequence)
    _peekController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 5), // Total sequence time
    );

    _setupStaggeredAnimations();

    _tabController.addListener(() => setState(() {}));
    _peekController.addListener(() => setState(() {}));
    
    // Start "First Open" animation sequence shortly after mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
       Future.delayed(const Duration(seconds: 2), () {
         if (mounted) _startPeekingSequence();
       });
    });
  }

  void _setupStaggeredAnimations() {
    // Sequence: 5 Seconds total
    // 0.00-0.15: Hands In
    // 0.15-0.30: Head In
    // 0.30-0.38: Look Right (At User)
    // 0.42-0.58: Wink (Hold Look)
    // 0.62-0.70: Look Back (Reset)
    // 0.70-0.85: Head Out
    // 0.85-1.00: Hands Out

    _handsAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70), 
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 15),
    ]).animate(_peekController);

    _headAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40), 
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15), 
    ]).animate(_peekController);
    
    // Look Direction: 0.0 (Left/Normal) -> 1.0 (Right/User)
    _lookAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 8), // Look
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 24), // Hold Look
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 8), // Look Back
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
    ]).animate(_peekController);

    // Wink: 0.0 -> 1.0 -> 0.0
    _blinkAnim = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 42),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 3), // Close Eye
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10), // Hold Wink
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 3), // Open Eye
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 42),
    ]).animate(_peekController);
  }

  void _startPeekingSequence() async {
    if (!mounted) return;
    _idleTimer?.cancel();

    // 1. Hide Tab
    await _tabController.forward();
    
    // 2. Play Peek Sequence
    if (!mounted) return;
    await _peekController.forward();
    _peekController.reset();

    // 3. Show Tab
    if (!mounted) return;
    await _tabController.reverse();
    
    _scheduleNextPeek();
  }

  void _scheduleNextPeek() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleInterval, _startPeekingSequence);
  }

  @override
  void dispose() {
    _peekController.dispose();
    _tabController.dispose();
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, 
      height: 120,
      child: CustomPaint(
        painter: _UnifiedHandlePainter(
          tabPosition: _tabController.value,
          handsProgress: _handsAnim.value,
          headProgress: _headAnim.value,
          blinkProgress: _blinkAnim.value, // Acts as wink progress
          lookProgress: _lookAnim.value,   // Acts as gaze shift
          opacity: widget.opacity,
        ),
      ),
    );
  }
}

class _UnifiedHandlePainter extends CustomPainter {
  final double tabPosition;
  final double handsProgress;
  final double headProgress;
  final double blinkProgress;
  final double lookProgress;
  final double opacity;

  _UnifiedHandlePainter({
    required this.tabPosition, 
    required this.handsProgress,
    required this.headProgress,
    required this.blinkProgress,
    required this.lookProgress,
    required this.opacity,
  });

  // Colors
  final Color primaryColor = const Color(0xFF7C3AED); // Violeta 600
  final Color strokeColor = const Color(0xFFE0E0E0);

  @override
  void paint(Canvas canvas, Size size) {
    _drawTab(canvas, size);
    _drawPeekingAgent(canvas, size);
  }

  void _drawTab(Canvas canvas, Size size) {
    // If tab is fully hidden (position 1.0), skip
    if (tabPosition >= 1.0) return;

    // Tab Configuration: Taller and Narrower
    final tabWidth = 10.0; 
    final tabHeight = 64.0;
    final screenRight = size.width;
    
    // Position Calculations
    final currentOffset = tabPosition * tabWidth;
    final x = screenRight - tabWidth + currentOffset;
    final y = (size.height - tabHeight) / 2;

    // Opacity Logic
    final effectiveOpacity = opacity.clamp(0.0, 1.0);

    // Paint Setup
    final paintFill = Paint()
      ..color = primaryColor.withOpacity(effectiveOpacity)
      ..style = PaintingStyle.fill;
    
    final paintStroke = Paint()
      ..color = strokeColor.withOpacity(0.4 * effectiveOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw Tab Body (Rounded Left Corners)
    final rect = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, y, tabWidth + 20, tabHeight), 
      topLeft: const Radius.circular(12),
      bottomLeft: const Radius.circular(12),
    );

    canvas.drawRRect(rect, paintFill);
    
    // Draw Border Line (Left Side Only)
    final borderPath = Path();
    borderPath.moveTo(screenRight, y); 
    borderPath.lineTo(x + 12, y); 
    borderPath.quadraticBezierTo(x, y, x, y + 12); 
    borderPath.lineTo(x, y + tabHeight - 12); 
    borderPath.quadraticBezierTo(x, y + tabHeight, x + 12, y + tabHeight); 
    borderPath.lineTo(screenRight, y + tabHeight); 

    canvas.drawPath(borderPath, paintStroke);
    
    // Chevron Icon '<'
    if (tabPosition < 0.5) {
      final iconPath = Path();
      final cx = x + (tabWidth / 2); 
      final cy = y + (tabHeight / 2);
      
      iconPath.moveTo(cx + 2, cy - 5);
      iconPath.lineTo(cx - 2, cy);
      iconPath.lineTo(cx + 2, cy + 5);
      
      final iconPaint = Paint()
        ..color = Colors.white.withOpacity(0.8 * effectiveOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(iconPath, iconPaint);
    }
  }

  void _drawPeekingAgent(Canvas canvas, Size size) {
    if (handsProgress <= 0.01 && headProgress <= 0.01) return;

    _drawHead(canvas, size);
    _drawHands(canvas, size);
  }

  void _drawHands(Canvas canvas, Size size) {
    if (handsProgress <= 0.01) return;

    // Hands slide in with handsProgress
    final handW = 10.0;
    final handH = 14.0;
    final startX = size.width + handW; 
    final endX = size.width - handW + 4; // Grabbing edge
    
    final currentX = startX + (endX - startX) * handsProgress;
    
    // Spread hands out (Top and Bottom)
    final topHandY = size.height / 2 - 25;
    final bottomHandY = size.height / 2 + 25;

    final paintFill = Paint()..color = primaryColor..style = PaintingStyle.fill;
    final paintStroke = Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = 1.5;

    // Top Hand
    final topRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(currentX, topHandY, handW, handH), 
      const Radius.circular(4)
    );
    canvas.drawRRect(topRect, paintFill);
    canvas.drawRRect(topRect, paintStroke);

    // Bottom Hand
    final bottomRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(currentX, bottomHandY, handW, handH), 
      const Radius.circular(4)
    );
    canvas.drawRRect(bottomRect, paintFill);
    canvas.drawRRect(bottomRect, paintStroke);
  }

  void _drawHead(Canvas canvas, Size size) {
    if (headProgress <= 0.01) return;

    // Head moves from hidden to peeking
    final starRadius = 24.0;
    final hiddenX = size.width + starRadius;
    
    // CHANGED: visibleX is now closer to edge (less peeking)
    // Was -20, now -12. 
    // size.width - 12 means center is 12px inside screen.
    // with 24px radius, that means 12px (half) is visible + 12px hidden.
    // Just a "spiedinha".
    final peekedX = size.width - 12; 
    
    final currentX = hiddenX + (peekedX - hiddenX) * headProgress;
    // Align with vertical center
    final currentY = size.height / 2;

    // Rotation effect: -30 deg when fully peeked
    final rotation = -0.5 * headProgress; 

    canvas.save();
    canvas.translate(currentX, currentY);
    canvas.rotate(rotation);

    _drawStarShape(canvas, 0, 0, starRadius);
    _drawFace(canvas, 0, 0, starRadius);

    canvas.restore();
  }

  void _drawStarShape(Canvas canvas, double cx, double cy, double outerRadius) {
    final innerRadius = outerRadius * 0.6;
    const spikes = 12;

    final path = Path();
    final angleStep = math.pi * 2 / spikes;
    final startAngle = -math.pi / 2;

    for (int i = 0; i < spikes; i++) {
        final radius = (i % 2 == 0) ? outerRadius : innerRadius;
        final angle = startAngle + i * angleStep;
        final x = cx + math.cos(angle) * radius;
        final y = cy + math.sin(angle) * radius;
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = primaryColor..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeJoin = StrokeJoin.round);
  }

  void _drawFace(Canvas canvas, double cx, double cy, double radius) {
    // Face Logic with "Look Direction" and "Wink"
    
    // 1. Calculate Shift based on Look
    // Base is -6.0 (Looking Left/Inside).
    // LookProgress spans 0 -> 1.
    // If Look=1, we shift Right by +5.0 => -1.0 (Almost Straight/Center).
    final currentLookShift = lookProgress * 5.0;
    final eyeOffsetX = -6.0 + currentLookShift;
    final eyeGap = 7.0;
    
    // 2. Setup Paiints
    final paintEye = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final paintStroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    
    // 3. Draw Eyes
    final leftEyePos = Offset(cx + eyeOffsetX - eyeGap, cy - 2);
    final rightEyePos = Offset(cx + eyeOffsetX + eyeGap, cy - 2);

    // Left Eye (Viewer's Left) - Always Open
    canvas.drawCircle(leftEyePos, 2.5, paintEye);

    // Right Eye (Viewer's Right) - Winkable
    if (blinkProgress > 0.1) {
      // Winking: Draw a curve (Classic wink >)
      // Path for "Chevron" or "Curve" style wink
      final winkPath = Path();
      // Drawn as a small "less than" or "down curve"
      winkPath.moveTo(rightEyePos.dx - 3, rightEyePos.dy);
      winkPath.quadraticBezierTo(rightEyePos.dx, rightEyePos.dy + 3, rightEyePos.dx + 3, rightEyePos.dy);
      
      canvas.drawPath(winkPath, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    } else {
      // Open
      canvas.drawCircle(rightEyePos, 2.5, paintEye);
    }
    
    // 4. Mouth (Smile) - Tilts if winking
    final paintMouth = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    
    // Calculate Mouth Offset
    /* 
       Mouth moves with look direction too.
       Base: cx + eyeOffsetX - 4
    */
    canvas.save();
    
    // If winking, specific tilt to the Right side
    if (blinkProgress > 0.1) {
       // Pivot around mouth center and rotate slightly
       final mouthCx = cx + eyeOffsetX;
       final mouthCy = cy + 7;
       canvas.translate(mouthCx, mouthCy);
       canvas.rotate(-0.2); // Tilt up on right
       canvas.translate(-mouthCx, -mouthCy);
    }

    final path = Path();
    path.moveTo(cx + eyeOffsetX - 4, cy + 6);
    path.quadraticBezierTo(cx + eyeOffsetX, cy + 8, cx + eyeOffsetX + 4, cy + 6);
    canvas.drawPath(path, paintMouth);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UnifiedHandlePainter oldDelegate) {
    return oldDelegate.tabPosition != tabPosition || 
           oldDelegate.handsProgress != handsProgress ||
           oldDelegate.headProgress != headProgress ||
           oldDelegate.blinkProgress != blinkProgress ||
           oldDelegate.lookProgress != lookProgress ||
           oldDelegate.opacity != opacity;
  }
}
