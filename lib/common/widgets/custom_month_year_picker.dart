import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

enum _PickerMode { month, year }

class CustomMonthYearPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const CustomMonthYearPicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<CustomMonthYearPicker> createState() => _CustomMonthYearPickerState();
}

class _CustomMonthYearPickerState extends State<CustomMonthYearPicker> {
  late DateTime _selectedDate;
  _PickerMode _mode = _PickerMode.month;

  // For Year Pagination (viewing a page of years)
  late int _yearPageStart;
  static const int _yearsPerPage = 12;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    // Align year page to the selected year
    _yearPageStart = (_selectedDate.year ~/ _yearsPerPage) * _yearsPerPage;
  }

  void _handleMonthChanged(int month) {
    setState(() {
      // Clamp day to max days in new month
      final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, month);
      int day = _selectedDate.day;
      if (day > daysInMonth) day = daysInMonth;

      _selectedDate = DateTime(_selectedDate.year, month, day);
    });
  }

  void _handleYearChanged(int year) {
    setState(() {
      final daysInMonth = DateUtils.getDaysInMonth(year, _selectedDate.month);
      int day = _selectedDate.day;
      if (day > daysInMonth) day = daysInMonth;

      _selectedDate = DateTime(year, _selectedDate.month, day);
      // Optional: Switch back to month? Or stay in year?
      // Keeping user in year mode is safer for browsing.

      // Update page if jumped
      _yearPageStart = (year ~/ _yearsPerPage) * _yearsPerPage;
      _mode = _PickerMode
          .month; // Auto-switch back to month often feels natural after picking year
    });
  }

  void _changeYearPage(int delta) {
    setState(() {
      _yearPageStart += (delta * _yearsPerPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildDisplay(),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _mode == _PickerMode.month
                    ? _buildMonthGrid()
                    : _buildYearGrid(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.secondaryText),
          onPressed: () => Navigator.pop(context),
        ),
        const Text(
          "Selecione Mês e Ano",
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check, color: AppColors.primary),
          onPressed: () => Navigator.pop(context, _selectedDate),
        ),
      ],
    );
  }

  Widget _buildDisplay() {
    final monthStr =
        DateFormat('MMM', 'pt_BR').format(_selectedDate).toUpperCase();
    final yearStr = DateFormat('yyyy').format(_selectedDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDisplayItem(
          text: monthStr,
          isSelected: _mode == _PickerMode.month,
          onTap: () => setState(() => _mode = _PickerMode.month),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            "/",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText.withValues(alpha: 0.4),
            ),
          ),
        ),
        _buildDisplayItem(
          text: yearStr,
          isSelected: _mode == _PickerMode.year,
          onTap: () => setState(() {
            _mode = _PickerMode.year;
            // Ensure page matches current year when switching
            _yearPageStart =
                (_selectedDate.year ~/ _yearsPerPage) * _yearsPerPage;
          }),
        ),
      ],
    );
  }

  Widget _buildDisplayItem(
      {required String text,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primary : AppColors.primaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid() {
    return GridView.builder(
      key: const ValueKey('OffsetMonthGrid'),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final monthIndex = index + 1;
        final monthName = DateFormat('MMM', 'pt_BR')
            .format(DateTime(2000, monthIndex))
            .toUpperCase();
        final isSelected = _selectedDate.month == monthIndex;

        return _buildGridItem(
            label: monthName,
            isSelected: isSelected,
            onTap: () => _handleMonthChanged(monthIndex));
      },
    );
  }

  Widget _buildYearGrid() {
    // Determine viewable range
    final int startYear = _yearPageStart;
    final int endYear = startYear + _yearsPerPage - 1;

    // Check bounds
    // We want to show a grid of years.

    return Column(
      key: const ValueKey('OffsetYearGrid'),
      children: [
        // Pagination Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon:
                  const Icon(Icons.chevron_left, color: AppColors.primaryText),
              onPressed: startYear > widget.firstDate.year
                  ? () => _changeYearPage(-1)
                  : null,
            ),
            Text(
              "$startYear - $endYear",
              style: const TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            IconButton(
              icon:
                  const Icon(Icons.chevron_right, color: AppColors.primaryText),
              onPressed: endYear < widget.lastDate.year
                  ? () => _changeYearPage(1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _yearsPerPage,
            itemBuilder: (context, index) {
              final year = startYear + index;
              if (year < widget.firstDate.year || year > widget.lastDate.year) {
                return const SizedBox.shrink();
              }

              final isSelected = _selectedDate.year == year;
              return _buildGridItem(
                label: year.toString(),
                isSelected: isSelected,
                onTap: () => _handleYearChanged(year),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(
      {required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.secondaryText,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
