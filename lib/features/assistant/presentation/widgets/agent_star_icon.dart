import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AgentStarMode {
  dashboard, // 🔢 Dashboard, Harmonia
  agenda, // 📅 Agenda, Ciclos do Tempo
  diario, // 📓 Diário, Registro
  tarefas, // ✅ Tarefas, Realização
  metas, // 🏁 Metas, Conquista
}

class AgentStarIcon extends StatefulWidget {
  final double size;
  final AgentStarMode mode;
  final bool isStatic;
  final bool isHollow;
  final bool isWhiteFilled; // New Mode
  final bool slowAnimation; // 🐢 Slower intervals

  const AgentStarIcon({
    super.key,
    this.size = 28.0,
    this.mode = AgentStarMode.dashboard,
    this.isStatic = false,
    this.isHollow = false,
    this.isWhiteFilled = false,
    this.slowAnimation = false,
  });

  @override
  State<AgentStarIcon> createState() => _AgentStarIconState();
}

class _AgentStarIconState extends State<AgentStarIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _time = 0;

  // Emotion State
  String _emotionState = 'neutral';
  double _emotionTimer = 0;
  String _nextTaskExpression = 'task_wink';

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));

    _controller.addListener(_tick);

    if (!widget.isStatic) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AgentStarIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStatic != oldWidget.isStatic) {
      if (widget.isStatic) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    }

    if (oldWidget.mode != widget.mode) {
      _emotionTimer = 0;
      if (widget.mode == AgentStarMode.tarefas) {
        _nextTaskExpression = 'task_wink';
        _emotionState = 'task_neutral';
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  void _tick() {
    setState(() {
      _time += 0.04;
      _updateEmotion();
    });
  }

  void _updateEmotion() {
    // Multiplier for slower animations
    final double slowFactor = widget.slowAnimation ? 3.0 : 1.0;

    if (widget.mode == AgentStarMode.tarefas) {
      if (_emotionTimer > 0) {
        _emotionTimer--;
        return;
      }
      if (_emotionState != 'task_neutral') {
        _emotionState = 'task_neutral';
        _emotionTimer = (250 + math.Random().nextDouble() * 200) * slowFactor;
        return;
      }
      if (_nextTaskExpression == 'task_wink') {
        _emotionState = 'task_wink';
        _nextTaskExpression = 'task_smile';
      } else {
        _emotionState = 'task_smile';
        _nextTaskExpression = 'task_wink';
      }
      _emotionTimer = (60 + math.Random().nextDouble() * 30) * slowFactor;
      return;
    }

    if (widget.mode == AgentStarMode.diario) {
      _emotionState = 'reading_loop';
      return;
    }

    if (_emotionTimer > 0) {
      _emotionTimer--;
      return;
    }

    if (_emotionState != 'neutral') {
      _emotionState = 'neutral';
      _emotionTimer = (250 + math.Random().nextDouble() * 250) * slowFactor;
      return;
    }

    final rand = math.Random().nextDouble();
    if (rand < 0.25) {
      _emotionState = 'smile';
      _emotionTimer = 80 * slowFactor;
    } else if (rand < 0.45) {
      _emotionState = 'blink';
      _emotionTimer = 20 * slowFactor;
    } else if (rand < 0.60) {
      _emotionState = 'winkLeft';
      _emotionTimer = 60 * slowFactor;
    } else if (rand < 0.75) {
      _emotionState = 'winkRight';
      _emotionTimer = 60 * slowFactor;
    } else if (rand < 0.90) {
      _emotionState = 'happy';
      _emotionTimer = 70 * slowFactor;
    } else {
      _emotionState = 'skeptical';
      _emotionTimer = 60 * slowFactor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _AgentStarPainter(
          time: _time,
          mode: widget.mode,
          emotionState: _emotionState,
          isStatic: widget.isStatic,
          isHollow: widget.isHollow,
          isWhiteFilled: widget.isWhiteFilled,
        ),
      ),
    );
  }
}

class _AgentStarPainter extends CustomPainter {
  final double time;
  final AgentStarMode mode;
  final String emotionState;
  final bool isStatic;
  final bool isHollow;
  final bool isWhiteFilled;

  _AgentStarPainter({
    required this.time,
    required this.mode,
    required this.emotionState,
    this.isStatic = false,
    this.isHollow = false,
    this.isWhiteFilled = false,
  });

  // Colors
  final Color primaryColor = const Color(0xFF7C3AED); // Violeta 600
  final Color bodyStrokeColor =
      const Color(0xFFE5E7EB); // Gray 200 (Whitish-gray) for Body
  final Color faceColor = Colors.white; // Make face pure white
  final Color strokeColor =
      const Color(0xFFE0E0E0); // Grayish white for border (was Colors.white)
  final Color secondaryColor = const Color(0xFFA78BFA); // Violeta 400

  // Dark Background Color for Cut-out effect (Matches AppColors.background)
  final Color darkBgColor = const Color(0xFF131316);

  // Constants
  static const double baseSize = 280.0;
  static const double strokeWidthBase = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / baseSize;
    canvas.scale(scale, scale);

    const centerX = baseSize / 2;
    const centerY = baseSize / 2;

    const double starRadius = 110.0;

    _drawStar(canvas, centerX, centerY, starRadius, scale);
    _drawFace(canvas, centerX, centerY, starRadius, scale);
  }

  void _drawStar(
      Canvas canvas, double cx, double cy, double outerRadius, double scale) {
    final innerRadius = outerRadius * 0.6; // FIXED: Original JS Ratio
    const spikes = 12;

    final path = Path();
    const angleStep = math.pi * 2 / spikes;
    const startAngle = -math.pi / 2;

    for (int i = 0; i < spikes; i++) {
      final radius = (i % 2 == 0) ? outerRadius : innerRadius;
      final angle = startAngle + i * angleStep;

      final x = cx + math.cos(angle) * radius;
      final y = cy + math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Fill Logic
    if (isWhiteFilled) {
      final paintFill = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paintFill);
    } else if (!isHollow) {
      final paintFill = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paintFill);
    }

    // Stroke Logic
    final paintStroke = Paint()
      ..color = (isHollow || isWhiteFilled)
          ? bodyStrokeColor
          : ((mode == AgentStarMode.dashboard) ? strokeColor : Colors.white)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidthBase
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paintStroke);
  }

  void _drawFace(
      Canvas canvas, double cx, double cy, double radius, double scale) {
    canvas.save();
    if (isWhiteFilled || isHollow) {
      canvas.translate(cx, cy);
      canvas.scale(1.35); // Aumenta os olhos e boca ("rosto") em 35%
      canvas.translate(-cx, -cy);
    }

    // Proportional Scaling based on standard JS radius (65) vs current radius
    const double standardRadius = 65.0;
    // FIXED: Ratio strictly controls POSITIONS (layout), never scale.
    final double ratio = radius / standardRadius;

    // Feature Size Multiplier: Increases the "thickness" or "size" of individual elements
    // without moving them apart.
    // CHANGED: Boosted for visibility
    // CHANGED: Boosted drastically for visibility (request: "buraco dos zolhos")
    final double elementScale = (isWhiteFilled || isHollow) ? 4.0 : 1.0;

    final x = cx;
    final y = cy;

    final Color featureColor =
        isWhiteFilled ? darkBgColor : (isHollow ? Colors.white : faceColor);

    final paintStroke = Paint()
      ..color = featureColor
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          strokeWidthBase * elementScale // Bold stroke for mouth/brows
      ..strokeCap = StrokeCap.round;

    final paintFill = Paint()
      ..color = featureColor
      ..style = PaintingStyle.fill;

    // SCALED CONSTANTS
    final eyeOffset = 16.0 * ratio; // Spacing stays same
    final eyeYOffset = 5.0 * ratio;
    final eyeRadius = 4.5 * ratio * elementScale; // Eyes get bigger

    final eyeY = y - eyeYOffset;

    // Helpers
    void drawOpenEye(double bx, double by) {
      canvas.drawCircle(Offset(bx, by), eyeRadius, paintFill);
    }

    void drawClosedEye(double bx, double by) {
      final w = 7.0 * ratio;
      final p = Path()
        ..moveTo(bx - w, by)
        ..lineTo(bx + w, by);
      canvas.drawPath(p, paintStroke);
    }

    void drawHappyEye(double bx, double by) {
      // JS: arc(bx, by+2, 7 ...)
      // Scale offsets and radius
      final r = 7.0 * ratio;
      final yOff = 2.0 * ratio;
      final rect = Rect.fromCircle(center: Offset(bx, by + yOff), radius: r);
      canvas.drawArc(rect, math.pi, math.pi, false, paintStroke);
    }

    void drawFlatEye(double bx, double by) {
      final w = 7.0 * ratio;
      final h = 3.0 * ratio;
      final p = Path()
        ..moveTo(bx - w, by - h)
        ..lineTo(bx + w, by - h);
      canvas.drawPath(p, paintStroke);
    }

    // Static Mode
    if (isStatic) {
      // Apply elementScale to static eyes
      final double staticEyeRadius = 3.5 *
          ratio *
          (elementScale > 1.0
              ? 1.5
              : 1.0); // Slightly less aggressive scale for radius than stroke
      canvas.drawCircle(
          Offset(cx - eyeOffset, eyeY), staticEyeRadius, paintFill);
      canvas.drawCircle(
          Offset(cx + eyeOffset, eyeY), staticEyeRadius, paintFill);

      // Small smile
      final mouthPath = Path();
      final mx = 6.0 * ratio;
      final my1 = 10.0 * ratio;
      final my2 = 15.0 * ratio;

      mouthPath.moveTo(cx - mx, cy + my1);
      mouthPath.quadraticBezierTo(cx, cy + my2, cx + mx, cy + my1);
      canvas.drawPath(mouthPath, paintStroke);
      canvas.restore();
      return;
    }

    // === 1. SOBRANCELHAS ===
    final browYOffset = 9.0 * ratio;
    final browY = eyeY - browYOffset;
    final browPath = Path();

    // Brow Helpers (scaled)
    final bW = 5.0 * ratio; // Width half
    final bH = 2.0 * ratio; // small height adjustments
    final bW7 = 7.0 * ratio;

    if (emotionState == 'task_neutral') {
      browPath.moveTo(x - eyeOffset - bW, browY);
      browPath.lineTo(x - eyeOffset + bW, browY);
      browPath.moveTo(x + eyeOffset - bW, browY);
      browPath.lineTo(x + eyeOffset + bW, browY);
    } else if (emotionState == 'task_wink') {
      browPath.moveTo(x - eyeOffset - bW, browY + (1 * ratio));
      browPath.lineTo(x - eyeOffset + bW, browY - (2 * ratio));
      browPath.moveTo(x + eyeOffset - bW, browY);
      browPath.lineTo(x + eyeOffset + bW, browY);
    } else if (emotionState == 'task_smile' ||
        emotionState == 'happy' ||
        emotionState == 'smile') {
      browPath.moveTo(x - eyeOffset - bW7, browY + (2 * ratio));
      browPath.quadraticBezierTo(x - eyeOffset, browY - (5 * ratio),
          x - eyeOffset + bW7, browY + (2 * ratio));

      browPath.moveTo(x + eyeOffset - bW7, browY + (2 * ratio));
      browPath.quadraticBezierTo(x + eyeOffset, browY - (5 * ratio),
          x + eyeOffset + bW7, browY + (2 * ratio));
    } else if (emotionState == 'reading_loop') {
      browPath.moveTo(x - eyeOffset - bW, browY - (1 * ratio));
      browPath.lineTo(x - eyeOffset + bW, browY - (1 * ratio));
      browPath.moveTo(x + eyeOffset - bW, browY - (1 * ratio));
      browPath.lineTo(x + eyeOffset + bW, browY - (1 * ratio));
    } else if (emotionState == 'skeptical') {
      browPath.moveTo(x - eyeOffset - bW, browY);
      browPath.lineTo(x - eyeOffset + bW, browY);
      final r = 6.0 * ratio;
      final rect =
          Rect.fromCircle(center: Offset(x + eyeOffset, browY), radius: r);
      browPath.addArc(rect, math.pi * 1.2, math.pi * 0.6);
    } else {
      browPath.moveTo(x - eyeOffset - bW, browY);
      browPath.lineTo(x - eyeOffset + bW, browY);
      browPath.moveTo(x + eyeOffset - bW, browY);
      browPath.lineTo(x + eyeOffset + bW, browY);
    }

    canvas.drawPath(browPath, paintStroke);

    // === 2. OLHOS ===
    switch (emotionState) {
      case 'task_neutral':
        drawOpenEye(x - eyeOffset, eyeY);
        drawOpenEye(x + eyeOffset, eyeY);
        break;
      case 'task_wink':
        drawOpenEye(x - eyeOffset, eyeY);
        drawFlatEye(x + eyeOffset, eyeY + (3 * ratio));
        break;
      case 'task_smile':
        drawOpenEye(x - eyeOffset, eyeY);
        drawOpenEye(x + eyeOffset, eyeY);
        break;
      case 'blink':
        drawClosedEye(x - eyeOffset, eyeY);
        drawClosedEye(x + eyeOffset, eyeY);
        break;
      case 'winkLeft':
        drawClosedEye(x - eyeOffset, eyeY);
        drawOpenEye(x + eyeOffset, eyeY);
        break;
      case 'winkRight':
        drawOpenEye(x - eyeOffset, eyeY);
        drawClosedEye(x + eyeOffset, eyeY);
        break;
      case 'happy':
        drawHappyEye(x - eyeOffset, eyeY);
        drawHappyEye(x + eyeOffset, eyeY);
        break;
      case 'smile':
        drawOpenEye(x - eyeOffset, eyeY);
        drawOpenEye(x + eyeOffset, eyeY);
        break;
      case 'skeptical':
        drawFlatEye(x - eyeOffset, eyeY);
        drawOpenEye(x + eyeOffset, eyeY);
        break;
      case 'reading_loop':
        const cycleLength = 14;
        final t = time % cycleLength;
        double lookFactor = 0;
        if (t < 3) {
          lookFactor = 0;
        } else if (t < 4) {
          final phase = t - 3;
          lookFactor = phase * phase * (3 - 2 * phase);
        } else if (t < 10) {
          lookFactor = 1;
        } else if (t < 11) {
          final phase = t - 10;
          final smooth = phase * phase * (3 - 2 * phase);
          lookFactor = 1 - smooth;
        } else {
          lookFactor = 0;
        }

        final moveX = -4.0 * ratio * lookFactor;
        final moveY = 3.0 * ratio * lookFactor;
        drawOpenEye(x - eyeOffset + moveX, eyeY + moveY);
        drawOpenEye(x + eyeOffset + moveX, eyeY + moveY);
        break;
      default:
        drawOpenEye(x - eyeOffset, eyeY);
        drawOpenEye(x + eyeOffset, eyeY);
        break;
    }

    // === 3. BOCA ===
    final mouthPath = Path();
    final mouthY = y + (12 * ratio);

    if (emotionState == 'task_wink') {
      final rect = Rect.fromCircle(
          center: Offset(x, mouthY - (1 * ratio)), radius: 9 * ratio);
      mouthPath.addArc(rect, 0.15, (math.pi - 0.15) - 0.15);
    } else if (emotionState == 'task_smile') {
      final rect = Rect.fromCircle(
          center: Offset(x, mouthY - (2 * ratio)), radius: 10 * ratio);
      mouthPath.addArc(rect, 0.1, (math.pi - 0.1) - 0.1);
    } else if (emotionState == 'task_neutral') {
      mouthPath.moveTo(x - (5 * ratio), mouthY);
      mouthPath.quadraticBezierTo(
          x, mouthY + (1 * ratio), x + (5 * ratio), mouthY);
    } else if (emotionState == 'reading_loop') {
      final rect = Rect.fromCircle(
          center: Offset(x, mouthY - (1 * ratio)), radius: 8 * ratio);
      mouthPath.addArc(rect, 0.2, (math.pi - 0.2) - 0.2);
    } else if (emotionState == 'happy' || emotionState == 'smile') {
      final rect = Rect.fromCircle(
          center: Offset(x, mouthY - (2 * ratio)), radius: 10 * ratio);
      mouthPath.addArc(rect, 0.1, (math.pi - 0.1) - 0.1);
    } else if (emotionState == 'winkLeft') {
      mouthPath.moveTo(x + (5 * ratio), mouthY);
      mouthPath.quadraticBezierTo(
          x, mouthY + (2 * ratio), x - (7 * ratio), mouthY - (3 * ratio));
    } else if (emotionState == 'winkRight') {
      mouthPath.moveTo(x - (5 * ratio), mouthY);
      mouthPath.quadraticBezierTo(
          x, mouthY + (2 * ratio), x + (7 * ratio), mouthY - (3 * ratio));
    } else if (emotionState == 'skeptical') {
      mouthPath.moveTo(x - (4 * ratio), mouthY);
      mouthPath.lineTo(x + (4 * ratio), mouthY);
    } else {
      mouthPath.moveTo(x - (5 * ratio), mouthY);
      mouthPath.quadraticBezierTo(
          x, mouthY + (1 * ratio), x + (5 * ratio), mouthY);
    }

    canvas.drawPath(mouthPath, paintStroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AgentStarPainter oldDelegate) {
    return true;
  }
}
