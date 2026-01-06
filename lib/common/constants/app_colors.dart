import 'package:flutter/material.dart';

// Classe que centraliza a paleta de cores do SincroApp
class AppColors {
  static const Color background = Color(0xFF111827); // gray-900
  static const Color cardBackground = Color(0xFF1F2937); // gray-800
  static const Color border = Color(0xFF4B5563); // gray-600

  static const Color primaryText = Color(0xFFFFFFFF); // white
  static const Color secondaryText = Color(0xFFD1D5DB); // gray-300 (Labels)
  static const Color tertiaryText = Color(0xFF9CA3AF); // gray-400 (Subtítulos)

  static const Color primaryAccent = Color(0xFF7C3AED); // purple-600 (botão)
  static const Color secondaryAccent = Color(0xFFA78BFA); // purple-400 (links)

  static const Color primary = Color(0xff7c3aed);

  // Novas cores para os marcadores do Calendário
  static const Color taskMarker = Color(0xFF3B82F6); // blue-500
  static const Color goalTaskMarker = Color(0xFFEC4899); // pink-500
  static const Color journalMarker = Color(0xFF14B8A6); // teal-500
  static const Color success = Color(0xFF10B981); // green-500
  
  // Cor para sistema de compartilhamento/contatos
  static const Color contact = Color(0xFF64B5F6); // light-blue-400 (azul claro)
}

// Compat: Flutter < 3.27 não possui Color.withValues. Este extension
// fornece uma versão limitada que respeita apenas o alpha, mapeando
// para withOpacity. Em SDKs mais novos, o método nativo tem prioridade.
extension ColorWithValuesCompat on Color {
  Color withValues({double? alpha, double? red, double? green, double? blue}) {
    if (alpha != null) {
      return withOpacity(alpha); // ignore: deprecated_member_use
    }
    return this;
  }
}
