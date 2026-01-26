import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/strategy/models/strategy_recommendation.dart';
import 'package:sincro_app_flutter/features/strategy/presentation/widgets/strategy_detail_modal.dart';

class StrategyCard extends StatefulWidget {
  final StrategyRecommendation recommendation;
  final VoidCallback? onTap;
  final bool isEditMode;
  final Widget? dragHandle;

  const StrategyCard({
    super.key,
    required this.recommendation,
    this.onTap,
    this.isEditMode = false,
    this.dragHandle,
  });

  @override
  State<StrategyCard> createState() => _StrategyCardState();
}

class _StrategyCardState extends State<StrategyCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final mode = widget.recommendation.mode;

    // Use mode color for border on hover or active state
    final Color borderColor = (_isHovered && !widget.isEditMode)
        ? mode.color.withValues(alpha: 0.8)
        : AppColors.border.withValues(alpha: 0.7);
    final double borderWidth = (_isHovered && !widget.isEditMode) ? 1.5 : 1.0;

final cardContent = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.cardBackground, // Fallback
            gradient: LinearGradient(
              colors: [
                 mode.color.withValues(alpha: 0.15), // Subtle tint of mode color
                 AppColors.cardBackground.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              )
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header: Icon + "Sincro Flow"
                    Row(
                      children: [
                        Icon(mode.icon, color: mode.color, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          "Sincro Flow",
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (!widget.isEditMode)
                          const Icon(Icons.info_outline,
                              color: AppColors.tertiaryText, size: 16),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main Content: Mode Title & Methodology
                    Text(
                      mode.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: mode.color,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: mode.color.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.recommendation.methodologyName,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.recommendation.reason,
                      style: const TextStyle(
                        color: AppColors.tertiaryText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                    // Divider if there are AI Suggestions
                    if (widget.recommendation.aiSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Divider(color: AppColors.border.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: "Sugestões do Dia (IA)",
                        items: widget.recommendation.aiSuggestions.take(2).toList(), // Show only 2 on card
                        color: AppColors.primary,
                      ),
                      if (widget.recommendation.aiSuggestions.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "+ ${widget.recommendation.aiSuggestions.length - 2} sugestões...",
                            style: const TextStyle(
                              color: AppColors.tertiaryText,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (widget.dragHandle != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: widget.dragHandle!,
                ),
            ],
          ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null && !widget.isEditMode
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: widget.isEditMode
              ? null
              : (widget.onTap ?? () => _showTipsDialog(context)),
          borderRadius: BorderRadius.circular(16.0),
          splashColor: mode.color.withValues(alpha: 0.1),
          highlightColor: mode.color.withValues(alpha: 0.1),
          hoverColor: Colors.transparent,
          child: cardContent,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Icon(Icons.auto_awesome, // Changed icon for AI
                        color: color.withValues(alpha: 0.6), size: 10),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  void _showTipsDialog(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => StrategyDetailModal(
          recommendation: widget.recommendation,
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StrategyDetailModal(
            recommendation: widget.recommendation,
          ),
        ),
      );
    }
  }
}
