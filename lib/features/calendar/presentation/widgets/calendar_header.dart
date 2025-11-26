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

  const CalendarHeader({
    super.key,
    required this.focusedDay,
    required this.onTodayButtonTap,
    required this.onLeftArrowTap,
    required this.onRightArrowTap,
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
                    final shortFormat = DateFormat('MMM yyyy', 'pt_BR');
                    
                    final fullText = toBeginningOfSentenceCase(fullFormat.format(focusedDay))!;
                    final shortText = toBeginningOfSentenceCase(shortFormat.format(focusedDay))!;

                    // Check if full text fits
                    final textPainter = TextPainter(
                      text: TextSpan(
                        text: fullText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24, // Tenta manter 24 se couber
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      maxLines: 1,
                      textDirection: ui.TextDirection.ltr,
                    );
                    
                    textPainter.layout(maxWidth: constraints.maxWidth);

                    final useShort = textPainter.didExceedMaxLines;
                    
                    // Se usar short, podemos manter 24 ou reduzir para 20 se ainda assim ficar apertado?
                    // O usuário pediu "diminuir um pouco a fonte" no request anterior, mas agora pediu "automático".
                    // Vamos tentar: Se full cabe -> 24. Se não -> Short com 24. 
                    // Se Short não couber (muito raro), o Text vai quebrar ou elipsar, mas "Nov. 2025" é bem curto.
                    
                    return Text(
                      useShort ? shortText : fullText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: useShort ? 24 : 24, // Mantém 24 para consistência, ou 20 se preferir
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
