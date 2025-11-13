import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Asumimos las rutas para los componentes necesarios
// En un proyecto real, necesitarías un AuthFailure.dart o manejar el error directamente.
// Para este ejemplo autocontenido, se asume que existe.
import '../../../core/auth_failure.dart'; // Para el manejo de errores (Mantengo la línea original)

// ===================================================================
// DEFINICIÓN DE CLASES DE MODELO
// ===================================================================

// CLASE SERIE
class Serie {
  final double tiempoSec;
  final int distanciaM;
  final int descansoSec;
  final double rpe;

  Serie({
    required this.tiempoSec,
    required this.distanciaM,
    required this.descansoSec,
    required this.rpe,
  }) : assert(tiempoSec >= 0),
       assert(distanciaM >= 0),
       assert(descansoSec >= 0),
       assert(rpe >= 1 && rpe <= 10);

  int ritmoSecPorKm() {
    if (distanciaM <= 0) {
      throw StateError('distanciaM debe ser > 0 para calcular ritmo');
    }
    final double km = distanciaM / 1000.0;
    final double secPerKm = tiempoSec / km;
    return secPerKm.round();
  }

  String ritmoTexto() {
    try {
      final int secKm = ritmoSecPorKm();
      final int mm = secKm ~/ 60;
      final int ss = secKm % 60;
      final String ss2 = ss < 10 ? '0$ss' : ss.toString();
      return '$mm:$ss2';
    } catch (_) {
      return '--:--';
    }
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tiempoSec': tiempoSec,
      'distanciaM': distanciaM,
      'descansoSec': descansoSec,
      'rpe': rpe,
    };
  }

  static Serie fromMap(Map<String, dynamic> map) {
    return Serie(
      tiempoSec: (map['tiempoSec'] as num).toDouble(),
      distanciaM: (map['distanciaM'] as num).toInt(),
      descansoSec: (map['descansoSec'] as num).toInt(),
      rpe: (map['rpe'] as num).toDouble(),
    );
  }
}

// CLASE ENTRENAMIENTO
class Entrenamiento {
  final String titulo;
  final DateTime fecha;
  final bool gps;
  final List<Serie> series;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? id;

  Entrenamiento({
    required this.titulo,
    required this.fecha,
    required this.gps,
    required this.series,
    this.createdAt,
    this.updatedAt,
    this.id,
  });

  int distanciaTotalM() {
    return series.fold(0, (sum, serie) => sum + serie.distanciaM);
  }

  double tiempoTotalSec() {
    return series.fold(
      0.0,
      (sum, serie) => sum + serie.tiempoSec + serie.descansoSec,
    );
  }

  double rpePromedio() {
    if (series.isEmpty) return 0.0;
    return series.fold(0.0, (sum, serie) => sum + serie.rpe) / series.length;
  }

  int ritmoMedioSecPorKm() {
    final int distanciaM = distanciaTotalM();
    final double tiempoSec = tiempoTotalSec();
    if (distanciaM <= 0 || tiempoSec <= 0) return 0;

    final double km = distanciaM / 1000.0;
    final double secPerKm = tiempoSec / km;
    return secPerKm.round();
  }

  String _formatSeconds(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes min ${seconds.toString().padLeft(2, '0')}s';
  }

  String tiempoTotalTexto() {
    return _formatSeconds(tiempoTotalSec().round());
  }

  String ritmoMedioTexto() {
    final int secKm = ritmoMedioSecPorKm();
    if (secKm == 0) return '--:-- /km';
    final int mm = secKm ~/ 60;
    final int ss = secKm % 60;
    final String ss2 = ss < 10 ? '0$ss' : ss.toString();
    return '$mm:$ss2 /km';
  }

  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> listaSeries = series
        .map((s) => s.toMap())
        .toList();
    final Map<String, dynamic> base = <String, dynamic>{
      'titulo': titulo,
      'fecha': fecha.toIso8601String(),
      'gps': gps,
      'series': listaSeries,
      'distanciaTotalM': distanciaTotalM(),
      'tiempoTotalSec': tiempoTotalSec(),
      'rpePromedio': rpePromedio(),
    };
    try {
      base['ritmoMedioSecKm'] = ritmoMedioSecPorKm();
    } catch (_) {
      base['ritmoMedioSecKm'] = null;
    }
    return base;
  }

  static DateTime _parseFechaFlexible(dynamic v) {
    if (v is Timestamp) {
      // Soporte para Timestamp de Firestore
      return v.toDate();
    }
    if (v is String) {
      return DateTime.parse(v);
    }
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return DateTime.now();
  }

  static Entrenamiento fromMap(Map<String, dynamic> map, {String? id}) {
    final List<dynamic> rawSeries = map['series'] as List<dynamic>;
    final List<Serie> cargadas = rawSeries
        .map((m) => Serie.fromMap(m as Map<String, dynamic>))
        .toList();

    return Entrenamiento(
      id: id,
      titulo: map['titulo'] as String,
      fecha: _parseFechaFlexible(map['fecha']),
      gps: map['gps'] as bool,
      series: cargadas,
      // Extrayendo campos de metadatos de Firestore
      createdAt: map.containsKey('createdAt')
          ? _parseFechaFlexible(map['createdAt'])
          : null,
      updatedAt: map.containsKey('updatedAt')
          ? _parseFechaFlexible(map['updatedAt'])
          : null,
    );
  }
}

// ===================================================================
// REPOSITORIO DE ENTRENAMIENTO
// ===================================================================

class TrainingRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Entrenamiento>> getTrainings() async {
    // Simulando un usuario logueado para que el código compile y funcione en un entorno de prueba
    final User? user = _auth.currentUser;
    if (user == null) {
      // **IMPORTANTE**: Sustituir 'AuthFailure' por la gestión real de autenticación.
      // Por ahora, se simula una lista vacía si no hay usuario real, para evitar crash.
      // throw AuthFailure('No user logged inUser not authenticated.');
      return Future.value(
        [],
      ); // Retorna lista vacía si no hay usuario simulado.
    }

    try {
      final CollectionReference trainingsRef = _db
          .collection('users')
          .doc(user.uid)
          .collection('trainings');

      final QuerySnapshot snapshot = await trainingsRef
          .orderBy('createdAt', descending: true)
          .get();

      final List<Entrenamiento> trainings = snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
        return Entrenamiento.fromMap(data, id: doc.id);
      }).toList();

      return trainings;
    } on FirebaseException catch (e) {
      throw Exception(
        'Error de Firebase al cargar entrenamientos: ${e.message}',
      );
    } catch (e) {
      throw Exception('Error inesperado al cargar entrenamientos: $e');
    }
  }
}

// ===================================================================
// CONTROLADOR
// ===================================================================

class ProfileController {
  final TrainingRepository _trainingRepo;

  ProfileController({TrainingRepository? trainingRepo})
    : _trainingRepo = trainingRepo ?? TrainingRepository();

  final ValueNotifier<List<Entrenamiento>> trainings =
      ValueNotifier<List<Entrenamiento>>([]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  Future<void> loadTrainings() async {
    error.value = null;
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final List<Entrenamiento> loadedTrainings = await _trainingRepo
          .getTrainings();
      trainings.value = loadedTrainings;
    } catch (e) {
      error.value = e.toString().contains('Exception:')
          ? e.toString().split('Exception:')[1].trim()
          : 'Error desconocido al cargar los entrenamientos.';
    } finally {
      isLoading.value = false;
    }
  }

  void dispose() {
    trainings.dispose();
    isLoading.dispose();
    error.dispose();
  }
}

// ===================================================================
// WIDGET TrainingCard (Tarjeta de Entrenamiento - CON DROP DOWN)
// ===================================================================

class _TrainingCard extends StatelessWidget {
  final Entrenamiento training;

  const _TrainingCard({required this.training});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // --- FUNCIÓN DEL BOTÓN POPUP / DROPDOWN ---
  Widget _buildDropdownButton(BuildContext context) {
    // Opción que se mostrará en el menú
    const String downloadOption = 'Descargar estadísticas en PDF';

    return PopupMenuButton<String>(
      // Icono que activa el menú (los tres puntos verticales)
      icon: const Icon(Icons.more_vert, color: _ProfileViewState._brandDark),

      // La función que se ejecuta cuando se selecciona una opción
      onSelected: (String result) {
        if (result == downloadOption) {
          // =======================================================
          // [ESPACIO PARA AÑADIR FUNCIONALIDAD]
          // Aquí es donde irá la lógica para generar y descargar el PDF.
          // Por ejemplo: call: generatePdf(training);
          // =======================================================

          // Muestra un mensaje temporal (Snackbar) al usuario
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Iniciando descarga de PDF para: ${training.titulo}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },

      // Constructor del menú
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: downloadOption,
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: _ProfileViewState._brandDark),
              SizedBox(width: 8),
              Text(downloadOption),
            ],
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. CABECERA DE LA TARJETA (Título y Dropdown)
          Container(
            padding: const EdgeInsets.only(
              left: 16,
              right: 0,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: _ProfileViewState._cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12.0),
              ),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    training.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _ProfileViewState._brandDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Botón de menú contextual (Dropdown)
                _buildDropdownButton(context),
              ],
            ),
          ),

          // 2. DETALLES DEL ENTRENAMIENTO
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna 1: Distancia y Ritmo
                _buildDetailColumn([
                  _buildDetailText(
                    '${(training.distanciaTotalM() / 1000.0).toStringAsFixed(1)} KM',
                    isPrimary: true,
                  ),
                  _buildDetailText(
                    training.ritmoMedioTexto(),
                    isPrimary: false,
                  ),
                ]),

                // Columna 2: RPE
                _buildDetailColumn([
                  _buildDetailText(
                    'RPE ${training.rpePromedio().toStringAsFixed(1).replaceAll('.', ',')}',
                    isPrimary: true,
                  ),
                  _buildDetailText(
                    '${training.tiempoTotalTexto()}',
                    isPrimary: false,
                  ),
                ]),

                // Columna 3: Series, Tiempo y Fecha
                _buildDetailColumn([
                  _buildDetailText(
                    '${training.series.length} series',
                    isPrimary: true,
                  ),
                  const SizedBox(height: 4),
                  _buildDetailText(
                    _formatDate(training.fecha),
                    isPrimary: false,
                  ),
                ], alignment: CrossAxisAlignment.end),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para las columnas de detalles
  Widget _buildDetailColumn(
    List<Widget> children, {
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    return Column(crossAxisAlignment: alignment, children: children);
  }

  // Widget auxiliar para el texto de detalles
  Widget _buildDetailText(String text, {required bool isPrimary}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isPrimary ? 14 : 12,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
          color: isPrimary
              ? _ProfileViewState._brandDark
              : Colors.grey.shade600,
        ),
      ),
    );
  }
}

// ===================================================================
// VISTA DE PERFIL (ProfileView)
// ===================================================================

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  // --- Colores ---
  static const Color _brandPurple = Color(0xFF8E24AA);
  static const Color _brandDark = Color(0xFF333333);
  static const Color _cardColor = Color(0xFFF0F0F0);
  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  // --- Controlador ---
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController();
    _controller.loadTrainings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER
            _buildHeader(),

            // 2. TÍTULO
            const Padding(
              padding: EdgeInsets.only(top: 24.0, bottom: 16.0),
              child: Text(
                'HISTORIAL DE ENTRENAMIENTOS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _brandDark,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            // 3. BODY (LISTA DE ENTRENAMIENTOS)
            Expanded(child: _buildTrainingList()),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 1. HEADER
  // ===================================================================
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [_bgGradientColor, Colors.white],
          stops: [0.0, 1.0],
        ),
        // **IMPORTANTE**: Asegúrate de que esta ruta de imagen sea válida
        image: const DecorationImage(
          image: AssetImage('assets/images/fondo.png'), // Ruta de tu imagen
          fit: BoxFit.cover,
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
                // Icono de Corredor (Volver)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Funcionalidad de volver
                  },
                  child: CircleAvatar(
                    radius: 24.0,
                    backgroundColor: _ProfileViewState
                        ._brandPurple, // Este será el color si la imagen falla o tiene transparencia
                    // 💡 SOLUCIÓN CLAVE: Usar backgroundImage para que la imagen rellene el círculo
                    backgroundImage: const AssetImage('assets/images/logo.png'),

                    // **IMPORTANTE:** Cuando usas backgroundImage, ya NO necesitas un 'child' con Image.asset
                    // ni propiedades como 'width', 'height', 'fit', o 'color' para la imagen.
                    // El CircleAvatar se encarga de recortar y ajustar la imagen para rellenar.

                    // Si tu logo tiene un fondo transparente y quieres que el fondo del CircleAvatar
                    // se vea (como el morado), 'backgroundImage' superpondrá la imagen.
                    // El 'backgroundColor' actuará como un respaldo o un tinte si la imagen no tiene fondo.
                  ),
                ),
                // Avatar del Usuario
                GestureDetector(
                  onTap: () {
                    debugPrint("Botón de Perfil presionado");
                  },
                  child: const CircleAvatar(
                    radius: 24.0,
                    // **IMPORTANTE**: Asegúrate de que esta ruta de imagen sea válida
                    backgroundImage: AssetImage(
                      'assets/images/icono_defecto.jpg', // Imagen de perfil
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Línea divisoria debajo del header
          Container(height: 1.0, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  // ===================================================================
  // 2. BODY - Lista de entrenamientos con manejo de estado
  // ===================================================================
  Widget _buildTrainingList() {
    // Escucha el estado de carga
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isLoading,
      builder: (context, isLoading, child) {
        // Muestra el indicador de carga si está cargando y la lista está vacía
        if (isLoading && _controller.trainings.value.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: _brandPurple),
          );
        }

        // Escucha el estado de error
        return ValueListenableBuilder<String?>(
          valueListenable: _controller.error,
          builder: (context, error, child) {
            if (error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GestureDetector(
                    onTap: _controller.loadTrainings,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error al cargar entrenamientos: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Toca para reintentar.',
                          style: TextStyle(
                            color: _brandPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Escucha la lista de entrenamientos
            return ValueListenableBuilder<List<Entrenamiento>>(
              valueListenable: _controller.trainings,
              builder: (context, trainings, child) {
                if (trainings.isEmpty && !isLoading) {
                  return const Center(
                    child: Text(
                      'No hay entrenamientos registrados. ¡Comienza uno nuevo!',
                    ),
                  );
                }

                // Lista de tarjetas (TrainingCard)
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: trainings.length,
                  itemBuilder: (context, index) {
                    final training = trainings[index];
                    return _TrainingCard(training: training);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ===================================================================
// Fin del código
// ===================================================================
