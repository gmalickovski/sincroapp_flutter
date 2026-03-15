import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

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
  final bool isActive; // Novo parâmetro para indicar item ativo (desktop)
  final Function(TaskModel, DateTime)?
      onRescheduleDate; // NOVO: Callback para menu
  final UserModel?
      userData; // Para cálculo dinâmico do dia pessoal em tarefas perpétuas
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
    this.isActive = false, // Novo parâmetro
    this.onRescheduleDate, // Callback para ações do menu
    this.userData, // Para cálculo dinâmico do dia pessoal
    // --- FIM DA MUDANÇA ---
    // Props de layout
    this.isCompact = false,
    this.verticalPaddingOverride,
    // Callbacks de Swipe
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  // Callbacks de Swipe (Future<bool> para confirmar ação)
  final Future<bool?> Function(TaskModel)? onSwipeLeft; // Excluir
  final Future<bool?> Function(TaskModel)? onSwipeRight; // Reagendar

  TextSpan _buildMentionHighlightedText(
    String text, {
    required TextStyle baseStyle,
    required TextStyle mentionStyle,
    required TextStyle tagStyle,
    required TextStyle goalStyle,
  }) {
    // Regex para encontrar @username OU #tag
    // Captura @letras.pontos, #letras ou !letras
    final regex = RegExp(r'(@[\w.]+|#[\wÀ-ÿ]+|![\wÀ-ÿ]+)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      final matchText = match.group(0)!;

      // Texto antes da coincidência
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      // Aplica estilo dependendo se é menção, tag ou meta
      final isMention = matchText.startsWith('@');
      final isGoal = matchText.startsWith('!');

      TextStyle matchStyle;
      if (isMention) {
        matchStyle = mentionStyle;
      } else if (isGoal) {
        matchStyle = goalStyle;
      } else {
        matchStyle = tagStyle;
      }

      spans.add(TextSpan(
        text: matchText,
        style: matchStyle,
      ));

      lastEnd = match.end;
    }

    // Texto após a última coincidência
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
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
        margin: const EdgeInsets.only(right: 8.0, top: 2.0),
        child: Container(
          // Removido Transform.scale para manter tamanho original
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

  // ... (checkbox methods omitted) ...

  // --- INÍCIO DA MUDANÇA (Solicitação 1): Checkbox de Seleção ---
  /// O checkbox de seleção (padrão do Flutter)
  Widget _buildSelectionCheckbox(
      bool isSelected, double verticalAlignmentPadding) {
    return Container(
      width: 32, // Largura total
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.topLeft,
      // Alinha com a primeira linha do texto (ajustado para compensar padding interno do Checkbox)
      margin: const EdgeInsets.only(right: 6.0, top: 0.0),
      child: Transform.scale(
        scale: 0.8, // Ajustado para igualar o tamanho do círculo de conclusão
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
    // final bool shouldShowTagIcon = showTagsIconFlag && task.tags.isNotEmpty; // REMOVIDO
    final bool isRecurrent = task.recurrenceType != RecurrenceType.none;
    final bool isFlowOrInstance = task.recurrenceCategory == 'flow' ||
        task.recurrenceCategory == 'flow_instance';
    // Somente instâncias de commitment (não o valor default 'commitment' em tarefas normais)
    final bool isCommitmentInstance =
        task.recurrenceCategory == 'commitment_instance';
    // Mostra ícone de data para tarefas normais e recorrentes de compromisso; nunca para flow
    final bool shouldShowDateIcon =
        (task.hasDeadline || task.startDate != null) && !isFlowOrInstance;
    // Calcula o dia pessoal efetivo: dinâmico para tarefas perpétuas, estático para agendadas
    int? effectivePersonalDay = task.personalDay;
    if (userData != null &&
        userData!.nomeAnalise.isNotEmpty &&
        userData!.dataNasc.isNotEmpty) {
      // Tarefa perpétua (nem flow nem agendada): calcula dia pessoal baseado na data de hoje
      try {
        final engine = NumerologyEngine(
          nomeCompleto: userData!.nomeAnalise,
          dataNascimento: userData!.dataNasc,
        );
        final now = DateTime.now();
        final todayUtc = DateTime.utc(now.year, now.month, now.day);
        final day = engine.calculatePersonalDayForDate(todayUtc);
        if (day > 0) effectivePersonalDay = day;
      } catch (_) {}
    }

    // Pílula vibracional para todos os tipos de tarefa (commitment, flow, normais)
    final bool shouldShowPill = showVibrationPillFlag &&
        effectivePersonalDay != null &&
        effectivePersonalDay > 0;
    // Nova flag para lembrete
    final bool shouldShowReminderIcon = task.reminderAt != null;
    // Flag para ícone de foco (tarefas sem data marcadas como foco)
    final bool shouldShowFocusIcon =
        !task.hasDeadline && task.startDate == null && task.isFocus;

    // Padding vertical (inalterado)
    const double baseVerticalPadding = 6.0;
    final double verticalPadding =
        verticalPaddingOverride ?? baseVerticalPadding;

    // Tamanhos (inalterado)
    const double mainFontSize = 16.0;
    const double iconIndicatorSize = 16.0;

    // Ajuste fino do padding vertical (inalterado)
    const double verticalAlignmentPadding = 2.5;

    // --- INÍCIO DA MUDANÇA (Solicitação 1): Verifica se está selecionado ---
    final bool isSelected = selectedTaskIds.contains(task.id);
    // --- FIM DA MUDANÇA ---

    // Constrói o texto de exibição (Texto Original + Tags)
    String displayText = task.text;
    if (task.tags.isNotEmpty) {
      final tagsString = task.tags.map((t) => '#$t').join(' ');
      displayText += ' $tagsString';
    }

    // Widget principal (Conteúdo)
    final Widget content = InkWell(
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
        // --- INÍCIO DA MUDANÇA: Feedback visual de seleção e ativo ---
        decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.2)
                : (isActive
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent), // Highlight se ativo
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isActive
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border.withValues(alpha: 0.3)),
              width: (isSelected || isActive) ? 1.0 : 0.5,
            ),
            borderRadius: BorderRadius.circular(8.0)),
        // --- FIM DA MUDANÇA ---
        child: Padding(
          padding:
              EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 6.0),
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

              // 2. Texto Principal com destaque de menções e tags
              Expanded(
                child: RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: _buildMentionHighlightedText(
                    displayText,
                    baseStyle: TextStyle(
                      color: task.completed
                          ? AppColors.tertiaryText
                          : (task.isOverdue
                              // Red-400 equivalent for good contrast on dark bg
                              ? const Color(0xFFEF5350)
                              : AppColors.secondaryText),
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      fontSize: mainFontSize,
                      height: 1.45,
                      letterSpacing: 0.15,
                      fontFamily: 'Poppins',
                    ),
                    mentionStyle: TextStyle(
                      color: AppColors.taskMarker, // Blue-500
                      fontWeight: FontWeight.bold,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      fontSize: mainFontSize,
                      height: 1.45,
                      letterSpacing: 0.15,
                      fontFamily: 'Poppins',
                    ),
                    tagStyle: TextStyle(
                      color: AppColors.harmonyPink, // Pink for tags
                      fontWeight: FontWeight.w600,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      fontSize: mainFontSize,
                      height: 1.45,
                      letterSpacing: 0.15,
                      fontFamily: 'Poppins',
                    ),
                    goalStyle: TextStyle(
                      color: AppColors.goalTaskMarker, // Pink for goals
                      fontWeight: FontWeight.w600,
                      decoration: task.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      fontSize: mainFontSize,
                      height: 1.45,
                      letterSpacing: 0.15,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),

              // 3. Grupo de Ícones/Pílula sem constraint
              if (shouldShowDateIcon ||
                  shouldShowGoalIcon ||
                  // shouldShowTagIcon || // REMOVIDO
                  shouldShowReminderIcon ||
                  shouldShowFocusIcon ||
                  shouldShowPill ||
                  isRecurrent ||
                  isCommitmentInstance ||
                  isFlowOrInstance)
                Padding(
                  // Alinha com a primeira linha do texto (considerando height 1.45)
                  padding: const EdgeInsets.only(left: 8.0, top: 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (shouldShowDateIcon)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3.0),
                          child: Icon(
                            task.isOverdue
                                ? Icons.event_busy
                                : Icons.calendar_today_outlined,
                            size: iconIndicatorSize,
                            color: task.isOverdue
                                ? const Color(0xFFEF5350)
                                : const Color(0xFFFB923C), // orange-400
                          ),
                        ),
                      if (shouldShowReminderIcon) // Ícone de Lembrete
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.0),
                          child: Icon(
                            Icons.notifications_active_outlined,
                            size: iconIndicatorSize,
                            color: AppColors.primary, // Roxo como destaque
                          ),
                        ),
                      // Ícone de recorrência: apenas templates (recurrenceType != none)
                      // + instâncias explícitas (commitment_instance / flow / flow_instance)
                      // Nunca para tarefas normais que têm recurrenceCategory='commitment' por padrão
                      if (isRecurrent || isCommitmentInstance || isFlowOrInstance)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.0),
                          child: Icon(
                            Icons.repeat_rounded,
                            size: iconIndicatorSize,
                            color: Color(0xFF8B5CF6), // Violet-500
                          ),
                        ),
                      if (shouldShowGoalIcon)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.0),
                          child: Icon(
                            Icons.flag_outlined,
                            size: iconIndicatorSize,
                            color: Color(0xFF06B6D4), // cyan-500
                          ),
                        ),
                      // Ícone de foco (bolt) para tarefas sem data em foco
                      if (shouldShowFocusIcon)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.0),
                          child: Icon(
                            Icons.bolt,
                            size: iconIndicatorSize,
                            color: Colors.amber,
                          ),
                        ),
                      // ICONE DE TAG REMOVIDO DAQUI
                      if (shouldShowPill)
                        Padding(
                          padding: EdgeInsets.only(
                            left: (shouldShowDateIcon ||
                                    shouldShowGoalIcon ||
                                    shouldShowReminderIcon ||
                                    isRecurrent ||
                                    isCommitmentInstance ||
                                    isFlowOrInstance)
                                ? 6.0
                                : 0,
                          ),
                          child: VibrationPill(
                            vibrationNumber: effectivePersonalDay,
                            type: VibrationPillType.compact,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Se estiver em modo de seleção, NÃO permite swipe
    if (selectionMode) {
      return content;
    }

    // Retorna o Dismissible — somente swipe esquerdo (excluir)
    return Dismissible(
      key: ValueKey('dismiss_${task.id}'),
      direction: DismissDirection.endToStart, // apenas ← para excluir
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (onSwipeLeft != null) {
          return await onSwipeLeft!(task);
        }
        return false;
      },
      child: content,
    );
  }
} // Fim da classe TaskItem
