import 'package:flutter/material.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isUnlocked = false,
  });

  Achievement copyWith({bool? isUnlocked}) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      icon: icon,
      color: color,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

class GamificationService {
  
  // LISTA MAESTRA DE LOGROS
  static final List<Achievement> _masterList = [
    Achievement(
      id: 'first_run',
      title: 'Primeros Pasos',
      description: 'Completa tu primer entrenamiento.',
      icon: Icons.directions_run,
      color: Colors.green,
    ),
    Achievement(
      id: 'distance_10k',
      title: 'Fondo 10K',
      description: 'Corre 10km acumulados en total.',
      icon: Icons.map,
      color: Colors.blue,
    ),
    Achievement(
      id: 'distance_42k',
      title: 'Maratoniano',
      description: 'Acumula 42km totales (distancia de maratón).',
      icon: Icons.emoji_events,
      color: Colors.amber,
    ),
    Achievement(
      id: 'consistency_3',
      title: 'Constancia',
      description: 'Registra al menos 3 entrenamientos.',
      icon: Icons.calendar_today,
      color: Colors.purple,
    ),
    Achievement(
      id: 'speed_demon',
      title: 'Demonio Veloz',
      description: 'Logra un ritmo medio mejor que 5:00 /km en una sesión.',
      icon: Icons.flash_on,
      color: Colors.red,
    ),
  ];

  /// Calcula cuáles logros ha desbloqueado el usuario basándose en su historial
  static List<Achievement> calculateAchievements(List<Entrenamiento> history) {
    // 1. Calcular estadisticas base
    final int totalRuns = history.length;
    double totalKm = 0;
    bool hasFastRun = false;

    for (var t in history) {
      totalKm += t.distanciaTotalM() / 1000.0;
      
      // Ritmo (sec/km). Si es < 300 (5 min/km) y distancia > 1km (para evitar errores de GPS cortos)
      try {
        if (t.distanciaTotalM() > 1000 && t.ritmoMedioSecPorKm() < 300) {
          hasFastRun = true;
        }
      } catch (_) {}
    }

    // 2. Verificar condiciones
    return _masterList.map((a) {
      bool unlocked = false;
      switch (a.id) {
        case 'first_run':
          unlocked = totalRuns >= 1;
          break;
        case 'distance_10k':
          unlocked = totalKm >= 10;
          break;
        case 'distance_42k':
          unlocked = totalKm >= 42;
          break;
        case 'consistency_3':
          unlocked = totalRuns >= 3;
          break;
        case 'speed_demon':
          unlocked = hasFastRun;
          break;
      }
      return a.copyWith(isUnlocked: unlocked);
    }).toList();
  }
}

