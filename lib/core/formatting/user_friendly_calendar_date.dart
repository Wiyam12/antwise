/// Long-form calendar date for user-visible assistant replies.
///
/// Style: September 12, 2026 (full month name, day without leading zero, 4-digit year).
String formatUserFriendlyCalendarDate(DateTime local) {
  final DateTime d = DateTime(local.year, local.month, local.day);
  if (d.month < 1 || d.month > 12) {
    return '${d.year}';
  }
  const List<String> months = <String>[
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[d.month]} ${d.day}, ${d.year}';
}
