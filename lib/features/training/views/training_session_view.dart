import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // Para SystemSound
import 'dart:ui' show FontFeature;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../data/serie.dart';
import '../../../app/tema.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/services/gps_service.dart';


class TrainingSessionView extends StatefulWidget {
  final String distancia;
  final String descanso;
  final bool gpsActivo;
  final int? alarmIntervalMs; // intervalo de pitido en milisegundos (opcional)


  const TrainingSessionView({
    Key? key,
    required this.distancia,
    required this.descanso,
    required this.gpsActivo,
    this.alarmIntervalMs,
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
      
      // Timer para actualizar distancia y ritmo GPS cada 500ms
      _gpsUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted && _gpsService != null) {
          setState(() {
            _distanciaGpsMetros = _gpsService!.totalDistanceMeters;
            _ritmoActual = _gpsService!.currentPace;
          });
        }
      });
    } else {
      // Mostrar error específico según el estado del GPS
      if (mounted) {
        String errorMessage = 'No se pudo activar el GPS.';
        String actionMessage = '';
        
        if (_gpsService!.status == GpsStatus.disabled) {
          errorMessage = '📍 GPS desactivado';
          actionMessage = 'Activa la ubicación en los ajustes de tu móvil';
        } else if (_gpsService!.status == GpsStatus.permissionDenied) {
          errorMessage = '🔒 Permisos de ubicación denegados';
          actionMessage = 'Ve a Ajustes → Apps → Running Laps → Permisos → Ubicación';
        } else {
          errorMessage = '❌ Error al iniciar GPS';
          actionMessage = 'Verifica que el GPS esté activo y los permisos estén dados';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (actionMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    actionMessage,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }


  @override
  void dispose() {
    _timer?.cancel();
    _beepTimer?.cancel();
    _gpsUpdateTimer?.cancel();
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


  void _handlePausePress() {
    // Detener crono, timer y alarma
    _stopwatch.stop();
    _timer?.cancel();
    _stopBeepTimer();
    _gpsService?.pause(); // Pausar GPS

    setState(() {
      _isRunning = false;
    });

    // Mostrar selector de RPE
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

    // Cerrar diálogo de RPE
    Navigator.of(context).pop();
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
    );

    // 3. Cerrar el diálogo de RPE
    Navigator.of(context).pop();
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
          const SizedBox(height: 32.0),
          
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
            // CON GPS: Distancia GPS, Ritmo, y Descanso
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: "Distancia GPS",
                    value: "${_distanciaGpsMetros.round()}m",
                    icon: Icons.location_on,
                    color: Tema.brandPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    label: "Ritmo",
                    value: _ritmoActual,
                    icon: Icons.speed,
                    color: Colors.orange,
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
                      child: Text(
                        _tiempoMostrado,
                        style: const TextStyle(
                          fontSize: 80.0,
                          fontWeight: FontWeight.w200,
                          height: 1.0,
                          letterSpacing: -2.0,
                          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "TIEMPO TOTAL",
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey,
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
              onTap: _isRunning ? _handlePausePress : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: _isRunning ? Colors.white : Tema.brandPurple,
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
                  _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
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


  void _showRpePicker() {
    final double rpeInicial = _rpeSeleccionado;
    final int initialItemIndex = ((_rpeSeleccionado - 1.0) * 2).round();


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext ctx) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Container(
            height: 350,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)
                  )
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Valora tu esfuerzo (RPE)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.check, color: Tema.brandPurple, size: 28),
                        onPressed: () {
                           // Si GPS est\u00e1 activo, mostrar di\u00e1logo de selecci\u00f3n de distancia
                           if (widget.gpsActivo) {
                             Navigator.of(context).pop(); // Cerrar RPE picker
                             _showDistanceSelectionDialog();
                           } else {
                             // Sin GPS, guardar directamente
                             _handleSave();
                           }
                        },
                      )
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40.0,
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
                          style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.w500),
                        ),
                      );
                    }),
                  ),
                ),
                // Safety cancel button just in case
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
                  child: TextButton(
                    child: const Text('Cancelar / Reanudar', style: TextStyle(color: Colors.grey)),
                    onPressed: () {
                        _rpeSeleccionado = rpeInicial;
                        _handleResume();
                    },
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================================================================
  // DIÁLOGO DE SELECCIÓN DE DISTANCIA (GPS vs Manual)
  // ===================================================================

  void _showDistanceSelectionDialog() {
    final int distanciaGps = _distanciaGpsMetros.round();
    final int diferencia = (distanciaGps - _distanciaInt).abs();

    showDialog(
      context: context,
      barrierDismissible: false, // No cerrar al tocar fuera
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.compare_arrows, color: Tema.brandPurple),
              const SizedBox(width: 12),
              const Text('Selecciona la distancia', style: TextStyle(fontSize: 20)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Qué distancia quieres usar para esta serie?',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              
              // Distancia planificada (Manual)
              _buildDistanceOption(
                label: 'Distancia Planificada',
                value: '$_distanciaInt m',
                icon: Icons.route,
                color: Colors.blue,
                subtitle: 'Distancia que introdujiste',
              ),
              
              const SizedBox(height: 16),
              
              // Distancia GPS
              _buildDistanceOption(
                label: 'Distancia GPS',
                value: '$distanciaGps m',
                icon: Icons.location_on,
                color: Tema.brandPurple,
                subtitle: 'Medida por GPS',
              ),
              
              const SizedBox(height: 16),
              
              // Diferencia
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Diferencia: $diferencia m',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Botón: Usar Manual
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.blue),
                ),
                icon: const Icon(Icons.route, color: Colors.blue, size: 20),
                label: Text(
                  'Usar Manual ($_distanciaInt m)',
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Cerrar diálogo
                  _saveWithSelectedDistance(_distanciaInt, false);
                },
              ),
            ),
            const SizedBox(width: 12),
            // Botón: Usar GPS
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Tema.brandPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.location_on, color: Colors.white, size: 20),
                label: Text(
                  'Usar GPS ($distanciaGps m)',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Cerrar diálogo
                  _saveWithSelectedDistance(distanciaGps, true);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Widget helper para opciones de distancia
  Widget _buildDistanceOption({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}



