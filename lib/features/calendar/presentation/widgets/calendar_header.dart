// lib/features/calendar/presentation/widgets/calendar_header.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:table_calendar/table_calendar.dart';

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
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                toBeginningOfSentenceCase(
                    DateFormat.yMMMM('pt_BR').format(focusedDay))!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: onLeftArrowTap,
                  ),
                  TextButton(
                    onPressed: onTodayButtonTap,
                    child: const Text('Hoje',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
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
