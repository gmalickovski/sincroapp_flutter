// =========================================================================
// PASSO CRÍTICO: ESTA É A LINHA QUE RESOLVE O ERRO.
// ELA DEVE SER A PRIMEIRA LINHA DO ARQUIVO.
import 'dart:ui';
// =========================================================================

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

class BussolaCard extends StatefulWidget {
  final BussolaContent bussolaContent;
  final VoidCallback? onTap;
  final bool isEditMode;

  const BussolaCard({
    super.key,
    required this.bussolaContent,
    this.onTap,
    this.isEditMode = false,
  });

  @override
  State<BussolaCard> createState() => _BussolaCardState();
}

class _BussolaCardState extends State<BussolaCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:
                      MainAxisSize.min, // Chave para altura flexível no mobile
                  children: [
                    const Row(children: [
                      Icon(Icons.compass_calibration,
                          color: AppColors.primaryAccent, size: 24),
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
                ),
              ),
              if (widget.isEditMode)
                MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(Icons.drag_indicator,
                        color: AppColors.secondaryText, size: 24),
                  ),
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
                            color: color.withOpacity(0.5), size: 8),
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
            .toList(),
      ],
    );
  }
}
