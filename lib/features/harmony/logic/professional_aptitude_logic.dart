import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class ProfessionalAptitudeData {
  final NumerologyResult numerologyResult;
  final int expressionNumber;
  final VibrationContent? staticContent;

  ProfessionalAptitudeData({
    required this.numerologyResult,
    required this.expressionNumber,
    this.staticContent,
  });
}

class ProfessionalAptitudeLogic {
  /// Calculates the professional aptitude profile for a given user.
  ///
  /// This leverages the core [NumerologyEngine] to get the base calculations,
  /// then extracts the specific logic needed for the professional features.
  static ProfessionalAptitudeData calculateForUser(UserModel user) {
    // 1. Leverage the core Numerology Engine
    final engine = NumerologyEngine(
      nomeCompleto: user.nomeAnalise,
      dataNascimento: user.dataNasc,
    );

    // 2. Get the raw result
    final result = engine.calculateProfile();

    // 3. Extract the key metric for this feature (Expression Number)
    final int expression = result.numeros['expressao'] ?? 0;

    // 4. Retrieve the associated static content
    final content = ContentData.textosAptidoesProfissionais[expression];

    return ProfessionalAptitudeData(
      numerologyResult: result,
      expressionNumber: expression,
      staticContent: content,
    );
  }
}
