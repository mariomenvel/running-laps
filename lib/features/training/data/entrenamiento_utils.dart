import 'package:running_laps/features/training/data/entrenamiento.dart';

/// Utilidades para el modelo Entrenamiento
/// Incluye helpers para análisis y agregación de datos
class EntrenamientoUtils {
  /// Genera la clave de semana ISO para una fecha
  /// Formato: "2025-W52" (año-W[número de semana])
  static String getWeekKey(DateTime date) {
    // Calcular semana ISO 8601
    // ISO week starts on Monday
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final firstMonday = DateTime(date.year, 1, 1);
    final firstMondayIndex = (8 - firstMonday.weekday) % 7;
    final weekNumber = ((dayOfYear - firstMondayIndex) / 7).floor() + 1;
    
    // Ajustar casos especiales (primera y última semana del año)
    int year = date.year;
    int week = weekNumber;
    
    if (week < 1) {
      // Pertenece a la última semana del año anterior
      year = date.year - 1;
      week = _getWeeksInYear(year);
    } else if (week > _getWeeksInYear(year)) {
      // Pertenece a la primera semana del año siguiente
      year = date.year + 1;
      week = 1;
    }
    
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  /// Calcula el número de semanas en un año según ISO 8601
  static int _getWeeksInYear(int year) {
    final dec28 = DateTime(year, 12, 28);
    final dayOfWeek = dec28.weekday;
    final dayOfYear = dec28.difference(DateTime(year, 1, 1)).inDays + 1;
    return ((dayOfYear - dayOfWeek + 10) / 7).floor();
  }

  /// Calcula la carga de entrenamiento (Training Load)
  /// Fórmula: RPE promedio * duración en minutos
  static double calculateLoad(Entrenamiento entrenamiento) {
    final durationMin = entrenamiento.tiempoTotalSec() / 60.0;
    final rpe = entrenamiento.rpePromedio();
    return durationMin * rpe;
  }

  /// Crea un nuevo Entrenamiento con campos de analytics calculados
  /// 
  /// Útil al guardar un entrenamiento nuevo para asegurarse de que
  /// todos los campos de analytics están populados
  static Entrenamiento withAnalyticsFields(
    Entrenamiento entrenamiento, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final loadScore = calculateLoad(entrenamiento);

    return Entrenamiento(
      id: entrenamiento.id,
      titulo: entrenamiento.titulo,
      fecha: entrenamiento.fecha,
      gps: entrenamiento.gps,
      series: entrenamiento.series,
      tags: entrenamiento.tags,
      loadScore: loadScore,
      createdAt: entrenamiento.createdAt ?? timestamp,
      updatedAt: timestamp,
    );
  }

  /// Agrupa entrenamientos por semana
  /// 
  /// Retorna mapa: weekKey -> lista de entrenamientos
  static Map<String, List<Entrenamiento>> groupByWeek(
    List<Entrenamiento> entrenamientos
  ) {
    final grouped = <String, List<Entrenamiento>>{};
    
    for (var entreno in entrenamientos) {
      final key = getWeekKey(entreno.fecha);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(entreno);
    }
    
    return grouped;
  }

  /// Agrupa entrenamientos por mes
  /// 
  /// Retorna mapa: "2025-01" -> lista de entrenamientos
  static Map<String, List<Entrenamiento>> groupByMonth(
    List<Entrenamiento> entrenamientos
  ) {
    final grouped = <String, List<Entrenamiento>>{};
    
    for (var entreno in entrenamientos) {
      final key = '${entreno.fecha.year}-${entreno.fecha.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(entreno);
    }
    
    return grouped;
  }

  /// Calcula estadísticas semanales agregadas
  static WeekStats calculateWeekStats(List<Entrenamiento> entrenamientos) {
    if (entrenamientos.isEmpty) {
      return WeekStats(
        entrenamientos: 0,
        totalKm: 0,
        totalDuration: 0,
        avgPace: 0,
        avgRPE: 0,
        totalLoad: 0,
      );
    }

    int totalMeters = 0;
    double totalSeconds = 0;
    double totalRPE = 0;
    double totalLoad = 0;

    for (var entreno in entrenamientos) {
      totalMeters += entreno.distanciaTotalM();
      totalSeconds += entreno.tiempoTotalSec();
      totalRPE += entreno.rpePromedio();
      totalLoad += entreno.loadScore ?? calculateLoad(entreno);
    }

    final totalKm = totalMeters / 1000.0;
    final avgPace = totalMeters > 0 ? (totalSeconds / (totalMeters / 1000.0)) : 0;
    final avgRPE = totalRPE / entrenamientos.length;

    return WeekStats(
      entrenamientos: entrenamientos.length,
      totalKm: totalKm,
      totalDuration: totalSeconds,
      avgPace: avgPace.round(),
      avgRPE: avgRPE,
      totalLoad: totalLoad,
    );
  }
}

/// Estadísticas semanales agregadas
class WeekStats {
  final int entrenamientos;
  final double totalKm;
  final double totalDuration; // Segundos
  final int avgPace; // Seg/km
  final double avgRPE;
  final double totalLoad;

  WeekStats({
    required this.entrenamientos,
    required this.totalKm,
    required this.totalDuration,
    required this.avgPace,
    required this.avgRPE,
    required this.totalLoad,
  });

  /// Duración formateada
  String get durationFormatted {
    final hours = (totalDuration / 3600).floor();
    final minutes = ((totalDuration % 3600) / 60).floor();
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Pace formateado
  String get paceFormatted {
    if (avgPace <= 0) return '-';
    final mm = avgPace ~/ 60;
    final ss = avgPace % 60;
    final ss2 = ss < 10 ? '0$ss' : '$ss';
    return '$mm:$ss2 /km';
  }
}

