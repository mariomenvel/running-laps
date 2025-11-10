import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../data/serie.dart'; // Asegúrate que la ruta es correcta

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

  // --- Colores ---
  static const Color _brandPurple = Color(0xFF8E24AA);
  // ¡COLOR DEL GRADIENTE ACTUALIZADO! (Un poco más visible)
  static const Color _bgGradientColor = Color(0xFFF5EEF8);

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
    String hundredths =
        (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
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

  Widget _buildHeader() {
    return Container(
      // ¡GRADIENTE ACTUALIZADO!
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.0, // Ajustado para un brillo más concentrado
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 0.9], // Se difumina al 90% del radio
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const CircleAvatar(
              radius: 24.0,
              backgroundColor: _brandPurple,
              child: Icon(
                Icons.directions_run,
                color: Colors.white,
                size: 28.0,
              ),
            ),
            const CircleAvatar(
              radius: 24.0,
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=MnwxfDB8MXxyYW5kb218MHx8cHJvZmlsZSwgbWFsZSxwb3J0cmFpdHx8fHx8fDE3MTkyNTg0MzQ&ixlib.rb-4.0.3&q=80&w=1080',
              ),
            ),
          ],
        ),
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
          _buildInfoIcon(
            Icons.route_outlined,
            "${_distanciaInt}m",
          ),

          // --- Cronómetro ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
            decoration: BoxDecoration(
              border: Border.all(color: _brandPurple, width: 6.0),
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
        Icon(icon, color: _brandPurple, size: 48.0),
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

  Widget _buildFooter() {
    return Container(
      // ¡GRADIENTE ACTUALIZADO!
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.0, // Ajustado para un brillo más concentrado
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 0.9], // Se difumina al 90% del radio
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: GestureDetector(
          onTap: _isRunning ? _handlePausePress : null, // Solo funciona si está corriendo
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
              color: _brandPurple,
              size: 40.0,
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // Diálogo de RPE (La "Ruleta")
  // ===================================================================

  void _showRpePicker() {
    // Guarda el RPE actual por si el usuario cancela
    final double rpeInicial = _rpeSeleccionado;
    // Calcula el índice inicial para la ruleta
    final int initialItemIndex = ((_rpeSeleccionado - 1.0) * 10).round();

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
              scrollController: FixedExtentScrollController(initialItem: initialItemIndex),
              onSelectedItemChanged: (int index) {
                // index 0 -> 1.0
                // index 1 -> 1.1
                // ...
                // index 90 -> 10.0
                _rpeSeleccionado = (index / 10.0) + 1.0;
              },
              children: List.generate(91, (index) {
                // 91 items: de 1.0 (índice 0) a 10.0 (índice 90)
                final value = (index / 10.0) + 1.0;
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
              style: ElevatedButton.styleFrom(backgroundColor: _brandPurple),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
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