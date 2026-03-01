import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class InlineMonthYearSelector extends StatefulWidget {
  final DateTime focusedDay;
  final ValueChanged<DateTime> onDateChanged;

  const InlineMonthYearSelector({
    super.key,
    required this.focusedDay,
    required this.onDateChanged,
  });

  @override
  State<InlineMonthYearSelector> createState() =>
      _InlineMonthYearSelectorState();
}

class _InlineMonthYearSelectorState extends State<InlineMonthYearSelector> {
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  final List<String> _months = [
    "JANEIRO",
    "FEVEREIRO",
    "MARÇO",
    "ABRIL",
    "MAIO",
    "JUNHO",
    "JULHO",
    "AGOSTO",
    "SETEMBRO",
    "OUTUBRO",
    "NOVEMBRO",
    "DEZEMBRO"
  ];

  late List<int> _years;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _years = List.generate(41, (index) => currentYear - 20 + index);

    _monthController =
        FixedExtentScrollController(initialItem: widget.focusedDay.month - 1);

    int yearIndex = _years.indexOf(widget.focusedDay.year);
    if (yearIndex == -1) yearIndex = 20;

    _yearController = FixedExtentScrollController(initialItem: yearIndex);
  }

  @override
  void didUpdateWidget(InlineMonthYearSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedDay != oldWidget.focusedDay) {
      final targetMonthIndex = widget.focusedDay.month - 1;
      if (_monthController.selectedItem != targetMonthIndex) {
        _monthController.animateToItem(targetMonthIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      }

      final targetYearIndex = _years.indexOf(widget.focusedDay.year);
      if (targetYearIndex != -1 &&
          _yearController.selectedItem != targetYearIndex) {
        _yearController.animateToItem(targetYearIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      }
    }
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _scrollMonth(int delta) {
    final newIndex = _monthController.selectedItem + delta;
    if (newIndex >= 0 && newIndex < _months.length) {
      _monthController.animateToItem(
        newIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollYear(int delta) {
    final newIndex = _yearController.selectedItem + delta;
    if (newIndex >= 0 && newIndex < _years.length) {
      _yearController.animateToItem(
        newIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Row(
        children: [
          // Months
          Expanded(
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up,
                      color: AppColors.secondaryText),
                  onPressed: () => _scrollMonth(-1),
                  tooltip: 'Mês anterior',
                ),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 40,
                    perspective: 0.005,
                    physics: const FixedExtentScrollPhysics(),
                    controller: _monthController,
                    onSelectedItemChanged: (index) {
                      final newMonth = index + 1;
                      if (newMonth != widget.focusedDay.month) {
                        widget.onDateChanged(
                            DateTime(widget.focusedDay.year, newMonth, 1));
                      }
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _months.length,
                      builder: (context, index) {
                        final isSelected =
                            (index + 1) == widget.focusedDay.month;
                        return Center(
                          child: Text(
                            _months[index],
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.secondaryText,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: isSelected ? 18 : 16,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.secondaryText),
                  onPressed: () => _scrollMonth(1),
                  tooltip: 'Próximo mês',
                ),
              ],
            ),
          ),

          // Years
          Expanded(
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up,
                      color: AppColors.secondaryText),
                  onPressed: () => _scrollYear(-1),
                  tooltip: 'Ano anterior',
                ),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 40,
                    perspective: 0.005,
                    physics: const FixedExtentScrollPhysics(),
                    controller: _yearController,
                    onSelectedItemChanged: (index) {
                      final newYear = _years[index];
                      if (newYear != widget.focusedDay.year) {
                        widget.onDateChanged(
                            DateTime(newYear, widget.focusedDay.month, 1));
                      }
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _years.length,
                      builder: (context, index) {
                        final year = _years[index];
                        final isSelected = year == widget.focusedDay.year;
                        return Center(
                          child: Text(
                            "$year",
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.secondaryText,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: isSelected ? 18 : 16,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.secondaryText),
                  onPressed: () => _scrollYear(1),
                  tooltip: 'Próximo ano',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
