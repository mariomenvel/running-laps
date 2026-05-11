// ignore_for_file: avoid_print
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../features/templates/data/athlete_session_mapper.dart';
import '../features/templates/data/workout_block.dart';
import '../features/templates/data/workout_segment.dart';
import '../features/templates/data/workout_session.dart';
import '../features/templates/data/target_config.dart';
import '../features/templates/data/saved_block.dart';
import '../features/athlete/data/athlete_session_model.dart';
import '../features/training/data/entrenamiento.dart';
import '../features/training/data/serie.dart';
import '../core/services/gps_service.dart';

const _uuid = Uuid();
final _rng = Random();

Future<void> main() async {
  final uid = 'test_user_${DateTime.now().millisecondsSinceEpoch}';

  final templates = _generateTemplates();
  final plannedSessions = _generatePlannedSessions(templates, uid);
  final trainings = _generateTrainings();
  final savedBlocks = _generateSavedBlocks();

  await _saveToBatch(uid, templates, plannedSessions, trainings, savedBlocks);

  print('✓ Test user $uid creado con éxito');
  print('  Templates:        ${templates.length}');
  print('  Planned sessions: ${plannedSessions.length}');
  print('  Trainings:        ${trainings.length}');
  print('  Saved blocks:     ${savedBlocks.length}');
}

// ─────────────────────────────────────
// TEMPLATES
// ─────────────────────────────────────

List<WorkoutSession> _generateTemplates() {
  return [
    _buildIntervalSession(
      title: '5×1000m VO2max',
      type: WorkoutType.intervals,
      reps: 5,
      distanceM: 1000,
      recoverySec: 90,
      targetZone: HeartRateZone.z5,
    ),
    _buildContinuousSession(
      title: 'Rodaje base 60 min',
      type: WorkoutType.continuous,
      durationSec: 3600,
      targetZone: HeartRateZone.z2,
    ),
    _buildFartlekSession(),
    _buildHillsSession(),
    _buildCompetitionSession(),
  ];
}

WorkoutSession _buildIntervalSession({
  required String title,
  required WorkoutType type,
  required int reps,
  required int distanceM,
  required int recoverySec,
  required HeartRateZone targetZone,
}) {
  final warmup = WorkoutBlock(
    id: _uuid.v4(),
    role: BlockRole.warmup,
    repetitions: 1,
    segments: [
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.interval,
        durationSec: 600,
        target: TargetConfig(zone: HeartRateZone.z1),
      ),
    ],
  );
  final main = WorkoutBlock(
    id: _uuid.v4(),
    role: BlockRole.main,
    repetitions: reps,
    segments: [
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.interval,
        distanceM: distanceM,
        target: TargetConfig(zone: targetZone),
      ),
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.recovery,
        durationSec: recoverySec,
        recoveryType: RecoveryType.active,
      ),
    ],
  );
  final cooldown = WorkoutBlock(
    id: _uuid.v4(),
    role: BlockRole.cooldown,
    repetitions: 1,
    segments: [
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.interval,
        durationSec: 300,
        target: TargetConfig(zone: HeartRateZone.z1),
      ),
    ],
  );
  return WorkoutSession(
    id: _uuid.v4(),
    title: title,
    type: type,
    blocks: [warmup, main, cooldown],
    isTemplate: true,
  );
}

WorkoutSession _buildContinuousSession({
  required String title,
  required WorkoutType type,
  required int durationSec,
  required HeartRateZone targetZone,
}) {
  final main = WorkoutBlock(
    id: _uuid.v4(),
    role: BlockRole.main,
    repetitions: 1,
    segments: [
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.interval,
        durationSec: durationSec,
        target: TargetConfig(zone: targetZone),
      ),
    ],
  );
  return WorkoutSession(
    id: _uuid.v4(),
    title: title,
    type: type,
    blocks: [main],
    isTemplate: true,
  );
}

WorkoutSession _buildFartlekSession() {
  final durations = [300, 240, 180, 300, 240, 180];
  final zones = [
    HeartRateZone.z4,
    HeartRateZone.z3,
    HeartRateZone.z5,
    HeartRateZone.z4,
    HeartRateZone.z3,
    HeartRateZone.z5,
  ];
  final segments = <WorkoutSegment>[];
  for (var i = 0; i < durations.length; i++) {
    segments.add(WorkoutSegment(
      id: _uuid.v4(),
      type: SegmentType.interval,
      durationSec: durations[i],
      target: TargetConfig(zone: zones[i]),
    ));
    if (i < durations.length - 1) {
      segments.add(WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.recovery,
        durationSec: 60,
        recoveryType: RecoveryType.active,
      ));
    }
  }
  return WorkoutSession(
    id: _uuid.v4(),
    title: "Fartlek 5'-4'-3'",
    type: WorkoutType.fartlek,
    blocks: [
      WorkoutBlock(
        id: _uuid.v4(),
        role: BlockRole.main,
        repetitions: 1,
        segments: segments,
      ),
    ],
    isTemplate: true,
  );
}

WorkoutSession _buildHillsSession() {
  final warmup = WorkoutBlock(
    id: _uuid.v4(),
    role: BlockRole.warmup,
    repetitions: 1,
    segments: [
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.interval,
        durationSec: 600,
        target: TargetConfig(zone: HeartRateZone.z1),
      ),
    ],
  );
  final main = WorkoutBlock(
    id: _uuid.v4(),
    role: BlockRole.main,
    repetitions: 8,
    label: 'Cuesta',
    segments: [
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.interval,
        distanceM: 200,
        target: TargetConfig(zone: HeartRateZone.z5, rpe: 9),
      ),
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.recovery,
        durationSec: 120,
        recoveryType: RecoveryType.active,
      ),
    ],
  );
  return WorkoutSession(
    id: _uuid.v4(),
    title: '8×200m cuestas',
    type: WorkoutType.hills,
    blocks: [warmup, main],
    isTemplate: true,
  );
}

WorkoutSession _buildCompetitionSession() {
  final main = WorkoutBlock(
    id: _uuid.v4(),
    role: BlockRole.main,
    repetitions: 1,
    segments: [
      WorkoutSegment(
        id: _uuid.v4(),
        type: SegmentType.interval,
        distanceM: 10000,
        target: TargetConfig(zone: HeartRateZone.z4, rpe: 8),
      ),
    ],
  );
  return WorkoutSession(
    id: _uuid.v4(),
    title: 'Competición simulada',
    type: WorkoutType.competition,
    blocks: [main],
    isTemplate: true,
    notes: 'Simular condiciones de carrera',
  );
}

// ─────────────────────────────────────
// PLANNED SESSIONS
// ─────────────────────────────────────

List<AthleteSession> _generatePlannedSessions(
  List<WorkoutSession> templates,
  String uid,
) {
  final sessions = <AthleteSession>[];
  final today = DateTime.now();

  for (var i = 0; i < 30; i++) {
    final day = today.add(Duration(days: i));
    if (day.weekday == DateTime.sunday) continue;
    if (_rng.nextDouble() < 0.3) continue;

    final template = templates[_rng.nextInt(templates.length)];
    final isCompleted = i < 5 && _rng.nextDouble() < 0.2;
    final isMorning = _rng.nextBool();

    final base = mapWorkoutSessionToAthlete(template, uid: uid);
    sessions.add(base.copyWith(
      id: _uuid.v4(),
      uid: uid,
      date: _dateStr(day),
      time: isMorning ? '07:00' : '18:00',
      status: isCompleted ? AthleteSessionStatus.completed : AthleteSessionStatus.planned,
      planningNotes: _rng.nextDouble() < 0.4 ? _randomPlanningNote() : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  return sessions;
}

String _randomPlanningNote() {
  const notes = [
    'Mantener ritmo cómodo',
    'Importante no salir demasiado rápido',
    'Recuperación activa entre series',
    'Control de FC durante todo el entrenamiento',
    'Hidratación cada 20 min',
    'Calentar bien antes de las series',
  ];
  return notes[_rng.nextInt(notes.length)];
}

// ─────────────────────────────────────
// TRAININGS (historial)
// ─────────────────────────────────────

List<Entrenamiento> _generateTrainings() {
  final trainings = <Entrenamiento>[];
  final today = DateTime.now();
  const trainingTypes = ['Series', 'Continuo', 'Fartlek', 'Cuestas'];

  for (var i = 1; i <= 90; i++) {
    if (_rng.nextDouble() < 0.6) continue;

    final day = today.subtract(Duration(days: i));
    final tipo = trainingTypes[_rng.nextInt(trainingTypes.length)];
    final numSeries = 1 + _rng.nextInt(5);
    final series = List.generate(numSeries, (_) => _generateSerie(day));
    final gpsPoints = _generateGpsPoints(day, series.length * 10);

    trainings.add(Entrenamiento(
      titulo: '$tipo ${_dateStr(day)}',
      fecha: day,
      gps: true,
      series: series,
      trackPoints: gpsPoints,
      fcMediaSesion: 140 + _rng.nextDouble() * 40,
      notas: _rng.nextDouble() < 0.3 ? _randomNote() : null,
      createdAt: day,
      updatedAt: day,
    ));
  }

  return trainings;
}

Serie _generateSerie(DateTime base) {
  final distanciaM = (1000 + _rng.nextInt(4) * 500);
  final paceSecPerKm = 240 + _rng.nextInt(120);
  final tiempoSec = (distanciaM / 1000.0) * paceSecPerKm;
  final descansoSec = 60 + _rng.nextInt(120);
  final rpe = 5.0 + _rng.nextDouble() * 4.0;
  final fcMedia = 140.0 + _rng.nextDouble() * 40.0;

  return Serie(
    tiempoSec: tiempoSec,
    distanciaM: distanciaM,
    descansoSec: descansoSec,
    rpe: rpe,
    usedGps: true,
    usedGpsDistance: true,
    fcMedia: fcMedia,
    finishedAt: base.add(Duration(seconds: tiempoSec.toInt())),
  );
}

List<GpsPoint> _generateGpsPoints(DateTime base, int count) {
  const baseLat = 40.4168;
  const baseLng = -3.7038;
  var lat = baseLat + (_rng.nextDouble() - 0.5) * 0.1;
  var lng = baseLng + (_rng.nextDouble() - 0.5) * 0.1;
  final points = <GpsPoint>[];

  for (var i = 0; i < count; i++) {
    lat += (_rng.nextDouble() - 0.5) * 0.001;
    lng += (_rng.nextDouble() - 0.5) * 0.001;
    points.add(GpsPoint(
      latitude: lat,
      longitude: lng,
      altitude: 600 + _rng.nextDouble() * 50,
      timestamp: base.add(Duration(seconds: i * 30)),
    ));
  }

  return points;
}

String _randomNote() {
  const notes = [
    'Buenas sensaciones',
    'Piernas cargadas',
    'Viento en contra',
    'Calor excesivo',
    'Excelente sesión',
    'Regular, dormir mejor',
    'Después de descanso',
  ];
  return notes[_rng.nextInt(notes.length)];
}

// ─────────────────────────────────────
// SAVED BLOCKS
// ─────────────────────────────────────

List<SavedBlock> _generateSavedBlocks() {
  final now = DateTime.now();

  WorkoutBlock warmupBlock(int minutes) => WorkoutBlock(
        id: _uuid.v4(),
        role: BlockRole.warmup,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            id: _uuid.v4(),
            type: SegmentType.interval,
            durationSec: minutes * 60,
            target: TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      );

  WorkoutBlock cooldownBlock(int minutes) => WorkoutBlock(
        id: _uuid.v4(),
        role: BlockRole.cooldown,
        repetitions: 1,
        segments: [
          WorkoutSegment(
            id: _uuid.v4(),
            type: SegmentType.interval,
            durationSec: minutes * 60,
            target: TargetConfig(zone: HeartRateZone.z1),
          ),
        ],
      );

  WorkoutBlock intervalsBlock(int reps, int distanceM, int recoverySec) => WorkoutBlock(
        id: _uuid.v4(),
        role: BlockRole.main,
        repetitions: reps,
        segments: [
          WorkoutSegment(
            id: _uuid.v4(),
            type: SegmentType.interval,
            distanceM: distanceM,
            target: TargetConfig(zone: HeartRateZone.z4),
          ),
          WorkoutSegment(
            id: _uuid.v4(),
            type: SegmentType.recovery,
            durationSec: recoverySec,
            recoveryType: RecoveryType.active,
          ),
        ],
      );

  WorkoutBlock fartlekMainBlock() => WorkoutBlock(
        id: _uuid.v4(),
        role: BlockRole.main,
        repetitions: 1,
        label: 'Fartlek mixto',
        segments: [
          WorkoutSegment(
            id: _uuid.v4(),
            type: SegmentType.interval,
            durationSec: 300,
            target: TargetConfig(zone: HeartRateZone.z4),
          ),
          WorkoutSegment(
            id: _uuid.v4(),
            type: SegmentType.recovery,
            durationSec: 60,
            recoveryType: RecoveryType.active,
          ),
          WorkoutSegment(
            id: _uuid.v4(),
            type: SegmentType.interval,
            durationSec: 180,
            target: TargetConfig(zone: HeartRateZone.z5),
          ),
          WorkoutSegment(
            id: _uuid.v4(),
            type: SegmentType.recovery,
            durationSec: 60,
            recoveryType: RecoveryType.active,
          ),
        ],
      );

  return [
    SavedBlock(id: _uuid.v4(), name: 'Calentamiento 10 min', role: BlockRole.warmup, block: warmupBlock(10), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: 'Calentamiento 15 min', role: BlockRole.warmup, block: warmupBlock(15), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: 'Calentamiento 20 min', role: BlockRole.warmup, block: warmupBlock(20), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: '5×1000m Z4', role: BlockRole.main, block: intervalsBlock(5, 1000, 90), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: '3×2000m tempo', role: BlockRole.main, block: intervalsBlock(3, 2000, 120), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: '6×400m rápidos', role: BlockRole.main, block: intervalsBlock(6, 400, 60), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: 'Fartlek mixto', role: BlockRole.main, block: fartlekMainBlock(), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: 'Vuelta a la calma 5 min', role: BlockRole.cooldown, block: cooldownBlock(5), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: 'Vuelta a la calma 10 min', role: BlockRole.cooldown, block: cooldownBlock(10), createdAt: now),
    SavedBlock(id: _uuid.v4(), name: 'Vuelta a la calma 15 min', role: BlockRole.cooldown, block: cooldownBlock(15), createdAt: now),
  ];
}

// ─────────────────────────────────────
// FIRESTORE BATCH
// ─────────────────────────────────────

Future<void> _saveToBatch(
  String uid,
  List<WorkoutSession> templates,
  List<AthleteSession> plannedSessions,
  List<Entrenamiento> trainings,
  List<SavedBlock> savedBlocks,
) async {
  final db = FirebaseFirestore.instance;

  // Firestore batch tiene límite de 500 operaciones; dividir si hace falta.
  var batch = db.batch();
  var opCount = 0;

  Future<void> flush() async {
    if (opCount > 0) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  void addDoc(DocumentReference ref, Map<String, dynamic> data) {
    batch.set(ref, data);
    opCount++;
  }

  // Perfil de usuario con zonas FC
  addDoc(db.collection('users').doc(uid), _buildProfile());

  // Templates
  for (final t in templates) {
    addDoc(db.collection('users').doc(uid).collection('templates').doc(t.id), t.toMap());
  }

  // Planned sessions
  for (final s in plannedSessions) {
    addDoc(db.collection('users').doc(uid).collection('athleteSessions').doc(s.id), s.toMap());
  }

  // Trainings
  for (final t in trainings) {
    final id = _uuid.v4();
    addDoc(db.collection('users').doc(uid).collection('trainings').doc(id), t.toMap());
    if (opCount >= 490) await flush();
  }

  // Saved blocks
  for (final b in savedBlocks) {
    addDoc(db.collection('users').doc(uid).collection('savedBlocks').doc(b.id), b.toMap());
  }

  await flush();
}

Map<String, dynamic> _buildProfile() {
  const fcMax = 190;
  return {
    'fcMax': fcMax,
    'zones': {
      'z1': {'min': (fcMax * 0.50).round(), 'max': (fcMax * 0.60).round()},
      'z2': {'min': (fcMax * 0.60).round(), 'max': (fcMax * 0.70).round()},
      'z3': {'min': (fcMax * 0.70).round(), 'max': (fcMax * 0.80).round()},
      'z4': {'min': (fcMax * 0.80).round(), 'max': (fcMax * 0.90).round()},
      'z5': {'min': (fcMax * 0.90).round(), 'max': fcMax},
    },
    'isTestUser': true,
    'createdAt': DateTime.now().toIso8601String(),
  };
}

// ─────────────────────────────────────
// UTILS
// ─────────────────────────────────────

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
