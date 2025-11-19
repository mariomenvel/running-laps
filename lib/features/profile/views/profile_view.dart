import 'package:flutter/material.dart';
import 'package:running_laps/app/tema.dart';
import 'package:running_laps/features/profile/views/avatar_editor_wrapper_view.dart';
import 'package:running_laps/features/profile/viewmodels/profile_controller.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import '../../training/data/serie.dart';
import '../../../core/widgets/app_footer.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() {
    return _ProfileViewState();
  }
}

class _ProfileViewState extends State<ProfileView> {
  // Colores de la vista
  static const Color _brandDark = Color(0xFF333333);
  static const Color _cardColor = Color(0xFFF0F0F0);
  static const Color _bgGradientColor = Color(0xFFF9F5FB);

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
          children: <Widget>[
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

            // 3. LISTA (scrollable)
            Expanded(child: _buildTrainingList()),

            // 4. FOOTER (Fijo abajo)
            AppFooter(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return const TrainingStartView();
                    },
                  ),
                );
              },
              isLoading: false,
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // HEADER
  // ============================
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment.topCenter,
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(
                    radius: 24.0,
                    backgroundColor: Tema.brandPurple,
                    backgroundImage: const AssetImage('assets/images/logo.png'),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) {
                          return const AvatarEditorWrapperView();
                        },
                      ),
                    );
                  },
                  child: const CircleAvatar(
                    radius: 24.0,
                    backgroundImage: AssetImage(
                      'assets/images/icono_defecto.jpg',
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

  // ============================
  // LISTA DE ENTRENAMIENTOS
  // ============================
  Widget _buildTrainingList() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isLoading,
      builder: (BuildContext context, bool isLoading, Widget? child) {
        if (isLoading && _controller.trainings.value.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Tema.brandPurple),
          );
        }

        return ValueListenableBuilder<String?>(
          valueListenable: _controller.error,
          builder: (BuildContext context, String? error, Widget? child) {
            if (error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GestureDetector(
                    onTap: _controller.loadTrainings,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Toca para reintentar.',
                          style: TextStyle(
                            color: Tema.brandPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ValueListenableBuilder<List<Entrenamiento>>(
              valueListenable: _controller.trainings,
              builder:
                  (
                    BuildContext context,
                    List<Entrenamiento> trainings,
                    Widget? child,
                  ) {
                    if (trainings.isEmpty && !isLoading) {
                      return const Center(
                        child: Text(
                          'No hay entrenamientos registrados. ¡Comienza uno nuevo!',
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: trainings.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Entrenamiento training = trainings[index];
                        return TrainingCard(
                          training: training,
                          brandDark: _brandDark,
                          cardColor: _cardColor,
                        );
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

// ============================
// WIDGET: TARJETA ENTRENAMIENTO
// ============================
class TrainingCard extends StatefulWidget {
  final Entrenamiento training;
  final Color brandDark;
  final Color cardColor;

  const TrainingCard({
    Key? key,
    required this.training,
    required this.brandDark,
    required this.cardColor,
  }) : super(key: key);

  @override
  _TrainingCardState createState() {
    return _TrainingCardState();
  }
}

class _TrainingCardState extends State<TrainingCard> {
  bool _expanded = false;

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();
    return day + '/' + month + '/' + year;
  }

  String _formatSeconds(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String secText = seconds.toString().padLeft(2, '0');
    return minutes.toString() + ' min ' + secText + 's';
  }

  Widget _buildDropdownButton(BuildContext context) {
    const String downloadOption = 'Descargar estadísticas en PDF';

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: widget.brandDark),
      onSelected: (String value) {
        if (value == downloadOption) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Iniciando descarga de PDF para: ' + widget.training.titulo,
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      itemBuilder: (BuildContext context) {
        final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[];
        items.add(
          PopupMenuItem<String>(
            value: downloadOption,
            child: Row(
              children: <Widget>[
                Icon(Icons.picture_as_pdf, color: widget.brandDark),
                const SizedBox(width: 8),
                const Text(downloadOption),
              ],
            ),
          ),
        );
        return items;
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildDetailText(String text, bool isPrimary) {
    FontWeight weight;
    double size;
    Color color;

    if (isPrimary) {
      weight = FontWeight.w600;
      size = 14;
      color = widget.brandDark;
    } else {
      weight = FontWeight.normal;
      size = 12;
      color = Colors.grey.shade600;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Text(
        text,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color),
      ),
    );
  }

  Widget _buildDetailColumn(
    List<Widget> children,
    CrossAxisAlignment alignment,
  ) {
    return Column(crossAxisAlignment: alignment, children: children);
  }

  // Lista de series: una línea por serie, con columnas alineadas
  // Lista de series: columnas bien separadas
  Widget _buildSeriesListInline() {
    final List<Widget> children = <Widget>[];

    for (int i = 0; i < widget.training.series.length; i = i + 1) {
      final Serie serie = widget.training.series[i];

      final String distanciaText = serie.distanciaM.toString() + ' m';
      final String ritmoText = serie.ritmoTexto(); // ej: "0:09 /km"
      final String rpeText = 'RPE ' + serie.rpe.toString();
      final String descansoText =
          'Descanso ' + serie.descansoSec.toString() + ' s';

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Columna fija izquierda: "Serie 1", "Serie 2"...
              SizedBox(
                width: 80,
                child: Text(
                  'Serie ' + (i + 1).toString(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: widget.brandDark,
                  ),
                ),
              ),

              // Columna distancia
              Expanded(
                flex: 2,
                child: Text(
                  distanciaText,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                ),
              ),
              const SizedBox(width: 16),

              // Columna ritmo
              Expanded(
                flex: 2,
                child: Text(
                  ritmoText,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                ),
              ),
              const SizedBox(width: 16),

              // Columna RPE
              Expanded(
                flex: 2,
                child: Text(
                  rpeText,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                ),
              ),
              const SizedBox(width: 16),

              // Columna Descanso
              Expanded(
                flex: 3,
                child: Text(
                  descansoText,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double kmTotal = widget.training.distanciaTotalM() / 1000.0;
    final String distanciaTexto = kmTotal.toStringAsFixed(1) + ' KM';

    final String ritmoTexto = widget.training.ritmoMedioTexto();
    final String rpeTexto =
        'RPE ' +
        widget.training.rpePromedio().toStringAsFixed(1).replaceAll('.', ',');

    final String tiempoTexto = _formatSeconds(
      widget.training.tiempoTotalSec().round(),
    );

    // Icono de expandir/colapsar
    IconData expandIcon;
    if (_expanded) {
      expandIcon = Icons.expand_less;
    } else {
      expandIcon = Icons.expand_more;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          // Cabecera tarjeta (título + menú PDF)
          Container(
            padding: const EdgeInsets.only(
              left: 16,
              right: 0,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12.0),
              ),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.training.titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: widget.brandDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildDropdownButton(context),
              ],
            ),
          ),

          // Resumen entrenamiento
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildDetailColumn(<Widget>[
                  _buildDetailText(distanciaTexto, true),
                  _buildDetailText(ritmoTexto, false),
                ], CrossAxisAlignment.start),
                _buildDetailColumn(<Widget>[
                  _buildDetailText(rpeTexto, true),
                  _buildDetailText(tiempoTexto, false),
                ], CrossAxisAlignment.center),
                _buildDetailColumn(<Widget>[
                  _buildDetailText(
                    widget.training.series.length.toString() + ' series',
                    true,
                  ),
                  const SizedBox(height: 4),
                  _buildDetailText(_formatDate(widget.training.fecha), false),
                ], CrossAxisAlignment.end),
              ],
            ),
          ),

          // Botón de desplegar + lista de series
          if (widget.training.series.isNotEmpty)
            Padding(
              // mismo margen horizontal que el resumen (16)
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 8.0,
                top: 0.0,
              ),
              child: Column(
                children: <Widget>[
                  // Icono arriba a la derecha, pegado al contenido
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          expandIcon,
                          size: 22,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () {
                          setState(() {
                            _expanded = !_expanded;
                          });
                        },
                      ),
                    ],
                  ),

                  // Contenido desplegable (series)
                  if (_expanded)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4.0),
                      child: _buildSeriesListInline(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
