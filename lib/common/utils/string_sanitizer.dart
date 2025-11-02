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

  /// Converte uma string como "Minha Meta"
  /// para uma tag simplificada como "minhameta".
  /// Garante minúsculas, remove acentos, espaços e caracteres não alfanuméricos.
  static String toSimpleTag(String text) {
    // 1. Remove acentos
    String sanitized = _unaccent(text);

    // 2. Converte para minúsculas PRIMEIRO
    sanitized = sanitized.toLowerCase();

    // 3. Remove espaços
    sanitized = sanitized.replaceAll(' ', '');

    // 4. Remove qualquer outro caractere que não seja letra ou número
    //    (agora [^a-z0-9] pois já garantimos minúsculas)
    sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9]'), '');

    return sanitized; // Ex: "minhameta"
  }
}
