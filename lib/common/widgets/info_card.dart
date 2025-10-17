// lib/common/widgets/info_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

class InfoCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String number;
  final VibrationContent info;
  final Color color;
  final VoidCallback? onTap;
  final bool isEditMode;
  final Widget? dragHandle;
  final bool isDesktopLayout;

  const InfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.number,
    required this.info,
    this.color = AppColors.primaryAccent,
    this.onTap,
    this.isEditMode = false,
    this.dragHandle,
    this.isDesktopLayout = false,
  });

  @override
  State<InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<InfoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.info.tituloTradicional ?? widget.info.titulo;

    final cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
            boxShadow: [
              if (_isHovered && !widget.isEditMode)
                BoxShadow(
                  color: AppColors.primaryAccent.withOpacity(0.6),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
            ],
          ),
          child: Stack(
            children: [
              Padding(
                // *** PADDING INTERNO REDUZIDO PARA MELHOR LAYOUT ***
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
        ),
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
          splashColor: AppColors.primaryAccent.withOpacity(0.1),
          highlightColor: AppColors.primaryAccent.withOpacity(0.1),
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
        Row(children: [
          Icon(widget.icon, color: AppColors.primaryAccent, size: 24),
          const SizedBox(width: 12),
          Text(widget.title,
              style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(widget.number,
              style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                  height: 1,
                  shadows: [
                    Shadow(color: widget.color.withOpacity(0.5), blurRadius: 15)
                  ])),
          Container(
              height: 60,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                AppColors.primaryAccent.withOpacity(0.0),
                AppColors.primaryAccent.withOpacity(0.3),
                AppColors.primaryAccent.withOpacity(0.0)
              ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(displayTitle,
                    style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(widget.info.descricaoCurta,
                    style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                        height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
        if (widget.info.tags.isNotEmpty) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: widget.info.tags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                        color: AppColors.primaryAccent.withOpacity(0.3))),
                child: Text(tag,
                    style: const TextStyle(
                        color: Color(0xffe9d5ff),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
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
        Row(
          children: [
            Icon(widget.icon, color: AppColors.primaryAccent, size: 24),
            const SizedBox(width: 12),
            Text(widget.title,
                style: const TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        Expanded(
          child: Center(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(
                widget.number,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                  height: 1,
                  shadows: [
                    Shadow(color: widget.color.withOpacity(0.5), blurRadius: 15)
                  ],
                ),
              ),
              Container(
                  height: 60,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20.0),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                    AppColors.primaryAccent.withOpacity(0.0),
                    AppColors.primaryAccent.withOpacity(0.3),
                    AppColors.primaryAccent.withOpacity(0.0)
                  ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayTitle,
                        style: const TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(widget.info.descricaoCurta,
                        style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 14,
                            height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
          ),
        ),
        if (widget.info.tags.isNotEmpty)
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: widget.info.tags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                        color: AppColors.primaryAccent.withOpacity(0.3))),
                child: Text(tag,
                    style: const TextStyle(
                        color: Color(0xffe9d5ff),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
      ],
    );
  }
}
