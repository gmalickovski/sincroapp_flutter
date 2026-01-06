// lib/common/widgets/mention_text_editing_controller.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

/// Controller que destaca menções (@username) no texto
class MentionTextEditingController extends TextEditingController {
  final Map<String, TextStyle> map;
  final Pattern pattern;

  MentionTextEditingController({String? text})
      : map = {
          r'@[a-z0-9_.]+': const TextStyle(
            color: AppColors.contact,
            fontWeight: FontWeight.bold,
          ),
        },
        pattern = RegExp(r'@[a-z0-9_.]+'),
        super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required boolwithComposing,
  }) {
    final List<InlineSpan> children = [];
    final text = value.text;
    
    if (text.isEmpty) {
      return TextSpan(style: style, children: []);
    }

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        children.add(TextSpan(
          text: match[0],
          style: style?.merge(const TextStyle(color: AppColors.contact)),
        ));
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
