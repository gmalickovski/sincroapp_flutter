import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
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

  // (Solicitação 1) Novos parâmetros de seleção (AGORA OPCIONAIS)
  final bool selectionMode;
  final Set<String> selectedTaskIds;
  final Function(String, bool)? onTaskSelected; // Tornou-se opcional
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

    // (Solicitação 1) Adiciona ao construtor (COM VALORES PADRÃO / OPCIONAIS)
    this.selectionMode = false,
    this.selectedTaskIds = const {},
    this.onTaskSelected, // Não é mais 'required'
    // --- FIM DA MUDANÇA ---
    // Props de layout
    this.isCompact = false,
    this.verticalPaddingOverride,
    // Callbacks de menu removidos: onDelete, onEdit, onDuplicate
    // Props de exibição antigos removidos: showJourney, showTags, showGoal, showVibration
  });

  // Helper para verificar se a data NÃO é hoje (inalterado)
  bool _isNotToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    return !today.isAtSameMomentAs(targetDate);
  }

  // --- INÍCIO DA MUDANÇA: (Solicitação 1) Checkbox de Conclusão (Original) ---
  /// O checkbox de conclusão original (círculo customizado)
  Widget _buildCompletionCheckbox(double verticalAlignmentPadding) {
    return GestureDetector(
      onTap: onToggle != null ? () => onToggle!(!task.completed) : null,
      behavior: HitTestBehavior.opaque, // Impede o InkWell de ser ativado aqui
      child: Container(
        width: 32, // Largura total da área de toque
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.topLeft,
        // Alinha com a primeira linha do texto (ajustado para height 1.45)
        margin: const EdgeInsets.only(right: 12.0, top: 2.0),
        child: Container(
          width: 19, // Tamanho do círculo
          height: 19,
          decoration: BoxDecoration(
            color: task.completed ? Colors.green.shade500 : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: task.completed
                  ? Colors.green.shade500
                  : AppColors.tertiaryText.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: task.completed
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : null,
        ),
      ),
    );
  }
  // --- FIM DA MUDANÇA ---

  // --- INÍCIO DA MUDANÇA (Solicitação 1): Checkbox de Seleção ---
  /// O checkbox de seleção (padrão do Flutter)
  Widget _buildSelectionCheckbox(
      bool isSelected, double verticalAlignmentPadding) {
    return Container(
      width: 32, // Largura total
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.topLeft,
      // Alinha com a primeira linha do texto (ajustado para compensar padding interno do Checkbox)
      margin: const EdgeInsets.only(right: 8.0, top: 0.0),
      child: Transform.scale(
        scale: 0.9, // Reduz ligeiramente para melhor proporção
        child: Checkbox(
          value: isSelected,
          // Adiciona verificação nula
          onChanged: onTaskSelected == null
              ? null
              : (bool? value) {
                  onTaskSelected!(task.id, value ?? false);
                },
          checkColor: Colors.white,
          activeColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
  // --- FIM DA MUDANÇA ---

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

    // --- INÍCIO DA MUDANÇA (Solicitação 1): Verifica se está selecionado ---
    final bool isSelected = selectedTaskIds.contains(task.id);
    // --- FIM DA MUDANÇA ---

    return InkWell(
      // --- INÍCIO DA MUDANÇA (Solicitação 1): Lógica de toque dinâmica ---
      onTap: () {
        if (selectionMode) {
          // Em modo de seleção, o toque no item seleciona/deseleciona
          if (onTaskSelected != null) {
            // Adiciona verificação nula
            onTaskSelected!(task.id, !isSelected);
          }
        } else if (onTap != null) {
          // Modo normal, chama o onTap original (abrir detalhes)
          onTap!();
        }
      },
      // --- FIM DA MUDANÇA ---
      splashColor: AppColors.primary.withValues(alpha: 0.1),
      highlightColor: AppColors.primary.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8.0),
      child: AnimatedContainer(
        // Adicionado para feedback visual
        duration: const Duration(milliseconds: 200),
        // --- INÍCIO DA MUDANÇA (Solicitação 1): Feedback visual de seleção ---
        decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0)),
        // --- FIM DA MUDANÇA ---
        child: Padding(
          padding:
              EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- INÍCIO DA MUDANÇA (Solicitação 1): Checkbox condicional ---
              // 1. Checkbox (agora condicional)
              if (selectionMode)
                _buildSelectionCheckbox(isSelected, verticalAlignmentPadding)
              else
                _buildCompletionCheckbox(verticalAlignmentPadding),
              // --- FIM DA MUDANÇA ---

              // 2. Texto Principal
              Expanded(
                child: Text(
                  task.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.completed
                        ? AppColors.tertiaryText
                        : AppColors.secondaryText,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    fontSize: mainFontSize,
                    height: 1.45, // Line-height padrão de leitura confortável
                    letterSpacing:
                        0.15, // Espaçamento de letra para melhor legibilidade
                  ),
                ),
              ),

              // 3. Grupo de Ícones/Pílula com largura limitada
              if (shouldShowDateIcon ||
                  shouldShowGoalIcon ||
                  shouldShowTagIcon ||
                  shouldShowPill)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Padding(
                    // Alinha com a primeira linha do texto (considerando height 1.45)
                    padding: const EdgeInsets.only(left: 8.0, top: 1.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (shouldShowDateIcon)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 3.0),
                            child: Icon(
                              Icons.calendar_today_outlined,
                              size: iconIndicatorSize,
                              color: const Color(
                                  0xFFFB923C), // orange-400 (laranja como no chip)
                            ),
                          ),
                        if (shouldShowGoalIcon)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 3.0),
                            child: Icon(
                              Icons.flag_outlined,
                              size: iconIndicatorSize,
                              color: const Color(
                                  0xFF06B6D4), // cyan-500 (ciano como no chip)
                            ),
                          ),
                        if (shouldShowTagIcon)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 3.0),
                            child: Icon(
                              Icons.label_outline,
                              size: iconIndicatorSize,
                              color: const Color(
                                  0xFFEC4899), // pink-500 (rosa/magenta como no chip)
                            ),
                          ),
                        if (shouldShowPill)
                          Padding(
                            padding: EdgeInsets.only(
                              left: (shouldShowDateIcon ||
                                      shouldShowGoalIcon ||
                                      shouldShowTagIcon)
                                  ? 6.0
                                  : 0,
                            ),
                            child: VibrationPill(
                              vibrationNumber: task.personalDay!,
                              type: VibrationPillType.compact,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} // Fim da classe TaskItem
