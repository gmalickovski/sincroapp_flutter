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

  Widget _buildDescriptionRich(String text) {
    const baseStyle = TextStyle(
      color: AppColors.tertiaryText,
      fontSize: 14,
      height: 1.4,
    );

    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final widgets = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trim();

      // Detectar linha de intervalo destacado para textos de ciclos/desafios/momentos
      // Verifica se contém padrões de idade (números seguidos de "anos", "a", "até", etc.)
      // ou padrões de anos completos (2019 a 2028)
      final isIntervaloDestacado =
          RegExp(r'^\d+\s+a\s+\d+\s+anos$').hasMatch(line) || // "29 a 56 anos"
              RegExp(r'^\d{4}\s+a\s+\d{4}$').hasMatch(line) || // "2019 a 2028"
              RegExp(r'^\d{4}\s+a\s+XXXX$').hasMatch(line) || // "2028 a XXXX"
              RegExp(r'^nascimento até \d+\s+anos$')
                  .hasMatch(line) || // "nascimento até 36 anos"
              RegExp(r'^até \d+\s+anos$').hasMatch(line) || // "até 36 anos"
              RegExp(r'^a partir de \d+\s+anos$')
                  .hasMatch(line) || // "a partir de 55 anos"
              RegExp(r'^\d+\s+anos em diante$')
                  .hasMatch(line); // "57 anos em diante"

      if (isIntervaloDestacado) {
        // Espaçamento maior antes do intervalo para separar do texto acima
        widgets.add(const SizedBox(height: 12));

        // Container com destaque sutil para o período
        widgets.add(
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: AppColors.primaryAccent.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.primaryAccent.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  line,
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryAccent,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Linha normal com ou sem número em negrito
        final match = RegExp(r'^(\d+):\s*(.*)$').firstMatch(line);
        if (match != null) {
          final num = match.group(1)!;
          final rest = match.group(2)!;
          widgets.add(
            RichText(
              text: TextSpan(style: baseStyle, children: [
                TextSpan(
                  text: '$num: ',
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
                TextSpan(text: rest),
              ]),
            ),
          );
        } else {
          widgets.add(Text(line, style: baseStyle));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.info.tituloTradicional ?? widget.info.titulo;

    // Compute animated border like GoalCard (purple on hover)
    final Color borderColor = (_isHovered && !widget.isEditMode)
        ? AppColors.primary.withValues(alpha: 0.8)
        : AppColors.border.withValues(alpha: 0.7);
    final double borderWidth = (_isHovered && !widget.isEditMode) ? 1.5 : 1.0;

    final cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: borderColor, width: borderWidth),
            // Hover effect now uses only the border; keep a subtle, constant shadow
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
                    Shadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 15)
                  ])),
          Container(
              height: 60,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                AppColors.primaryAccent.withValues(alpha: 0.0),
                AppColors.primaryAccent.withValues(alpha: 0.3),
                AppColors.primaryAccent.withValues(alpha: 0.0)
              ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(displayTitle,
                    style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                _buildDescriptionRich(widget.info.descricaoCurta),
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
              // Detecta se a tag é um período (anos: "1991 a 2017", "até 36 anos", etc.)
              final isPeriodTag = RegExp(
                      r'\d{4}\s+a\s+\d{4}|\d{4}\s+a\s+XXXX|nascimento até|até \d+|a partir de \d+|\d+ a \d+ anos')
                  .hasMatch(tag);

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                        color: AppColors.primaryAccent.withValues(alpha: 0.3))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPeriodTag) ...[
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xffe9d5ff),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(tag,
                        style: const TextStyle(
                            color: Color(0xffe9d5ff),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
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
                    Shadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 15)
                  ],
                ),
              ),
              Container(
                  height: 60,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20.0),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                    AppColors.primaryAccent.withValues(alpha: 0.0),
                    AppColors.primaryAccent.withValues(alpha: 0.3),
                    AppColors.primaryAccent.withValues(alpha: 0.0)
                  ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayTitle,
                        style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    _buildDescriptionRich(widget.info.descricaoCurta),
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
              // Detecta se a tag é um período (anos: "1991 a 2017", "até 36 anos", etc.)
              final isPeriodTag = RegExp(
                      r'\d{4}\s+a\s+\d{4}|\d{4}\s+a\s+XXXX|nascimento até|até \d+|a partir de \d+|\d+ a \d+ anos')
                  .hasMatch(tag);

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                        color: AppColors.primaryAccent.withValues(alpha: 0.3))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPeriodTag) ...[
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xffe9d5ff),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(tag,
                        style: const TextStyle(
                            color: Color(0xffe9d5ff),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
