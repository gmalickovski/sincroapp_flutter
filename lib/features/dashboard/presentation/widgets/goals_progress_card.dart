// lib/features/dashboard/presentation/widgets/goals_progress_card.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class GoalsProgressCard extends StatefulWidget {
  final List<Goal> goals;
  final VoidCallback onViewAll;
  final Function(Goal goal) onGoalSelected;
  final Widget? dragHandle;
  final bool isEditMode;
  final String userId; // necessário para calcular progresso via tasks
  final VoidCallback? onAddGoal; // Novo callback opcional

  const GoalsProgressCard({
    super.key,
    required this.goals,
    required this.onViewAll,
    required this.onGoalSelected,
    required this.userId,
    this.dragHandle,
    this.isEditMode = false,
    this.onAddGoal,
  });

  @override
  State<GoalsProgressCard> createState() => _GoalsProgressCardState();
}

class _GoalsProgressCardState extends State<GoalsProgressCard> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _pageController.addListener(() {
      if (mounted && _pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 768.0;
    final Color borderColor = _isHovered
        ? AppColors.primary.withValues(alpha: 0.8)
        : AppColors.border.withValues(alpha: 0.7);
    final double borderWidth = _isHovered ? 1.5 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isEditMode
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isEditMode ? null : widget.onViewAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 8,
                    )
                  ]
                : [],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    widget.goals.isEmpty
                        ? _buildEmptyState()
                        : _buildCarousel(context),
                    const SizedBox(height: 12),
                    _buildFooter(context),
                  ],
                ),
              ),
              // Controles de navegação (somente Desktop e quando há mais de 1 meta)
              if (!widget.isEditMode && isDesktop && widget.goals.length > 1)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: _buildNavButton(
                            context,
                            align: Alignment.centerLeft,
                            onTap: _goPrev,
                            enabled: _currentPage > 0,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: _buildNavButton(
                            context,
                            align: Alignment.centerRight,
                            onTap: _goNext,
                            enabled: _currentPage < widget.goals.length - 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.isEditMode && widget.dragHandle != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: widget.dragHandle!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _goPrev() {
    if (_currentPage <= 0) return;
    _pageController.previousPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _goNext() {
    if (_currentPage >= (widget.goals.length - 1)) return;
    _pageController.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Widget _buildNavButton(BuildContext context,
      {required Alignment align,
      required VoidCallback onTap,
      required bool enabled}) {
    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.4,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onTap : null,
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.9),
                border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.8), width: 1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                align == Alignment.centerLeft
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: AppColors.primary,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(right: widget.isEditMode ? 32 : 0),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, color: AppColors.primary, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Metas',
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48.0),
      child: Center(
        child: Text(
          'Nenhuma meta definida.\nComece a planejar suas jornadas!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryText),
        ),
      ),
    );
  }

  Widget _buildCarousel(BuildContext context) {
    // Se há apenas uma meta, renderiza diretamente sem PageView para evitar excesso de espaço
    if (widget.goals.length == 1) {
      final goal = widget.goals.first;
      return GestureDetector(
        onTap: widget.isEditMode ? null : () => widget.onGoalSelected(goal),
        child: Container(
          color: Colors.transparent,
          // Remove padding horizontal do PageView item, mas mantém consistência visual
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: _buildGoalItem(goal),
        ),
      );
    }

    // Altura do slide ajustada dinamicamente para evitar overflow em mobile
    final bool isMobile = MediaQuery.of(context).size.width < 768.0;
    final double estDiameter = ((MediaQuery.of(context).size.width * 0.6)
            .clamp(isMobile ? 150.0 : 180.0, isMobile ? 200.0 : 240.0))
        .toDouble();
    // Reserva espaço para título, descrição (2 linhas) e data alvo
    final double pageHeight = estDiameter + (isMobile ? 130.0 : 110.0);

    return Column(
      children: [
        SizedBox(
          // Altura dinâmica para comportar o círculo + textos sem overflow
          height: pageHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.goals.length,
            itemBuilder: (context, index) {
              final goal = widget.goals[index];
              return GestureDetector(
                onTap: widget.isEditMode
                    ? null
                    : () => widget.onGoalSelected(goal),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _buildGoalItem(goal),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildGoalItem(Goal goal) {
    return GoalItemWidget(
      key: ValueKey(goal.id),
      goal: goal,
      userId: widget.userId,
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.goals.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            height: 8,
            width: _currentPage == index ? 24 : 8,
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? AppColors.primary
                  : AppColors.secondaryText.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween, // Botões nas extremidades
      children: [
        // Botão Ver Tudo (Esquerda) - Estilo Pílula
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.isEditMode ? null : widget.onViewAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3), width: 1),
              ),
              child: const Text(
                'Ver todas',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        // Botão Adicionar "Padronizado" (Direita)
        if (!widget.isEditMode && widget.onAddGoal != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onAddGoal,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class GoalItemWidget extends StatefulWidget {
  final Goal goal;
  final String userId;

  const GoalItemWidget({
    super.key,
    required this.goal,
    required this.userId,
  });

  @override
  State<GoalItemWidget> createState() => _GoalItemWidgetState();
}

class _GoalItemWidgetState extends State<GoalItemWidget> {
  late Stream<List<TaskModel>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _tasksStream =
        SupabaseService().getTasksForGoalStream(widget.userId, widget.goal.id);
  }

  @override
  void didUpdateWidget(covariant GoalItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goal.id != oldWidget.goal.id ||
        widget.userId != oldWidget.userId) {
      _tasksStream = SupabaseService()
          .getTasksForGoalStream(widget.userId, widget.goal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Verificar data alvo recebida do modelo
    // debugPrint('GoalsProgressCard: Meta "${widget.goal.title}" - targetDate: ${widget.goal.targetDate}');

    // Calcula progresso em tempo real a partir das tasks da meta
    return StreamBuilder<List<TaskModel>>(
      stream: _tasksStream,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const <TaskModel>[];
        int totalMarcos =
            tasks.isNotEmpty ? tasks.length : widget.goal.subTasks.length;
        int marcosConcluidos = tasks.isNotEmpty
            ? tasks.where((t) => t.completed).length
            : widget.goal.subTasks.where((t) => t.isCompleted).length;
        // Fallback: usa progress salvo quando não há tasks carregadas
        final double pct = totalMarcos > 0
            ? (marcosConcluidos / totalMarcos).clamp(0.0, 1.0)
            : (widget.goal.progress / 100).clamp(0.0, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = MediaQuery.of(context).size.width < 768.0;
            final double diameter = ((constraints.maxWidth *
                        (isMobile ? 0.6 : 0.65))
                    .clamp(isMobile ? 150.0 : 180.0, isMobile ? 200.0 : 240.0))
                .toDouble(); // Ocupa ~60-65% da largura, com limites por plataforma

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Círculo grande ocupando a largura
                Center(
                  child: _FullWidthGoalProgress(
                    diameter: diameter,
                    percent: pct,
                    completed: marcosConcluidos,
                    total: totalMarcos,
                    targetDate: widget.goal.targetDate, // Passa a data alvo
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.goal.title,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.goal.description.isEmpty
                      ? 'Sem descrição'
                      : widget.goal.description,
                  style: TextStyle(
                    color: widget.goal.description.isEmpty
                        ? AppColors.tertiaryText.withValues(alpha: 0.5)
                        : AppColors.tertiaryText,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ===================== WIDGETS DE APOIO =====================

class _FullWidthGoalProgress extends StatelessWidget {
  final double diameter;
  final double percent; // 0..1
  final int completed;
  final int total;
  final DateTime? targetDate; // Data alvo da meta
  const _FullWidthGoalProgress({
    required this.diameter,
    required this.percent,
    required this.completed,
    required this.total,
    this.targetDate,
  });

  @override
  Widget build(BuildContext context) {
    final int displayPercent = (percent * 100).round();

    // Formata a data alvo se existir
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
      formattedDate =
          '${targetDate!.day} ${months[targetDate!.month - 1]} ${targetDate!.year}';
    }

    return SizedBox(
      height: diameter,
      width: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: diameter,
              width: diameter,
              child: CircularProgressIndicator(
                value: percent.isNaN ? 0 : percent,
                strokeWidth: 12,
                backgroundColor: AppColors.border.withValues(alpha: 0.35),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$displayPercent%',
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                total > 0 ? '$completed/$total marcos' : 'Sem marcos',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (formattedDate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C), // Dark pill background
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.flag,
                        size: 16,
                        color: Color(0xFF8B5CF6), // Purple accent
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
