// lib/features/tasks/presentation/widgets/task_item.dart

import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // Não é mais necessário para formatar data aqui
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
// import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart'; // Não mais necessário aqui
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';

class TaskItem extends StatelessWidget {
  final TaskModel task;
  final void Function(bool)? onToggle;
  final VoidCallback? onTap; // Callback para abrir detalhes

  // --- INÍCIO DA MUDANÇA ---
  // Novas Flags para controlar a exibição dos ícones/pílula
  final bool showGoalIconFlag;
  final bool showTagsIconFlag;
  final bool showVibrationPillFlag;
  // --- FIM DA MUDANÇA ---

  // Props de layout (mantidos por enquanto, mas isCompact pode ser obsoleto)
  final bool isCompact;
  final double? verticalPaddingOverride;

  const TaskItem({
    super.key,
    required this.task,
    this.onToggle,
    this.onTap,
    // --- INÍCIO DA MUDANÇA ---
    // Flags para controle (padrão true)
    this.showGoalIconFlag = true,
    this.showTagsIconFlag = true,
    this.showVibrationPillFlag = true,
    // --- FIM DA MUDANÇA ---
    // Props de layout
    this.isCompact = false,
    this.verticalPaddingOverride,
    // Callbacks de menu removidos: onDelete, onEdit, onDuplicate
    // Props de exibição antigos removidos: showJourney, showTags, showGoal, showVibration
  });

  // Helper para verificar se a data NÃO é hoje (inalterado)
  bool _isNotToday(DateTime? date) {
    // ... (código inalterado)
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    return !today.isAtSameMomentAs(targetDate);
  }

  @override
  Widget build(BuildContext context) {
    // Determina se os ícones/pílula devem ser mostrados BASEADO NAS FLAGS e nos dados da task
    final bool shouldShowGoalIcon = showGoalIconFlag &&
        task.journeyTitle != null &&
        task.journeyTitle!.isNotEmpty;
    final bool shouldShowTagIcon = showTagsIconFlag && task.tags.isNotEmpty;
    final bool shouldShowDateIcon = _isNotToday(
        task.dueDate); // Data futura sempre mostra ícone (se não for hoje)
    final bool shouldShowPill = showVibrationPillFlag &&
        task.personalDay != null &&
        task.personalDay! > 0;

    // Padding vertical (inalterado)
    const double baseVerticalPadding = 6.0;
    final double verticalPadding =
        verticalPaddingOverride ?? baseVerticalPadding;

    // Tamanhos (inalterado)
    final double mainFontSize = 16.0;
    final double iconIndicatorSize = 16.0;

    // Ajuste fino do padding vertical (inalterado)
    const double verticalAlignmentPadding = 2.5;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primary.withOpacity(0.1),
      highlightColor: AppColors.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding:
            EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Checkbox (inalterado)
            GestureDetector(
              // ... (código inalterado)
              onTap: onToggle != null ? () => onToggle!(!task.completed) : null,
              behavior: HitTestBehavior
                  .opaque, // Impede o InkWell de ser ativado aqui
              child: Container(
                width: 32, // Largura total da área de toque
                constraints: const BoxConstraints(
                    minHeight: 32), // Altura mínima área de toque
                alignment:
                    Alignment.topLeft, // Alinha o Padding interno ao topo
                margin: const EdgeInsets.only(
                    right: 12.0), // Espaço após o checkbox
                child: Padding(
                  padding: const EdgeInsets.only(
                      top:
                          verticalAlignmentPadding), // **ALINHAMENTO VERTICAL**
                  child: Container(
                    width: 19, // Tamanho do círculo
                    height: 19,
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
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),

            // 2. Texto Principal (inalterado)
            Expanded(
              // ... (código inalterado)
              child: Padding(
                // Padding superior para alinhar linha de base do texto + padding direito
                padding: const EdgeInsets.only(top: 1.0, right: 8.0),
                child: Text(
                  task.text,
                  // Considerar maxLines e overflow se o texto puder ser muito longo
                  // maxLines: 2,
                  // overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.completed
                        ? AppColors.tertiaryText
                        : AppColors.secondaryText,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    fontSize: mainFontSize,
                    height:
                        1.4, // Ajuste da altura da linha para melhor leitura
                  ),
                ),
              ),
            ),

            // 3. Grupo de Ícones/Pílula (inalterado)
            if (shouldShowDateIcon ||
                shouldShowGoalIcon ||
                shouldShowTagIcon ||
                shouldShowPill)
              Padding(
                // ... (código inalterado)
                padding: const EdgeInsets.only(
                    top: verticalAlignmentPadding), // **ALINHAMENTO VERTICAL**
                child: Row(
                  mainAxisSize: MainAxisSize
                      .min, // Não ocupa mais espaço que o necessário
                  crossAxisAlignment: CrossAxisAlignment
                      .center, // Alinha ícones/pílula verticalmente entre si
                  children: [
                    // Ícone de Data Futura
                    if (shouldShowDateIcon)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3.0), // Espaçamento horizontal
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: iconIndicatorSize,
                          color: AppColors.tertiaryText.withOpacity(0.8),
                        ),
                      ),

                    // Ícone de Meta
                    if (shouldShowGoalIcon)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.0),
                        child: Icon(
                          Icons.flag_outlined,
                          size: iconIndicatorSize,
                          color: Colors.cyanAccent.withOpacity(0.8),
                        ),
                      ),

                    // Ícone de Tags
                    if (shouldShowTagIcon)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.0),
                        child: Icon(
                          Icons.label_outline, // Ou Icons.tag se preferir
                          size: iconIndicatorSize,
                          color: Colors.purple.shade200.withOpacity(0.9),
                        ),
                      ),

                    // Pílula de Vibração
                    if (shouldShowPill)
                      Padding(
                        // Adiciona padding esquerdo APENAS se houver ícones antes
                        padding: EdgeInsets.only(
                            left: (shouldShowDateIcon ||
                                    shouldShowGoalIcon ||
                                    shouldShowTagIcon)
                                ? 6.0
                                : 0,
                            right:
                                0 // Sem padding direito extra aqui, a Row já tem padding geral
                            ),
                        child: VibrationPill(
                          vibrationNumber: task.personalDay!,
                          type: VibrationPillType.compact,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
} // Fim da classe TaskItem
