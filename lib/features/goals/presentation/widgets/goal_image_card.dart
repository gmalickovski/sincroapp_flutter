import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';

class GoalImageCard extends StatefulWidget {
  final Goal goal;
  final VoidCallback onTap;

  const GoalImageCard({
    super.key,
    required this.goal,
    required this.onTap,
  });

  @override
  State<GoalImageCard> createState() => _GoalImageCardState();
}

class _GoalImageCardState extends State<GoalImageCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        widget.goal.imageUrl != null && widget.goal.imageUrl!.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovering
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border.withValues(alpha: 0.3),
              width: _isHovering ? 1.5 : 1.0,
            ),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: hasImage ? _buildImageContent() : _buildPlaceholderContent(),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.goal.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.cardBackground,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image,
                            color: AppColors.secondaryText, size: 32),
                        const SizedBox(height: 8),
                        Text('Erro ao carregar',
                            style: TextStyle(
                                color: AppColors.secondaryText
                                    .withValues(alpha: 0.7),
                                fontSize: 12)),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isHovering
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: _isHovering
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.8),
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Visualize o Sucesso ✨\nToque para adicionar uma imagem de capa',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
