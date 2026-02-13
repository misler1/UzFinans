class PeriodUtils {
  static ({int month, int year}) defaultSelectedPeriod() {
    final now = DateTime.now();

    // Ayın 6'sı ve sonrası => filtre otomatik bir sonraki ay
    if (now.day >= 6) {
      if (now.month == 12) {
        return (month: 1, year: now.year + 1);
      } else {
        return (month: now.month + 1, year: now.year);
      }
    }
    return (month: now.month, year: now.year);
  }

  // Replit mantığı: gün >= 6 ise bir sonraki aya yaz
  static bool belongsToSelectedPeriod({
    required DateTime date,
    required int selectedMonth,
    required int selectedYear,
  }) {
    if (date.day >= 6) {
      final nextMonth = DateTime(date.year, date.month + 1, date.day);
      return nextMonth.month == selectedMonth && nextMonth.year == selectedYear;
    }
    return date.month == selectedMonth && date.year == selectedYear;
  }
}
