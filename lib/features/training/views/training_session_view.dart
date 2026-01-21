import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Para SystemSound
import 'dart:ui' show FontFeature;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../../core/widgets/modern_snackbar.dart';

import '../data/serie.dart';
import 'package:running_laps/config/app_theme.dart';
import '../../../core/widgets/app_header.dart';
import 'package:running_laps/core/constants/app_help_content.dart';
import 'package:running_laps/core/widgets/info_tooltip.dart';
import '../../../core/services/gps_service.dart';


class TrainingSessionView extends StatefulWidget {
  final String distancia;
  final String descanso;
  final bool gpsActivo;
  final int? alarmIntervalMs;
  final int? currentSeries;
  final int? totalSeries;


  const TrainingSessionView({
    Key? key,
    required this.distancia,
    required this.descanso,
    required this.gpsActivo,
    this.alarmIntervalMs,
    this.currentSeries,
    this.totalSeries,
  }) : super(key: key);


  @override
  _TrainingSessionViewState createState() => _TrainingSessionViewState();
}


class _TrainingSessionViewState extends State<TrainingSessionView> {
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

  // --- Colores (coincide con TrainingStartView) ---
  static const Color _bgGradientColor = Color(0xFFF9F5FB);


  @override
  void initState() {
    super.initState();

    // Parsear los valores de la serie
    _distanciaInt = int.tryParse(widget.distancia) ?? 0;
    _descansoInt = int.tryParse(widget.descanso) ?? 0;

    // Intervalo de alarma recibido
    _alarmIntervalMs = widget.alarmIntervalMs;

    // Iniciar el cronómetro
    _stopwatch.start();
    _startTimer();
    _startBeepTimerIfNeeded();

    // Iniciar GPS si está activo
    if (widget.gpsActivo) {
      _initializeGPS();
    }
  }

  /// Inicializa el GPS service
  Future<void> _initializeGPS() async {
    _gpsService = GPSService();
    final bool initialized = await _gpsService!.initialize();
    
    if (initialized) {
      await _gpsService!.startTracking();
      // Ya no necesitamos timer, la UI es reactiva con ValueListenableBuilder
      setState(() {}); // Rebuild para que los builders tengan acceso a _gpsService inicializado
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


  @override
  void dispose() {
    _timer?.cancel();
    _beepTimer?.cancel();
    _gpsUpdateTimer?.cancel(); // Se mantiene por seguridad si existe instancia previa
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
      }
    });
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

    // 2. Crear el objeto Serie (sin GPS)
    final Serie serieTerminada = Serie(
      tiempoSec: tiempoFinalSec,
      distanciaM: _distanciaInt, // Distancia manual
      descansoSec: _descansoInt,
      rpe: _rpeSeleccionado,
      usedGps: false,
      usedGpsDistance: null,
      gpsPoints: null,
      finishedAt: _finishedAt, // Pasamos el timestamp
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
      finishedAt: _finishedAt, // Pasamos el timestamp
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
    return "$twoDigitMinutes:$twoDigitSeconds:$hundredths";
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
    if (paceString.contains("--")) return Colors.grey;

    try {
      // Formato esperado "mm:ss /km" o "mm:ss"
      final parts = paceString.split(' ')[0].split(':');
      if (parts.length != 2) return Colors.black87;

      final int minutes = int.tryParse(parts[0]) ?? 0;
      final int seconds = int.tryParse(parts[1]) ?? 0;
      final int totalSeconds = (minutes * 60) + seconds;

      // Lógica de colores simple
      if (totalSeconds < 240) { // < 4:00 min/km
        return Colors.green.shade600;
      } else if (totalSeconds < 300) { // 4:00 - 5:00 min/km
        return Colors.orange.shade700;
      } else { // > 5:00 min/km
        return Colors.red.shade400;
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader() {
    // Deshabilito las acciones para que no se puedan ir sin terminar
    return AppHeader(onTapLeft: () {}, onTapRight: () {});
  }


  Widget _buildBody() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: <Widget>[
          if (widget.currentSeries != null) ...[
            const SizedBox(height: 16.0),
            Text(
              widget.totalSeries != null 
                  ? "SERIE ${widget.currentSeries} DE ${widget.totalSeries}" 
                  : "SERIE ${widget.currentSeries}",
              style: const TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.bold, 
                color: Tema.brandPurple, 
                letterSpacing: 1.2
              ),
            ),
          ],
          const SizedBox(height: 16.0),
          
          // Info Cards - 2 cards si no GPS, 3 cards si GPS
          if (!widget.gpsActivo)
            // SIN GPS: solo Distancia Manual y Descanso
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: "Distancia",
                    value: "${_distanciaInt}m",
                    icon: Icons.route_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    label: "Descanso",
                    value: _formatDescanso(_descansoInt),
                    icon: Icons.snooze_rounded,
                  ),
                ),
              ],
            )
          else
            // CON GPS: Distancia GPS (Reactiva) y Descanso
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _gpsService?.totalDistanceMeters ?? ValueNotifier(0),
                    builder: (context, distance, _) {
                      return _buildMetricCard(
                        label: "Distancia GPS",
                        value: "${distance}m",
                        icon: Icons.location_on,
                        color: Tema.brandPurple,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    label: "Descanso",
                    value: _formatDescanso(_descansoInt),
                    icon: Icons.snooze_rounded,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
         
          // Cronómetro Central
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isAlarmActive ? Tema.brandPurple : Tema.brandPurple.withOpacity(0.3),
                        width: _isAlarmActive ? 8.0 : 4.0
                      ),
                      borderRadius: BorderRadius.circular(100.0),
                      boxShadow: _isAlarmActive ? [
                        BoxShadow(
                          color: Tema.brandPurple.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ] : [],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                          // 1. TIEMPO
                          Text(
                            _tiempoMostrado,
                            style: const TextStyle(
                              fontSize: 56.0, // Reducido para caber
                              fontWeight: FontWeight.w200,
                              height: 1.0,
                              letterSpacing: -1.0,
                              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                              color: Colors.black87,
                            ),
                          ),
                          // 2. RITMO (Solo si GPS activo - Reactivo)
                          if (widget.gpsActivo) ...[
                            const SizedBox(height: 8), 
                            ValueListenableBuilder<String>(
                              valueListenable: _gpsService?.currentPace ?? ValueNotifier("--:-- /km"),
                              builder: (context, pace, _) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      pace.split(' ')[0], // Solo "mm:ss"
                                      style: TextStyle(
                                        fontSize: 56.0,
                                        fontWeight: FontWeight.w200,
                                        height: 1.0,
                                        letterSpacing: -1.0,
                                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                        color: _getPaceColor(pace), // Color dinámico
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "min/km",
                                      style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                                    )
                                  ],
                                );
                              }
                            ),
                            // Cadencia (Opcional, pequeño abajo)
                             const SizedBox(height: 4), 
                             ValueListenableBuilder<int>(
                               valueListenable: _gpsService?.cadence ?? ValueNotifier(0),
                               builder: (context, spm, _) {
                                 if (spm < 10) return const SizedBox.shrink();
                                 return Text(
                                   "$spm spm",
                                   style: TextStyle(
                                     fontSize: 14, 
                                     color: Colors.grey.shade400,
                                     fontWeight: FontWeight.w500
                                   ),
                                 );
                               },
                             ),
                          ]
                       ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final cardColor = color ?? Tema.brandPurple;
    
    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: Colors.grey.shade200, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: cardColor.withOpacity(0.8)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.2,
          colors: <Color>[_bgGradientColor, Colors.white],
          stops: <double>[0.0, 1.0],
        ),
        image: const DecorationImage(
          image: AssetImage('assets/images/fondo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: <Widget>[
          Container(height: 1.0, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0), // Reduced from 20.0
              child: GestureDetector(
                onTap: _isRunning ? _finishSeries : null, // Solo permitir parar
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _isRunning ? Colors.white : Colors.grey, // Grey when disabled
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Tema.brandPurple.withOpacity(_isRunning ? 0.2 : 0.0),
                      width: 1,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Tema.brandPurple.withOpacity(0.2),
                        blurRadius: 20.0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRunning ? Icons.stop_rounded : Icons.check, // Icono Stop
                    color: _isRunning ? Tema.brandPurple : Colors.white,
                    size: 48.0,
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }


  // ===================================================================
  // DIÁLOGO DE RPE (RULETA)
  // ===================================================================


  Future<void> _showRpePicker() async {
    final double rpeInicial = _rpeSeleccionado;
    final int initialItemIndex = ((_rpeSeleccionado - 1.0) * 2).round();


    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext ctx) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Container(
            height: 320, // Altura ajustada
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), // Radio más suave tipo iOS
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header estilo iOS
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Espacio vacío para equilibrar el header (ya que quitamos el botón cancelar)
                      const SizedBox(width: 48),
                      
                      // Título (Centro)
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
                      
                      // Botón Guardar (Derecha)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Text("Listo", style: TextStyle(color: Tema.brandPurple, fontSize: 17, fontWeight: FontWeight.bold)),
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
                          style: const TextStyle(fontSize: 21.0, fontWeight: FontWeight.w400, color: Colors.black),
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
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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
           _showDistanceSelectionSheet();
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)
                  )
                 ),
               ),
               
               const Text(
                 'Confirma la Distancia',
                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 8),
               const Text(
                 'Hemos calculado la distancia por GPS. ¿Cuál prefieres usar para esta serie?',
                 style: TextStyle(fontSize: 14, color: Colors.grey),
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
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(color: Colors.grey.shade300, width: 2),
                           boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                           ]
                         ),
                         child: Column(
                           children: [
                             const Icon(Icons.edit_road, size: 32, color: Colors.purple),
                             const SizedBox(height: 12),
                             const Text("MANUAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                             const SizedBox(height: 4),
                             Text("$_distanciaInt m", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: Colors.grey.shade300, width: 2), // Borde neutro
                              boxShadow: [
                               BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                             ]
                           ),
                           child: Column(
                             children: [
                               const Icon(Icons.gps_fixed, size: 32, color: Tema.brandPurple),
                               const SizedBox(height: 12),
                               const Text("GPS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Tema.brandPurple, letterSpacing: 1)),
                               const SizedBox(height: 4),
                               Text("$distanciaGps m", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.compare_arrows, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        "Diferencia de $diferencia m detectada",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
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
}


