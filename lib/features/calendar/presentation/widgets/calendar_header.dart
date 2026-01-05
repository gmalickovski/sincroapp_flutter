// lib/features/calendar/presentation/widgets/calendar_header.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class CalendarHeader extends StatelessWidget {
  final DateTime focusedDay;
  final VoidCallback onTodayButtonTap;
  final VoidCallback onLeftArrowTap;
  final VoidCallback onRightArrowTap;

  final bool isDesktop; // Nova propriedade
  final bool isCompact; // Propriedade faltante restaurada

  const CalendarHeader({
    super.key,
    required this.focusedDay,
    required this.onTodayButtonTap,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
    this.isCompact = false,
    this.isDesktop = false, // Default false
  });

  @override
  Widget build(BuildContext context) {
    final fullFormat = DateFormat('MMMM yyyy', 'pt_BR');
    final titleText = toBeginningOfSentenceCase(fullFormat.format(focusedDay));
    // Tamanho da fonte: Desktop = 24 (igual ao painel), Mobile = 16/18
    final double fontSize = isDesktop ? 24.0 : (isCompact ? 16.0 : 18.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: isDesktop 
              // --- LAYOUT DESKTOP ---
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Título Alinhado à Esquerda + Dropdown + Hoje
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titleText ?? '',
                          style: TextStyle(
                            color: Colors.white, // Título branco no desktop (fundo escuro)
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                         const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.secondaryText,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                         TextButton(
                          onPressed: onTodayButtonTap,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Hoje', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ],
                    ),

                    // Setas à Direita
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: onLeftArrowTap,
                          iconSize: 28,
                          splashRadius: 24,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white),
                          onPressed: onRightArrowTap,
                          iconSize: 28,
                          splashRadius: 24,
                           constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                )
              // --- LAYOUT MOBILE (Original) ---
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.primaryText),
                      onPressed: onLeftArrowTap,
                      iconSize: 24,
                      splashRadius: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Flexible(
                             child: Text(
                              titleText ?? '',
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                           ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.secondaryText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: onTodayButtonTap,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Hoje', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.primaryText),
                      onPressed: onRightArrowTap,
                      iconSize: 24,
                      splashRadius: 24,
                      padding: EdgeInsets.zero,
                       constraints: const BoxConstraints(),
                    ),
                  ],
                ),
        ),
        _buildDaysOfWeekHeader(),
      ],
    );
  }

  Widget _buildDaysOfWeekHeader() {
    final days = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return Row(
      children: days
          .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: AppColors.tertiaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
