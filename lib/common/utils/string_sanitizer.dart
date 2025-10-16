// lib/common/utils/string_sanitizer.dart

class StringSanitizer {
  static String _unaccent(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖòóôõöÈÉÊËèéêëðÇçÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia =
        'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeeCcIIIIiiiiUUUUuuuuNnSsYyyZz';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }

  /// Converte uma string como "Aprender a Tocar Violão"
  /// para uma tag simplificada como "AprenderaTocarViolao".
  static String toSimpleTag(String text) {
    // 1. Remove acentos
    String sanitized = _unaccent(text);
    // 2. Remove espaços
    sanitized = sanitized.replaceAll(' ', '');
    // 3. Remove qualquer outro caractere que não seja letra ou número para segurança
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return sanitized;
  }
}
