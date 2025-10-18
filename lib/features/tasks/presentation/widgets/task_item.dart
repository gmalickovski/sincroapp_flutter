// lib/features/tasks/presentation/widgets/task_item.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class TaskItem extends StatelessWidget {
  final TaskModel task;
  final void Function(bool) onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final bool showJourney;
  final bool isCompact;
  final double? verticalPaddingOverride;

  const TaskItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onDuplicate,
    this.showJourney = true,
    this.isCompact = false,
    this.verticalPaddingOverride,
  });

  bool _isNotToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    return !today.isAtSameMomentAs(targetDate);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasJourney =
        task.journeyTitle != null && task.journeyTitle!.isNotEmpty;
    final showDateIndicator = _isNotToday(task.dueDate);
    final currentYear = DateTime.now().year;

    final String dateFormat = (task.dueDate?.year ?? currentYear) != currentYear
        ? 'dd/MMM/yy'
        : 'dd/MMM';

    // --- INÍCIO DA MODIFICAÇÃO (Espaçamento Externo Zerado) ---
    // Zeramos o padding base para TODAS as versões por padrão.
    const double baseVerticalPadding = 0.0;
    // --- FIM DA MODIFICAÇÃO ---

    // O verticalPaddingOverride ainda pode ser usado se alguma tela
    // específica precisar de um padding diferente (como o calendário).
    final double verticalPadding =
        verticalPaddingOverride ?? baseVerticalPadding;

    final double mainFontSize =
        isCompact ? 14.0 : 16.0; // Fonte principal menor
    final double indicatorFontSize =
        isCompact ? 11.0 : 12.0; // Fonte indicadora um pouco menor
    final double indicatorIconSize =
        isCompact ? 12.0 : 14.0; // Ícone indicador menor

    final double popupMenuButtonSize =
        isCompact ? 36.0 : 48.0; // Botão de menu menor (opcional)

    return Padding(
      // Aplicamos o padding calculado aqui (que agora será 0.0 por padrão)
      padding: EdgeInsets.only(
          left: 4, right: 0, top: verticalPadding, bottom: verticalPadding),

      // --- Coluna Principal ---
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LINHA 1: Itens Principais ---
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Alinha verticalmente
            children: [
              // 1. Checkbox (Tamanho 21x21, Ícone 12)
              GestureDetector(
                onTap: () => onToggle(!task.completed),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  // Usamos Alignment.center para garantir
                  // que o Container menor fique centralizado no SizedBox
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 21, // Círculo
                      height: 21, // Círculo
                      margin: const EdgeInsets.only(
                          right: 8), // Removemos a margem do topo
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
                          ? const Icon(
                              Icons.check,
                              size: 12, // Ícone
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // 2. Texto da Tarefa + Pílula de Vibração
              Expanded(
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Alinha texto e pílula
                  children: [
                    Expanded(
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
                          height: 1.3,
                        ),
                        maxLines: isCompact ? 2 : null,
                        overflow: isCompact
                            ? TextOverflow.ellipsis
                            : TextOverflow.visible,
                      ),
                    ),
                    if (task.personalDay != null && task.personalDay! > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 8.0), // Padding da pílula
                        child: VibrationPill(
                          vibrationNumber: task.personalDay!,
                          type: VibrationPillType.compact,
                        ),
                      ),
                  ],
                ),
              ),

              // 3. Menu de 3 pontos
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  } else if (value == 'duplicate') {
                    onDuplicate();
                  }
                },
                color: const Color(0xFF2a2141),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                constraints:
                    BoxConstraints.tight(Size.square(popupMenuButtonSize)),
                iconSize: isCompact ? 18 : 24,
                padding: EdgeInsets.zero,
                icon:
                    const Icon(Icons.more_vert, color: AppColors.tertiaryText),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 20, color: AppColors.secondaryText),
                        SizedBox(width: 12),
                        Text('Editar Tarefa'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_outlined,
                            size: 20, color: AppColors.secondaryText),
                        SizedBox(width: 12),
                        Text('Duplicar Tarefa'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            size: 20, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Text('Excluir Tarefa',
                            style: TextStyle(color: Colors.redAccent.shade100)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // --- LINHA 2: Indicadores (Data, Meta, Tags) ---

          // (Espaçamento Interno: -8.0 - Como estava)
          if (showDateIndicator ||
              task.tags.isNotEmpty ||
              (showJourney && hasJourney))
            Transform.translate(
              offset: const Offset(0, -8.0), // Puxa 8 pixels para cima
              child: Padding(
                padding: EdgeInsets.only(
                  left: 32, // Pula o espaço do Checkbox
                  right: popupMenuButtonSize, // Pula o espaço do Menu
                ),
                child: Wrap(
                  spacing: 10, // Espaçamento entre indicadores
                  runSpacing: isCompact
                      ? 2
                      : 4, // Espaçamento entre linhas de indicadores
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (showDateIndicator)
                      _IndicatorIcon(
                        icon: Icons.calendar_today_outlined,
                        text: DateFormat(dateFormat, 'pt_BR')
                            .format(task.dueDate!),
                        color: AppColors.tertiaryText.withOpacity(0.8),
                        iconSize: indicatorIconSize,
                        fontSize: indicatorFontSize,
                      ),
                    if (showJourney && hasJourney)
                      _IndicatorIcon(
                        icon: Icons.flag_outlined,
                        text:
                            '@${StringSanitizer.toSimpleTag(task.journeyTitle!)}',
                        color: Colors.cyanAccent.withOpacity(0.8),
                        iconSize: indicatorIconSize,
                        fontSize: indicatorFontSize,
                      ),
                    ...task.tags
                        .map((tag) => _TagChip(tag: tag, isCompact: isCompact))
                        .toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Widgets auxiliares (_IndicatorIcon, _TagChip) com ajustes para isCompact
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
      children: [
        Icon(icon, color: color, size: iconSize),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color, fontSize: fontSize, fontWeight: FontWeight.w500)),
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
    final double verticalPadding = isCompact ? 1.5 : 3.0; // Menor padding
    final double horizontalPadding = isCompact ? 5.0 : 8.0; // Menor padding
    final double fontSize = isCompact ? 10.0 : 12.0; // Fonte menor

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          // Borda sutil opcional
          color: Colors.purple.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text('#$tag',
          style: TextStyle(
              color: Colors.purple.shade200,
              fontSize: fontSize,
              fontWeight: FontWeight.w500)),
    );
  }
}
