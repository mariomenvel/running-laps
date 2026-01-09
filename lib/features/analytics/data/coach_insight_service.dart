import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

enum InsightType {
  inactivity,
  consistency,
  progress,
  personalBest,
  motivational,
}

class CoachInsight {
  final String title;
  final String message;
  final IconData icon;
  final List<Color> colors;
  final String typeLabel;
  final InsightType type;

  CoachInsight({
    required this.title,
    required this.message,
    required this.icon,
    required this.colors,
    required this.typeLabel,
    required this.type,
  });
}

class CoachInsightService {
  CoachInsight generateInsight(List<Entrenamiento> data) {
    if (data.isEmpty) {
      return CoachInsight(
        title: "¡Bienvenido!",
        message: "¡Qué alegría verte por aquí! Es un gran día para registrar tu primer entrenamiento.",
        icon: Icons.celebration_rounded,
        colors: [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
        typeLabel: "COMIENZO",
        type: InsightType.motivational,
      );
    }

    final now = DateTime.now();
    final lastTraining = data.first;
    final lastTrainingDate = lastTraining.fecha;
    final daysSinceLast = now.difference(lastTrainingDate).inDays;

    // 1. INACTIVITY LOGIC
    if (daysSinceLast >= 5) {
      return CoachInsight(
        title: "¡Te echamos de menos!",
        message: "Llevas $daysSinceLast días sin entrenar. No dejes que la pereza gane hoy, ¡solo 15 minutos marcan la diferencia!",
        icon: Icons.timer_off_rounded,
        colors: [const Color(0xFFFF512F), const Color(0xFFDD2476)],
        typeLabel: "RETORNO",
        type: InsightType.inactivity,
      );
    }

    // 2. PERSONAL BEST LOGIC (Only if more than 1 training exists)
    if (data.length > 2) {
      final previousTrainings = data.skip(1).toList();
      
      // Check Distance Record
      final lastDist = lastTraining.distanciaTotalM();
      final maxPrevDist = previousTrainings.fold<double>(0.0, (max, e) => e.distanciaTotalM().toDouble() > max ? e.distanciaTotalM().toDouble() : max);
      
      if (lastDist > maxPrevDist && lastDist > 0) {
        return CoachInsight(
          title: "¡RÉCORD DE DISTANCIA!",
          message: "¡Increíble! Tus ${(lastDist / 1000).toStringAsFixed(2)} km son tu mayor distancia hasta la fecha. ¡Eres una máquina!",
          icon: Icons.workspace_premium_rounded,
          colors: [const Color(0xFFFFD700), const Color(0xFFFFA000)], // Golden
          typeLabel: "RÉCORD",
          type: InsightType.personalBest,
        );
      }
      
      // Check Pace Record (only for meaningful distances > 500m)
      if (lastDist > 500) {
        final lastPace = lastTraining.tiempoTotalSec() / (lastDist / 1000.0);
        final bestPrevPace = previousTrainings
            .where((e) => e.distanciaTotalM() > 500)
            .fold<double>(999999.0, (min, e) {
              final pace = e.tiempoTotalSec() / (e.distanciaTotalM() / 1000.0);
              return pace < min ? pace : min;
            });
            
        if (lastPace < bestPrevPace && bestPrevPace < 999999) {
           final m = lastPace ~/ 60;
           final s = (lastPace % 60).toInt().toString().padLeft(2, '0');
           return CoachInsight(
            title: "¡RÉCORD DE RITMO!",
            message: "¡Vuelas! Has logrado tu mejor ritmo medio histórico: $m:$s min/km. ¡Espectacular!",
            icon: Icons.speed_rounded,
            colors: [const Color(0xFF00F2FE), const Color(0xFF4FACFE)], // Cyan/Blue
            typeLabel: "VELOCIDAD",
            type: InsightType.personalBest,
          );
        }
      }
    }

    // 3. CONSISTENCY LOGIC (3+ trainings in last 7 days)
    final last7Days = data.where((e) => now.difference(e.fecha).inDays <= 7).length;
    if (last7Days >= 3) {
      return CoachInsight(
        title: "¡Imparable!",
        message: "Llevas $last7Days entrenamientos esta semana. Tu constancia es inspiradora, ¡sigue así!",
        icon: Icons.auto_awesome_rounded,
        colors: [const Color(0xFF11998e), const Color(0xFF38ef7d)],
        typeLabel: "CONSTANCIA",
        type: InsightType.consistency,
      );
    }

    // 3. PROGRESS LOGIC (Compare this week vs last week distance)
    final thisWeekKm = data
        .where((e) => now.difference(e.fecha).inDays <= 7)
        .fold(0.0, (sum, e) => sum + (e.distanciaTotalM() / 1000.0));
    final lastWeekKm = data
        .where((e) {
          final diff = now.difference(e.fecha).inDays;
          return diff > 7 && diff <= 14;
        })
        .fold(0.0, (sum, e) => sum + (e.distanciaTotalM() / 1000.0));

    if (thisWeekKm > lastWeekKm && lastWeekKm > 0) {
      final diff = ((thisWeekKm - lastWeekKm) / lastWeekKm * 100).toStringAsFixed(0);
      return CoachInsight(
        title: "¡Progresando!",
        message: "Esta semana has corrido un $diff% más que la anterior. ¡Tus piernas lo notan!",
        icon: Icons.trending_up_rounded,
        colors: [const Color(0xFF2196F3), const Color(0xFF00BCD4)],
        typeLabel: "PROGRESO",
        type: InsightType.progress,
      );
    }

    // 4. FALLBACK MOTIVATIONAL
    final quotes = [
      "El único entrenamiento malo es el que no ocurrió.",
      "No tienes que ser el mejor para empezar, pero tienes que empezar para ser el mejor.",
      "Cada kilómetro cuenta para la versión más fuerte de ti mismo.",
      "Tu ritmo no importa, lo que importa es que no te detengas.",
      "Siente el asfalto, respira profundo y disfruta del camino hoy."
    ];
    final quote = quotes[now.day % quotes.length];

    return CoachInsight(
      title: "Coach Virtual",
      message: quote,
      icon: Icons.emoji_objects_rounded,
      colors: [const Color(0xFF8E24AA), const Color(0xFF673AB7)],
      typeLabel: "INSIGHT",
      type: InsightType.motivational,
    );
  }
}

