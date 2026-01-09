/// Helper for calculating period keys and date ranges for challenges
/// All functions are pure (no side effects)
class PeriodHelper {
  /// Calcula la clave de periodo para la semana actual (formato ISO: YYYY-Www)
  /// La semana comienza en LUNES (ISO 8601)
  static String currentWeekPeriodKey(DateTime now) {
    // Para ISO weeks, el año puede ser diferente al año calendario (e.g. 29 Dic 2025 puede ser Week 1 2026)
    final isoWeek = _getISOWeekInfo(now);
    return '${isoWeek.year}-W${isoWeek.weekNumber.toString().padLeft(2, '0')}';
  }

  /// Calcula la clave de periodo para el mes actual (formato: YYYY-MM)
  static String currentMonthPeriodKey(DateTime now) {
    final year = now.year;
    final month = now.month;
    return '${year}-${month.toString().padLeft(2, '0')}';
  }

  /// Obtiene el inicio de la semana (lunes a las 00:00:00)
  static DateTime getWeekStart(DateTime date) {
    // DateTime.weekday: Monday = 1, Sunday = 7
    final daysToSubtract = date.weekday - 1; // 0 for Monday, 6 for Sunday
    final monday = date.subtract(Duration(days: daysToSubtract));
    return DateTime(monday.year, monday.month, monday.day, 0, 0, 0, 0, 0);
  }

  /// Obtiene el fin de la semana (domingo a las 23:59:59.999)
  /// EXCLUSIVE: el próximo lunes a las 00:00:00
  /// (Para queries Firestore: use < endAt para incluir todo el domingo)
  static DateTime getWeekEnd(DateTime date) {
    final weekStart = getWeekStart(date);
    // Add 7 days to get to next Monday 00:00:00 (exclusive end)
    return weekStart.add(const Duration(days: 7));
  }

  /// Obtiene el inicio del mes (día 1 a las 00:00:00)
  static DateTime getMonthStart(DateTime date) {
    return DateTime(date.year, date.month, 1, 0, 0, 0, 0, 0);
  }

  /// Obtiene el fin del mes (último día a las 23:59:59.999)
  /// EXCLUSIVE: primer día del siguiente mes a las 00:00:00
  static DateTime getMonthEnd(DateTime date) {
    // Get first day of next month
    final nextMonth = date.month == 12 
        ? DateTime(date.year + 1, 1, 1, 0, 0, 0, 0, 0)
        : DateTime(date.year, date.month + 1, 1, 0, 0, 0, 0, 0);
    return nextMonth;
  }

  /// Calcula el número de semana ISO 8601 (1-53)
  /// Week 1 is the first week with a Thursday
  /// Retorna info de año y semana ISO 8601
  static ({int year, int weekNumber}) _getISOWeekInfo(DateTime date) {
    // Algoritmo: La semana 1 es la que tiene el primer jueves del año.
    // 1. Encontrar el jueves de la semana actual
    // Monday=1 ... Sunday=7 -> Thursday=4
    final dayOfWeek = date.weekday;
    final thursdayOfThisWeek = date.add(Duration(days: 4 - dayOfWeek));

    // 2. El año de la semana ISO es el año de ese jueves
    final isoYear = thursdayOfThisWeek.year;

    // 3. La semana 1 de ese año comienza el lunes de la semana que contiene el 4 de enero
    // O simplificado: calcular ordinal date del jueves y dividir por 7
    final firstJan = DateTime(isoYear, 1, 1);
    final daysOffset = firstJan.weekday <= 4 ? firstJan.weekday - 1 : firstJan.weekday - 1 - 7;
    // Si 1 Ene es Lu-Ju, semana 1 empieza el Lunes de esa semana.
    // Si 1 Ene es Vi-Do, semana 1 empieza el Lunes de la SIGUIENTE semana.
    // Pero es más fácil: calcular dayOfYear del jueves.
    
    final dayOfYear = int.parse(
      '${thursdayOfThisWeek.difference(DateTime(isoYear, 1, 1)).inDays + 1}'
    );
    
    final weekNumber = ((dayOfYear - 1) / 7).floor() + 1;
    
    return (year: isoYear, weekNumber: weekNumber);
  }

  /// Genera un docId determinista para un challenge automático
  /// Format: tmpl__<templateId>__<periodKey>
  static String generateChallengeDeterministicId(
    String templateId,
    String periodKey,
  ) {
    return 'tmpl__${templateId}__$periodKey';
  }
}

