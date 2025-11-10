import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Para capturar FirebaseException

// Asegúrate que las rutas son correctas
import '../data/entrenamiento.dart';
import '../data/serie.dart';
import '../data/training_repository.dart';
import 'training_session_view.dart';

class TrainingStartView extends StatefulWidget {
  const TrainingStartView({Key? key}) : super(key: key);

  @override
  _TrainingStartViewState createState() => _TrainingStartViewState();
}

class _TrainingStartViewState extends State<TrainingStartView> {
  // --- Repositorio (Lazy) ---
  late final TrainingRepository _trainingRepo = TrainingRepository();

  // --- Estado ---
  bool _isGpsOn = false;
  List<Map<String, dynamic>> series = [];

  // --- Controladores ---
  final TextEditingController _distanciaController = TextEditingController();
  final TextEditingController _descansoController = TextEditingController();
  final TextEditingController _trainingNameController = TextEditingController();
  
  bool _isSaving = false;

  // --- Estado del Descanso ---
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isResting = false;

  // --- Colores ---
  static const Color _brandPurple = Color(0xFF8E24AA);
  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  @override
  void dispose() {
    _distanciaController.dispose();
    _descansoController.dispose();
    _trainingNameController.dispose();
    _restTimer?.cancel();
    super.dispose();
  }

  // ===================================================================
  // Lógica del Temporizador de Descanso
  // ===================================================================

  void _startRestCountdown() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 0) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isResting = false;
        });
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restSecondsRemaining = 0;
    });
  }

  String _formatRestTime() {
    final int minutes = _restSecondsRemaining ~/ 60;
    final int seconds = _restSecondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ===================================================================
  // Lógica de Botones del Footer
  // ===================================================================

  /// Lógica para empezar la siguiente serie
  void _onStartSeriesTap() async {
    final String distanciaVal = _distanciaController.text;
    final String descansoVal = _descansoController.text;

    if (distanciaVal.isEmpty || descansoVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, introduce distancia y descanso.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrainingSessionView(
          distancia: distanciaVal,
          descanso: descansoVal,
          gpsActivo: _isGpsOn,
        ),
      ),
    );

    if (result != null && result is Serie) {
      setState(() {
        series.add(result.toMap());
      });

      _distanciaController.clear();
      _descansoController.clear();

      if (result.descansoSec > 0) {
        setState(() {
          _restSecondsRemaining = result.descansoSec;
          _isResting = true;
        });
        _startRestCountdown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Serie guardada! Ritmo: ${result.ritmoTexto()}'),
            backgroundColor: _brandPurple,
          ),
        );
      }
    }
  }

  /// 1. Muestra un diálogo para pedir el nombre
  void _onFinishTrainingTap() {
    if (_isSaving) return;
    _trainingNameController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar Entrenamiento'),
        content: TextField(
          controller: _trainingNameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del entrenamiento'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brandPurple),
            child: const Text('Guardar'),
            onPressed: () {
              final String trainingName = _trainingNameController.text;
              if (trainingName.isEmpty) return;
              
              Navigator.of(ctx).pop();
              _saveTrainingToFirebase(trainingName);
            },
          ),
        ],
      ),
    );
  }

  /// 2. Guarda el entrenamiento completo
  Future<void> _saveTrainingToFirebase(String trainingName) async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Convertir List<Map> a List<Serie>
      final List<Serie> seriesAsObjects = series
          .map((serieMap) => Serie.fromMap(serieMap))
          .toList();

      // Crear el objeto de dominio
      final Entrenamiento newTraining = Entrenamiento(
        titulo: trainingName,
        fecha: DateTime.now(),
        gps: _isGpsOn, // Usa el estado de _isGpsOn de la vista
        series: seriesAsObjects,
      );

      // Llamar al repositorio
      final String newTrainingId = await _trainingRepo.createTraining(newTraining);

      print('Entrenamiento guardado con ID: $newTrainingId');

      // ¡Comprobar 'mounted' ANTES de usar el context!
      if (!mounted) return;

      // Éxito y limpieza
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Entrenamiento "$trainingName" guardado!'),
          backgroundColor: _brandPurple,
        ),
      );

      setState(() {
        series.clear();
        _restTimer?.cancel();
        _isResting = false;
        _restSecondsRemaining = 0;
      });

    } catch (e) {
      // ¡Comprobar 'mounted' ANTES de usar el context!
      if (!mounted) return;

      // Ahora es seguro mostrar el SnackBar de error
      print("--- ERROR CAPTURADO ---");
      print("runtimeType: ${e.runtimeType}");
      print("toString(): ${e.toString()}");
      print("-------------------------");

      String errorMessage = "Error desconocido";
      String errorString = e.toString();

      // Analizar el texto del error
      if (errorString.contains("No hay usuario autenticado")) {
        errorMessage = "Error: No hay usuario autenticado";
      } else if (errorString.contains("PERMISSION_DENIED") || errorString.contains("permiso")) {
        errorMessage = "Error: Permiso denegado. Revisa las reglas de Firestore.";
      } else if (e is FirebaseException) {
        errorMessage = e.message ?? "Error de Firebase";
      } else if (e is Exception) {
        errorMessage = e.toString();
      } else {
        errorMessage = "Error de tipo en Web. ¿Estás logueado?";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );

    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false; 
        });
      }
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
        child: Column(children: [
          _buildHeader(),
          Expanded(child: _buildBody()), // El body se expande
          _buildFooter()
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 1.0],
        ),
      ),
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
                GestureDetector(
                  onTap: () {
                    print("Botón de Logo presionado");
                  },
                  child: const CircleAvatar(
                    radius: 24.0,
                    backgroundColor: _brandPurple,
                    child: Icon(
                      Icons.directions_run,
                      color: Colors.white,
                      size: 28.0,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    print("Botón de Perfil presionado");
                  },
                  child: const CircleAvatar(
                    radius: 24.0,
                    backgroundImage: NetworkImage(
                      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=MnwxfDB8MXxyYW5kb218MHx8cHJvZmlsZSwgbWFsZSxwb3J0cmFpdHx8fHx8fDE3MTkyNTg0MzQ&ixlib.rb-4.0.3&q=80&w=1080',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1.0, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40.0),
            _buildFormContainer(),
            const SizedBox(height: 40.0),
            
            // GPS solo se muestra si no hay series
            if (series.isEmpty) ...[
              _buildGpsToggle(),
              const SizedBox(height: 30.0),
            ],

            const Text(
              'Series Guardadas',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            Container(
              height: 1.0,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
            ),
            _buildSeriesList(),
            const SizedBox(height: 40.0), // Espacio al final
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesList() {
    if (series.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20.0),
        child: Text(
          'Aún no has añadido series.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final serie = Serie.fromMap(series[index]);
        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _brandPurple,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
                '${serie.distanciaM}m en ${serie.tiempoSec.toStringAsFixed(1)}s'),
            subtitle: Text('Ritmo: ${serie.ritmoTexto()} | RPE: ${serie.rpe}'),
            trailing: Text('Desc: ${serie.descansoSec}s'),
          ),
        );
      },
    );
  }

  Widget _buildFormContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade300, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 8.0, 0),
                child: TextField(
                  controller: _distanciaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  decoration: InputDecoration(
                    labelText: 'Distancia en metros',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.cancel, color: Colors.grey[400]),
                      onPressed: () => _distanciaController.clear(),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 1.0,
              color: Colors.grey[300],
              margin: const EdgeInsets.symmetric(vertical: 12.0),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 8.0, 0),
                child: TextField(
                  controller: _descansoController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  decoration: InputDecoration(
                    labelText: 'Descanso en segundos',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.cancel, color: Colors.grey[400]),
                      onPressed: () => _descansoController.clear(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsToggle() {
    return Column(
      children: [
        const Text(
          'GPS',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: _brandPurple,
          ),
        ),
        const SizedBox(height: 12.0),
        const Icon(Icons.location_searching, color: _brandPurple, size: 48.0),
        const SizedBox(height: 12.0),
        Transform.scale(
          scale: 1.3,
          child: Switch(
            value: _isGpsOn,
            onChanged: (bool value) {
              setState(() {
                _isGpsOn = value;
              });
              print("GPS Alternado: $_isGpsOn");
            },
            activeColor: _brandPurple,
            activeTrackColor: _brandPurple.withOpacity(0.5),
            inactiveThumbColor: Colors.grey[300],
            inactiveTrackColor: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // Footer Dinámico
  // ===================================================================

  Widget _buildFooter() {
    return _isResting
        ? _buildRestTimerFooter()
        : _buildStartButtonFooter();
  }

  Widget _buildRestTimerFooter() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.2,
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 1.0],
        ),
      ),
      child: Column(
        children: [
          Container(height: 1.0, color: Colors.grey.shade200),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
            child: Column(
              children: [
                Text(
                  "Descanso restante",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 10),
                Text(
                  _formatRestTime(),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: _brandPurple,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  child: const Text("Saltar descanso",
                      style: TextStyle(color: _brandPurple)),
                  onPressed: _skipRest,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButtonFooter() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.2,
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 1.0],
        ),
      ),
      child: Column(
        children: [
          Container(height: 1.0, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 40.0),
            child: (series.isEmpty)
                // Estado 1: Antes de la primera serie
                ? _buildCircularButton(
                    icon: Icons.play_arrow,
                    onTap: _onStartSeriesTap,
                  )
                // Estado 2: A partir de la segunda serie
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botón Play
                      _buildCircularButton(
                        icon: Icons.play_arrow,
                        onTap: _onStartSeriesTap,
                      ),
                      // Botón Terminar (con loader)
                      _buildCircularButton(
                        icon: Icons.close,
                        onTap: _onFinishTrainingTap,
                        color: Colors.red[700],
                        isLoading: _isSaving, // Pasa el estado de carga
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Helper para botones circulares (con loader)
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap, // Deshabilitar onTap si está cargando
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
        child: isLoading
            ? SizedBox(
                width: 40.0,
                height: 40.0,
                child: CircularProgressIndicator(
                  strokeWidth: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(color ?? _brandPurple),
                ),
              )
            : Icon(
                icon,
                color: color ?? _brandPurple,
                size: 40.0,
              ),
      ),
    );
  }
}