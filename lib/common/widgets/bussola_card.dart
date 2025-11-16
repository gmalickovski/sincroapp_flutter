// lib/common/widgets/bussola_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

class BussolaCard extends StatefulWidget {
  final BussolaContent bussolaContent;
  final VoidCallback? onTap;
  final bool isEditMode;
  final Widget? dragHandle;

  const BussolaCard({
    super.key,
    required this.bussolaContent,
    this.onTap,
    this.isEditMode = false,
    this.dragHandle,
  });

  @override
  State<BussolaCard> createState() => _BussolaCardState();
}

class _BussolaCardState extends State<BussolaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Animated purple border like GoalCard
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
            // Keep a subtle constant shadow
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
                // *** PADDING INTERNO AJUSTADO PARA 20.0 ***
                padding: const EdgeInsets.all(20.0),
                child: _buildLayout(),
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

  // *** LAYOUT UNIFICADO, REMOVENDO A LÓGICA MOBILE/DESKTOP DESNECESSÁRIA ***
  Widget _buildLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize
          .min, // Permite que a altura do card se ajuste ao conteúdo
      children: [
        const Row(children: [
          Icon(Icons.explore_outlined, // Ícone atualizado para consistência
              color: AppColors.primaryAccent,
              size: 24),
          SizedBox(width: 12),
          Text("Bússola de Atividades",
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
        const SizedBox(height: 24),
        _buildBussolaSection(
            title: "Potencializar",
            items: widget.bussolaContent.potencializar,
            color: Colors.green.shade300),
        const SizedBox(height: 24),
        _buildBussolaSection(
            title: "Atenção",
            items: widget.bussolaContent.atencao,
            color: Colors.red.shade300),
      ],
    );
  }

  Widget _buildBussolaSection(
      {required String title,
      required List<String> items,
      required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0),
                        child: Icon(Icons.circle,
                            color: color.withValues(alpha: 0.5), size: 8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(item,
                              style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 13,
                                  height: 1.4))),
                    ],
                  ),
                ))
            ,
      ],
    );
  }
}
