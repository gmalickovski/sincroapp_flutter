import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';

/// A unified widget for filter popups (Mood, Vibration, Tags, etc.)
/// Uses the "Discord-style" dark theme container.
class SincroFilterSelector extends StatelessWidget {
  final String title;
  final Widget child; // The content (Grid, List, etc.)
  final VoidCallback? onClear; // Optional clear action
  final double? width;

  const SincroFilterSelector({
    super.key,
    required this.title,
    required this.child,
    this.onClear,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, // Removed default 280

      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground, // Correct Match
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                // Limpar button removed
              ],
            ),
          ),

          // Content
          child,
        ],
      ),
    );
  }

  // ─── Factory / Specialized Builders ───

  /// Creates a Mood Filter Popup
  static Widget mood({
    required int? selectedMood,
    required ValueChanged<int?> onSelected,
  }) {
    final moods = [1, 2, 3, 4, 5];

    return SincroFilterSelector(
      title: "Filtrar por Humor",
      onClear: () => onSelected(null),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // "Todos" Option (Infinity Icon)
          _buildOptionButton(
            isSelected: selectedMood == null,
            onTap: () => onSelected(null),
            child: Icon(
              Icons.all_inclusive,
              color: selectedMood == null
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            backgroundColor:
                selectedMood == null ? AppColors.primary : Colors.transparent,
            borderColor: selectedMood == null
                ? Colors.transparent
                : Colors.grey.withValues(alpha: 0.3),
          ),

          // Mood Options
          ...moods.map((mood) {
            final isSelected = selectedMood == mood;
            return _buildOptionButton(
              isSelected: isSelected,
              onTap: () => onSelected(isSelected ? null : mood),
              child: Icon(
                getMoodIcon(mood),
                color: isSelected ? Colors.white : getMoodColor(mood),
                size: 24,
              ),
              backgroundColor:
                  isSelected ? getMoodColor(mood) : Colors.transparent,
              borderColor: Colors.transparent, // No border for cleaner look
            );
          }),
        ],
      ),
    );
  }

  /// Creates a Vibration Filter Popup
  static Widget vibration({
    required int? selectedVibration,
    required ValueChanged<int?> onSelected,
  }) {
    final vibes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22];

    return SincroFilterSelector(
      title: "Filtrar por Vibração",
      // Width removed to match Mood's auto-width
      onClear: () => onSelected(null),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // "Todos" Option
          _buildOptionButton(
            isSelected: selectedVibration == null,
            onTap: () => onSelected(null),
            child: Icon(
              Icons.all_inclusive,
              color: selectedVibration == null
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            backgroundColor: selectedVibration == null
                ? AppColors.primary
                : Colors.transparent,
            borderColor: selectedVibration == null
                ? Colors.transparent
                : Colors.grey.withValues(alpha: 0.3),
          ),

          // Vibration Options
          ...vibes.map((vibe) {
            final isSelected = selectedVibration == vibe;
            final colors = getColorsForVibration(vibe);

            return _buildOptionButton(
              isSelected: isSelected,
              onTap: () => onSelected(isSelected ? null : vibe),
              child: Text(
                '$vibe',
                style: TextStyle(
                  color: isSelected ? Colors.white : colors.background,
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Increased slightly for better visibility
                ),
              ),
              backgroundColor:
                  isSelected ? colors.background : Colors.transparent,
              borderColor: isSelected ? Colors.transparent : colors.background,
            );
          }),
        ],
      ),
    );
  }

  /// Creates a Tag Filter Popup (Placeholder for Tasks/Goals)
  static Widget tags({
    required String? selectedTag,
    required List<String> availableTags,
    required ValueChanged<String?> onSelected,
  }) {
    return SincroFilterSelector(
      title: "Filtrar por Tag",
      onClear: () => onSelected(null),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // "None" Option
          _buildOptionButton(
            isSelected: selectedTag == null,
            onTap: () => onSelected(null),
            child: Icon(
              Icons.label_off,
              color: selectedTag == null
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            borderColor: selectedTag == null
                ? Colors.white
                : Colors.grey.withValues(alpha: 0.3),
          ),

          ...availableTags.map((tag) {
            final isSelected = selectedTag == tag;
            return GestureDetector(
              onTap: () => onSelected(isSelected ? null : tag),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Helper Helpers ───

  static Widget _buildOptionButton({
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.transparent,
            width: 2, // Consistent border width
          ),
        ),
        child: child,
      ),
    );
  }

  static IconData getMoodIcon(int mood) {
    switch (mood) {
      case 1:
        return Icons.sentiment_very_dissatisfied;
      case 2:
        return Icons.sentiment_dissatisfied;
      case 3:
        return Icons.sentiment_neutral; // Fixed color usage
      case 4:
        return Icons.sentiment_satisfied;
      case 5:
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  static Color getMoodColor(int mood) {
    switch (mood) {
      case 1:
        return Colors.redAccent;
      case 2:
        return Colors.orangeAccent;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }
}
