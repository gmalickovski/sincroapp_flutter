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

  final bool isCompact;

  const CalendarHeader({
    super.key,
    required this.focusedDay,
    required this.onTodayButtonTap,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fullFormat = DateFormat('MMMM yyyy', 'pt_BR');
                    // Formato curto: "Nov. 2025"
                    // DateFormat('MMM', 'pt_BR') retorna "nov." (com ponto)
                    // Então construímos manualmente para garantir o formato desejado
                    final monthShort = toBeginningOfSentenceCase(DateFormat('MMM', 'pt_BR').format(focusedDay))!;
                    final year = DateFormat('yyyy').format(focusedDay);
                    final shortText = "$monthShort $year";
                    
                    final fullText = toBeginningOfSentenceCase(fullFormat.format(focusedDay))!;

                    // Define o tamanho da fonte com base no modo (Mobile vs Desktop)
                    final double fontSize = isCompact ? 20.0 : 24.0;

                    // Check if full text fits
                    final textPainter = TextPainter(
                      text: TextSpan(
                        text: fullText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      maxLines: 1,
                      textDirection: ui.TextDirection.ltr,
                      textScaler: MediaQuery.of(context).textScaler, // Importante para precisão
                    );
                    
                    textPainter.layout(maxWidth: constraints.maxWidth);

                    // Verifica se a largura do texto excede a largura disponível
                    final useShort = textPainter.width > constraints.maxWidth;
                    
                    return Text(
                      useShort ? shortText : fullText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: AppColors.secondaryText),
                    onPressed: onLeftArrowTap,
                  ),
                  TextButton(
                    onPressed: onTodayButtonTap,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryText,
                      backgroundColor: AppColors.cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Hoje'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: AppColors.secondaryText),
                    onPressed: onRightArrowTap,
                  ),
                ],
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
