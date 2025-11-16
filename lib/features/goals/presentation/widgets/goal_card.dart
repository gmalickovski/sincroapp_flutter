import 'package:flutter/material.dart';
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
    final firestore = FirestoreService();

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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isMobile =
                      MediaQuery.of(context).size.width < 768.0;
                  final double diameter = isMobile ? 220 : 260;
                  final double headerHeight =
                      diameter + 24; // espaço para centralizar o círculo

                  return Stack(
                    children: [
                      // Botão de opções no canto superior direito
                      if (widget.onDelete != null || widget.onEdit != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: AppColors.secondaryText,
                              size: 20,
                            ),
                            tooltip: 'Opções',
                            color: AppColors.cardBackground,
                            position: PopupMenuPosition.under,
                            itemBuilder: (context) {
                              final items = <PopupMenuEntry<String>>[];
                              if (widget.onEdit != null) {
                                items.add(const PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Editar',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ));
                              }
                              if (widget.onDelete != null) {
                                items.add(const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.redAccent, size: 18),
                                      SizedBox(width: 8),
                                      Text('Excluir',
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ));
                              }
                              return items;
                            },
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

                      // Conteúdo do card
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Círculo centralizado
                          SizedBox(
                            height: headerHeight,
                            child: Center(
                              child: StreamBuilder<List<TaskModel>>(
                                stream: widget.userId.isNotEmpty
                                    ? firestore.getTasksForGoalStream(
                                        widget.userId, widget.goal.id)
                                    : null,
                                builder: (context, snapshot) {
                                  final tasks =
                                      snapshot.data ?? const <TaskModel>[];
                                  final int total = tasks.isNotEmpty
                                      ? tasks.length
                                      : widget.goal.subTasks.length;
                                  final int done = tasks.isNotEmpty
                                      ? tasks.where((t) => t.completed).length
                                      : widget.goal.subTasks
                                          .where((t) => t.isCompleted)
                                          .length;
                                  final double percent = total > 0
                                      ? (done / total).clamp(0.0, 1.0)
                                      : (widget.goal.progress / 100)
                                          .clamp(0.0, 1.0);

                                  return _ProgressCircle(
                                    diameter: diameter,
                                    percent: percent,
                                    done: done,
                                    total: total,
                                    targetDate: widget.goal.targetDate,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.goal.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (widget.goal.description.isNotEmpty)
                            Text(
                              widget.goal.description,
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 14,
                              ),
                              softWrap: true,
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ====== UI de progresso radial (estilo dashboard) ======
class _ProgressCircle extends StatelessWidget {
  final double diameter;
  final double percent; // 0..1
  final int done;
  final int total;
  final DateTime? targetDate;

  const _ProgressCircle({
    required this.diameter,
    required this.percent,
    required this.done,
    required this.total,
    required this.targetDate,
  });

  @override
  Widget build(BuildContext context) {
    // Formata data alvo
    String? formattedDate;
    if (targetDate != null) {
      final months = [
        'Jan',
        'Fev',
        'Mar',
        'Abr',
        'Mai',
        'Jun',
        'Jul',
        'Ago',
        'Set',
        'Out',
        'Nov',
        'Dez'
      ];
      final d = targetDate!;
      formattedDate =
          '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    }
    final int displayPercent = (percent * 100).round();

    return SizedBox(
      height: diameter,
      width: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: diameter,
            width: diameter,
            child: CustomPaint(painter: _RadialBasePainter()),
          ),
          SizedBox(
            height: diameter,
            width: diameter,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: percent),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (context, value, _) =>
                  CustomPaint(painter: _RadialProgressPainter(value)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$displayPercent%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(total == 0 ? 'Sem marcos' : '$done de $total',
                  style: const TextStyle(
                      color: AppColors.secondaryText, fontSize: 14)),
              if (formattedDate != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(formattedDate,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RadialBasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = AppColors.border.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width / 2) - 8;
    canvas.drawCircle(c, r, base);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RadialProgressPainter extends CustomPainter {
  final double percent;
  _RadialProgressPainter(this.percent);
  @override
  void paint(Canvas canvas, Size size) {
    final progress = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    final start = -90 * 3.1415926535 / 180; // topo
    final sweep = percent * 2 * 3.1415926535;
    canvas.drawArc(rect.deflate(8), start, sweep, false, progress);
  }

  @override
  bool shouldRepaint(covariant _RadialProgressPainter old) =>
      old.percent != percent;
}
