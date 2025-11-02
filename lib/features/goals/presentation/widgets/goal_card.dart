// lib/features/goals/presentation/widgets/goal_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';

// CONVERTIDO PARA STATEFULWIDGET para gerenciar o estado de hover
class GoalCard extends StatefulWidget {
  final Goal goal;
  final String userId; // usado para calcular progresso igual ao GoalDetail
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
    required this.userId,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> {
  bool _isHovered = false; // Estado para controlar o hover

  @override
  Widget build(BuildContext context) {
    // Se tivermos userId, escutamos as tasks da meta para calcular progresso
    final FirestoreService _firestoreService = FirestoreService();

    Widget progressWidget(int progress, String? formattedDate) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$progress%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (formattedDate != null)
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.tertiaryText,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Até $formattedDate',
                      style: const TextStyle(
                        color: AppColors.tertiaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress / 100.0,
            backgroundColor: AppColors.background.withOpacity(0.7),
            color: AppColors.primary,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
        ],
      );
    }

    final formattedDate = widget.goal.targetDate != null
        ? DateFormat('dd/MM/yyyy', 'pt_BR').format(widget.goal.targetDate!)
        : null;

    // *** LÓGICA DA BORDA DE HOVER ***
    final Color borderColor;
    final double borderWidth;

    if (_isHovered) {
      borderColor = AppColors.primary.withOpacity(0.8);
      borderWidth = 1.5;
    } else {
      borderColor = AppColors.border.withOpacity(0.7);
      borderWidth = 1.0;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        // Anima a transição da borda
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor, // Borda dinâmica
            width: borderWidth, // Largura dinâmica
          ),
          boxShadow: _isHovered // Sombra sutil opcional no hover
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 8,
                  )
                ]
              : [],
        ),
        // O Card foi removido para usarmos o AnimatedContainer como base
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: AppColors.primary.withOpacity(0.1),
            highlightColor: AppColors.primary.withOpacity(0.1),
            hoverColor: Colors.transparent, // DESLIGA O HOVER PADRÃO
            child: Stack(
              // Stack para posicionar o botão de deletar
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título (com espaço para o botão de deletar)
                      Padding(
                        padding: const EdgeInsets.only(right: 30.0), // Espaço
                        child: Text(
                          widget.goal.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Descrição
                      if (widget.goal.description.isNotEmpty)
                        Text(
                          widget.goal.description,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          maxLines: 3, // Ocupa mais espaço se for desktop
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Spacer para empurrar o progresso para baixo
                      // Em um ListView, isso não funciona bem,
                      // então vamos apenas usar um SizedBox se a descrição for vazia
                      if (widget.goal.description.isEmpty)
                        const SizedBox(height: 24),

                      const Spacer(), // Usa o espaço restante

                      // Rodapé do Card (Progresso e Data) -> usa StreamBuilder para calcular igual ao GoalDetail
                      StreamBuilder<List<TaskModel>>(
                        stream: widget.userId.isNotEmpty
                            ? _firestoreService.getTasksForGoalStream(
                                widget.userId, widget.goal.id)
                            : null,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final milestones = snapshot.data!;
                            final int progress = milestones.isEmpty
                                ? 0
                                : (milestones.where((m) => m.completed).length /
                                        milestones.length *
                                        100)
                                    .round();
                            return progressWidget(progress, formattedDate);
                          } else if (snapshot.hasError) {
                            // Em caso de erro, usa o progresso armazenado no Goal
                            return progressWidget(
                                widget.goal.progress, formattedDate);
                          } else if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            // Mostra o progresso salvo enquanto carrega
                            return progressWidget(
                                widget.goal.progress, formattedDate);
                          } else {
                            return progressWidget(
                                widget.goal.progress, formattedDate);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Menu de opções
                if (widget.onDelete != null || widget.onEdit != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.secondaryText,
                        size: 20,
                      ),
                      tooltip: 'Opções',
                      color: AppColors.cardBackground,
                      position: PopupMenuPosition.under,
                      itemBuilder: (context) => [
                        if (widget.onEdit != null)
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.secondaryText,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text('Editar',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                        if (widget.onDelete != null)
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    color: Colors.red.shade400, size: 20),
                                const SizedBox(width: 8),
                                Text('Excluir',
                                    style:
                                        TextStyle(color: Colors.red.shade400)),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit' && widget.onEdit != null) {
                          widget.onEdit!();
                        } else if (value == 'delete' &&
                            widget.onDelete != null) {
                          widget.onDelete!();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
