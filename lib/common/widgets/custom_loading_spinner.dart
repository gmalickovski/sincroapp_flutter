import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class CustomLoadingSpinner extends StatefulWidget {
  final double? size;
  
  const CustomLoadingSpinner({
    super.key,
    this.size,
  });

  @override
  State<CustomLoadingSpinner> createState() => _CustomLoadingSpinnerState();
}

class _CustomLoadingSpinnerState extends State<CustomLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fillAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _dashAnimation;
  late Animation<double> _strokeWidthAnimation;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Rotação global (0° → 360°)
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    // Preenchimento da estrela (1.0 → 0.0 → 1.0)
    _fillAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
    ]).animate(_controller);

    // Escala da estrela (1.1 → 0.95 → 1.1)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.95),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
    ]).animate(_controller);

    // Dash da linha (Length) (0.0 → 1.0 → 0.0)
    _dashAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    // Offset da linha (0.0 → 1.0) - Simula o movimento "dash-elastic"
    _offsetAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Espessura da linha (10 → 22 → 10)
    _strokeWidthAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 10.0, end: 22.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 22.0, end: 10.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _defaultSize {
    // Tamanhos responsivos por plataforma (Aumentados conforme solicitado)
    if (kIsWeb) return 80.0;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return 60.0;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 90.0;
      default:
        return 60.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? _defaultSize;
    
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: StarCometPainter(
              rotation: _rotationAnimation.value,
              fillOpacity: _fillAnimation.value,
              scale: _scaleAnimation.value,
              dashProgress: _dashAnimation.value,
              offsetProgress: _offsetAnimation.value,
              strokeWidth: _strokeWidthAnimation.value,
              color: AppColors.primaryAccent,
            ),
          );
        },
      ),
    );
  }
}

class StarCometPainter extends CustomPainter {
  final double rotation;
  final double fillOpacity;
  final double scale;
  final double dashProgress;
  final double offsetProgress;
  final double strokeWidth;
  final Color color;

  StarCometPainter({
    required this.rotation,
    required this.fillOpacity,
    required this.scale,
    required this.dashProgress,
    required this.offsetProgress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // 1. Desenhar a cauda (arco com dash)
    _drawTail(canvas, radius);

    // 2. Desenhar a estrela
    _drawStar(canvas, radius);

    canvas.restore();
  }

  void _drawTail(Canvas canvas, double radius) {
    final tailRadius = radius * 0.42; // 42% do raio total
    final rect = Rect.fromCircle(center: Offset.zero, radius: tailRadius);

    // Calcular dash offset e array
    final circumference = 2 * math.pi * tailRadius;
    
    // HTML: dasharray 1, 300 -> 120, 300. (120/300 = 0.4)
    final dashLength = circumference * (0.01 + dashProgress * 0.39); 
    
    // HTML: dashoffset 0 -> -260. (260/300 = 0.86)
    // Offset negativo move "para frente" no sentido horário (ou anti dependendo da implementação)
    // Aqui simulamos movendo o ponto de início.
    final currentOffset = circumference * offsetProgress * 0.86;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * (radius / 100) // Escala baseada no tamanho
      ..strokeCap = dashProgress < 0.15 
          ? StrokeCap.round
          : StrokeCap.butt;

    // Caminho base: Círculo completo começando do topo (-pi/2)
    final path = Path()..addArc(rect, -math.pi / 2, 2 * math.pi);
    
    // Extrair o sub-caminho baseado no offset e length
    // Como é um círculo fechado, precisamos lidar com o wrap-around
    final metrics = path.computeMetrics().first;
    
    final start = currentOffset;
    final end = start + dashLength;
    
    final extractedPath = Path();
    
    if (end <= metrics.length) {
      // Caso simples: não dá a volta
      extractedPath.addPath(
        metrics.extractPath(start, end),
        Offset.zero,
      );
    } else {
      // Caso wrap-around: desenha do start até o fim, e do 0 até o restante
      extractedPath.addPath(
        metrics.extractPath(start, metrics.length),
        Offset.zero,
      );
      extractedPath.addPath(
        metrics.extractPath(0, end - metrics.length),
        Offset.zero,
      );
    }

    canvas.drawPath(extractedPath, paint);
  }

  void _drawStar(Canvas canvas, double radius) {
    final starRadius = radius * 0.32; // 32% do raio total
    final starPath = _createStarPath(starRadius);

    canvas.save();
    canvas.translate(0, -radius * 0.42); // Posição da estrela no topo do círculo
    canvas.scale(scale);

    // Stroke da estrela (sempre visível)
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * (radius / 100)
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 10;

    canvas.drawPath(starPath, strokePaint);

    // Fill da estrela (animado)
    if (fillOpacity > 0) {
      final fillPaint = Paint()
        ..color = color.withOpacity(fillOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawPath(starPath, fillPaint);
    }

    canvas.restore();
  }

  Path _createStarPath(double radius) {
    final path = Path();
    const points = 6; // Estrela de 6 pontas (HTML tem 12 vértices = 6 pontas)
    final angleStep = (2 * math.pi) / points;
    final innerRadius = radius * 0.5;

    for (int i = 0; i < points * 2; i++) {
      final angle = i * angleStep / 2 - math.pi / 2;
      final r = i.isEven ? radius : innerRadius;
      final x = r * math.cos(angle);
      final y = r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(StarCometPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.scale != scale ||
        oldDelegate.dashProgress != dashProgress ||
        oldDelegate.offsetProgress != offsetProgress ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
