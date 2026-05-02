/// Shared math for card-widget grids (settings preview + runtime layout rules).
///
/// **Rule 1 — 2 columns:** If [widgetCount] is odd, the last widget spans full width.
/// **Rule 2 — 3 columns:** The last row fills leftover columns by expanding the last
/// widget only (`rem == 2`: previous slot stays one column wide; last spans the rest).
List<double> computeCardWidgetWrapSlotWidths({
  required double maxWidth,
  required double spacing,
  required int gridCount,
  required int widgetCount,
}) {
  final int n = widgetCount;
  if (n <= 0) {
    return <double>[];
  }
  final int k = gridCount.clamp(1, 3);
  if (k == 1) {
    return List<double>.filled(n, maxWidth);
  }
  if (k == 2) {
    final double half = (maxWidth - spacing) / 2;
    if (n.isEven) {
      return List<double>.filled(n, half);
    }
    return List<double>.generate(
      n,
      (int i) => i == n - 1 ? maxWidth : half,
    );
  }
  // k == 3
  final double unit = (maxWidth - 2 * spacing) / 3;
  final int rem = n % 3;
  if (rem == 0) {
    return List<double>.filled(n, unit);
  }
  final List<double> out = List<double>.filled(n, unit);
  final int startLast = n - rem;
  if (rem == 1) {
    out[n - 1] = maxWidth;
  } else {
    out[startLast] = unit;
    out[n - 1] = maxWidth - unit - spacing;
  }
  return out;
}
