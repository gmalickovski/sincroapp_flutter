// lib/features/calendar/presentation/widgets/calendar_header.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
                child: Text(
                  toBeginningOfSentenceCase(
                      DateFormat.yMMMM('pt_BR').format(focusedDay))!,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
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
