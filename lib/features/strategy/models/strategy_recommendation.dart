import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';

class StrategyRecommendation {
  final StrategyMode mode;
  final String reason;
  final List<String> tips;
  final String methodologyName; // e.g., "GTD (Getting Things Done)", "The One Thing"

  const StrategyRecommendation({
    required this.mode,
    required this.reason,
    required this.tips,
    this.aiSuggestions = const [],
    required this.methodologyName,
  });

  final List<String> aiSuggestions;
}
