import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Para SystemSound
import 'package:firebase_core/firebase_core.dart'; // Para FirebaseException

import '../data/serie.dart';
import '../data/entrenamiento.dart';
import '../data/training_repository.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/rpe_badge.dart';
import 'package:running_laps/core/widgets/ios_picker.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/services/ios_live_activity_service.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/modern_snackbar.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/app_transitions.dart';

import 'package:running_laps/core/widgets/main_shell.dart';
import 'package:running_laps/core/widgets/number_picker_field.dart';
import 'training_summary_screen.dart';
import 'complete_session_manually_view.dart';
import '../viewmodels/training_viewmodel.dart';
import '../data/tag_model.dart';
import '../data/tag_manager.dart';
import '../widgets/create_tag_dialog.dart';
import 'training_session_view.dart';
import '../../templates/views/templates_list_view.dart';
import '../../templates/data/template_models.dart';
import '../../templates/views/template_editor_view.dart';
import '../../templates/data/workout_block.dart';
import '../../templates/data/workout_segment.dart';
import '../../templates/data/workout_session.dart';
import '../../templates/views/workout_editor_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/features/athlete/data/athlete_session_model.dart';
import 'package:running_laps/features/athlete/data/athlete_session_repository.dart';
import 'package:running_laps/core/services/heart_rate_service.dart';
import 'package:running_laps/features/profile/views/heart_rate_monitor_view.dart';
import 'package:running_laps/core/services/notification_service.dart';
import 'package:running_laps/core/services/session_recovery_service.dart';
import 'package:running_laps/core/services/training_load_service.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/profile/data/zones_repository.dart';
import '../../templates/data/athlete_session_mapper.dart';
import 'pre_execution_screen.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/home/viewmodels/home_view_model.dart';
import 'package:running_laps/features/ai_coach/data/pb_detector.dart';


// ===============================================================
// ENUM PARA LA ALARMA
// ===============================================================



class TrainingStartView extends StatefulWidget {
  final TrainingTemplate? sourceTemplate;
  final String? athleteSessionId;
  final List<Serie>? recoveredSeries;
  final DateTime? recoveredStartTime;

  const TrainingStartView({
    Key? key,
    this.sourceTemplate,
    this.athleteSessionId,
    this.recoveredSeries,
    this.recoveredStartTime,
  }) : super(key: key);

  @override
  _TrainingStartViewState createState() => _TrainingStartViewState();
}


class _TrainingStartViewState extends State<TrainingStartView>
    with TickerProviderStateMixin {
  // --- ViewModel ---
  final TrainingViewModel _vm = TrainingViewModel();

  Color get _brandAccentColor => Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand;

  // --- Estado UI ---
  bool _isSaving = false;


  //  // ELIMINADOS: TextEditingController _distanciaController & _descansoController
  // Ahora usamos variables de estado directas para la UI


  // Valores actuales (seleccionados por el usuario)
  int _distanciaSeleccionada = 400; // Valor por defecto
  int _descansoSeleccionado = 60;   // Valor por defecto


  // Últimos valores guardados (para persistencia entre series)
  int _ultimoValorDistancia = 400;
  int _ultimoValorDescanso = 60;


  final TextEditingController _trainingNameController = TextEditingController();


  // --- Estado del Descanso (UI) ---
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  int _restTotalSeconds = 0;
  bool _isResting = false;
  double _restRpe = 5.0;
  StreamSubscription<String>? _iosRestActionSubscription;

  // Momento de inicio de sesión (para recovery)
  DateTime? _sessionStartTime;

  // --- Colores ---
  static const Color _bgGradientColor = Color(0xFFF9F5FB);


  // ===============================================================
  // ESTADO DE LA ALARMA
  // ===============================================================
  bool _alarmEnabled = false;
  bool _bleEnabled = true;
  AlarmMode _alarmMode = AlarmMode.bySeconds;


  // Por tiempo (cada X segundos)
  int _timeMin = 0;
  int _timeSecHalfIndex = 0; // 0..119 (0.0 .. 59.5)


  // Por ritmo (min/km + metros)
  int _paceMin = 4;
  int _paceSecIndex = 0; // 0..11 (0, 5, 10...55)
 
  final List<int> _segmentDistances = <int>[50, 100, 200, 300, 400, 500, 1000];
  int _segmentIndex = 3; // por defecto 300m


  int? _alarmIntervalMs; // intervalo final en milisegundos
  
  // Storage for GPS points from Continuous Run
  List<GpsPoint>? _collectedGpsPoints;

  // FC máxima del perfil del usuario
  int? _fcMax;

  // --- Tags (Selección al guardar) ---
  final Set<String> _selectedTags = {};

  // --- Rediseño pre-entrenamiento ---
  String? _selectedTrainingType;
  AthleteSession? _plannedSession;
  bool _ignoreSession = false;
  AthleteSession? _todaySession;
  bool _loadingTodaySession = true;

  // --- Configuración por tipo ---
  final _cfgDistKmCtrl   = TextEditingController(); // rodaje/largo: dist objetivo km
  final _cfgPaceCtrl     = TextEditingController(); // pace objetivo mm:ss
  int    _cfgSeries      = 5;                       // series: número
  int    _cfgSeriesDist  = 400;                      // metros por serie
  int    _cfgDescanso    = 90;                      // series: descanso en segundos
  final _cfgSeriesPaceCtrl = TextEditingController(); // pace por serie
  int    _cfgTempoDur    = 30;                      // tempo: minutos
  final _cfgTempoPaceCtrl = TextEditingController(); // tempo: pace
  int    _cfgFartlekDur  = 40;                      // fartlek: minutos totales
  int    _cfgFartlekBloques = 6;                    // fartlek: bloques rápidos/lentos


  Future<void> _loadFcMax() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final profile = await ZonesRepository().getUserProfile(uid);
      if (mounted) setState(() => _fcMax = profile?.fcMax);
    } catch (e) {
      debugPrint('[TrainingStartView] _loadFcMax error: $e');
    }
  }

  Future<void> _loadPlannedSession() async {
    if (widget.athleteSessionId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final session = await AthleteSessionRepository()
          .getSession(uid: uid, id: widget.athleteSessionId!);
      if (mounted) setState(() => _plannedSession = session);
    } catch (e) {
      debugPrint('[TrainingStartView] _loadPlannedSession: $e');
    }
  }

  Future<void> _loadTodaySession() async {
    // Si llegó con athleteSessionId explícito, la búsqueda automática no aplica.
    if (widget.athleteSessionId != null) {
      if (mounted) setState(() => _loadingTodaySession = false);
      return;
    }
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _loadingTodaySession = false);
        return;
      }
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final sessions = await AthleteSessionRepository()
          .getSessionsForDate(uid: uid, date: dateStr);
      final planned = sessions
          .where((s) => s.status == AthleteSessionStatus.planned)
          .toList();
      if (mounted) {
        setState(() {
          _todaySession = planned.isNotEmpty ? planned.first : null;
          _loadingTodaySession = false;
        });
      }
    } catch (e) {
      debugPrint('[TrainingStart] _loadTodaySession error: $e');
      if (mounted) setState(() => _loadingTodaySession = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _loadFcMax();
    _loadPlannedSession();
    _loadTodaySession();
    // CAMBIO 4: reconectar pulsómetro si hay uno guardado
    if (HeartRateService().connectionState.value ==
        HrConnectionState.disconnected) {
      HeartRateService()
          .autoReconnect()
          .catchError((e) => debugPrint('[TrainingStartView] HR reconnect: $e'));
    }
    // Si se abre con plantilla preseleccionada, cargarla inmediatamente
    if (widget.sourceTemplate != null) {
      _vm.loadTemplate(widget.sourceTemplate!);
      if (_vm.plannedBlocks.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyTemplateBlock(_vm.plannedBlocks[0]);
        });
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _iosRestActionSubscription =
          IOSLiveActivityService.instance.actions.listen((String action) {
        if (action == 'skip_rest' && _isResting) {
          _skipRest();
        }
      });
    }
    // Cargar series recuperadas si se abre desde el banner de recovery
    if (widget.recoveredSeries != null && widget.recoveredSeries!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final serie in widget.recoveredSeries!) {
          _vm.addSerie(serie);
        }
        _sessionStartTime = widget.recoveredStartTime;
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _loadUserPreferences() async {
    final settings = SettingsService();
    final alarm = await settings.getAlarmEnabled();
    final gps = await settings.getGpsDefault();
    final config = await settings.getAlarmConfig();
    
    if (mounted) {
      setState(() {
        _alarmEnabled = alarm;
        _vm.setGpsOn(gps);
        
        _alarmMode = config['mode'] == 'pace' ? AlarmMode.byPace : AlarmMode.bySeconds;
        _timeMin = config['timeMin'];
        _timeSecHalfIndex = ((config['timeSec'] as double) * 2).round();
        _paceMin = config['paceMin'];
        _paceSecIndex = config['paceSec'];
        
        int savedSegment = config['segment'];
        int segIdx = _segmentDistances.indexOf(savedSegment);
        if (segIdx != -1) _segmentIndex = segIdx;
      });
      _updateAlarmInterval();
    }
  }


  @override
  void dispose() {
    _trainingNameController.dispose();
    _restTimer?.cancel();
    _iosRestActionSubscription?.cancel();
    _cfgDistKmCtrl.dispose();
    _cfgPaceCtrl.dispose();
    _cfgSeriesPaceCtrl.dispose();
    _cfgTempoPaceCtrl.dispose();
    super.dispose();
  }


  // ===================================================================
  // Lógica del Temporizador de Descanso (UI)
  // ===================================================================


  void _startRestCountdown() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 0) {
        setState(() {
          _restSecondsRemaining--;
        });
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          IOSLiveActivityService.instance.update(
            IOSLiveActivityPayload.rest(
              restCountdown: _restSecondsRemaining,
              serie: _vm.series.length + 1,
            ),
          );
        }
      } else {
        timer.cancel();
        HapticFeedback.mediumImpact();
        _vm.updateSerieRpeAt(_vm.series.length - 1, _restRpe);
        setState(() {
          _isResting = false;
        });
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          IOSLiveActivityService.instance.stop();
        }
      }
    });
  }


  void _skipRest() {
    _restTimer?.cancel();
    HapticFeedback.mediumImpact();
    _vm.updateSerieRpeAt(_vm.series.length - 1, _restRpe);
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
    });
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      IOSLiveActivityService.instance.stop();
    }
  }




  String _formatMinSec(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString()}:${s.toString().padLeft(2, '0')}';
  }


  // ===================================================================
  // Lógica de la Alarma
  // ===================================================================


  void _updateAlarmInterval() {
    int? newIntervalMs;


    if (!_alarmEnabled) {
      newIntervalMs = null;
    } else {
      if (_alarmMode == AlarmMode.bySeconds) {
       
        double secValue = _timeSecHalfIndex * 0.5;
        double totalSeconds = _timeMin * 60 + secValue;


        if (totalSeconds > 0.0) {
          newIntervalMs = (totalSeconds * 1000).round();
        } else {
          newIntervalMs = null;
        }
      } else {
        // AlarmMode.byPace
        int secValue = _paceSecIndex * 5;
        int paceSecPerKm = _paceMin * 60 + secValue;
       
        if (paceSecPerKm > 0) {
          int meters = _segmentDistances[_segmentIndex];
          double secondsDouble =
              paceSecPerKm * meters / 1000.0; // proporcional al tramo
          int ms = (secondsDouble * 1000).round();
          newIntervalMs = ms > 0 ? ms : null;
        } else {
          newIntervalMs = null;
        }
      }
    }


    // No usamos setState aquí si lo llaman desde init/dispose para evitar rebuilds innecesarios,
    // pero si es desde UI, sí. Como esta fx se llama desde UI:
    setState(() {
      _alarmIntervalMs = newIntervalMs;
    });

    if (_alarmEnabled) {
      SettingsService().saveAlarmConfig(
        mode: _alarmMode == AlarmMode.byPace ? 'pace' : 'time',
        timeMin: _timeMin,
        timeSec: _timeSecHalfIndex * 0.5,
        paceMin: _paceMin,
        paceSec: _paceSecIndex,
        segment: _segmentDistances[_segmentIndex],
      );
    }
  }


  String _formatAlarmMs(int ms) {
    double totalSec = ms / 1000.0;
    int minutes = totalSec ~/ 60;
    double secFrac = totalSec - minutes * 60;
    int wholeSec = secFrac.floor();
    double decimal = secFrac - wholeSec;


    String mm = minutes.toString().padLeft(2, '0');
    String ss = wholeSec.toString().padLeft(2, '0');


    // Solo vamos a tener .0 o .5 realmente
    if (decimal.abs() > 0.001) {
      return '$mm:$ss.5';
    } else {
      return '$mm:$ss';
    }
  }


  String _alarmSummaryText() {
    if (!_alarmEnabled || _alarmIntervalMs == null) {
      return '';
    }


    if (_alarmMode == AlarmMode.bySeconds) {
      return 'Cada ${_formatAlarmMs(_alarmIntervalMs!)}';
    } else {
      int metros = _segmentDistances[_segmentIndex];
      double seconds = _alarmIntervalMs! / 1000.0;
      return 'Cada ${metros}m (~${seconds.toStringAsFixed(1)}s)';
    }
  }


  // ===================================================================
  // Lógica de Botones del Footer
  // ===================================================================

  void _applyTemplateBlock(TemplateBlock block) {
    setState(() {
      // 1. Basic properties
      if (block.type == TemplateBlockType.distance) {
         _distanciaSeleccionada = block.value;
      }
      _descansoSeleccionado = block.restSeconds;
      
      // 2. Alerts
      final alerts = block.alerts;
      _alarmEnabled = alerts.enabled;
      
      if (_alarmEnabled) {
        _alarmMode = alerts.mode == 'time' ? AlarmMode.bySeconds : AlarmMode.byPace;
        _timeMin = alerts.timeMin;
        _timeSecHalfIndex = (alerts.timeSec * 2).round();
        
        _paceMin = alerts.paceMin;
        _paceSecIndex = (alerts.paceSec / 5).round();
        
        // Find closest segment index
        int segIndex = _segmentDistances.indexOf(alerts.segmentDistance);
        if (segIndex == -1) segIndex = 3; // default
        _segmentIndex = segIndex;
      }
    });
    
    // Recalculate alarm interval
    _updateAlarmInterval();
  }

  void _selectType(String type) => setState(() => _selectedTrainingType = type);

  /// Mapea el tipo al WorkoutType del editor.
  WorkoutType _workoutTypeFor(String type) {
    switch (type) {
      case 'series':
        return WorkoutType.intervals;
      case 'fartlek':
        return WorkoutType.fartlek;
      case 'cuestas':
        return WorkoutType.intervals;
      default: // continuo, competicion
        return WorkoutType.continuous;
    }
  }

  /// Abre WorkoutEditorScreen en modo quick-start con el tipo preseleccionado.
  void _openWorkoutEditor(String type) {
    final workoutType = _workoutTypeFor(type);

    // Sesión mínima con el tipo preseleccionado y un bloque principal vacío.
    final initialSession = WorkoutSession(
      title: _labelForType(type),
      type: workoutType,
      blocks: [
        WorkoutBlock(
          role: BlockRole.main,
          repetitions: 1,
          segments: [
            WorkoutSegment(
              type: SegmentType.interval,
              distanceM: 1000,
            ),
          ],
        ),
      ],
      isTemplate: false,
    );

    Navigator.push(
      context,
      AppRoute(
        page: WorkoutEditorScreen(
          isQuickStart: true,
          initialSession: initialSession,
          onSave: (session) {
            // El editor hace pop justo después de este callback: empujar la
            // pre-ejecución en el frame siguiente, sobre esta vista.
            // Desde ahí: EMPEZAR → WorkoutExecutionScreen → summary (guarda).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.push(
                context,
                AppRoute(page: PreExecutionScreen(session: session)),
              );
            });
          },
        ),
      ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'series':     return 'Series';
      case 'fartlek':    return 'Fartlek';
      case 'cuestas':    return 'Cuestas';
      case 'competicion': return 'Competición';
      default:           return 'Continuo';
    }
  }

  /// Devuelve (min, sec) del pace de config según el tipo activo, o null.
  (int, int)? _cfgPaceParsed() {
    final type = _selectedTrainingType;
    if (type == 'continuo') return _parsePace(_cfgPaceCtrl.text);
    if (type == 'series') return _parsePace(_cfgSeriesPaceCtrl.text);
    return null;
  }

  void _applyConfigToSeriesState() {
    if (_selectedTrainingType != 'series') return;
    if (_cfgSeriesDist > 0) {
      setState(() => _distanciaSeleccionada = _cfgSeriesDist);
    }
    setState(() => _descansoSeleccionado = _cfgDescanso);
  }

  void _showCountdown() {
    _applyConfigToSeriesState();
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => _CountdownDialog(
        onComplete: () {
          Navigator.of(ctx).pop();
          if (_selectedTrainingType == 'libre') {
            _startContinuousRun();
          } else if (_selectedTrainingType == 'series') {
            _onStartSeriesTap();
          } else {
            _startContinuousRunWithConfig();
          }
        },
      ),
    );
  }

  void _onStartSeriesTap() async {
    // Validamos datos (aunque con los selectores es difícil que falle,
    // pero por si acaso)
    if (_distanciaSeleccionada <= 0) {
      ModernSnackBar.showError(context, 'La distancia debe ser mayor a 0');
      return;
    }


    // Aseguramos recálculo de la alarma por si acaso
    _updateAlarmInterval();


    // Bloque actual de la plantilla (si existe) para pasar objetivos
    final int _currentBlockIdx = _vm.series.length;
    final TemplateBlock? _currentBlock =
        (_vm.source != null && _currentBlockIdx < _vm.plannedBlocks.length)
            ? _vm.plannedBlocks[_currentBlockIdx]
            : null;

    final result = await Navigator.push(
      context,
      AppRoute(
        page: TrainingSessionView(
          distancia:           _distanciaSeleccionada.toString(),
          descanso:            _descansoSeleccionado.toString(),
          gpsActivo:           _vm.gpsOn,
          alarmIntervalMs:     _alarmIntervalMs,
          currentSeries:       _vm.series.length + 1,
          totalSeries:         _vm.source != null ? _vm.plannedBlocks.length : null,
          targetPaceMinutes:   _currentBlock?.targetPaceMin ?? _cfgPaceParsed()?.$1,
          targetPaceSeconds:   _currentBlock?.targetPaceSec ?? _cfgPaceParsed()?.$2,
          targetRpe:           _currentBlock?.targetRpe,
          targetZone:          _currentBlock?.targetZone,
          fcMax:               _fcMax,
        ),
      ),
    );

    if (!mounted) return; // PROACTIVE FIX: Check if widget is still mounted

    if (result != null && result is Serie) {
      _sessionStartTime ??= DateTime.now();
      setState(() {
        _vm.addSerie(result);

        // Guardamos como "último valor"
        _ultimoValorDistancia = result.distanciaM;
        _ultimoValorDescanso = result.descansoSec;

        // CHECK TEMPLATE PROGRESSION
        bool appliedTemplate = false;
        if (_vm.source != null && _vm.plannedBlocks.isNotEmpty) {
           final int nextIndex = _vm.series.length; // series includes the one just added
           if (nextIndex < _vm.plannedBlocks.length) {
              _applyTemplateBlock(_vm.plannedBlocks[nextIndex]);
              appliedTemplate = true;
           } else {
             // Template Finished
             ModernSnackBar.showSuccess(context, "¡Plantilla completada!");
             
             // Auto-finish after a short delay
             Future.delayed(const Duration(milliseconds: 600), () {
               if (mounted) _onFinishTrainingTap();
             });
           }
        }
        
        if (!appliedTemplate) {
          _distanciaSeleccionada = _ultimoValorDistancia;
          _descansoSeleccionado = _ultimoValorDescanso;
        }
      });

      SessionRecoveryService().saveSession(
        series: _vm.series,
        gpsOn: _vm.gpsOn,
        startTime: _sessionStartTime!,
        templateName: _vm.source?.templateSnapshot?.name,
      );

      if (result.descansoSec > 0) {
        // Calculate remaining rest time considering time spent in RPE/Save
        int remainingRest = result.descansoSec;
        if (result.finishedAt != null) {
          final elapsed = DateTime.now().difference(result.finishedAt!);
          remainingRest = (result.descansoSec - elapsed.inSeconds).clamp(0, result.descansoSec);
        }

        setState(() {
          _restTotalSeconds = result.descansoSec;
          _restSecondsRemaining = remainingRest;
          _isResting = true;
          _restRpe = result.rpe;
        });
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          IOSLiveActivityService.instance.start(
            IOSLiveActivityPayload.rest(
              restCountdown: _restSecondsRemaining,
              serie: _vm.series.length + 1,
            ),
          );
        }
        _startRestCountdown();
      } else {
        ModernSnackBar.showSuccess(context, '¡Serie guardada! Ritmo: ${result.ritmoTexto()}');
      }
  }
}


  void _discardTraining(BuildContext modalContext) async {
    // Cerramos el modal de guardar primero
    Navigator.of(modalContext).pop();

    // Pedimos confirmación con bottom sheet moderno
    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icono de warning
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.rpeMax,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_rounded,
                size: 48,
                color: AppColors.rpeMax,
              ),
            ),
            const SizedBox(height: 24),

            // Título
            Text(
              '¿Descartar entrenamiento?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Descripción
            Text(
              'Se perderán todas las series registradas de esta sesión.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Botón de descarte (rojo y prominente)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rpeMax,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.rpeMax.withValues(alpha: 0.4),
                ),
                child: const Text(
                  'Descartar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Botón cancelar (secundario)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      setState(() {
        _vm.clearSeries();
        _trainingNameController.clear();
        _isResting = false;
        _restTimer?.cancel();
        _restSecondsRemaining = 0;
      });
      
      if (mounted) {
        ModernSnackBar.showInfo(context, 'Sesión descartada');
        // Navegamos al Home
        Navigator.of(context).pop(); 
      }
    }
  }

  void _onFinishTrainingTap() {
    if (_isSaving) return;
    
    // 1. Limpiamos siempre al abrir (salvo que sea un re-intento fallido, pero asumimos flujo nuevo)
    _trainingNameController.clear();
    
    // 2. Si viene de una Plantilla, sugerimos el nombre de la plantilla
    if (_vm.source != null && _vm.source!.templateSnapshot != null) {
       _trainingNameController.text = _vm.source!.templateSnapshot!.name;
    }
    // Si no (Manual o Continua), se queda vacío para que el usuario escriba.

    // 3. Limpiar tags previas (las plantillas no tienen tags predefinidas)
    _selectedTags.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Guardar Entrenamiento',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _trainingNameController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Nombre de la sesión',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                         borderSide: BorderSide(color: _brandAccentColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // -- SECCIÓN ETIQUETAS --
                  const Text(
                    'Etiquetas',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<TrainingTag>>(
                    future: TagManager().getUserTags(),
                    builder: (context, snapshot) {
                      // 1. LOADING
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SizedBox(
                          height: 40, 
                          child: Center(
                            child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          )
                        );
                      }
                      
                      // 2. ERROR (CRUCIAL: esto evita el congelamiento)
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.rpeMax,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.rpeMax),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: AppColors.rpeMax, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                'Error al cargar etiquetas',
                                style: TextStyle(
                                  color: AppColors.rpeMax,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Puedes reintentar o continuar sin etiquetas',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => setModalState(() {}),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Reintentar'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // 3. SUCCESS
                      final tags = snapshot.data ?? [];
                      
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Botón nueva etiqueta
                          ActionChip(
                            avatar: Icon(Icons.add, size: 16, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
                            label: Text('Nueva', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand)),
                            backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            onPressed: () async {
                              final TrainingTag? newTag = await showModalBottomSheet<TrainingTag>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const CreateTagDialog()
                              );
                              if (newTag != null) {
                                // Auto-seleccionar la nueva etiqueta
                                setModalState(() {
                                  _selectedTags.add(newTag.name);
                                });
                              }
                            },
                          ),
                          
                          // Lista de etiquetas
                          ...tags.map((tag) {
                            final bool isSelected = _selectedTags.contains(tag.name);
                            return FilterChip(
                              label: Text(
                                tag.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Color(tag.colorValue),
                              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? Colors.transparent : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              onSelected: (bool selected) {
                                setModalState(() {
                                  if (selected) {
                                    _selectedTags.add(tag.name);
                                  } else {
                                    _selectedTags.remove(tag.name);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandAccentColor,
                      foregroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.surface : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Guardar y Terminar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      final String trainingName = _trainingNameController.text;
                      if (trainingName.isEmpty) return;

                      // Close sheet then save → summary screen on success
                      Navigator.of(ctx).pop();
                      _saveTrainingToFirebase(trainingName, _selectedTags.toList());
                    },
                  ),
                  const SizedBox(height: 12),
                  // FINISH / DISCARD buttons row
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _discardTraining(ctx),
                          child: const Text('Descartar', style: TextStyle(color: AppColors.rpeMax)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          child: const Text('Cancelar', style: TextStyle(color: AppColors.iconMuted)),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  String _normalizeDateForPlanning(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _buildComparison({
    required AthleteSession planned,
    required List<Serie> executed,
  }) {
    final blocks = <Map<String, dynamic>>[];
    for (int i = 0; i < planned.blocks.length; i++) {
      final block = planned.blocks[i];
      final serie = i < executed.length ? executed[i] : null;

      final targetPaceSec = block.targetPaceMinMin != null
          ? block.targetPaceMinMin! * 60 + (block.targetPaceMinSec ?? 0)
          : null;

      final executedPaceSec = serie != null && serie.distanciaM > 0
          ? serie.tiempoSec / (serie.distanciaM / 1000)
          : null;

      blocks.add({
        'order': i,
        'planned': {
          'distanceM':       block.distanceM,
          'durationMinutes': block.durationMinutes,
          'targetPaceSec':   targetPaceSec,
          'targetRpe':       block.targetRpe,
          'targetZone':      block.targetZone,
          'restSeconds':     block.restSeconds,
        },
        'executed': serie != null
            ? {
                'distanceM':  serie.distanciaM,
                'durationSec': serie.tiempoSec,
                'paceSec':    executedPaceSec,
                'rpe':        serie.rpe,
              }
            : null,
      });
    }
    return {
      'athleteSessionId':  planned.id,
      'sessionCategory':   planned.category,
      'date':              planned.date,
      'blocks':            blocks,
      'completedAt':       DateTime.now().toIso8601String(),
    };
  }

  Future<void> _saveTrainingToFirebase(String trainingName, List<String> tags) async {
    setState(() {
      _isSaving = true;
    });

    // Capture before clearing state
    final List<Serie> seriesSnapshot = List<Serie>.from(_vm.series);
    final List<GpsPoint>? gpsSnapshot = _collectedGpsPoints != null
        ? List<GpsPoint>.from(_collectedGpsPoints!)
        : null;
    final bool gpsOn = _vm.gpsOn;

    try {
      final String newTrainingId = await _vm.guardarEntrenamiento(
        trainingName,
        tags: tags.isNotEmpty ? tags : null,
        recordedPoints: gpsSnapshot,
      );

      _checkPersonalRecords(seriesSnapshot);

      // ── Vincular con sesión planificada ───────────────────────────────
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          if (widget.athleteSessionId != null) {
            // Vinculación automática — viene de "Ejecutar sesión"
            await AthleteSessionRepository().markAsCompleted(
              uid:        uid,
              sessionId:  widget.athleteSessionId!,
              trainingId: newTrainingId,
            );
            HomeViewModel.needsReload.value++;
            // Guardar comparativa planificado vs ejecutado
            try {
              final planned = await AthleteSessionRepository()
                  .getSession(uid: uid, id: widget.athleteSessionId!);
              if (planned != null) {
                final comparison = _buildComparison(
                  planned:  planned,
                  executed: seriesSnapshot,
                );
                await TrainingRepository().updateTrainingAnalysis(
                  uid: uid,
                  trainingId: newTrainingId,
                  plannedComparison: comparison,
                );
              }
            } catch (e) {
              debugPrint('Error guardando comparativa: $e');
            }
          } else {
            // Vinculación manual — mostrar sheet si hay sesiones pendientes
            final today = _normalizeDateForPlanning(DateTime.now());
            final planned = await AthleteSessionRepository()
                .getSessionsForDate(uid: uid, date: today);
            final pending = planned
                .where((s) => s.status == AthleteSessionStatus.planned)
                .toList();
            if (pending.isNotEmpty && mounted) {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _LinkSessionSheet(
                  plannedSessions: pending,
                  onLink: (session) async {
                    await AthleteSessionRepository().markAsCompleted(
                      uid:        uid,
                      sessionId:  session.id,
                      trainingId: newTrainingId,
                    );
                    HomeViewModel.needsReload.value++;
                  },
                  parentContext: context,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Error vinculando sesión planificada: $e');
        // no interrumpir el flujo — la vinculación es opcional
      }


      // CAMBIO 4 — fcMediaSesion
      final seriesConFc = seriesSnapshot.where((s) => s.fcMedia != null).toList();
      final double? fcMediaSesion = seriesConFc.isNotEmpty
          ? seriesConFc.map((s) => s.fcMedia!).reduce((a, b) => a + b) / seriesConFc.length
          : null;

      // CAMBIO 5 — actualizar Firestore con fcMediaSesion + loadScore TRIMP
      if (fcMediaSesion != null && _fcMax != null) {
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            final profile = await ZonesRepository().getUserProfile(uid);
            final double distKm = seriesSnapshot.fold<int>(0, (acc, s) => acc + s.distanciaM) / 1000.0;
            final double durMin = seriesSnapshot.fold<double>(0.0, (acc, s) => acc + s.tiempoSec) / 60.0;
            final double load = TrainingLoadService.instance.calculateLoad(
              distanceKm: distKm,
              durationMinutes: durMin,
              fcAvgBpm: fcMediaSesion,
              fcMax: _fcMax!.toDouble(),
              fcRest: profile?.fcReposo?.toDouble(),
            );
            await TrainingRepository().updateTrainingAnalysis(
              uid: uid,
              trainingId: newTrainingId,
              loadScore: load,
              fcMediaSesion: fcMediaSesion,
            );
          }
        } catch (e) {
          debugPrint('[_saveTrainingToFirebase] FC load update error: $e');
        }
      }

      if (!mounted) return;

      final Entrenamiento savedEntrenamiento = Entrenamiento(
        id: newTrainingId,
        titulo: trainingName,
        fecha: DateTime.now(),
        gps: gpsOn,
        series: seriesSnapshot,
        tags: tags.isNotEmpty ? tags : null,
        trackPoints: gpsSnapshot ?? [],
        fcMediaSesion: fcMediaSesion,
      );

      SessionRecoveryService().clearSession();
      setState(() {
        _vm.clearSeries();
        _restTimer?.cancel();
        _isResting = false;
        _restSecondsRemaining = 0;
        _selectedTags.clear();
      });

      ModernSnackBar.showSuccess(
        context,
        '¡Entrenamiento "$trainingName" guardado!',
        duration: const Duration(seconds: 2),
      );

      if (!mounted) return;

      // Detectar nueva marca personal si el entreno tiene GPS
      await _checkForNewPb(savedEntrenamiento);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        AppModalRoute(
          page: TrainingSummaryScreen(entrenamiento: savedEntrenamiento),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;





      String errorMessage = "Error desconocido";
      String errorString = e.toString();


      if (errorString.contains("No hay usuario autenticado")) {
        errorMessage = "Error: No hay usuario autenticado";
      } else if (errorString.contains("PERMISSION_DENIED") ||
          errorString.contains("permiso")) {
        errorMessage =
            "Error: Permiso denegado. Revisa las reglas de Firestore.";
      } else if (e is FirebaseException) {
        errorMessage = e.message ?? "Error de Firebase";
      } else if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = "Error de tipo en Web. ¿Estás logueado?";
      }


      ModernSnackBar.showError(context, errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  Future<void> _checkPersonalRecords(List<Serie> series) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      const standards = {
        400:   [320,  480],
        1000:  [900,  1100],
        1500:  [1275, 1725],
        5000:  [4250, 5750],
        10000: [8500, 11500],
      };

      final existing = await ProgressRepository().getPersonalRecords(uid);

      for (final serie in series) {
        if (serie.distanciaM <= 0 || serie.tiempoSec <= 0) continue;
        final pace = serie.tiempoSec / (serie.distanciaM / 1000);

        for (final entry in standards.entries) {
          final dist  = entry.key;
          final range = entry.value;
          if (serie.distanciaM >= range[0] && serie.distanciaM <= range[1]) {
            final existingRecord = existing[dist];
            if (existingRecord == null || pace < existingRecord.paceSecPerKm) {
              final distLabel = dist < 1000
                  ? '${dist}m'
                  : dist == 1500
                      ? '1.5km'
                      : '${dist ~/ 1000}km';
              final paceMin = pace ~/ 60;
              final paceSec = (pace % 60).round();
              final paceStr =
                  '$paceMin:${paceSec.toString().padLeft(2, '0')}';
              if (mounted) {
                NotificationService().showPersonalRecord(
                  distance: distLabel,
                  pace: paceStr,
                ).catchError((e) => debugPrint('PR notification: $e'));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('checkPersonalRecords error: $e');
    }
  }

  Future<void> _checkForNewPb(Entrenamiento training) async {
    // Solo tiene sentido con GPS activo (distancia fiable)
    if (!training.gps) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final distanceM = training.distanciaTotalM();
      final timeSeconds = training.tiempoTotalSec().round();
      if (distanceM < 1000) return;

      final profile = await AiCoachRepository().getProfile(uid: uid);
      if (profile == null) return;

      final pb = PbDetector.detect(
        distanceM: distanceM,
        timeSeconds: timeSeconds,
        profile: profile,
      );
      if (pb == null) return;

      final updated = PbDetector.applyPb(
        profile: profile,
        field: pb.field,
        seconds: pb.seconds,
      );
      await AiCoachRepository().saveProfile(updated);

      if (!mounted) return;
      final label = PbDetector.labelFor(pb.field);
      ModernSnackBar.showSuccess(
        context,
        '🎉 ¡Nuevo récord en $label! ${PbDetector.format(pb.seconds)}',
      );
    } catch (e) {
      debugPrint('[PbDetector] error: $e');
    }
  }

  void _onLogoTapped() {
    if (_vm.series.isEmpty) {
      Navigator.pop(context);
    } else {
      ModernSnackBar.showWarning(
        context,
        'Por favor, termina el entrenamiento actual antes de salir.',
      );
    }
  }


  // ===================================================================
  // Widgets de la UI
  // ===================================================================


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface2Of(context),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: _buildBody(),
          ),
          if (_isResting) _buildRestScreen(),
        ],
      ),
    );
  }


  void _startContinuousRun() async {
    if (_vm.series.isNotEmpty) {
       bool confirm = await showAppConfirmDialog(
         context: context,
         title: 'Iniciar nueva sesión',
         message: 'Al iniciar una carrera continua se perderán las series actuales. ¿Continuar?',
         confirmLabel: 'Continuar',
         isDestructive: true,
       ) ?? false;
       if (!confirm) return;
    }

    _vm.clearSeries();
    _vm.startContinuousSession();

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      AppRoute(
        page: TrainingSessionView(
          gpsActivo: _vm.gpsOn,
          distancia: "Libre",
          descanso:  "0",
          fcMax:     _fcMax,
        ),
      ),
    );

    if (result != null && result is Serie) {
      _sessionStartTime ??= DateTime.now();
      setState(() {
        if (result.gpsPoints != null) {
          _collectedGpsPoints = result.gpsPoints!.map((m) => GpsPoint.fromMap(m)).toList();
        }
        _vm.addSerie(result);
      });

      SessionRecoveryService().saveSession(
        series: _vm.series,
        gpsOn: _vm.gpsOn,
        startTime: _sessionStartTime!,
        templateName: _vm.source?.templateSnapshot?.name,
      );

      if (mounted) {
        _onFinishTrainingTap();
      }
    }
  }

  void _startContinuousRunWithConfig() async {
    if (_vm.series.isNotEmpty) {
      final confirm = await showAppConfirmDialog(
        context: context,
        title: 'Iniciar nueva sesión',
        message: 'Al iniciar una carrera continua se perderán las series actuales. ¿Continuar?',
        confirmLabel: 'Continuar',
        isDestructive: true,
      ) ?? false;
      if (!confirm) return;
    }

    _vm.clearSeries();
    _vm.startContinuousSession();

    final pace = _cfgPaceParsed();

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      AppRoute(
        page: TrainingSessionView(
          gpsActivo: true,
          distancia: 'Libre',
          descanso:  '0',
          fcMax:     _fcMax,
          targetPaceMinutes: pace?.$1,
          targetPaceSeconds: pace?.$2,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && result is Serie) {
      _sessionStartTime ??= DateTime.now();
      setState(() {
        if (result.gpsPoints != null) {
          _collectedGpsPoints = result.gpsPoints!.map((m) => GpsPoint.fromMap(m)).toList();
        }
        _vm.addSerie(result);
      });

      SessionRecoveryService().saveSession(
        series: _vm.series,
        gpsOn: _vm.gpsOn,
        startTime: _sessionStartTime!,
        templateName: _vm.source?.templateSnapshot?.name,
      );

      if (mounted) _onFinishTrainingTap();
    }
  }

  Widget _buildQuickStartTab() {
     return Padding(
       padding: const EdgeInsets.all(24.0),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.directions_run_rounded, size: 80, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
           const SizedBox(height: 24),
           const Text(
             "Carrera Continua",
             style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
           ),
           const SizedBox(height: 12),
           Text(
             "Registra tu carrera libremente con GPS. \nSin series ni pausas programadas.",
             textAlign: TextAlign.center,
             style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
           ),
           const Spacer(),
           SizedBox(
             width: double.infinity,
             height: 60,
             child: ElevatedButton.icon(
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.brand,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                 elevation: 8,
                 shadowColor: AppColors.brand.withValues(alpha: 0.5),
               ),
               icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
               label: const Text("EMPEZAR AHORA", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1)),
               onPressed: _startContinuousRun,
             ),
           ),
           const SizedBox(height: 40),
         ]
       ),
     );
  }

  Widget _buildTemplatesTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20.0),
                  
                  if (_vm.source != null && _vm.series.isEmpty) ...[
                     _buildTemplateCard(),
                     const SizedBox(height: 16),
                  ],
                  
                  _buildFormContainer(),
                     
                  const SizedBox(height: 24.0),
                  
                  if (_vm.source == null) ...[
                    _buildAlarmSection(),
                    const SizedBox(height: 20.0), 
                  ],

                  if (_vm.series.isEmpty) ...[
                    _buildGpsToggle(),
                    _buildHrToggle(),
                    const SizedBox(height: 30.0),
                  ],
                  Text(
                    'Series Guardadas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    height: 1.0,
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                  ),

                  // Lista de series (no scrollable here, outer scroll handles it)
                  _buildSeriesList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildBody() {
    if (_vm.series.isEmpty && !_isResting) {
      return _buildPreTraining();
    }
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20.0),
                  _buildFormContainer(),
                  const SizedBox(height: 24.0),
                  if (_vm.source == null) ...[
                    _buildAlarmSection(),
                    const SizedBox(height: 20.0),
                  ],
                  Text(
                    'Series Guardadas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    height: 1.0,
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                  ),
                  _buildSeriesList(),
                  const SizedBox(height: 16),
                  if (_vm.source != null) ...[
                    _buildTemplateCard(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  // ── Pre-training redesign ──────────────────────────────────────────────────

  Widget _buildPreTraining() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.l),

          // Rama 0: athleteSessionId explícito desde athlete_hub (prioridad)
          if (widget.athleteSessionId != null && !_ignoreSession)
            _plannedSession != null
                ? _buildSessionCard()
                : const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )

          // Rama 1: sesión planificada para hoy (automática)
          else if (_loadingTodaySession)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_todaySession != null && !_ignoreSession)
            _buildTodaySessionCard(_todaySession!)

          // Rama 2: plantilla cargada manualmente
          else if (_vm.source != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: _buildTemplateCard(),
            ),
            const SizedBox(height: AppSpacing.m),
          ]

          // Rama 3: sin sesión planificada ni plantilla
          else
            _buildNoSessionOptions(),

          _buildAlerts(),
          const SizedBox(height: AppSpacing.xl),
          if (_todaySession == null || _ignoreSession)
            _buildStartButtonNew(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Divider(
        color: AppColors.borderOf(context),
        thickness: 0.5,
        height: 0.5,
      ),
    );
  }

  Widget _buildSessionCard() {
    final session = _plannedSession!;
    const brand = AppColors.brand;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today, color: brand, size: 18),
                ),
                const SizedBox(width: AppSpacing.m),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SESIÓN PLANIFICADA',
                      style: AppTypography.small.copyWith(
                        color: brand,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (session.category != null)
                      Text(
                        session.category!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: AppColors.borderOf(context), thickness: 0.5, height: 0.5),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: [
                if (session.warmup != null)
                  _buildBlockRow(
                    'Calentamiento',
                    durationMinutes: session.warmup!.durationMinutes,
                    icon: Icons.whatshot_outlined,
                  ),
                ...session.blocks.asMap().entries.map(
                  (e) => _buildBlockRow(
                    'Bloque ${e.key + 1}',
                    block: e.value,
                    icon: Icons.directions_run,
                  ),
                ),
                if (session.cooldown != null)
                  _buildBlockRow(
                    'Vuelta calma',
                    durationMinutes: session.cooldown!.durationMinutes,
                    icon: Icons.self_improvement,
                  ),
              ],
            ),
          ),
          Divider(color: AppColors.borderOf(context), thickness: 0.5, height: 0.5),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _ignoreSession = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary(context),
                      side: BorderSide(color: AppColors.borderOf(context)),
                    ),
                    child: const Text('Entrenar libre'),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        AppRoute(
                          page: CompleteSessionManuallyView(
                            session: session,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary(context),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Rellenar manual'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySessionCard(AthleteSession session) {
    const brand = AppColors.brand;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today, color: brand, size: 18),
                ),
                const SizedBox(width: AppSpacing.m),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SESIÓN PLANIFICADA PARA HOY',
                      style: AppTypography.small.copyWith(
                        color: brand,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (session.category != null)
                      Text(
                        session.category!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: AppColors.borderOf(context), thickness: 0.5, height: 0.5),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              children: [
                if (session.warmup != null)
                  _buildBlockRow(
                    'Calentamiento',
                    durationMinutes: session.warmup!.durationMinutes,
                    icon: Icons.whatshot_outlined,
                  ),
                ...session.blocks.asMap().entries.map(
                  (e) => _buildBlockRow(
                    'Bloque ${e.key + 1}',
                    block: e.value,
                    icon: Icons.directions_run,
                  ),
                ),
                if (session.cooldown != null)
                  _buildBlockRow(
                    'Vuelta calma',
                    durationMinutes: session.cooldown!.durationMinutes,
                    icon: Icons.self_improvement,
                  ),
              ],
            ),
          ),
          Divider(color: AppColors.borderOf(context), thickness: 0.5, height: 0.5),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _ignoreSession = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary(context),
                      side: BorderSide(color: AppColors.borderOf(context)),
                    ),
                    child: const Text('Ignorar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _launchPlannedSession(session),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                    ),
                    child: const Text('Empezar sesión'),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  AppRoute(page: CompleteSessionManuallyView(session: session)),
                );
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary(context)),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Completar manualmente'),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
      ),
    );
  }

  void _launchPlannedSession(AthleteSession session) {
    final workoutSession = mapAthleteSessionToWorkout(session);
    if (workoutSession != null) {
      Navigator.of(context).push(AppRoute(
        page: PreExecutionScreen(
          session: workoutSession,
          athleteSession: session,
        ),
      ));
    }
  }

  Widget _buildNoSessionOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué hacemos hoy?',
            style: AppTypography.h2.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.l),

          FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Correr libre'),
            onPressed: _startContinuousRun,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brand,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface2Of(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: _buildSensors(),
          ),
          const SizedBox(height: AppSpacing.m),

          OutlinedButton.icon(
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Planificar sesión de hoy'),
            onPressed: () {
              final today = DateTime.now();
              final dateStr =
                  '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
              MainShell.shellKey.currentState?.navigateTo(
                13,
                params: AthleteSessionShellParams(
                  date: dateStr,
                  session: null,
                  onSaved: (athleteSession) {
                    if (mounted) _launchPlannedSession(athleteSession);
                  },
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              foregroundColor: AppColors.brand,
              side: BorderSide(color: AppColors.brand.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockRow(
    String titulo, {
    SessionBlock? block,
    int? durationMinutes,
    required IconData icon,
  }) {
    final distanceM = block?.distanceM;
    final reps = block?.reps;
    final paceMinMin = block?.targetPaceMinMin;
    final paceMinSec = block?.targetPaceMinSec;
    final paceMaxMin = block?.targetPaceMaxMin;
    final paceMaxSec = block?.targetPaceMaxSec;
    final targetRpe = block?.targetRpe;

    String valueText;
    if (distanceM != null && reps != null && reps > 1) {
      valueText = '${reps}x${distanceM}m';
    } else if (distanceM != null) {
      valueText = '${distanceM}m';
    } else if (durationMinutes != null) {
      valueText = '${durationMinutes} min';
    } else {
      valueText = '-';
    }

    String? paceText;
    if (paceMinMin != null && paceMaxMin != null) {
      final t1 = '$paceMinMin:${(paceMinSec ?? 0).toString().padLeft(2, "0")}';
      final t2 = '$paceMaxMin:${(paceMaxSec ?? 0).toString().padLeft(2, "0")}';
      paceText = '$t1–$t2/km';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Icon(icon, color: AppColors.iconMutedOf(context), size: 16),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              titulo,
              style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
            ),
          ),
          Text(
            valueText,
            style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
          ),
          if (paceText != null) ...[
            const SizedBox(width: AppSpacing.s),
            Text(paceText, style: AppTypography.small.copyWith(color: AppColors.brand)),
          ],
          if (targetRpe != null) ...[
            const SizedBox(width: AppSpacing.s),
            RpeBadge(rpe: targetRpe, size: RpeBadgeSize.text),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Text(
            '¿Qué entrenamos hoy?',
            style: AppTypography.h2.copyWith(color: AppColors.textPrimary(context)),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            children: [
              _buildTypeCard('Continuo', Icons.directions_run, 'continuo'),
              _buildTypeCard('Series', Icons.repeat, 'series'),
              _buildTypeCard('Cuestas', Icons.landscape, 'cuestas'),
              _buildTypeCard('Competición', Icons.emoji_events, 'competicion'),
              _buildTypeCard('Fartlek', Icons.shuffle, 'fartlek'),
            ],
          ),
        ),
        _buildTypeConfig(),
        const SizedBox(height: AppSpacing.m),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.folder_outlined),
            label: const Text('Cargar plantilla'),
            onPressed: () => MainShell.shellKey.currentState?.navigateTo(11),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary(context),
              side: BorderSide(color: AppColors.borderOf(context)),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Helpers de configuración por tipo ----

  /// Parsea "mm:ss" y devuelve (minutos, segundos). Retorna null si inválido.
  (int, int)? _parsePace(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0]);
    final s = int.tryParse(parts[1]);
    if (m == null || s == null || s >= 60) return null;
    return (m, s);
  }

  Widget _cfgTextField(TextEditingController ctrl, String hint, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard ?? TextInputType.number,
      style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary(context)),
        filled: true,
        fillColor: AppColors.surfaceOf(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderOf(context), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderOf(context), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }

  Widget _cfgLabel(String text) => Text(
    text,
    style: AppTypography.small.copyWith(
      color: AppColors.textSecondary(context),
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _cfgSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _cfgLabel(label),
            Text(valueLabel, style: AppTypography.body.copyWith(color: AppColors.brand, fontWeight: FontWeight.w600)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.brand,
            thumbColor: AppColors.brand,
            inactiveTrackColor: AppColors.brand.withValues(alpha: 0.2),
            overlayColor: AppColors.brand.withValues(alpha: 0.1),
            trackHeight: 3,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _cfgStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _cfgLabel(label),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: value <= min ? AppColors.textSecondary(context) : AppColors.brand,
              onPressed: value <= min ? null : () => onChanged(value - 1),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: value >= max ? AppColors.textSecondary(context) : AppColors.brand,
              onPressed: value >= max ? null : () => onChanged(value + 1),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeConfig() {
    final type = _selectedTrainingType;
    Widget content;

    if (type == 'continuo') {
      content = Column(
        key: const ValueKey('continuo'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cfgLabel('Distancia objetivo (km, opcional)'),
          const SizedBox(height: AppSpacing.s),
          _cfgTextField(_cfgDistKmCtrl, 'ej. 10'),
          const SizedBox(height: AppSpacing.m),
          _cfgLabel('Pace objetivo (mm:ss/km, opcional)'),
          const SizedBox(height: AppSpacing.s),
          _cfgTextField(_cfgPaceCtrl, 'ej. 5:30', keyboard: TextInputType.text),
        ],
      );
    } else if (type == 'series') {
      content = Column(
        key: const ValueKey('series'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cfgStepper(
            label: 'Número de series',
            value: _cfgSeries,
            min: 1,
            max: 20,
            onChanged: (v) => setState(() => _cfgSeries = v),
          ),
          const SizedBox(height: AppSpacing.m),
          _cfgLabel('Distancia por serie (metros)'),
          const SizedBox(height: AppSpacing.s),
          NumberPickerField(
            label:     'Distancia por serie',
            value:     _cfgSeriesDist,
            min:       100,
            max:       5000,
            step:      100,
            unit:      'm',
            onChanged: (v) => setState(() => _cfgSeriesDist = v),
          ),
          const SizedBox(height: AppSpacing.m),
          _cfgSliderRow(
            label: 'Descanso entre series',
            value: _cfgDescanso.toDouble(),
            min: 30,
            max: 300,
            divisions: 9,
            valueLabel: _cfgDescanso < 60
                ? '${_cfgDescanso}s'
                : '${_cfgDescanso ~/ 60}min${_cfgDescanso % 60 > 0 ? ' ${_cfgDescanso % 60}s' : ''}',
            onChanged: (v) => setState(() => _cfgDescanso = v.round()),
          ),
          const SizedBox(height: AppSpacing.m),
          _cfgLabel('Pace objetivo por serie (mm:ss/km, opcional)'),
          const SizedBox(height: AppSpacing.s),
          _cfgTextField(_cfgSeriesPaceCtrl, 'ej. 4:15', keyboard: TextInputType.text),
        ],
      );
    } else if (type == 'fartlek') {
      content = Column(
        key: const ValueKey('fartlek'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cfgSliderRow(
            label: 'Duración total',
            value: _cfgFartlekDur.toDouble(),
            min: 20,
            max: 90,
            divisions: 14,
            valueLabel: '${_cfgFartlekDur} min',
            onChanged: (v) => setState(() => _cfgFartlekDur = v.round()),
          ),
          const SizedBox(height: AppSpacing.m),
          _cfgStepper(
            label: 'Bloques rápidos/lentos',
            value: _cfgFartlekBloques,
            min: 2,
            max: 20,
            onChanged: (v) => setState(() => _cfgFartlekBloques = v),
          ),
        ],
      );
    } else {
      content = const SizedBox.shrink(key: ValueKey('none'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(sizeFactor: animation, child: child),
      ),
      child: type == null
          ? const SizedBox.shrink(key: ValueKey('null'))
          : Padding(
              key: ValueKey(type),
              padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, 0),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.l),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderOf(context), width: 0.5),
                ),
                child: content,
              ),
            ),
    );
  }

  Widget _buildTypeCard(String label, IconData icon, String type) {
    final selected = _selectedTrainingType == type;
    const brand = AppColors.brand;
    return GestureDetector(
      onTap: () => _openWorkoutEditor(type),
      child: AnimatedContainer(
        duration: AppMotion.base,
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: selected ? brand.withValues(alpha: 0.08) : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? brand : AppColors.borderOf(context),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: brand, size: 28),
            const SizedBox(height: AppSpacing.s),
            Text(
              label,
              style: AppTypography.body.copyWith(
                color: selected ? brand : AppColors.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensors() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SENSORES',
            style: AppTypography.small.copyWith(
              color: AppColors.textSecondary(context),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          _buildSensorRow(
            icon: _vm.gpsOn ? Icons.gps_fixed : Icons.gps_off,
            label: 'GPS',
            subtitle: _vm.gpsOn ? 'Ubicación activa' : 'Desactivado',
            iconColor: _vm.gpsOn ? AppColors.brand : AppColors.iconMutedOf(context),
            toggle: CupertinoSwitch(
              value: _vm.gpsOn,
              onChanged: (v) => setState(() => _vm.setGpsOn(v)),
              activeTrackColor: AppColors.brand,
            ),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([
              HeartRateService().connectionState,
              HeartRateService().connectedDeviceName,
              HeartRateService().heartRate,
            ]),
            builder: (context, _) {
              final state = HeartRateService().connectionState.value;
              final deviceName = HeartRateService().connectedDeviceName.value;
              final hr = HeartRateService().heartRate.value;
              final isConnected = state == HrConnectionState.connected;
              final isConfigured = deviceName != null || state != HrConnectionState.disconnected;

              final String subtitle;
              if (isConnected && hr != null) {
                subtitle = '$hr bpm';
              } else if (isConnected) {
                subtitle = 'Conectando...';
              } else if (isConfigured) {
                subtitle = 'Desconectado';
              } else {
                subtitle = 'No configurado — toca para configurar';
              }

              return Column(
                children: [
                  Divider(
                    color: AppColors.borderOf(context),
                    thickness: 0.5,
                    height: AppSpacing.m * 2,
                  ),
                  _buildSensorRow(
                    icon: isConnected ? Icons.favorite_rounded : Icons.favorite_border,
                    label: deviceName ?? 'Pulsómetro',
                    subtitle: subtitle,
                    iconColor: isConnected ? AppColors.rpeLow : AppColors.iconMutedOf(context),
                    toggle: CupertinoSwitch(
                      value: _bleEnabled && isConfigured,
                      activeTrackColor: AppColors.brand,
                      onChanged: (v) async {
                        if (!isConfigured) {
                          MainShell.shellKey.currentState?.navigateTo(10);
                          return;
                        }
                        setState(() => _bleEnabled = v);
                        if (v && !isConnected) {
                          final lastId = await HeartRateService().getLastDeviceId();
                          if (lastId != null) HeartRateService().connect(lastId);
                        } else if (!v && isConnected) {
                          HeartRateService().disconnect();
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSensorRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color iconColor,
    required Widget toggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface2Of(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.small.copyWith(color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
          toggle,
        ],
      ),
    );
  }

  Widget _buildAlerts() {
    final summary = _alarmSummaryText();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALERTAS DE RITMO',
            style: AppTypography.small.copyWith(
              color: AppColors.textSecondary(context),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activar alertas',
                style: AppTypography.body.copyWith(color: AppColors.textPrimary(context)),
              ),
              CupertinoSwitch(
                value: _alarmEnabled,
                onChanged: (v) {
                  setState(() => _alarmEnabled = v);
                  _updateAlarmInterval();
                },
                activeTrackColor: AppColors.brand,
              ),
            ],
          ),
          if (_alarmEnabled) ...[
            const SizedBox(height: AppSpacing.s),
            GestureDetector(
              onTap: () => _showAlarmConfigSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m,
                  vertical: AppSpacing.s,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.brand.withValues(alpha: 0.4), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: AppColors.brand, size: 18),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        summary.isNotEmpty ? summary : 'Toca para configurar',
                        style: AppTypography.small.copyWith(
                          color: summary.isNotEmpty
                              ? AppColors.brand
                              : AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                    const Icon(Icons.edit, color: AppColors.brand, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartButtonNew() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: GestureDetector(
          onTap: _showCountdown,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard() {
    final template = _vm.source?.templateSnapshot;
    if (template == null) return const SizedBox.shrink();
    
    // Calculate total from planned blocks
    int totalMeters = 0;
    for(var b in _vm.plannedBlocks) {
      if (b.type == TemplateBlockType.distance) totalMeters += b.value;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _brandAccentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: _brandAccentColor.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: _brandAccentColor.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "PLANTILLA ACTIVA",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _vm.clearTemplate()),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.rpeMax.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: AppColors.rpeMax),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMiniStat(Icons.straighten_rounded, "$totalMeters m", "Distancia total"),
                      const SizedBox(width: 24),
                      _buildMiniStat(Icons.repeat_rounded, "${_vm.plannedBlocks.length} series", "Estructura"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _editActiveTemplate,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text("EDITAR ESTRUCTURA"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                        side: BorderSide(color: _brandAccentColor.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
  Widget _buildSeriesList() {
    final List<Serie> lista = _vm.series;


    if (lista.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Text(
          'Aquí aparecerán las series que realices.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }
    final List<Widget> children = [];


    for (int i = 0; i < lista.length; i++) {
        final Serie serie = lista[i];
        final Key itemKey = ValueKey("${i}_${serie.hashCode}");

        // 1. Ficha de la Serie (Dismissible)
        children.add(
          Dismissible(
            key: itemKey,
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20.0),
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              decoration: BoxDecoration(
                color: AppColors.rpeMax,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            ),
            confirmDismiss: (direction) async {
              return await showModalBottomSheet<bool>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.rpeMax,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.delete_sweep_rounded, color: AppColors.rpeMax, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "¿Borrar esta serie?",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(ctx).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "La serie #${i + 1} se eliminará permanentemente de esta sesión.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.rpeMax,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.rpeMax.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Sí, borrar', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            onDismissed: (direction) {
              setState(() {
                _vm.removeSerieAt(i);
              });
              ModernSnackBar.showInfo(context, 'Serie eliminada');
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
              padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.transparent
                        : Colors.black.withValues(alpha: 0.06),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 1. Badge Índice (Más vivo)
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _brandAccentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _brandAccentColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 2. Datos Principales con Iconos de color
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSerieStat('${serie.distanciaM}m', Icons.straighten, AppColors.rest),
                        _buildSerieStat('${serie.tiempoSec.toStringAsFixed(1)}s', Icons.timer_outlined, AppColors.rpeMid),
                        _buildSerieStat(serie.ritmoTexto(), Icons.speed, AppColors.rpeLow),
                        RpeBadge(rpe: serie.rpe.toDouble(), size: RpeBadgeSize.chip, showIcon: true),
                        if (serie.fcMedia != null)
                          _buildSerieStat('${serie.fcMedia!.round()} ppm', Icons.favorite_rounded, AppColors.rpeMax),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // 2. Fila de Descanso (Entre series)
        if (i < lista.length - 1 && serie.descansoSec > 0) {
           children.add(
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 4.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Container(width: 20, height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                   const SizedBox(width: 8),
                   Icon(Icons.snooze_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
                   const SizedBox(width: 4),
                   Text(
                     _formatDescanso(serie.descansoSec),
                     style: TextStyle(
                       fontSize: 12,
                       color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                       fontWeight: FontWeight.w500,
                     ),
                   ),
                   const SizedBox(width: 8),
                   Container(width: 20, height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                 ],
               ),
             ),
           );
        }
    }

    return Column(children: children);
  }

  Widget _buildSerieStat(String text, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
             fontSize: 12,
             fontWeight: FontWeight.w600,
             color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }


  Widget _buildFormContainer() {
    return Row(
      children: [
        Expanded(
          child: _buildInputCard(
            label: "Distancia",
            value: "${_distanciaSeleccionada}m",
            icon: Icons.straighten,
            onTap: _showDistancePicker,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInputCard(
            label: "Descanso",
            value: _formatMinSec(_descansoSeleccionado),
            icon: Icons.timer_outlined,
            onTap: _showRestPicker,
          ),
        ),
      ],
    );
  }

  void _createMomentaryTemplate() async {
    final TrainingTemplate? newTemplate = await Navigator.push(
      context,
      AppModalRoute(
        page: TemplateEditorView(
          isMomentary: true,
        ),
      ),
    );

    if (newTemplate != null) {
      if (newTemplate.blocks.isEmpty || !mounted) return;
      setState(() {
        _vm.loadTemplate(newTemplate);
        if (_vm.plannedBlocks.isNotEmpty) {
          _applyTemplateBlock(_vm.plannedBlocks[0]);
        }
      });
      ModernSnackBar.showSuccess(context, "Plantilla rápida cargada");
    }
  }

  void _editActiveTemplate() async {
    final template = _vm.source?.templateSnapshot;
    if (template == null) return;
    
    final bool isQuick = _vm.source?.templateId == 'temp';
    
    final modifiedTemplate = await Navigator.push(
      context,
      AppModalRoute(
        page: TemplateEditorView(
          template: template,
          isSelectionMode: true, // Allows "Updated" or "Temporary" choice
          isMomentary: isQuick,  // If it's already a quick one, don't ask to save original
        ),
      ),
    );
    
    if (modifiedTemplate != null) {
      if (!mounted) return;
      setState(() {
         _vm.loadTemplate(modifiedTemplate);
         // Reset to first block of new template if series haven't started?
         // Optimally we try to keep progress but safe bet is restart or just apply next.
         // For now, let's just re-apply current index if possible or 0
         
         final nextIndex = _vm.series.length;
         if (nextIndex < _vm.plannedBlocks.length) {
            _applyTemplateBlock(_vm.plannedBlocks[nextIndex]);
         }
      });
      ModernSnackBar.showSuccess(context, "Plantilla actualizada");
    }
  }

  void _openTemplateSelector() async {
    final TrainingTemplate? selected = await Navigator.push(
      context,
      AppModalRoute(page: const TemplatesListView(isSelectionMode: true)),
    );
    
    if (selected != null) {
      if (!mounted) return;
      setState(() {
        _vm.loadTemplate(selected);
        if (_vm.plannedBlocks.isNotEmpty) {
          _applyTemplateBlock(_vm.plannedBlocks[0]);
        }
      });
      ModernSnackBar.showSuccess(context, "Plantilla cargada");
    }
  }


  Widget _buildInputCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showDistancePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Distancia de la serie", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: Icon(Icons.keyboard, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
                    onPressed: () {
                      Navigator.pop(context);
                      _showManualInputDialog(isDistance: true);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: (_distanciaSeleccionada ~/ 50) - 1, // Aprox
                ),
                onSelectedItemChanged: (index) {
                   if (index == 100) {
                     // Opción "Otro..."
                     // No hacemos nada automático, el usuario debe pulsar el botón de abajo o "OK"
                   } else {
                     setState(() {
                       _distanciaSeleccionada = (index + 1) * 50;
                     });
                   }
                },
                children: [
                  ...List.generate(100, (index) => Center(child: Text("${(index + 1) * 50}m"))),
                  Center(child: Text("Otro...", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
             Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandAccentColor,
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.surface : Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () {
                   // Si el usuario deja "Otro..." seleccionado, abrimos manual
                   // El índice 100 de arriba corresponde a "Otro..." pero el state no se actualiza con ello
                   // Simplemente si quiere manual, pulsará el icono del teclado o seleccionará Otro y luego...
                   // Hack simple: Si selecciona "Otro...", lanzamos el manual
                   // Pero como aqui actualizamos state en tiempo real, es mejor el icono.
                   // O podemos detectar si la selección actual es la última.
                   // Simplificación: Botón OK cierra. Si quiere manual, use el icono o detecta "Otro..."
                   Navigator.pop(context);
                   
                   // Verificar si quedó en "Otro..." podríamos hacerlo controlando el índice scroll
                },
                child: const Text("Seleccionar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showRestPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Tiempo de descanso", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: Icon(Icons.keyboard, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
                    onPressed: () {
                      Navigator.pop(context);
                      _showManualInputDialog(isDistance: false);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: _descansoSeleccionado ~/ 5,
                ),
                onSelectedItemChanged: (index) {
                   if (index == 61) {
                     // Otro...
                   } else {
                     setState(() {
                       _descansoSeleccionado = index * 5;
                     });
                   }
                },
                children: [
                  ...List.generate(61, (index) => Center(child: Text(_formatMinSec(index * 5)))),
                  Center(child: Text("Otro...", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
             Padding(
               padding: const EdgeInsets.all(16.0),
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: _brandAccentColor,
                   foregroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.surface : Colors.white,
                   minimumSize: const Size(double.infinity, 48),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                 ),
                 onPressed: () {
                    // Si el usuario seleccionó "Otro...", abrimos manual
                    // Para simplificar, este botón solo cierra (confirma selección actual)
                    // Si seleccionó "Otro", no se actualizó la variable, así que se queda la anterior.
                    // Lo ideal es que al parar en "Otro", se abra solo? No, mejor click explícito.
                    // Vamos a dejar que el botón "Teclado" sea la vía principal.
                    // Y si paran en "Otro...", al dar "Seleccionar", abrimos input.
                    // Como no trackeamos index aquí facilmente sin otro estado, asumimos botón teclado.
                    Navigator.pop(context);
                 },
                 child: const Text("Seleccionar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
               ),
             ),
          ],
        ),
      ),
    );
  }


  void _showManualInputDialog({required bool isDistance}) {
    final TextEditingController manualController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final int? currentValue = int.tryParse(manualController.text);
          final bool hasValue = currentValue != null;
          final bool isValid = hasValue && (isDistance ? currentValue > 0 : currentValue >= 0);
          
          // Preview text
          String preview = '';
          if (hasValue) {
            if (isDistance) {
              if (currentValue >= 1000) {
                preview = '${(currentValue / 1000).toStringAsFixed(2)} km';
              } else {
                preview = '$currentValue metros';
              }
            } else {
              final int minutes = currentValue ~/ 60;
              final int seconds = currentValue % 60;
              if (minutes > 0) {
                preview = '$minutes min ${seconds}s';
              } else {
                preview = '${seconds}s';
              }
            }
          }
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Título
                  Text(
                    isDistance ? 'Distancia Manual' : 'Descanso Manual',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDistance ? 'Introduce los metros' : 'Introduce los segundos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Input grande
                  TextField(
                    controller: manualController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -1,
                    ),
                    decoration: InputDecoration(
                      hintText: isDistance ? '400' : '90',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                      ),
                      suffixText: isDistance ? 'm' : 's',
                      suffixStyle: TextStyle(
                        fontSize: 24,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                    ),
                    onChanged: (value) => setModalState(() {}),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Preview
                  AnimatedContainer(
                    duration: AppMotion.base,
                    height: hasValue ? 32 : 0,
                    child: hasValue
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isValid ? Icons.check_circle : Icons.error,
                                color: isValid ? AppColors.rpeLow : AppColors.rpeMax,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                preview,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isValid ? AppColors.rpeLow : AppColors.rpeMax,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: !isValid
                              ? null
                              : () {
                                  setState(() {
                                    if (isDistance) {
                                      _distanciaSeleccionada = currentValue!;
                                    } else {
                                      _descansoSeleccionado = currentValue!;
                                    }
                                  });
                                  Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandAccentColor,
                            foregroundColor: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.surface : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: isValid ? 4 : 0,
                            shadowColor: _brandAccentColor.withValues(alpha: 0.4),
                          ),
                          child: const Text(
                            'Aceptar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ===============================================================
  // SECCIÓN DE ALARMA
  // ===============================================================


  Widget _buildAlarmSection() {
    final String summary = _alarmSummaryText();
    final bool hasSpecificConfig = _alarmEnabled && summary.isNotEmpty;


    return GestureDetector(
      onTap: () {
        if (_alarmEnabled) {
          _showAlarmConfigSheet(context);
        }
      },
      child: AnimatedContainer(
        duration: AppMotion.slow,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
              color: _alarmEnabled ? AppColors.brand.withValues(alpha: 0.5) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: _alarmEnabled ? 2.0 : 1.0),
          boxShadow: [
            BoxShadow(
              color: _alarmEnabled
                  ? AppColors.brand.withValues(alpha: 0.1)
                  : Theme.of(context).brightness == Brightness.dark
                      ? Colors.transparent
                      : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
               Icon(
                _alarmEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                color: _alarmEnabled ? _brandAccentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avisos de Ritmo',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: _alarmEnabled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (hasSpecificConfig)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          summary,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                          ),
                        ),
                      )
                    else if (_alarmEnabled)
                       Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "Toca para configurar",
                          style: TextStyle(fontSize: 12.0, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                  ],
                ),
              ),
              if (_alarmEnabled)
                 IconButton(
                   icon: Icon(Icons.edit, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
                   onPressed: () => _showAlarmConfigSheet(context),
                 ),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: _alarmEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _alarmEnabled = value;
                    });
                    _updateAlarmInterval();
                    if (value) {
                       // Optional: Auto-open sheet when enabling?
                       // _showAlarmConfigSheet(context);
                    }
                  },
                  activeThumbColor: AppColors.brand,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)
                      : AppColors.surface2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showAlarmConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: 600, // Increased to remove scroll
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              // Helper to update both modal and parent state
              void updateState(VoidCallback fn) {
                setModalState(fn);
                setState(fn);
                _updateAlarmInterval();
              }


              return Column(
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Configurar Alarma",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Listo", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, fontWeight: FontWeight.w600)),
                        )
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: CupertinoSlidingSegmentedControl<AlarmMode>(
                                groupValue: _alarmMode,
                                thumbColor: _brandAccentColor,
                                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                                children: {
                                  AlarmMode.bySeconds: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text(
                                      'Por Tiempo',
                                      style: TextStyle(
                                        color: _alarmMode == AlarmMode.bySeconds ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  AlarmMode.byPace: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text(
                                      'Por Ritmo',
                                      style: TextStyle(
                                        color: _alarmMode == AlarmMode.byPace ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                },
                                onValueChanged: (AlarmMode? val) {
                                  if (val != null) {
                                    updateState(() {
                                      _alarmMode = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 30),
                            if (_alarmMode == AlarmMode.bySeconds)
                              _buildAlarmBySecondsClean(updateState)
                            else
                              _buildAlarmByPaceClean(updateState),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }


  Widget _buildAlarmBySecondsClean(void Function(VoidCallback) updateState) {
    return SizedBox(
      height: 160,
      child: Row(
        children: [
          // MINUTOS
          Expanded(
            child: _buildCupertinoWheel(
              label: 'min',
              itemCount: 60,
              initialItem: _timeMin,
              onChanged: (val) {
                updateState(() => _timeMin = val);
              },
              textBuilder: (index) => index.toString(),
            ),
          ),
          // SEGUNDOS
          Expanded(
            child: _buildCupertinoWheel(
              label: 'sec',
              itemCount: 120,
              initialItem: _timeSecHalfIndex,
              onChanged: (val) {
                updateState(() => _timeSecHalfIndex = val);
              },
              textBuilder: (index) => (index * 0.5).toStringAsFixed(1),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAlarmByPaceClean(void Function(VoidCallback) updateState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text("Marca tu ritmo objetivo", style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: Row(
            children: [
              // Pace Min
              Expanded(
                child: _buildCupertinoWheel(
                  label: 'min',
                  itemCount: 30, // de 0 a 29, ajustaremos para que empiece en 2
                  initialItem: (_paceMin - 2).clamp(0, 28),
                  onChanged: (val) {
                    updateState(() => _paceMin = val + 2);
                  },
                  textBuilder: (index) => (index + 2).toString(),
                ),
              ),
              // Pace Sec
              Expanded(
                child: _buildCupertinoWheel(
                  label: 'sec',
                  itemCount: 12, // 0, 5, ... 55
                  initialItem: _paceSecIndex,
                  onChanged: (val) {
                    updateState(() => _paceSecIndex = val);
                  },
                  textBuilder: (index) => (index * 5).toString().padLeft(2, '0'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text("Sonar cada:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: _buildCupertinoWheel(
            label: 'metros',
            itemCount: _segmentDistances.length,
            initialItem: _segmentIndex,
            onChanged: (val) {
              updateState(() => _segmentIndex = val);
            },
            textBuilder: (index) => _segmentDistances[index].toString(),
          ),
        ),
      ],
    );
  }


  Widget _buildCupertinoWheel({
    required String label,
    required int itemCount,
    required int initialItem,
    required ValueChanged<int> onChanged,
    required String Function(int) textBuilder,
  }) {
    return Center(
      child: IosPicker(
        label: label,
        itemCount: itemCount,
        initialItem: initialItem,
        itemExtent: 32,
        width: 70,
        onChanged: onChanged,
        textBuilder: textBuilder,
      ),
    );
  }

  String _formatDescanso(int totalSeconds) {
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }


  Widget _buildGpsToggle() {
    return AnimatedContainer(
      duration: AppMotion.slow,
      margin: const EdgeInsets.only(top: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: _vm.gpsOn ? _brandAccentColor.withValues(alpha: 0.5) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: _vm.gpsOn ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _vm.gpsOn
                ? _brandAccentColor.withValues(alpha: 0.1)
                : Theme.of(context).brightness == Brightness.dark
                    ? Colors.transparent
                    : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _vm.gpsOn ? Icons.location_on : Icons.location_off_outlined,
                color: _vm.gpsOn ? _brandAccentColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                size: 28,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registro GPS',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: _vm.gpsOn ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                   if (_vm.gpsOn)
                    Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Ubicación activa",
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: _vm.gpsOn,
              onChanged: (bool value) {
                setState(() {
                  _vm.setGpsOn(value);
                });

              },
              activeThumbColor: AppColors.brand,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)
                  : AppColors.surface2,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHrToggle() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        HeartRateService().connectionState,
        HeartRateService().connectedDeviceName,
      ]),
      builder: (context, _) {
        final state       = HeartRateService().connectionState.value;
        final isConnected = state == HrConnectionState.connected;
        final deviceName  = HeartRateService().connectedDeviceName.value ?? 'Pulsómetro';

        return AnimatedContainer(
          duration: AppMotion.slow,
          margin: const EdgeInsets.only(top: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: isConnected
                  ? AppColors.rpeMax.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: isConnected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isConnected
                    ? AppColors.rpeMax.withValues(alpha: 0.08)
                    : Theme.of(context).brightness == Brightness.dark
                        ? Colors.transparent
                        : Colors.black.withValues(alpha: 0.05),
                blurRadius: 10.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isConnected ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: isConnected
                        ? AppColors.rpeMax
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? deviceName : 'Pulsómetro',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (isConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Conectado',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.rpeMax,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: isConnected,
                  onChanged: (val) async {
                    if (val) {
                      final lastId = await HeartRateService().getLastDeviceId();
                      if (lastId != null) {
                        HeartRateService().connect(lastId);
                      } else {
                        // context.mounted: el context es del builder, no del State
                        if (!context.mounted) return;
                        await Navigator.push(
                          context,
                          AppRoute(page: const HeartRateMonitorView()),
                        );
                      }
                    } else {
                      HeartRateService().disconnect();
                    }
                  },
                  activeThumbColor: AppColors.rpeMax,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)
                      : AppColors.surface2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===================================================================
  // Template Buttons Section
  // ===================================================================

  Widget _buildTemplateButtons() {
    return Row(
      children: [
        // Load Template Card
        Expanded(
          child: _buildActionCard(
            onTap: _openTemplateSelector,
            icon: Icons.folder_open_rounded,
            title: 'Cargar\nPlantilla',
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
          ),
        ),
        const SizedBox(width: 12),
        // Quick Template Card
        Expanded(
          child: _buildActionCard(
            onTap: _createMomentaryTemplate,
            icon: Icons.bolt_rounded,
            title: 'Plantilla\nRápida',
            color: AppColors.rpeMid,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return StatefulBuilder(
      builder: (context, setCardState) {
        bool isPressed = false;
        return GestureDetector(
          onTapDown: (_) => setCardState(() => isPressed = true),
          onTapUp: (_) {
            setCardState(() => isPressed = false);
            onTap();
          },
          onTapCancel: () => setCardState(() => isPressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            height: 110,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: isPressed ? 0.3 : 0.1), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isPressed ? 0.05 : 0.08),
                  blurRadius: isPressed ? 4 : 12,
                  offset: Offset(0, isPressed ? 2 : 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildContinuousRunButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: _brandAccentColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _brandAccentColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _startContinuousRun,
          borderRadius: BorderRadius.circular(20),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_run_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'CARRERA CONTINUA',
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 15, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ===================================================================
  // Pantalla de descanso (overlay completo)
  // ===================================================================

  static Color _rpeColor(double v) {
    if (v <= 4) return AppColors.rpeLow;
    if (v <= 7) return AppColors.rpeMid;
    return AppColors.rpeMax;
  }

  Widget _buildRestScreen() {
    final double fillProgress = _restTotalSeconds > 0
        ? 1.0 - (_restSecondsRemaining / _restTotalSeconds)
        : 1.0;

    final Serie? lastSerie = _vm.series.isNotEmpty ? _vm.series.last : null;

    String distText = '';
    String timeText = '';
    String paceText = '';
    double? fcMedia;

    if (lastSerie != null) {
      distText = '${lastSerie.distanciaM}m';
      final int totalSec = lastSerie.tiempoSec.round();
      final int mm = totalSec ~/ 60;
      final int ss = totalSec % 60;
      timeText = '$mm:${ss.toString().padLeft(2, '0')}';
      try {
        paceText = lastSerie.ritmoTexto().replaceAll(' /km', '');
      } catch (_) {
        paceText = '--:--';
      }
      fcMedia = lastSerie.fcMedia;
    }

    final int completedIndex = _vm.series.length;
    final bool hasNext = _distanciaSeleccionada > 0;
    final String nextDistText = '${_distanciaSeleccionada}m';

    return Positioned.fill(
      child: Stack(
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _RestFillPainter(progress: fillProgress),
              child: const SizedBox.expand(),
            ),
          ),
          ...List.generate(8, (i) => RepaintBoundary(child: _FloatingBubble(index: i, progress: fillProgress))),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Text(
                  '${_restSecondsRemaining}s',
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A3A5A),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Descansando',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF1A3A5A).withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                if (lastSerie != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                    padding: const EdgeInsets.all(AppSpacing.l),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SERIE $completedIndex COMPLETADA',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF378ADD),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _RestStat('Distancia', distText),
                            _RestStat('Tiempo', timeText),
                            _RestStat('Pace', paceText),
                            if (fcMedia != null)
                              _RestStat('FC', '${fcMedia.round()} bpm'),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.m),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Column(
                    children: [
                      const Text(
                        'RPE de la serie',
                        style: TextStyle(fontSize: 12, color: Color(0xFF378ADD)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.s),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _restRpe,
                          min: 1,
                          max: 10,
                          divisions: 18,
                          activeColor: _rpeColor(_restRpe),
                          inactiveColor: _rpeColor(_restRpe).withValues(alpha: 0.2),
                          onChanged: (v) => setState(() => _restRpe = v),
                        ),
                      ),
                      Text(
                        _restRpe.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _rpeColor(_restRpe),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                if (hasNext)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.skip_next, color: Color(0xFF378ADD), size: 18),
                        const SizedBox(width: AppSpacing.s),
                        Text(
                          'Siguiente: Serie ${completedIndex + 1} — $nextDistText',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1A3A5A)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.m),
                TextButton(
                  onPressed: _skipRest,
                  child: const Text(
                    'Saltar descanso',
                    style: TextStyle(fontSize: 12, color: Color(0xFF378ADD)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // Footer Dinámico
  // ===================================================================


  Widget _buildFooter() {
    return _isResting ? const SizedBox.shrink() : _buildStartButtonFooter();
  }


  Widget _buildStartButtonFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: isDark
          ? BoxDecoration(color: Theme.of(context).colorScheme.surface)
          : const BoxDecoration(
              color: Colors.white,
              image: DecorationImage(
                image: AssetImage('assets/images/fondo.png'),
                fit: BoxFit.cover,
              ),
            ),
      child: Column(
        children: [
          Container(height: 1.0, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 10.0, // Reduced from 20.0
              horizontal: 40.0,
            ),
            child: (_vm.series.isEmpty)
                ? _buildCircularButton(
                    icon: Icons.play_arrow,
                    onTap: _onStartSeriesTap,
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCircularButton(
                        icon: Icons.play_arrow,
                        onTap: _onStartSeriesTap,
                      ),
                      _buildCircularButton(
                        icon: Icons.close,
                        onTap: _onFinishTrainingTap,
                        color: AppColors.rpeMax,
                        isLoading: _isSaving,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }


  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(15.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (color ?? AppColors.brand).withValues(alpha: 0.2),
              blurRadius: 20.0,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: 15.0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                width: 40.0,
                height: 40.0,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              )
            : Icon(icon, color: color ?? AppColors.brand, size: 40.0),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LinkSessionSheet
// ─────────────────────────────────────────────────────────────────────────────

class _LinkSessionSheet extends StatelessWidget {
  final List<AthleteSession> plannedSessions;
  final Future<void> Function(AthleteSession) onLink;
  final BuildContext parentContext;

  const _LinkSessionSheet({
    required this.plannedSessions,
    required this.onLink,
    required this.parentContext,
  });

  String _categoryLabel(String? cat) {
    if (cat == null) return 'Sin tipo';
    try {
      return SessionCategoryX.fromValue(cat).label;
    } catch (_) {
      return cat;
    }
  }

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'regenerativo':                        return AppColors.rest;
      case 'rodaje_base':                         return AppColors.rpeLow;
      case 'tempo':
      case 'fartlek':                             return AppColors.rpeMid;
      case 'series_largas':
      case 'series_cuestas':
      case 'series_mixtas':                       return AppColors.effort;
      case 'series_cortas':
      case 'competicion':                         return AppColors.rpeMax;
      default:                                    return AppColors.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width:  40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFAAAAAA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '¿Vincular con sesión planificada?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Tenías estas sesiones planificadas para hoy',
                style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
              ),
            ),
            const SizedBox(height: 16),

            // Session list (máx 3)
            ...plannedSessions.take(3).map((s) {
              final color = _categoryColor(s.category);
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(children: [
                  Container(
                    width:  10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _categoryLabel(s.category),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (s.time != null)
                          Text(
                            s.time!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFAAAAAA)),
                          ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await onLink(s);
                      if (context.mounted) Navigator.pop(context);
                      if (parentContext.mounted) {
                        ModernSnackBar.showSuccess(
                            parentContext, 'Sesión completada ✓');
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Vincular',
                        style: TextStyle(fontSize: 13)),
                  ),
                ]),
              );
            }),

            const SizedBox(height: 12),

            // Skip button
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFAAAAAA)),
                child: const Text('Omitir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _HrRecoveryLabel ──────────────────────────────────────────────────────────
// Muestra la FC actual durante el descanso para monitorizar la recuperación.

class _HrRecoveryLabel extends StatelessWidget {
  final int? fcMax;

  const _HrRecoveryLabel({this.fcMax});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        HeartRateService().connectionState,
        HeartRateService().heartRate,
      ]),
      builder: (context, _) {
        final state = HeartRateService().connectionState.value;
        final hr    = HeartRateService().heartRate.value;

        if (state != HrConnectionState.connected || hr == null) {
          return const SizedBox.shrink();
        }

        // Umbral de recuperación: 65 % de fcMax, o 120 ppm si no hay fcMax
        final threshold = fcMax != null ? (fcMax! * 0.65).round() : 120;
        final ready     = hr <= threshold;

        return Text(
          ready ? 'Listo para la siguiente' : 'Recuperando · $hr ppm',
          style: TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w500,
            color:      ready
                ? AppColors.rpeLow
                : AppColors.rpeMax,
          ),
        );
      },
    );
  }
}

// ── _RestFillPainter ──────────────────────────────────────────────────────────

class _RestFillPainter extends CustomPainter {
  final double progress; // 0.0 = inicio, 1.0 = fin descanso

  const _RestFillPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final fillHeight = size.height * progress;
    final top = size.height - fillHeight;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    if (fillHeight <= 0) return;

    final fillColor = Color.lerp(
      const Color(0xFFE3F2FD),
      const Color(0xFFBBDEFB),
      progress,
    )!;

    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, fillHeight),
      Paint()..color = fillColor,
    );
  }

  @override
  bool shouldRepaint(_RestFillPainter old) => old.progress != progress;
}

// ── _RestStat ────────────────────────────────────────────────────────────────

class _RestStat extends StatelessWidget {
  final String label;
  final String value;

  const _RestStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A3A5A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF378ADD),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── _FloatingBubble ───────────────────────────────────────────────────────────

class _FloatingBubble extends StatefulWidget {
  final int index;
  final double progress;

  const _FloatingBubble({required this.index, required this.progress});

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const List<double> _xFractions = [
    0.08, 0.22, 0.38, 0.52, 0.65, 0.78, 0.88, 0.95,
  ];
  static const List<double> _sizes = [8, 14, 10, 18, 12, 9, 16, 11];
  static const List<double> _durations = [4.0, 3.5, 5.0, 3.0, 4.5, 6.0, 3.8, 5.5];
  static const List<double> _opacities = [0.5, 0.6, 0.4, 0.7, 0.45, 0.55, 0.65, 0.4];

  @override
  void initState() {
    super.initState();
    final sec = _durations[widget.index % _durations.length];
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (sec * 1000).round()),
    )..repeat();
    // Offset so bubbles don't all start at same position
    _ctrl.forward(from: (widget.index * 0.13) % 1.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.progress < 0.05) return const SizedBox.shrink();

    final size = _sizes[widget.index % _sizes.length];
    final xFrac = _xFractions[widget.index % _xFractions.length];
    final opacity = _opacities[widget.index % _opacities.length];

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final fillStart = screenHeight * (1.0 - widget.progress);
        final travelHeight = screenHeight * widget.progress;

        final yFromTop = fillStart + travelHeight * (1.0 - _ctrl.value) - size;

        return Positioned(
          left: screenWidth * xFrac - size / 2,
          top: yFromTop,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Color(0xFF90CAF9),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountdownDialog extends StatefulWidget {
  final VoidCallback onComplete;
  const _CountdownDialog({required this.onComplete});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  late Timer _timer;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 1.4, end: 0.8).animate(
      CurvedAnimation(parent: _animController, curve: AppMotion.easeEnter),
    );
    _animController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_count <= 1) {
        _timer.cancel();
        widget.onComplete();
      } else {
        setState(() => _count--);
        _animController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Text(
            '$_count',
            style: const TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
