// lib/common/widgets/mention_text_editing_controller.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

/// Controller que destaca menções (@username) no texto
/// Controller que destaca menções (@username) e tags (#tag) no texto
class MentionTextEditingController extends TextEditingController {
  Set<String> validMentions;
  
  // Patterns
  final RegExp _mentionPattern = RegExp(r'@[a-z0-9_.]+');
  final RegExp _tagPattern = RegExp(r'#[a-zA-Z0-9_À-ÿ]+'); // Inclui acentos para tags
  
  // Styles
  final TextStyle _mentionStyle = const TextStyle(
    color: Colors.lightBlueAccent, // Azul para contatos válidos
    fontWeight: FontWeight.bold,
  );
  
  final TextStyle _tagStyle = const TextStyle(
    color: Colors.purpleAccent, // Roxo para tags (imediato)
    fontWeight: FontWeight.normal,
  );

  MentionTextEditingController({String? text, Set<String>? validUsernames})
      : validMentions = validUsernames ?? {},
        super(text: text);

  /// Atualiza a lista de usuários válidos e refaz o style
  void updateValidMentions(Set<String> newMentions) {
    validMentions = newMentions;
    notifyListeners(); // Força update na UI (embora para style precise de buildTextSpan)
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> children = [];
    final text = value.text;
    
    if (text.isEmpty) {
      return TextSpan(style: style, children: []);
    }

    // Regex combinado para encontrar ambos: (@word) OU (#word)
    // O splitMapJoin vai quebrar o texto nesses tokens
    final combinedPattern = RegExp(r'(@[a-z0-9_.]+|#[a-zA-Z0-9_À-ÿ]+)');

    text.splitMapJoin(
      combinedPattern,
      onMatch: (Match match) {
        final String matchText = match[0]!;
        
        if (matchText.startsWith('@')) {
          // É Menção: verifica se é válido
          // Remove o '@' para verificar na lista
          final username = matchText.substring(1);
          if (validMentions.contains(username)) {
            children.add(TextSpan(
              text: matchText,
              style: style?.merge(_mentionStyle),
            ));
          } else {
            // Se não for válido, estilo normal
            children.add(TextSpan(text: matchText, style: style));
          }
        } else if (matchText.startsWith('#')) {
          // É Tag: sempre estiliza (imediato)
          children.add(TextSpan(
            text: matchText,
            style: style?.merge(_tagStyle),
          ));
        } else {
          // Fallback (não deve ocorrer com o regex acima, mas por segurança)
          children.add(TextSpan(text: matchText, style: style));
        }
        return '';
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}
