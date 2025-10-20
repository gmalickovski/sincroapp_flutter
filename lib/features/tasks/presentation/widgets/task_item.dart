// lib/features/tasks/presentation/widgets/task_item.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart'; // Garanta que AppColors está importado
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class TaskItem extends StatelessWidget {
  final TaskModel task;
  // MUDANÇA: Tornando opcionais para simplificar chamadas onde não são necessários
  final void Function(bool)? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  // --- FIM DA MUDANÇA ---
  final bool showJourney; // Mantido do seu código original
  final bool isCompact; // Mantido do seu código original
  final double? verticalPaddingOverride; // Mantido do seu código original

  // --- INÍCIO DA ADIÇÃO ---
  final bool showTags;
  final bool
      showGoal; // Renomeado de showJourney no parâmetro, mas usa task.journeyTitle
  final bool showVibration;
  // --- FIM DA ADIÇÃO ---

  const TaskItem({
    super.key,
    required this.task,
    // MUDANÇA: Tornando opcionais
    this.onToggle,
    this.onDelete,
    this.onEdit,
    this.onDuplicate,
    // --- FIM DA MUDANÇA ---
    this.showJourney =
        true, // Mantido para compatibilidade, mas showGoal será usado internamente
    this.isCompact = false,
    this.verticalPaddingOverride,
    // --- INÍCIO DA ADIÇÃO ---
    this.showTags = true, // Padrão true
    this.showGoal =
        true, // Padrão true (usa showJourney se showGoal não for passado explicitamente)
    this.showVibration = true, // Padrão true
    // --- FIM DA ADIÇÃO ---
  });

  // Função auxiliar (sem alterações)
  bool _isNotToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    return !today.isAtSameMomentAs(targetDate);
  }

  @override
  Widget build(BuildContext context) {
    // Usa showGoal OU o valor de showJourney se showGoal for true (padrão)
    final bool shouldShowGoal = showGoal && showJourney;
    final bool hasJourney =
        task.journeyTitle != null && task.journeyTitle!.isNotEmpty;
    final showDateIndicator = _isNotToday(task.dueDate);
    final currentYear = DateTime.now().year;

    final String dateFormat = (task.dueDate?.year ?? currentYear) != currentYear
        ? 'dd/MMM/yy'
        : 'dd/MMM';

    // Padding vertical entre TaskItems
    const double baseVerticalPadding = 4.0;
    final double verticalPadding =
        verticalPaddingOverride ?? baseVerticalPadding;

    // Ajustes de tamanho (sem alterações)
    final double mainFontSize = isCompact ? 14.0 : 16.0;
    final double indicatorFontSize = isCompact ? 11.0 : 12.0;
    final double indicatorIconSize = isCompact ? 12.0 : 14.0;
    final double popupIconSize = isCompact ? 18 : 22;
    final double popupTargetWidth =
        isCompact ? 36.0 : 40.0; // Largura do botão de menu

    return Padding(
      // Padding externo para espaçamento entre itens
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LINHA 1: Checkbox, Texto, Pílula (condicional), Botão ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Checkbox (com GestureDetector)
              GestureDetector(
                onTap:
                    onToggle != null ? () => onToggle!(!task.completed) : null,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 8.0),
                  child: Container(
                    width: 21,
                    height: 21,
                    decoration: BoxDecoration(
                      color: task.completed
                          ? Colors.green.shade500
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.completed
                            ? Colors.green.shade500
                            : AppColors.tertiaryText.withOpacity(0.7),
                        width: 1.5,
                      ),
                    ),
                    child: task.completed
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
              ),

              // 2. Texto Principal e Pílula (condicional)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      // Para o texto quebrar linha se necessário
                      child: Text(
                        task.text,
                        style: TextStyle(
                          color: task.completed
                              ? AppColors.tertiaryText
                              : AppColors.secondaryText,
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          fontSize: mainFontSize,
                          height: 1.3, // Ajuste para melhor leitura
                        ),
                      ),
                    ),
                    // --- MUDANÇA: Mostra a pílula APENAS se showVibration for true ---
                    if (showVibration &&
                        task.personalDay != null &&
                        task.personalDay! > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: VibrationPill(
                          vibrationNumber: task.personalDay!,
                          type:
                              VibrationPillType.compact, // Usa o tipo compacto
                        ),
                      ),
                    // --- FIM DA MUDANÇA ---
                  ],
                ),
              ),

              // 3. Botão de Menu (se houver ações)
              if (onEdit != null || onDelete != null || onDuplicate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: SizedBox(
                    // Garante área de toque consistente
                    width: popupTargetWidth,
                    height: popupTargetWidth,
                    child: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit')
                          onEdit?.call(); // Usa ?.call() por segurança
                        else if (value == 'delete')
                          onDelete?.call();
                        else if (value == 'duplicate') onDuplicate?.call();
                      },
                      color: AppColors.cardBackground,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      icon: Center(
                          // Centraliza o ícone dentro do SizedBox
                          child: Icon(Icons.more_vert,
                              color: AppColors.tertiaryText,
                              size: popupIconSize)),
                      padding:
                          EdgeInsets.zero, // Remove padding interno do botão
                      tooltip: "Mais opções",
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        if (onEdit != null)
                          _buildPopupMenuItem(
                              icon: Icons.edit_outlined,
                              text: 'Editar Tarefa',
                              value: 'edit',
                              iconColor: AppColors.secondaryText,
                              textColor: AppColors.primaryText),
                        if (onDuplicate != null)
                          _buildPopupMenuItem(
                              icon: Icons.copy_outlined,
                              text: 'Duplicar Tarefa',
                              value: 'duplicate',
                              iconColor: AppColors.secondaryText,
                              textColor: AppColors.primaryText),
                        if (onDelete != null) ...[
                          PopupMenuDivider(
                              height: 1,
                              color: AppColors.border.withOpacity(0.5)),
                          _buildPopupMenuItem(
                              icon: Icons.delete_outline,
                              text: 'Excluir Tarefa',
                              value: 'delete',
                              iconColor: Colors.redAccent.shade100,
                              textColor: Colors.redAccent.shade100),
                        ]
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // --- LINHA 2: Indicadores (Data, Meta, Tags) - Condicional ---
          // Só mostra a linha 2 se NÃO for compacto E houver algo para mostrar nela
          if (!isCompact &&
              (showDateIndicator ||
                  (shouldShowGoal && hasJourney) || // Usa shouldShowGoal
                  (showTags && task.tags.isNotEmpty)))
            Padding(
              // Alinha à esquerda com o texto principal, e à direita antes do botão de menu
              padding: EdgeInsets.only(
                  left: 32.0 + 8.0,
                  right: popupTargetWidth + 4.0,
                  top: 4.0), // Aumenta o top padding
              child: Wrap(
                // Permite quebrar linha se houver muitos indicadores
                spacing: 12.0, // Espaço horizontal
                runSpacing: 4.0, // Espaço vertical se quebrar linha
                crossAxisAlignment:
                    WrapCrossAlignment.center, // Alinha verticalmente
                children: [
                  // Indicador de Data (se não for hoje)
                  if (showDateIndicator)
                    _IndicatorIcon(
                      icon: Icons.calendar_today_outlined,
                      text:
                          DateFormat(dateFormat, 'pt_BR').format(task.dueDate!),
                      color: AppColors.tertiaryText.withOpacity(0.8),
                      iconSize: indicatorIconSize,
                      fontSize: indicatorFontSize,
                    ),

                  // --- MUDANÇA: Indicador de Meta/Jornada (condicional) ---
                  if (shouldShowGoal && hasJourney)
                    _IndicatorIcon(
                      icon: Icons.flag_outlined, // Ícone diferente para meta
                      text:
                          '@${StringSanitizer.toSimpleTag(task.journeyTitle!)}', // Mostra a tag simplificada
                      color: Colors.cyanAccent
                          .withOpacity(0.8), // Cor diferente para meta
                      iconSize: indicatorIconSize,
                      fontSize: indicatorFontSize,
                    ),
                  // --- FIM DA MUDANÇA ---

                  // --- MUDANÇA: Indicador de Tags (condicional) ---
                  if (showTags && task.tags.isNotEmpty)
                    ...task.tags
                        .map((tag) => _TagChip(tag: tag, isCompact: isCompact))
                        .toList(),
                  // --- FIM DA MUDANÇA ---
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Função auxiliar para criar itens do menu popup (sem alterações)
  PopupMenuItem<String> _buildPopupMenuItem({
    required IconData icon,
    required String text,
    required String value,
    required Color iconColor,
    required Color textColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 40, // Altura um pouco menor para o menu
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Text(text,
              style: TextStyle(
                  color: textColor, fontSize: 14)), // Fonte um pouco menor
        ],
      ),
    );
  }
} // Fim da classe TaskItem

// Widgets auxiliares (_IndicatorIcon, _TagChip) sem alterações
class _IndicatorIcon extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final double iconSize;
  final double fontSize;

  const _IndicatorIcon({
    required this.icon,
    required this.text,
    required this.color,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, // Alinha ícone e texto
      children: [
        Icon(icon, color: color, size: iconSize),
        const SizedBox(width: 4),
        Padding(
          // Adiciona um pequeno padding superior para alinhar melhor o texto com o ícone
          padding: const EdgeInsets.only(top: 1.0),
          child: Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final bool isCompact;

  const _TagChip({required this.tag, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final double verticalPadding = isCompact ? 1.5 : 3.0;
    final double horizontalPadding = isCompact ? 5.0 : 8.0;
    final double fontSize = isCompact ? 10.0 : 11.0; // Levemente menor

    return Container(
      margin: const EdgeInsets.only(
          top:
              2.0), // Adiciona margem superior para alinhar melhor com _IndicatorIcon
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.15), // Um pouco mais suave
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withOpacity(0.3), width: 0.5),
      ),
      child: Text('#$tag',
          style: TextStyle(
              color: Colors.purple.shade200
                  .withOpacity(0.9), // Um pouco mais suave
              fontSize: fontSize,
              fontWeight: FontWeight.w500)),
    );
  }
}
