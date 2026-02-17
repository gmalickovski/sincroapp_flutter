// lib/common/utils/username_validator.dart

/// Utilitário para validação de usernames
///
/// Regras:
/// - 3 a 30 caracteres
/// - Apenas letras minúsculas, números, underline (_) e ponto (.)
/// - Sem espaços
/// - Case-insensitive (sempre convertido para lowercase)
class UsernameValidator {
  // Regex para validação de formato
  static final RegExp _usernameRegex = RegExp(r'^[a-z0-9_.]{3,30}$');

  /// Verifica se o username tem formato válido
  ///
  /// Retorna true se o username atende aos critérios de formato
  static bool isValidFormat(String username) {
    if (username.isEmpty) return false;

    final sanitized = sanitize(username);
    return _usernameRegex.hasMatch(sanitized);
  }

  /// Sanitiza o username (converte para lowercase e remove espaços)
  ///
  /// Use antes de salvar no banco ou fazer validações
  static String sanitize(String username) {
    return username.toLowerCase().trim();
  }

  /// Valida o username e retorna mensagem de erro se inválido
  ///
  /// Retorna null se válido, ou String com mensagem de erro
  static String? validate(String username) {
    if (username.isEmpty) {
      return 'O nome de usuário não pode estar vazio';
    }

    final sanitized = sanitize(username);

    if (sanitized.length < 3) {
      return 'Mínimo de 3 caracteres';
    }

    if (sanitized.length > 30) {
      return 'Máximo de 30 caracteres';
    }

    if (!_usernameRegex.hasMatch(sanitized)) {
      return 'Use apenas letras, números, _ e .';
    }

    // Verifica se contém espaços (antes do sanitize)
    if (username.contains(' ')) {
      return 'Não pode conter espaços';
    }

    return null; // Válido
  }

  /// Gera sugestões de username baseadas no email
  ///
  /// Exemplo: joao.silva@gmail.com → [joao_silva, joaosilva, j.silva]
  static List<String> generateSuggestions(String email) {
    if (email.isEmpty || !email.contains('@')) {
      return [];
    }

    final localPart = email.split('@')[0].toLowerCase();
    final suggestions = <String>[];

    // Sugestão 1: substituir pontos por underline
    if (localPart.contains('.')) {
      suggestions.add(localPart.replaceAll('.', '_'));
    }

    // Sugestão 2: remover pontos
    if (localPart.contains('.')) {
      suggestions.add(localPart.replaceAll('.', ''));
    }

    // Sugestão 3: manter pontos
    if (!suggestions.contains(localPart)) {
      suggestions.add(localPart);
    }

    // Sugestão 4: primeira letra + sobrenome (se tiver ponto)
    if (localPart.contains('.')) {
      final parts = localPart.split('.');
      if (parts.length >= 2) {
        suggestions.add('${parts[0][0]}.${parts[1]}');
      }
    }

    // Filtrar sugestões válidas
    return suggestions.where((s) => isValidFormat(s)).take(3).toList();
  }

  /// Extrai possíveis usernames de um texto
  ///
  /// Busca padrões @username no texto
  static List<String> extractMentionsFromText(String text) {
    final mentionRegex = RegExp(r'@([a-z0-9_.]{3,30})', caseSensitive: false);
    final matches = mentionRegex.allMatches(text);

    return matches
        .map((match) => match.group(1)!)
        .map((username) => sanitize(username))
        .toSet() // Remove duplicatas
        .toList();
  }

  /// Verifica se um texto contém menções
  static bool hasMentions(String text) {
    return text.contains(RegExp(r'@[a-z0-9_.]{3,30}', caseSensitive: false));
  }

  /// Lista de usernames reservados (não podem ser usados)
  static const List<String> _reservedUsernames = [
    'admin',
    'root',
    'sincro',
    'sincroapp',
    'support',
    'suporte',
    'help',
    'ajuda',
    'system',
    'sistema',
    'test',
    'teste',
    'null',
    'undefined',
  ];

  /// Verifica se o username é reservado
  static bool isReserved(String username) {
    return _reservedUsernames.contains(sanitize(username));
  }

  /// Validação completa (formato + reservado)
  static String? validateComplete(String username) {
    // Validação de formato
    final formatError = validate(username);
    if (formatError != null) return formatError;

    // Validação de palavras reservadas
    if (isReserved(username)) {
      return 'Este nome de usuário está reservado';
    }

    return null; // Válido
  }
}
