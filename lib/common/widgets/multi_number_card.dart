// lib/common/widgets/multi_number_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

/// Card especializado para exibir múltiplos números com textos individuais
/// Usado para: Lições Kármicas, Débitos Kármicos, Tendências Ocultas
class MultiNumberCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<int> numbers; // Lista de números para exibir
  final VibrationContent info; // Contém descrição completa para modal
  final Map<int, String> numberTexts; // Texto curto por número
  final Map<int, String>
      numberTitles; // Título por número (ex.: "Lição Kármica 1")
  final Color color;
  final VoidCallback? onTap;
  final bool isEditMode;
  final Widget? dragHandle;
  final bool isDesktopLayout;

  const MultiNumberCard({
    super.key,
    required this.title,
    required this.icon,
    required this.numbers,
    required this.info,
    required this.numberTexts,
    required this.numberTitles,
    this.color = AppColors.primaryAccent,
    this.onTap,
    this.isEditMode = false,
    this.dragHandle,
    this.isDesktopLayout = false,
  });

  @override
  State<MultiNumberCard> createState() => _MultiNumberCardState();
}

class _MultiNumberCardState extends State<MultiNumberCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.info.tituloTradicional ?? widget.info.titulo;

    final Color borderColor = (_isHovered && !widget.isEditMode)
        ? AppColors.primary.withValues(alpha: 0.8)
        : AppColors.border.withValues(alpha: 0.7);
    final double borderWidth = (_isHovered && !widget.isEditMode) ? 1.5 : 1.0;

final cardContent = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withValues(alpha: 0.95),
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
                child: widget.isDesktopLayout
                    ? _buildDesktopLayout(displayTitle)
                    : _buildMobileLayout(displayTitle),
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
          onTap: widget.isEditMode ? null : widget.onTap,
          borderRadius: BorderRadius.circular(16.0),
          splashColor: AppColors.primaryAccent.withValues(alpha: 0.1),
          highlightColor: AppColors.primaryAccent.withValues(alpha: 0.1),
          hoverColor: Colors.transparent,
          child: cardContent,
        ),
      ),
    );
  }

  Widget _buildMobileLayout(String displayTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabeçalho
        Row(children: [
          Icon(widget.icon, color: AppColors.primaryAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // Lista de números com textos
        ...widget.numbers.map((number) => _buildNumberRow(number)),

        // Tags
        if (widget.info.tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: widget.info.tags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                      color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Color(0xffe9d5ff),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout(String displayTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho
        Row(
          children: [
            Icon(widget.icon, color: AppColors.primaryAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Lista de números com textos (área expansível)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: widget.numbers
                  .map((number) => _buildNumberRow(number))
                  .toList(),
            ),
          ),
        ),

        // Tags
        if (widget.info.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: widget.info.tags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                      color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Color(0xffe9d5ff),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildNumberRow(int number) {
    final text = widget.numberTexts[number] ?? '';
    final title = widget.numberTitles[number] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número grande
          Text(
            number.toString(),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: widget.color,
              height: 1,
              shadows: [
                Shadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 15)
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Divisor vertical
          Container(
            height: 48,
            width: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryAccent.withValues(alpha: 0.0),
                  AppColors.primaryAccent.withValues(alpha: 0.3),
                  AppColors.primaryAccent.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Texto ao lado
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.tertiaryText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
