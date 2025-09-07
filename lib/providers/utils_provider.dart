/// A utility provider class for date formatting and manipulation operations.
///
/// This class provides various methods to format dates in different ways
/// and perform date calculations like finding the nearest Monday.
class UtilsProvider {
  /// Month abbreviations for formatting dates.
  /// Using a static const for better memory efficiency.
  static const List<String> _months = [
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

  /// Formats a date string into a human-readable format: "DD MMM YYYY"
  ///
  /// Example: "2024-03-15" -> "15 Mar 2024"
  ///
  /// Throws [FormatException] if the dateString is not a valid ISO 8601 format.
  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day} ${_months[date.month - 1]} ${date.year}';
    } on FormatException {
      throw FormatException('Invalid date format: $dateString');
    }
  }

  /// Formats a DateTime into "MMM DD" format.
  ///
  /// Returns 'N/A' if the date is null.
  /// Example: DateTime(2024, 3, 15) -> "Mar 15"
  static String formatMonthDay(DateTime? date) {
    if (date == null) return 'N/A';
    return '${_months[date.month - 1]} ${date.day}';
  }

  /// Formats a DateTime into ISO 8601 date format: "YYYY-MM-DD"
  ///
  /// Returns 'N/A' if the date is null.
  /// Example: DateTime(2024, 3, 5) -> "2024-03-05"
  static String formatDateForDisplay(DateTime? date) {
    if (date == null) return 'N/A';

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Finds the nearest Monday relative to the given date.
  ///
  /// Parameters:
  /// - [date]: The reference date
  /// - [allowFuture]: If true, returns the next Monday if [date] is not Monday.
  ///                  If false, returns the previous Monday if [date] is not Monday.
  ///
  /// Returns a DateTime object representing the nearest Monday with time set to midnight.
  ///
  /// Examples:
  /// - Wednesday with allowFuture=true -> Next Monday
  /// - Wednesday with allowFuture=false -> Previous Monday
  /// - Monday (regardless of allowFuture) -> Same Monday
  static DateTime getNearestMonday(DateTime date, {bool allowFuture = true}) {
    // Normalize the input date to midnight to avoid time component issues
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // If it's already Monday, return it
    if (date.weekday == DateTime.monday) {
      return normalizedDate;
    }

    if (allowFuture) {
      // Calculate days until next Monday
      final daysUntilMonday = (DateTime.monday - date.weekday + 7) % 7;
      return normalizedDate.add(Duration(days: daysUntilMonday));
    } else {
      // Calculate days since previous Monday
      final daysSinceMonday = (date.weekday - DateTime.monday) % 7;
      return normalizedDate.subtract(Duration(days: daysSinceMonday));
    }
  }

  /// Gets the start of the week (Monday) for any given date.
  ///
  /// This is a convenience method that always returns the Monday of the week
  /// containing the given date (same as getNearestMonday with allowFuture=false).
  static DateTime getWeekStart(DateTime date) {
    return UtilsProvider.getNearestMonday(date, allowFuture: false);
  }

  /// Gets the end of the week (Sunday) for any given date.
  ///
  /// Returns the Sunday that ends the week containing the given date.
  static DateTime getWeekEnd(DateTime date) {
    final weekStart = getWeekStart(date);
    return weekStart.add(const Duration(days: 6));
  }
}
