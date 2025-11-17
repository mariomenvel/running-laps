import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../data/serie.dart';
import '../../../app/tema.dart';

class TrainingSessionView extends StatefulWidget {
  final String distancia;
  final String descanso;
  final bool gpsActivo;

  const TrainingSessionView({
    Key? key,
    required this.distancia,
    required this.descanso,
    required this.gpsActivo,
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

  // --- Valores ---
  double _rpeSeleccionado = 5.0; // RPE inicial (escala 1-10)
  int _distanciaInt = 0;
  int _descansoInt = 0;

  // --- MODIFICADO (1 de 4) ---
  // Se iguala al color de TrainingStartView
  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  @override
  void initState() {
    super.initState();
    // Parsear los valores
    _distanciaInt = int.tryParse(widget.distancia) ?? 0;
    _descansoInt = int.tryParse(widget.descanso) ?? 0;

    // Iniciar el cronómetro
    _stopwatch.start();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  // ===================================================================
  // Lógica del Cronómetro
  // ===================================================================

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_stopwatch.isRunning) {
        setState(() {
          _tiempoMostrado = _formatTiempo(_stopwatch.elapsed);
        });
      }
    });
  }

  void _handlePausePress() {
    // Detener el crono y el timer
    _stopwatch.stop();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    // Mostrar el diálogo de RPE
    _showRpePicker();
  }

  void _handleResume() {
    // Reanudar el crono
    _stopwatch.start();
    _startTimer();
    setState(() {
      _isRunning = true;
    });
    Navigator.of(context).pop(); // Cerrar el diálogo
  }

  void _handleSave() {
    // 1. Obtener tiempo final en segundos
    final double tiempoFinalSec = _stopwatch.elapsed.inMilliseconds / 1000.0;

    // 2. Crear el objeto Serie
    final Serie serieTerminada = Serie(
      tiempoSec: tiempoFinalSec,
      distanciaM: _distanciaInt,
      descansoSec: _descansoInt,
      rpe: _rpeSeleccionado,
    );

    // 3. Cerrar el diálogo
    Navigator.of(context).pop();
    // 4. Volver a la pantalla anterior devolviendo la serie
    Navigator.of(context).pop(serieTerminada);
  }

  // ===================================================================
  // Formateadores de Texto
  // ===================================================================

  String _formatTiempo(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
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
  // Widgets de la UI
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // --- MODIFICADO (2 de 4) ---
  Widget _buildHeader() {
    return Container(
      // ¡GRADIENTE Y FONDO ACTUALIZADOS!
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2, // Ajustado para coincidir
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 1.0], // Ajustado para coincidir
        ),
        // Añadido para coincidir
        image: DecorationImage(
          image: AssetImage('assets/images/fondo.png'), // Ruta de tu imagen
          fit: BoxFit.cover, // Ajusta la imagen para cubrir
        ),
      ),
      // Añadida Column y línea divisoria para coincidir
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 24.0,
                  backgroundColor: Tema.brandPurple,
                  backgroundImage: const AssetImage('assets/images/logo.png'),
                ),
                CircleAvatar(
                  radius: 24.0,
                  backgroundImage: AssetImage(
                    'assets/images/icono_defecto.jpg',
                  ),
                ),
              ],
            ),
          ),
          // Línea divisoria añadida
          Container(height: 1.0, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      // El fondo es transparente, mostrando Colors.white del Scaffold
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- Distancia ---
          _buildInfoIcon(Icons.route_outlined, "${_distanciaInt}m"),

          // --- Cronómetro ---
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 20.0,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Tema.brandPurple, width: 6.0),
              borderRadius: BorderRadius.circular(100.0), // Borde muy redondo
            ),
            child: Text(
              _tiempoMostrado,
              style: const TextStyle(
                fontSize: 64.0,
                fontWeight: FontWeight.w300,
                fontFeatures: [FontFeature.tabularFigures()],
                color: Colors.black,
              ),
            ),
          ),

          // --- Descanso ---
          _buildInfoIcon(
            Icons.snooze_rounded, // Icono Zzz
            _formatDescanso(_descansoInt),
          ),
        ],
      ),
    );
  }

  /// Helper para los iconos de info de arriba y abajo
  Widget _buildInfoIcon(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Tema.brandPurple, size: 48.0),
        const SizedBox(height: 8.0),
        Text(
          text,
          style: const TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // --- MODIFICADO (3 de 4) ---
  Widget _buildFooter() {
    return Container(
      // ¡GRADIENTE Y FONDO ACTUALIZADOS!
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.2, // Ajustado para coincidir
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 1.0], // Ajustado para coincidir
        ),
        // Añadido para coincidir
        image: DecorationImage(
          image: AssetImage('assets/images/fondo.png'), // Ruta de tu imagen
          fit: BoxFit.cover, // Ajusta la imagen para cubrir
        ),
      ),
      // Añadida Column y línea divisoria para coincidir
      child: Column(
        children: [
          // Línea divisoria añadida
          Container(height: 1.0, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: GestureDetector(
              onTap: _isRunning
                  ? _handlePausePress
                  : null, // Solo funciona si está corriendo
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 15.0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  // Si está corriendo muestra Pausa, si no, muestra Play
                  _isRunning ? Icons.pause : Icons.play_arrow,
                  color: Tema.brandPurple,
                  size: 40.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // Diálogo de RPE (La "Ruleta")
  // ===================================================================

  // --- MODIFICADO (4 de 4) ---
  // Se ha corregido el generador de la lista del CupertinoPicker
  // para que tenga 19 items (de 1.0 a 10.0, en pasos de 0.5)
  // y se ha ajustado el cálculo del _rpeSeleccionado.
  void _showRpePicker() {
    // Guarda el RPE actual por si el usuario cancela
    final double rpeInicial = _rpeSeleccionado;
    // Calcula el índice inicial para la ruleta
    // (1.0 -> índice 0), (1.5 -> índice 1), (10.0 -> índice 18)
    final int initialItemIndex = ((_rpeSeleccionado - 1.0) * 2).round();

    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar pulsando fuera
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Valora tu esfuerzo (RPE)'),
          content: SizedBox(
            height: 150,
            child: CupertinoPicker(
              itemExtent: 32.0, // Altura de cada ítem
              scrollController: FixedExtentScrollController(
                initialItem: initialItemIndex,
              ),
              onSelectedItemChanged: (int index) {
                // index 0 -> 1.0
                // index 1 -> 1.5
                // ...
                // index 18 -> 10.0
                _rpeSeleccionado = (index * 0.5) + 1.0;
              },
              children: List.generate(19, (index) {
                // 19 items: 1.0, 1.5 ... 10.0
                final value = (index * 0.5) + 1.0;
                return Center(
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 22.0),
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                // Restaura el RPE y reanuda el crono
                _rpeSeleccionado = rpeInicial;
                _handleResume();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Tema.brandPurple, // Color de fondo
                foregroundColor: Colors.white, // Color del texto
              ),
              child: const Text('Guardar'),
              onPressed: () {
                // Guarda la serie y sale
                _handleSave();
              },
            ),
          ],
        );
      },
    );
  }
}
