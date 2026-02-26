// lib/common/parser/parser_popup.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';

/// Popup unificado de sugestões para #tags, @contatos e !metas.
class ParserPopup extends StatelessWidget {
  final List<ParserSuggestion> suggestions;
  final bool isLoading;
  final ParserKeyType activeType;
  final Function(ParserSuggestion) onSelected;
  final bool isMobile;

  const ParserPopup({
    super.key,
    required this.suggestions,
    required this.activeType,
    required this.onSelected,
    this.isLoading = false,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = TaskParser.colorForType(activeType);

    return Container(
      constraints: BoxConstraints(
        maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.35 : 280,
      ),
      margin: isMobile ? EdgeInsets.zero : const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : suggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _emptyMessage(),
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final item = suggestions[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          TaskParser.iconForType(item.type),
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: item.description != null
                          ? Text(
                              item.description!,
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => onSelected(item),
                    );
                  },
                ),
    );
  }

  String _emptyMessage() {
    switch (activeType) {
      case ParserKeyType.tag:
        return 'Nenhuma tag encontrada';
      case ParserKeyType.mention:
        return 'Nenhum contato encontrado';
      case ParserKeyType.goal:
        return 'Nenhuma meta encontrada';
    }
  }
}
