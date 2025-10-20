// lib/features/dashboard/presentation/widgets/focus_day_card.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart'; // Importar VibrationPill
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_item.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
// Import necessário para o TaskInputModal que será chamado pelo callback
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';

class FocusDayCard extends StatelessWidget {
  final List<TaskModel> tasks;
  final VoidCallback onViewAll;
  final Function(TaskModel task, bool isCompleted) onTaskStatusChanged;
  final UserModel userData;
  final Function(TaskModel task) onTaskDeleted;
  final Function(TaskModel task) onTaskEdited;
  final Function(TaskModel task) onTaskDuplicated;
  final Widget? dragHandle; // Recebe o DragHandle da DashboardScreen
  final bool isEditMode;
  final int? personalDayNumber; // Número do dia pessoal para HOJE
  // --- INÍCIO DA ADIÇÃO ---
  final VoidCallback onAddTask; // Callback para o botão de adicionar
  // --- FIM DA ADIÇÃO ---

  const FocusDayCard({
    super.key,
    required this.tasks,
    required this.onViewAll,
    required this.onTaskStatusChanged,
    required this.userData,
    required this.onTaskDeleted,
    required this.onTaskEdited,
    required this.onTaskDuplicated,
    required this.onAddTask, // Adicionado ao construtor
    this.dragHandle, // Recebe o handle
    this.isEditMode = false,
    this.personalDayNumber, // Recebe o dia pessoal
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Estilo do container principal (igual ao InfoCard)
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.8), // Leve transparência
        borderRadius: BorderRadius.circular(16.0), // Borda padrão
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          // Sombra padrão
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      // ClipRRect e BackdropFilter podem ser adicionados aqui se quiser o efeito de vidro fosco como no InfoCard
      child: Stack(
        children: [
          // Conteúdo principal do card
          Padding(
            // Padding interno padrão (igual ao InfoCard)
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize
                  .min, // Para o card não ocupar altura desnecessária
              children: [
                _buildHeader(
                    context), // <<< Passa o context para o header poder chamar o modal
                const SizedBox(height: 16), // Espaçamento padrão
                // Constrói a lista ou o estado vazio
                _buildTaskList(context),
              ],
            ),
          ),
          // Posiciona o DragHandle recebido no canto superior direito
          if (isEditMode && dragHandle != null)
            Positioned(
              top: 8, // Ajuste a posição conforme necessário
              right: 8,
              child: dragHandle!,
            ),
        ],
      ),
    );
  }

  // --- MUDANÇA: Recebe BuildContext e adiciona IconButton ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      // Padding direito para o texto não ficar embaixo do drag handle quando visível
      padding: EdgeInsets.only(right: isEditMode ? 32 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            CrossAxisAlignment.center, // Centraliza verticalmente
        children: [
          // Agrupa Ícone, Título e Pílula
          Flexible(
            // Para evitar overflow
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Ocupa espaço mínimo necessário
              children: [
                // Ícone com tamanho padrão
                const Icon(Icons.check_box_outlined,
                    color: AppColors.primary,
                    size: 24), // Tamanho igual InfoCard
                const SizedBox(width: 12), // Espaçamento igual InfoCard
                // Título com estilo padrão
                const Flexible(
                  // Para o texto quebrar se necessário
                  child: Text(
                    'Foco do Dia',
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold, // Igual InfoCard
                      fontSize: 16, // Igual InfoCard
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Pílula de Vibração do Dia (lógica mantida)
                if (personalDayNumber != null && personalDayNumber! > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0), // Espaçamento
                    child: VibrationPill(vibrationNumber: personalDayNumber!),
                  ),
              ],
            ),
          ),
          // Agrupa os botões de ação à direita
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- INÍCIO DA ADIÇÃO: Botão de Adicionar Tarefa ---
              if (!isEditMode) // Só mostra se não estiver em modo de edição
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppColors.primary),
                  tooltip: 'Adicionar Tarefa',
                  iconSize: 22, // Tamanho do ícone
                  padding: const EdgeInsets.all(4), // Padding interno do botão
                  constraints:
                      const BoxConstraints(), // Remove constraints padrão
                  splashRadius: 20, // Raio do splash
                  onPressed: onAddTask, // <<< CHAMA O CALLBACK PASSADO
                ),
              // --- FIM DA ADIÇÃO ---

              // Botão "Ver tudo" (estilo ajustado)
              Padding(
                padding:
                    const EdgeInsets.only(left: 4.0), // Espaço entre botões
                child: TextButton(
                  onPressed: isEditMode ? null : onViewAll,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2), // Padding menor
                      tapTargetSize: MaterialTapTargetSize
                          .shrinkWrap, // Reduz área de toque
                      foregroundColor:
                          AppColors.secondaryText, // Cor mais sutil
                      textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500) // Tamanho menor
                      ),
                  child: const Text('Ver tudo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // --- FIM DA MUDANÇA ---

  // Constrói o estado de lista vazia (sem alterações)
  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24.0), // Espaçamento vertical
      child: Center(
        child: Text(
          'Nenhuma tarefa para hoje.\nAdicione novas tarefas ou marcos!', // Texto atualizado
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.secondaryText, height: 1.5), // Melhora leitura
        ),
      ),
    );
  }

  // Constrói a lista de tarefas (sem alterações lógicas, apenas passa parâmetros corretos)
  Widget _buildTaskList(BuildContext context) {
    // Limita o número de tarefas visíveis no dashboard (ex: 3)
    final tasksToShow = tasks.take(3).toList();

    // Se não houver tarefas para mostrar (após o take), retorna o estado vazio
    if (tasksToShow.isEmpty) {
      return _buildEmptyState();
    }

    // Usando Column diretamente
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tasksToShow.map((task) {
        return TaskItem(
          key: ValueKey(task.id), // Key para performance
          task: task,
          // Passa os parâmetros corretos para o TaskItem mostrar/esconder detalhes
          showGoal: true, // MOSTRAR meta (@)
          showTags: true, // MOSTRAR tags (#)
          showVibration: false, // NÃO MOSTRAR pílula individual
          isCompact: false, // NÃO compacto para mostrar detalhes
          // Passa os callbacks recebidos pelo FocusDayCard
          onToggle: (isCompleted) => onTaskStatusChanged(task, isCompleted),
          onEdit: () => onTaskEdited(task),
          onDelete: () => onTaskDeleted(task),
          onDuplicate: () => onTaskDuplicated(task),
          verticalPaddingOverride: 6.0, // Padding ajustado
        );
      }).toList(),
    );
  }
}
