class UtilsProvider {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String formatDate(String dateString) {
    final date = DateTime.parse(dateString);

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String formatMonthDay(DateTime? date) {
    if (date == null) return 'N/A';
    return '${months[date.month - 1]} ${date.day}';
  }

  String formatDateForDisplay(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper function to find the nearest Monday (past or present, or future based on flag)
  DateTime getNearestMonday(DateTime date, {bool allowFuture = true}) {
    if (date.weekday == DateTime.monday) {
      return DateTime(
        date.year,
        date.month,
        date.day,
      ); // Already a Monday, normalize time
    }
    if (allowFuture) {
      return DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(days: (DateTime.monday - date.weekday + 7) % 7));
    } else {
      // Find previous Monday or today if Monday
      int daysToSubtract = (date.weekday - DateTime.monday + 7) % 7;
      return DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: daysToSubtract));
    }
  }
}
