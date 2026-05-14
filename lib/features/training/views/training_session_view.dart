import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Para SystemSound
import 'dart:math' show pi;
import 'dart:ui' show FontFeature;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../../core/widgets/modern_snackbar.dart';
import '../../../core/services/settings_service.dart';

import '../data/serie.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/constants/app_help_content.dart';
import 'package:running_laps/core/widgets/info_tooltip.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/gps_service.dart';
import '../../../core/services/zones_service.dart';
import '../../../core/services/heart_rate_service.dart';


class TrainingSessionView extends StatefulWidget {
  final String distancia;
  final String descanso;
  final bool gpsActivo;
  final int? alarmIntervalMs;
  final int? currentSeries;
  final int? totalSeries;

  // Objetivos de bloque (opcionales — solo se muestran si se pasan)
  final int? targetPaceMinutes;
  final int? targetPaceSeconds;
  final int? targetPaceMaxMinutes;
  final int? targetPaceMaxSeconds;
  final double? targetRpe;
  final int? targetZone;
  final int? fcMax;

  const TrainingSessionView({
    Key? key,
    required this.distancia,
    required this.descanso,
    required this.gpsActivo,
    this.alarmIntervalMs,
    this.currentSeries,
    this.totalSeries,
    this.targetPaceMinutes,
    this.targetPaceSeconds,
    this.targetPaceMaxMinutes,
    this.targetPaceMaxSeconds,
    this.targetRpe,
    this.targetZone,
    this.fcMax,
  }) : super(key: key);


  @override
  _TrainingSessionViewState createState() => _TrainingSessionViewState();
}


class _TrainingSessionViewState extends State<TrainingSessionView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // --- Estado del Cronómetro ---
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _tiempoMostrado = "00:00.00";
  bool _isRunning = true;

  // --- Valores serie ---
  double _rpeSeleccionado = 5.0; // RPE inicial (escala 1-10)
  int _distanciaInt = 0;
  int _descansoInt = 0;

  // --- Alarma ---
  Timer? _beepTimer;
  int? _alarmIntervalMs;
  bool _isAlarmActive = false; // Para efecto visual

  // --- GPS ---
  GPSService? _gpsService;
  double _distanciaGpsMetros = 0.0;
  String _ritmoActual = "--:-- /km";
  Timer? _gpsUpdateTimer;

  // NUEVO: Momento exacto en que se detuvo la serie
  DateTime? _finishedAt;

  // --- Acumulador FC para media de la serie ---
  final List<int> _hrReadings = [];

  // --- Demo mode (set to false for production) ---
  static const bool _demoMode = false;

  // --- Colores ---
  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  // --- Fade animation ---
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // --- Pulse animation (status dot for Libre mode) ---
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Fade-in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    // Suscribirse a FC para acumular lecturas durante la serie
    HeartRateService().heartRate.addListener(_onHrChanged);
    HeartRateService().connectionState.addListener(_onHrChanged);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Parsear los valores de la serie
    _distanciaInt = int.tryParse(widget.distancia) ?? 0;
    _descansoInt = int.tryParse(widget.descanso) ?? 0;

    // Intervalo de alarma recibido
    _alarmIntervalMs = widget.alarmIntervalMs;

    // Iniciar el cronómetro
    _stopwatch.start();
    _startTimer();
    _startBeepTimerIfNeeded();

    // Iniciar GPS (o solo la notificación foreground) según configuración
    if (widget.gpsActivo) {
      _initializeGPS();
    } else {
      _initializeNotificationService();
    }
  }

  /// Inicializa el GPS service
  Future<void> _initializeGPS() async {
    _gpsService = GPSService();

    // Register the notification-button listener immediately after construction
    // so we never miss an event, even before startTracking() is called.
    _gpsService!.notificationAction.addListener(_onNotificationAction);

    final bool initialized = await _gpsService!.initialize();

    if (initialized) {
      // "Libre" means a continuous free run; any integer distance is an interval.
      final mode = widget.distancia == 'Libre'
          ? TrackingMode.continuous
          : TrackingMode.intervals;

      // Load persisted stride length before starting so the first ticks
      // benefit from the previously calibrated value.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _gpsService!.loadStrideLength(uid);
      }

      await _gpsService!.startTracking(
        mode: mode,
        serieNumber: widget.currentSeries ?? 1,
      );
      // UI is reactive via ValueListenableBuilder; a single rebuild gives
      // builders access to the now-initialised _gpsService.
      setState(() {});
    } else {
      // Mostrar error específico según el estado del GPS
      if (mounted) {
        String errorMessage = 'No se pudo activar el GPS.';
        String actionMessage = '';

        if (_gpsService!.status.value == GpsStatus.disabled) {
          errorMessage = '📍 GPS desactivado';
          actionMessage = 'Activa la ubicación en los ajustes de tu móvil';
        } else if (_gpsService!.status.value == GpsStatus.permissionDenied) {
          errorMessage = '🔒 Permisos de ubicación denegados';
          actionMessage = 'Ve a Ajustes → Apps → Running Laps → Permisos → Ubicación';
        } else {
          errorMessage = '❌ Error al iniciar GPS';
          actionMessage = 'Verifica que el GPS esté activo y los permisos estén dados';
        }

        ModernSnackBar.showError(
          context,
          '$errorMessage${actionMessage.isNotEmpty ? '\n$actionMessage' : ''}',
          duration: const Duration(seconds: 6),
        );
      }
    }
  }


  /// Starts the foreground notification service without GPS tracking.
  ///
  /// Creates a [GPSService] purely for its foreground-service machinery.
  /// The notification will show the serie number and the stopwatch elapsed
  /// time, updated every ~30 ms by [_startTimer].
  Future<void> _initializeNotificationService() async {
    _gpsService = GPSService();
    _gpsService!.notificationAction.addListener(_onNotificationAction);

    final mode = widget.distancia == 'Libre'
        ? TrackingMode.continuous
        : TrackingMode.intervals;

    await _gpsService!.startNotificationOnly(
      mode: mode,
      serieNumber: widget.currentSeries ?? 1,
    );
  }

  void _onHrChanged() {
    final hr    = HeartRateService().heartRate.value;
    final state = HeartRateService().connectionState.value;
    if (hr != null && hr > 0 && state == HrConnectionState.connected) {
      _hrReadings.add(hr);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _stopwatch.isRunning) {
      // Force one immediate UI refresh so the displayed time
      // catches up after iOS/Android throttled the Timer.
      if (mounted) {
        setState(() {
          _tiempoMostrado = _formatTiempo(_stopwatch.elapsed);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HeartRateService().heartRate.removeListener(_onHrChanged);
    HeartRateService().connectionState.removeListener(_onHrChanged);
    _pulseController.dispose();
    _fadeController.dispose();
    _timer?.cancel();
    _beepTimer?.cancel();
    _gpsUpdateTimer?.cancel();
    // Remove listener BEFORE dispose() so we never call into a disposed notifier.
    _gpsService?.notificationAction.removeListener(_onNotificationAction);
    _gpsService?.dispose();
    _stopwatch.stop();
    super.dispose();
  }


  // ===================================================================
  // LÓGICA DEL CRONÓMETRO
  // ===================================================================


  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (Timer timer) {
      if (_stopwatch.isRunning) {
        setState(() {
          _tiempoMostrado = _formatTiempo(_stopwatch.elapsed);
        });
        // When GPS is off, keep the foreground notification elapsed in sync.
        if (!widget.gpsActivo) {
          _gpsService?.setExternalElapsed(
            _formatNotificationElapsed(_stopwatch.elapsed),
          );
        }
      }
    });
  }

  /// Formats a [Duration] as "MM:SS" for the foreground notification.
  String _formatNotificationElapsed(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }


  // ===================================================================
  // LÓGICA DE LA ALARMA
  // ===================================================================

  void _startBeepTimerIfNeeded() {
    _beepTimer?.cancel();

    if (_alarmIntervalMs != null && _alarmIntervalMs! > 0 && _isRunning) {
      _beepTimer = Timer.periodic(Duration(milliseconds: _alarmIntervalMs!), (
        Timer timer,
      ) {
        // 1. Sonido (Notificación fuerte)
        FlutterRingtonePlayer().playNotification();

        // 2. Efecto Visual (Pulse)
        if (mounted) {
          setState(() {
            _isAlarmActive = true;
          });

          // Apagar el efecto después de 500ms
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _isAlarmActive) {
              setState(() {
                _isAlarmActive = false;
              });
            }
          });
        }
      });
    }
  }


  void _stopBeepTimer() {
    _beepTimer?.cancel();
    _beepTimer = null;
  }


  // ===================================================================
  // ACCIONES: PAUSAR / REANUDAR / GUARDAR
  // ===================================================================


  /// Handles taps on the persistent notification action button (lock screen /
  /// background). Both 'end_serie' and 'finish_run' delegate to [_finishSeries],
  /// which already handles both interval and continuous sessions correctly.
  void _onNotificationAction() {
    final action = _gpsService?.notificationAction.value;
    if (action == null || !_isRunning) return;
    if (action == 'end_serie' || action == 'finish_run') {
      _finishSeries();
    }
  }

  void _finishSeries() {
    // 1. Detener todo INMEDIATAMENTE
    _stopwatch.stop();
    _timer?.cancel();
    _stopBeepTimer();
    _gpsService?.pause();

    setState(() {
      _isRunning = false;
      // 2. Guardar timestamp de finalización para calcular descanso real
      _finishedAt = DateTime.now();
    });

    // 3. Mostrar selector de RPE (Bloqueante, sin reanudar)
    _showRpePicker();
  }


  void _handleResume() {
    // Reanudar crono
    _stopwatch.start();
    _startTimer();
    _gpsService?.resume(); // Reanudar GPS

    setState(() {
      _isRunning = true;
    });

    // Reanudar alarma si procede
    _startBeepTimerIfNeeded();
  }


  void _handleSave() {
    // Detener todo
    _timer?.cancel();
    _stopBeepTimer();
    _stopwatch.stop();

    // 1. Obtener tiempo final en segundos
    final double tiempoFinalSec = _stopwatch.elapsed.inMilliseconds / 1000.0;

    // FC media acumulada durante la serie
    final List<int>? fcReadings = _hrReadings.isNotEmpty
        ? List<int>.from(_hrReadings) : null;
    final double? fcMedia = fcReadings != null
        ? fcReadings.reduce((a, b) => a + b) / fcReadings.length
        : null;
    debugPrint('[FC] Serie terminada — lecturas: ${fcReadings?.length ?? 0}, media: $fcMedia');
    _hrReadings.clear();

    // 2. Crear el objeto Serie (sin GPS)
    final Serie serieTerminada = Serie(
      tiempoSec: tiempoFinalSec,
      distanciaM: _distanciaInt, // Distancia manual
      descansoSec: _descansoInt,
      rpe: _rpeSeleccionado,
      usedGps: false,
      usedGpsDistance: null,
      gpsPoints: null,
      finishedAt: _finishedAt,
      fcMedia: fcMedia,
      fcReadings: fcReadings,
    );

    // 3. Cerrar el diálogo de RPE
    // El diálogo ya está cerrado porque awaiting por el resultado en _showRpePicker

    // 4. Volver a la pantalla anterior devolviendo la serie
    Navigator.of(context).pop(serieTerminada);
  }

  /// Guardar con distancia seleccionada (GPS o manual)
  void _saveWithSelectedDistance(int distanciaFinal, bool usedGpsDistance) {
    // Detener todo
    _timer?.cancel();
    _stopBeepTimer();
    _gpsUpdateTimer?.cancel();
    _stopwatch.stop();

    // 1. Obtener tiempo final en segundos
    final double tiempoFinalSec = _stopwatch.elapsed.inMilliseconds / 1000.0;

    // FC media acumulada durante la serie
    final List<int>? fcReadings = _hrReadings.isNotEmpty
        ? List<int>.from(_hrReadings) : null;
    final double? fcMedia = fcReadings != null
        ? fcReadings.reduce((a, b) => a + b) / fcReadings.length
        : null;
    debugPrint('[FC] Serie GPS terminada — lecturas: ${fcReadings?.length ?? 0}, media: $fcMedia');
    _hrReadings.clear();

    // 2. Convertir puntos GPS a Map
    List<Map<String, dynamic>>? gpsPointsMaps;
    if (_gpsService != null) {
      gpsPointsMaps = _gpsService!.points
          .map((point) => point.toMap())
          .toList();
    }

    // 3. Crear el objeto Serie con GPS
    final Serie serieTerminada = Serie(
      tiempoSec: tiempoFinalSec,
      distanciaM: distanciaFinal, // Distancia elegida por el usuario
      descansoSec: _descansoInt,
      rpe: _rpeSeleccionado,
      usedGps: true,
      usedGpsDistance: usedGpsDistance,
      gpsPoints: gpsPointsMaps,
      finishedAt: _finishedAt,
      fcMedia: fcMedia,
      fcReadings: fcReadings,
    );

    // 4. Volver a la pantalla anterior devolviendo la serie
    Navigator.of(context).pop(serieTerminada);
  }


  // ===================================================================
  // FORMATEADORES
  // ===================================================================


  String _formatTiempo(Duration duration) {
    String twoDigits(int n) {
      return n.toString().padLeft(2, '0');
    }


    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String hundredths = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return "$twoDigitMinutes:$twoDigitSeconds.$hundredths";
  }


  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDescanso(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes > 0) {
      return "${minutes}m${seconds.toString().padLeft(2, '0')}s";
    } else {
      return "${seconds}s";
    }
  }


  // ===================================================================
  // HELPERS COLOR
  // ===================================================================

  Color _getPaceColor(String paceString) {
    if (paceString.contains("--")) return AppColors.iconMuted;

    try {
      // Formato esperado "mm:ss /km" o "mm:ss"
      final parts = paceString.split(' ')[0].split(':');
      if (parts.length != 2) return Colors.black87;

      final int minutes = int.tryParse(parts[0]) ?? 0;
      final int seconds = int.tryParse(parts[1]) ?? 0;
      final int totalSeconds = (minutes * 60) + seconds;

      // Lógica de colores simple
      if (totalSeconds < 240) { // < 4:00 min/km
        return AppColors.rpeLow;
      } else if (totalSeconds < 300) { // 4:00 - 5:00 min/km
        return AppColors.rpeMid;
      } else { // > 5:00 min/km
        return AppColors.rpeMax;
      }
    } catch (e) {
      return Colors.black87;
    }
  }


  // ===================================================================
  // UI
  // ===================================================================


  @override
  Widget build(BuildContext context) {
    final bool isLibre = widget.distancia == 'Libre';
    return Scaffold(
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildBody()),
                  _buildFooter(),
                ],
              ),
            ),
          ),
          // 3px purple gradient accent line at the very top of the screen
          if (isLibre)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                ),
              ),
            ),
        ],
      ),
    );
  }


  // Libre: status pill. Interval: editorial serie header.
  Widget _buildHeader() {
    if (widget.distancia == 'Libre') return _buildLibreStatusBar();
    return _buildSerieHeader();
  }


  Widget _buildBody() {
    if (widget.distancia == 'Libre') return _buildLibreBody();
    return _buildIntervalBody();
  }


  // ===================================================================
  // INTERVAL/SERIES MODE — UI
  // ===================================================================

  // Editorial serie header: number + purple accent bar + subtext.
  Widget _buildSerieHeader() {
    final int serieNum = _demoMode ? 3 : (widget.currentSeries ?? 1);
    final int? totalNum = _demoMode ? 5 : widget.totalSeries;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.repeat_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Serie $serieNum',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          if (totalNum != null) ...[
            const SizedBox(height: 5),
            Text(
              'de $totalNum series',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Body for interval/series mode: TIEMPO hero → RITMO (GPS) → inline stats.
  Widget _buildIntervalBody() {
    final bool showRitmo = widget.gpsActivo || _demoMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildObjectivesBar(),
          const Spacer(flex: 2),
          _buildHeroTimer(),
          const Spacer(flex: 2),
          if (showRitmo) ...[
            _buildIntervalRitmo(),
            const Spacer(flex: 1),
          ],
          _buildInlineStats(),
          const SizedBox(height: 12),
          _HeartRateIndicator(
              fcMax: widget.fcMax, targetZone: widget.targetZone),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // RITMO speedometer for interval mode — reuses the same card as Libre.
  Widget _buildIntervalRitmo() {
    if (_demoMode) return _buildRitmoSpeedometer('4:45');
    return ValueListenableBuilder<String>(
      valueListenable: _gpsService?.currentPace ?? ValueNotifier("--:--"),
      builder: (ctx, pace, _) => _buildRitmoSpeedometer(pace),
    );
  }

  // DISTANCIA (target) + DESCANSO inline, no card background, separated by a divider.
  // DISTANCIA always shows the target distance from widget.distancia, not GPS.
  Widget _buildInlineStats() {
    final String descansoStr = _demoMode ? '1m30s' : _formatDescanso(_descansoInt);
    final Widget descansoStat = _buildInlineStat(
      icon: Icons.timer_rounded,
      value: descansoStr,
      label: 'DESCANSO',
    );

    final String targetDist = _demoMode ? '400m' : _formatTargetDistancia(_distanciaInt);
    final Widget distStat = _buildInlineStat(
      icon: Icons.flag_rounded,
      value: targetDist,
      label: 'DISTANCIA',
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        distStat,
        Container(
          width: 1,
          height: 40,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
          margin: const EdgeInsets.symmetric(horizontal: 28),
        ),
        descansoStat,
      ],
    );
  }

  String _formatTargetDistancia(int meters) {
    if (meters < 1000) return '${meters}m';
    final double km = meters / 1000.0;
    if (meters % 1000 == 0) return '${meters ~/ 1000}km';
    return '${km.toStringAsFixed(1)}km';
  }

  // Single inline stat: icon + value + label, no card background.
  Widget _buildInlineStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35)),
            const SizedBox(width: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // LIBRE MODE — UI
  // ===================================================================

  // Top bar: pulsing status pill only (tiempo moved below ritmo card).
  Widget _buildLibreStatusBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _isRunning
                  ? AppColors.brand.withOpacity(0.08)
                  : AppColors.rpeMax.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPulseDot(),
                const SizedBox(width: 6),
                Text(
                  _isRunning ? 'En carrera' : 'Pausado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isRunning ? AppColors.brand : AppColors.rpeMax,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Animated dot for the status pill — fades in/out while running.
  Widget _buildPulseDot() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, __) => Opacity(
        opacity: _isRunning ? _pulseAnimation.value : 1.0,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isRunning ? AppColors.brand : AppColors.rpeMax,
          ),
        ),
      ),
    );
  }

  // Body for Libre/continuous run: top half = distance hero, bottom = pace card.
  Widget _buildLibreBody() {
    // Demo values — only active when _demoMode is true.
    const int _demoDist = 3470;        // 3.47 km
    const String _demoPace = '5:12';   // moderado / amber

    return Column(
      children: [
        // Top half — DISTANCIA is the protagonist
        Expanded(
          flex: 5,
          child: _demoMode
              ? Center(child: _buildDistanciaHero(_demoDist))
              : ValueListenableBuilder<int>(
                  valueListenable: _gpsService?.totalDistanceMeters ?? ValueNotifier(0),
                  builder: (ctx, dist, _) => Center(
                    child: _buildDistanciaHero(dist),
                  ),
                ),
        ),
        // Bottom half — RITMO speedometer card + TIEMPO below it
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _demoMode
                    ? _buildRitmoSpeedometer(_demoPace)
                    : ValueListenableBuilder<String>(
                        valueListenable: _gpsService?.currentPace ?? ValueNotifier("--:--"),
                        builder: (ctx, pace, _) => _buildRitmoSpeedometer(pace),
                      ),
                const SizedBox(height: 10),
                _HeartRateIndicator(fcMax: widget.fcMax),
                const SizedBox(height: 4),
                // TIEMPO — centered, small, unobtrusive
                Text(
                  _tiempoMostrado,
                  style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w300,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                    height: 1.0,
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // DISTANCIA — the achievement. Huge number, bold, black. "km" suffix small and gray.
  Widget _buildDistanciaHero(int distanceMeters) {
    final double km = distanceMeters / 1000.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: km.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -4,
                      height: 1.0,
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      shadows: _isAlarmActive
                          ? [Shadow(color: AppColors.brand.withOpacity(0.4), blurRadius: 24)]
                          : null,
                    ),
                  ),
                  TextSpan(
                    text: ' km',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'DISTANCIA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  // RITMO — the live engine. White card with circular speedometer arc.
  Widget _buildRitmoSpeedometer(String paceString) {
    final Color arcColor = _getArcPaceColor(paceString);
    final double fraction = _computeArcFraction(paceString);
    final String paceDisplay = paceString.split(' ')[0];
    final String zoneLabel = _getPaceZoneLabel(paceString);
    final String hint = _getRitmoHint(paceString);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Speedometer arc with pace value inside
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(
              painter: _SpeedometerPainter(
                fraction: fraction,
                arcColor: arcColor,
                trackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      paceDisplay,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -1,
                        height: 1.0,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'min/km',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Right: label + zone badge + contextual hint
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RITMO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: arcColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: arcColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        zoneLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: arcColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Green <4:30 · Amber 4:30-6:00 · Red >6:00
  Color _getArcPaceColor(String paceString) {
    if (paceString.contains('--')) return AppColors.iconMuted;
    try {
      final parts = paceString.split(' ')[0].split(':');
      if (parts.length != 2) return AppColors.iconMuted;
      final int totalSeconds = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      if (totalSeconds < 270) return const Color(0xFF22C55E);  // < 4:30
      if (totalSeconds <= 360) return const Color(0xFFF59E0B); // 4:30–6:00
      return const Color(0xFFEF4444);                          // > 6:00
    } catch (_) {
      return AppColors.iconMuted;
    }
  }

  // 2:00/km = 1.0 (full) · 8:00/km = 0.0 (empty)
  double _computeArcFraction(String paceString) {
    if (paceString.contains('--')) return 0.0;
    try {
      final parts = paceString.split(' ')[0].split(':');
      if (parts.length != 2) return 0.0;
      final int totalSeconds = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      const int fastest = 120; // 2:00/km
      const int slowest = 480; // 8:00/km
      return (1.0 - (totalSeconds - fastest) / (slowest - fastest)).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  String _getPaceZoneLabel(String paceString) {
    if (paceString.contains('--')) return 'Calculando';
    try {
      final parts = paceString.split(' ')[0].split(':');
      if (parts.length != 2) return 'Calculando';
      final int totalSeconds = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      if (totalSeconds < 270) return 'Rápido';
      if (totalSeconds <= 360) return 'Moderado';
      return 'Intenso';
    } catch (_) {
      return 'Calculando';
    }
  }

  String _getRitmoHint(String paceString) {
    if (paceString.contains('--')) return 'Calculando ritmo...';
    try {
      final parts = paceString.split(' ')[0].split(':');
      if (parts.length != 2) return '';
      final int secPerKm = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      final int tenKmMin = (secPerKm * 10 / 60).round();
      return 'A este ritmo, 10 km en $tenKmMin min';
    } catch (_) {
      return '';
    }
  }

  // Small gray timer — used at the top for libre and interval+GPS modes.
  Widget _buildSmallTimer() {
    return Text(
      _tiempoMostrado,
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
        letterSpacing: 0.5,
        height: 1.0,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }


  // Large hero timer — used only for interval+noGPS mode (timer is protagonist).
  Widget _buildHeroTimer() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _tiempoMostrado,
              style: TextStyle(
                fontSize: 88,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -3,
                height: 1.0,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                shadows: _isAlarmActive
                    ? [
                        Shadow(
                          color: AppColors.brand.withOpacity(0.5),
                          blurRadius: 30,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'TIEMPO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }


  Widget _buildMetricsGrid() {
    // ── Interval mode only (Libre is handled by _buildLibreBody) ────
    final String serieValue = widget.currentSeries != null
        ? (widget.totalSeries != null
            ? "${widget.currentSeries}/${widget.totalSeries}"
            : "${widget.currentSeries}")
        : "--";

    if (!widget.gpsActivo) {
      // No GPS: only DESCANSO + SERIE (DISTANCIA and RITMO require GPS)
      return Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              label: "DESCANSO",
              value: _formatDescanso(_descansoInt),
              icon: Icons.timer_rounded,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _buildMetricCard(
              label: "SERIE",
              value: serieValue,
              icon: Icons.repeat_rounded,
            ),
          ),
        ],
      );
    }

    // Interval + GPS: symmetric 2×2 grid
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable:
                    _gpsService?.totalDistanceMeters ?? ValueNotifier(0),
                builder: (ctx, dist, _) => _buildMetricCard(
                  label: "DISTANCIA",
                  value: "${dist}m",
                  icon: Icons.gps_fixed_rounded,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable:
                    _gpsService?.currentPace ?? ValueNotifier("--:--"),
                builder: (ctx, pace, _) => _buildMetricCard(
                  label: "RITMO",
                  value: pace.split(' ')[0],
                  icon: Icons.speed_rounded,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                label: "DESCANSO",
                value: _formatDescanso(_descansoInt),
                icon: Icons.timer_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                label: "SERIE",
                value: serieValue,
                icon: Icons.repeat_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
    bool large = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: large ? 28 : 18,
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.transparent
                : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
            size: large ? 24 : 18,
          ),
          SizedBox(height: large ? 14 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: large ? 52 : 24,
                fontWeight: FontWeight.bold,
                color: large ? AppColors.brand : Theme.of(context).colorScheme.onSurface,
                letterSpacing: large ? -2.0 : -0.5,
                height: 1.0,
              ),
            ),
          ),
          SizedBox(height: large ? 10 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: large
                  ? AppColors.brand.withOpacity(0.55)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFooter() {
    final isLibre = widget.distancia == "Libre";
    final label = isLibre ? "Finalizar carrera" : "Finalizar serie";

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: GestureDetector(
        onTap: _isRunning ? _finishSeries : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            color: _isRunning
                ? AppColors.brand
                : AppColors.brand.withOpacity(0.35),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isRunning
                ? [
                    BoxShadow(
                      color: AppColors.brand.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ===================================================================
  // DIÁLOGO DE RPE (RULETA)
  // ===================================================================


  Future<void> _showRpePicker() async {
    final double rpeInicial = _rpeSeleccionado;
    final int initialItemIndex = ((_rpeSeleccionado - 1.0) * 2).round();


    // Capturar contexto antes de entrar al sheet
    final int serieNum = widget.currentSeries ?? 1;
    final Duration elapsed = _stopwatch.elapsed;
    final int distanciaM = widget.gpsActivo
        ? _gpsService?.totalDistanceMeters.value ?? 0
        : _distanciaInt;

    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Container(
            height: 390,
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Contexto de serie completada
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Serie completada',
                        style: TextStyle(
                            fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Serie $serieNum',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (elapsed.inSeconds > 0) ...[
                            _RpeStatChip(
                              icon: Icons.timer_rounded,
                              label: _formatElapsed(elapsed),
                            ),
                          ],
                          if (distanciaM > 0) ...[
                            const SizedBox(width: 8),
                            _RpeStatChip(
                              icon: Icons.straighten_rounded,
                              label: '${distanciaM}m',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Header estilo iOS
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Esfuerzo (RPE)",
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          const InfoTooltip(content: AppHelpContent.trainingRPE),
                        ],
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text("Listo", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, fontSize: 17, fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),

                // Picker
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32.0, // Más compacto
                    scrollController: FixedExtentScrollController(
                      initialItem: initialItemIndex,
                    ),
                    magnification: 1.22,
                    useMagnifier: true,
                    onSelectedItemChanged: (int index) {
                       _rpeSeleccionado = (index * 0.5) + 1.0;
                    },
                    children: List<Widget>.generate(19, (int index) {
                      final double value = (index * 0.5) + 1.0;
                      return Center(
                        child: Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(fontSize: 21.0, fontWeight: FontWeight.w400, color: Theme.of(ctx).colorScheme.onSurface),
                        ),
                      );
                    }),
                  ),
                ),

                // Nota informativa abajo
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0, top: 4),
                  child: Text(
                    "1 = Muy suave   ·   10 = Máximo esfuerzo",
                    style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.35), fontSize: 12),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );

    // Logic after sheet closes
    if (result == true) {
      // Confirmed
      if (widget.gpsActivo) {
        // Sincronizar distancia final desde el servicio
        if (_gpsService != null) {
          _distanciaGpsMetros = _gpsService!.totalDistanceMeters.value.toDouble();
        }

        // Small delay to allow the previous sheet to close smoothly
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
           // Si es carrera Libre (Continua), usamos SIEMPRE el GPS sin preguntar
           if (widget.distancia == "Libre") {
              final int finalDist = _distanciaGpsMetros.round();

              if (finalDist < 30) { // Umbral mínimo razonable (30m)
                 ModernSnackBar.showError(context, "Distancia demasiado baja para guardar (<30m). Descartando...");
                 await Future.delayed(const Duration(seconds: 2));
                 if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                 }
                 return;
              }
              // Guardar directo con GPS
              _saveWithSelectedDistance(finalDist, true);
           } else {
              // Si es serie Estructurada, seguimos preguntando
              _showDistanceSelectionSheet();
           }
        }
      } else {
        _handleSave();
      }
    } else {
      // Cancelled (should not happen with isDismissible: false and no cancel button)
      // Enforce selection or stay
      _handleSave(); // Fallback if they manage to close it, assume finished?
      // Better: prevent closing. But if they use android back system despite WillPopScope (rare): save.
    }
  }

  // ===================================================================
  // SHEET DE SELECCIÓN DE DISTANCIA (GPS vs Manual)
  // ===================================================================

  void _showDistanceSelectionSheet() {
    final int distanciaGps = _distanciaGpsMetros.round();
    final int diferencia = (distanciaGps - _distanciaInt).abs();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               // Header
               Center(
                 child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2)
                  )
                 ),
               ),

               Text(
                 'Confirma la Distancia',
                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 8),
               Text(
                 'Hemos calculado la distancia por GPS. ¿Cuál prefieres usar para esta serie?',
                 style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 24),

               // Botones de selección grandes
               Row(
                 children: [
                   // OPCIÓN MANUAL
                   Expanded(
                     child: GestureDetector(
                       onTap: () {
                          Navigator.of(context).pop();
                          _saveWithSelectedDistance(_distanciaInt, false);
                       },
                       child: Container(
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                           color: Theme.of(ctx).colorScheme.surface,
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2), width: 2),
                           boxShadow: [
                             BoxShadow(color: Theme.of(ctx).brightness == Brightness.dark ? Colors.transparent : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                           ]
                         ),
                         child: Column(
                           children: [
                             const Icon(Icons.edit_road, size: 32, color: AppColors.brand),
                             const SizedBox(height: 12),
                             Text("MANUAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5), letterSpacing: 1)),
                             const SizedBox(height: 4),
                             Text("$_distanciaInt m", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface)),
                           ],
                         ),
                       ),
                     ),
                   ),

                   const SizedBox(width: 16),

                   // OPCIÓN GPS
                   Expanded(
                     child: GestureDetector(
                        onTap: distanciaGps > 0 ? () {
                          Navigator.of(context).pop();
                          _saveWithSelectedDistance(distanciaGps, true);
                       } : null,
                       child: Opacity(
                         opacity: distanciaGps > 0 ? 1.0 : 0.5,
                         child: Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Theme.of(ctx).colorScheme.surface,
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: Theme.of(ctx).colorScheme.outline.withOpacity(0.2), width: 2),
                             boxShadow: [
                               BoxShadow(color: Theme.of(ctx).brightness == Brightness.dark ? Colors.transparent : Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                             ]
                           ),
                           child: Column(
                             children: [
                               Icon(Icons.gps_fixed, size: 32, color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
                               const SizedBox(height: 12),
                               Text("GPS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, letterSpacing: 1)),
                               const SizedBox(height: 4),
                               Text("$distanciaGps m", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface)),
                             ],
                           ),
                         ),
                       ),
                     ),
                   ),
                 ],
               ),

               const SizedBox(height: 24),

               // Diferencia info
               if (diferencia > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.compare_arrows, size: 16, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Text(
                        "Diferencia de $diferencia m detectada",
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
                      )
                    ],
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  // ── Barra de objetivos de bloque ────────────────────────────────────────────

  static int? _parsePaceSec(String pace) {
    final parts = pace.split(':');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0]);
    final s = int.tryParse(parts[1]);
    if (m == null || s == null) return null;
    return m * 60 + s;
  }

  static Color _rpeColorFor(double v) {
    if (v <= 3) return AppColors.rpeLow;
    if (v <= 6) return AppColors.rpeMid;
    if (v <= 8) return AppColors.effort;
    return AppColors.rpeMax;
  }

  static Color _zoneColorFor(int zone) {
    final colors = [
      const Color(0xFF5A9E9E), // Z1
      AppColors.rpeLow,        // Z2
      AppColors.rpeMid,        // Z3
      AppColors.effort,        // Z4
      AppColors.rpeMax,        // Z5
    ];
    if (zone >= 1 && zone <= 5) return colors[zone - 1];
    return const Color(0xFF8E8E93);
  }

  Widget _buildObjectivesBar() {
    final hasObjectives = widget.targetPaceMinutes != null ||
        widget.targetRpe != null ||
        widget.targetZone != null;
    if (!hasObjectives) return const SizedBox.shrink();

    final targetMinSec = widget.targetPaceMinutes != null
        ? widget.targetPaceMinutes! * 60 + (widget.targetPaceSeconds ?? 0)
        : null;
    final targetMaxSec = widget.targetPaceMaxMinutes != null
        ? widget.targetPaceMaxMinutes! * 60 + (widget.targetPaceMaxSeconds ?? 0)
        : (targetMinSec != null ? targetMinSec + 15 : null);

    final paceLabel = widget.targetPaceMinutes != null
        ? (widget.targetPaceMaxMinutes != null
            ? '${widget.targetPaceMinutes}:${(widget.targetPaceSeconds ?? 0).toString().padLeft(2, '0')}'
              '–${widget.targetPaceMaxMinutes}:${(widget.targetPaceMaxSeconds ?? 0).toString().padLeft(2, '0')}'
            : '${widget.targetPaceMinutes}:${(widget.targetPaceSeconds ?? 0).toString().padLeft(2, '0')}')
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Pace objetivo
            if (paceLabel != null)
              _ObjectiveChip(
                icon:     Icons.speed_rounded,
                label:    paceLabel,
                sublabel: '/km obj.',
              ),

            // Indicador pace actual vs objetivo
            if (targetMinSec != null && widget.gpsActivo)
              ValueListenableBuilder<String>(
                valueListenable:
                    _gpsService?.currentPace ?? ValueNotifier('--:--'),
                builder: (_, pace, __) {
                  final currentSec = _parsePaceSec(pace);
                  if (currentSec == null) return const SizedBox.shrink();
                  final inRange = currentSec >= targetMinSec - 5 &&
                      currentSec <= targetMaxSec! + 5;
                  final tooFast = currentSec < targetMinSec - 5;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _PaceStatusIndicator(
                        isInRange: inRange, isTooFast: tooFast),
                  );
                },
              ),

            // RPE objetivo
            if (widget.targetRpe != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _ObjectiveChip(
                  icon:     Icons.favorite_outline_rounded,
                  label:    'RPE ${widget.targetRpe!}',
                  sublabel: 'objetivo',
                  color:    _rpeColorFor(widget.targetRpe!),
                ),
              ),

            // Zona FC objetivo
            if (widget.targetZone != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _ObjectiveChip(
                  icon:     Icons.monitor_heart_outlined,
                  label:    'Z${widget.targetZone}',
                  sublabel: 'zona obj.',
                  color:    _zoneColorFor(widget.targetZone!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── HR helpers ────────────────────────────────────────────────────────────────

Color _hrZoneColor(int? hr, int? fcMax) {
  if (hr == null || fcMax == null) return const Color(0xFF8E8E93);
  final zone = ZonesService().zoneFor(hr, fcMax);
  if (zone == null) return const Color(0xFF8E8E93);
  final zones = ZonesService().zonesFor(fcMax);
  return zones[zone - 1].color;
}

// ── _HeartRateIndicator ───────────────────────────────────────────────────────

class _HeartRateIndicator extends StatefulWidget {
  final int? fcMax;
  final int? targetZone;

  const _HeartRateIndicator({this.fcMax, this.targetZone});

  @override
  State<_HeartRateIndicator> createState() => _HeartRateIndicatorState();
}

class _HeartRateIndicatorState extends State<_HeartRateIndicator> {
  bool _hasLastDevice = false;

  @override
  void initState() {
    super.initState();
    HeartRateService().getLastDeviceId().then((id) {
      if (mounted) setState(() => _hasLastDevice = id != null);
    });
  }

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

        if (state == HrConnectionState.connected) {
          if (hr == null) return const SizedBox.shrink();
          final color = _hrZoneColor(hr, widget.fcMax);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                '$hr ppm',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
              if (widget.targetZone != null && widget.fcMax != null) ...[
                const SizedBox(width: 4),
                _ZoneStatusIndicator(
                  currentHr:  hr,
                  targetZone: widget.targetZone!,
                  fcMax:      widget.fcMax!,
                ),
              ],
            ],
          );
        }

        if (state == HrConnectionState.scanning ||
            state == HrConnectionState.connecting) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width:  12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF8E8E93)),
              ),
              SizedBox(width: 4),
              Text('Conectando...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
            ],
          );
        }

        if (state == HrConnectionState.disconnected && _hasLastDevice) {
          return const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_outline_rounded,
                  color: Color(0xFF8E8E93), size: 14),
              SizedBox(width: 4),
              Text('Sin FC',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ── _ZoneStatusIndicator ──────────────────────────────────────────────────────

class _ZoneStatusIndicator extends StatelessWidget {
  final int currentHr;
  final int targetZone;
  final int fcMax;

  const _ZoneStatusIndicator({
    required this.currentHr,
    required this.targetZone,
    required this.fcMax,
  });

  @override
  Widget build(BuildContext context) {
    final currentZone = ZonesService().zoneFor(currentHr, fcMax) ?? 1;

    final Color color;
    final IconData icon;
    if (currentZone == targetZone) {
      color = AppColors.rpeLow;
      icon  = Icons.check_circle_rounded;
    } else if (currentZone > targetZone) {
      color = AppColors.rpeMax;
      icon  = Icons.arrow_upward_rounded;
    } else {
      color = AppColors.rpeMid;
      icon  = Icons.arrow_downward_rounded;
    }

    return Icon(icon, size: 16, color: color);
  }
}

// Speedometer arc painter for RITMO card.
// Draws a 270° gauge track + active arc, starting at bottom-left (225°).
class _SpeedometerPainter extends CustomPainter {
  final double fraction; // 0.0 = empty · 1.0 = full
  final Color arcColor;
  final Color trackColor;

  const _SpeedometerPainter({
    required this.fraction,
    required this.arcColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Start at 225° (7 o'clock), sweep 270° clockwise to 135° (5 o'clock).
    const double startAngle = pi * 5 / 4;
    const double sweepTotal = pi * 3 / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9.0
      ..strokeCap = StrokeCap.round;

    // Track
    paint.color = trackColor;
    canvas.drawArc(rect, startAngle, sweepTotal, false, paint);

    // Active arc
    if (fraction > 0.01) {
      paint.color = arcColor;
      canvas.drawArc(rect, startAngle, sweepTotal * fraction, false, paint);
    }
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) =>
      old.fraction != fraction ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor;
}

// ── _ObjectiveChip ────────────────────────────────────────────────────────────

class _ObjectiveChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _ObjectiveChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    this.color = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        border:       Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              Text(sublabel,
                  style: TextStyle(
                      fontSize: 10, color: color.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _PaceStatusIndicator ──────────────────────────────────────────────────────

class _PaceStatusIndicator extends StatelessWidget {
  final bool isInRange;
  final bool isTooFast;

  const _PaceStatusIndicator({
    required this.isInRange,
    required this.isTooFast,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData iconData;
    if (isInRange) {
      color    = AppColors.rpeLow;
      iconData = Icons.check_rounded;
    } else if (isTooFast) {
      color    = AppColors.rpeMid;
      iconData = Icons.arrow_upward_rounded;
    } else {
      color    = AppColors.rpeMax;
      iconData = Icons.arrow_downward_rounded;
    }
    return Container(
      width:  32,
      height: 32,
      decoration: BoxDecoration(
        color:  color.withValues(alpha: 0.15),
        shape:  BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Icon(iconData, size: 16, color: color),
    );
  }
}

class _RpeStatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RpeStatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1530),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.brand),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.brandLight,
            ),
          ),
        ],
      ),
    );
  }
}
