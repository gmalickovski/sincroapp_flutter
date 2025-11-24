import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';

class StrategyRecommendation {
  final StrategyMode mode;
  final String reason;
  final List<String> tips;
  final List<String> potencializar;
  final List<String> atencao;
  final String methodologyName; // e.g., "GTD (Getting Things Done)", "The One Thing"

  const StrategyRecommendation({
    required this.mode,
    required this.reason,
    required this.tips,
    this.potencializar = const [],
    this.atencao = const [],
    required this.methodologyName,
  });
}
