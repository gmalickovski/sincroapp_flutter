import 'package:intl/intl.dart';

enum RecurrenceType { none, daily, weekly, monthly }

class RecurrenceRule {
  final RecurrenceType type;
  final List<int> daysOfWeek;
  final DateTime? endDate;

  RecurrenceRule({
    this.type = RecurrenceType.none,
    this.daysOfWeek = const [],
    this.endDate,
  });

  RecurrenceRule copyWith({
    RecurrenceType? type,
    List<int>? daysOfWeek,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      daysOfWeek: daysOfWeek ?? List.from(this.daysOfWeek),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  String getSummaryText() {
    String summary;
    switch (type) {
      case RecurrenceType.none:
        return "Nunca";
      case RecurrenceType.daily:
        summary = "Diariamente";
        break;
      case RecurrenceType.weekly:
        final Set<int> daysSet = daysOfWeek.toSet();
        if (daysSet.isEmpty) {
          summary = "Semanalmente";
        } else if (daysSet.length == 7) {
          summary = "Diariamente";
        } else if (daysSet.length == 5 &&
            !daysSet.contains(DateTime.saturday) &&
            !daysSet.contains(DateTime.sunday)) {
          summary = "Dias da semana";
        } else if (daysSet.isNotEmpty) {
          final sortedDays = List<int>.from(daysSet)
            ..sort((a, b) {
              if (a == DateTime.sunday) return 1;
              if (b == DateTime.sunday) return -1;
              return a.compareTo(b);
            });
          final dayNames =
              sortedDays.map((d) => _getDayAbbreviation(d)).join(', ');
          summary = "Semanal ($dayNames)";
        } else {
          summary = "Semanalmente";
        }
        break;
      case RecurrenceType.monthly:
        summary = "Mensalmente";
        break;
    }

    if (endDate != null) {
      final formattedDate = DateFormat.yMd('pt_BR').format(endDate!);
      summary += ", até $formattedDate";
    }

    return summary;
  }

  static String _getDayAbbreviation(int day) {
    DateTime refDate = DateTime.now();
    while (refDate.weekday != day) {
      refDate = refDate.add(const Duration(days: 1));
    }
    return DateFormat('E', 'pt_BR').format(refDate);
  }
}
