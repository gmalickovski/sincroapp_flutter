// lib/features/dashboard/presentation/widgets/goals_progress_card.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';

class GoalsProgressCard extends StatefulWidget {
  final List<Goal> goals;
  final VoidCallback onViewAll;
  final Function(Goal goal) onGoalSelected;
  final Widget? dragHandle;
  final bool isEditMode;

  const GoalsProgressCard({
    super.key,
    required this.goals,
    required this.onViewAll,
    required this.onGoalSelected,
    this.dragHandle,
    this.isEditMode = false,
  });

  @override
  State<GoalsProgressCard> createState() => _GoalsProgressCardState();
}

class _GoalsProgressCardState extends State<GoalsProgressCard> {
  late final PageController _pageController;
  int _currentPage = 0;

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
    final completedGoals = widget.goals.where((g) => g.progress >= 100).length;
    final totalGoals = widget.goals.length;

    return GestureDetector(
      onTap: widget.isEditMode ? null : widget.onViewAll,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.border),
        ),
        // *** CORREÇÃO: Envolve com Stack ***
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Conteúdo principal (header, carrossel)
                  GestureDetector(
                      onTap: widget.isEditMode ? null : widget.onViewAll,
                      child: _buildHeader(completedGoals, totalGoals)),
                  const SizedBox(height: 16),
                  widget.goals.isEmpty
                      ? _buildEmptyState()
                      : _buildCarousel(context),
                ],
              ),
            ),
            // *** CORREÇÃO: Posiciona o dragHandle no canto superior direito ***
            if (widget.isEditMode && widget.dragHandle != null)
              Positioned(
                top: 8,
                right: 8,
                child: widget.dragHandle!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int completedGoals, int totalGoals) {
    // *** CORREÇÃO: Remove o dragHandle daqui ***
    return Container(
      // Adiciona padding direito para o texto não ficar embaixo do handle posicionado
      padding: EdgeInsets.only(right: widget.isEditMode ? 32 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Flexible(
            // Para evitar overflow no título
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.track_changes_outlined,
                    color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Flexible(
                  // Para o texto quebrar linha ou usar ellipsis
                  child: Text(
                    'Progresso das Metas',
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
          ),
          if (totalGoals > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                '$completedGoals/$totalGoals Concluídas',
                style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  // --- O restante do código (_buildEmptyState, _buildCarousel, _buildGoalItem, _buildPageIndicator) permanece o mesmo ---
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
    return Column(
      children: [
        SizedBox(
          height: 90,
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
        if (widget.goals.length > 1) _buildPageIndicator(),
      ],
    );
  }

  Widget _buildGoalItem(Goal goal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          goal.title,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goal.progress / 100.0,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${goal.progress}%',
              style: const TextStyle(
                  color: AppColors.secondaryText, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.goals.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.primary
                : AppColors.secondaryText.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
