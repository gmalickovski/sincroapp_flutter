// lib/common/parser/parser_text_controller.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';

/// Controller que destaca #tags, @menções e !metas no texto em tempo real.
class ParserTextEditingController extends TextEditingController {
  Set<String> validMentions;

  ParserTextEditingController({super.text, Set<String>? validUsernames})
      : validMentions = validUsernames ?? {};

  /// Atualiza a lista de usuários válidos e refaz o style
  void updateValidMentions(Set<String> newMentions) {
    validMentions = newMentions;
    notifyListeners();
  }

  /// Adiciona um username válido individual
  void addValidMention(String username) {
    validMentions.add(username);
    notifyListeners();
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
      return TextSpan(style: style, children: const []);
    }

    text.splitMapJoin(
      TaskParser.combinedPattern,
      onMatch: (Match match) {
        final String matchText = match[0]!;

        if (matchText.startsWith('@')) {
          // Menção: sempre colorir durante digitação ativa
          children.add(TextSpan(
            text: matchText,
            style: style?.merge(const TextStyle(
              color: TaskParser.mentionColor,
            )),
          ));
        } else if (matchText.startsWith('#')) {
          // Tag: sempre estiliza
          children.add(TextSpan(
            text: matchText,
            style: style?.merge(const TextStyle(
              color: TaskParser.tagColor,
            )),
          ));
        } else if (matchText.startsWith('!')) {
          // Meta: sempre estiliza
          children.add(TextSpan(
            text: matchText,
            style: style?.merge(const TextStyle(
              color: TaskParser.goalColor,
            )),
          ));
        } else {
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
