import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';

class HistoryCarousel extends StatefulWidget {
  final List<Entrenamiento> recentTrainings;
  final Function(Entrenamiento) onTapTraining;

  const HistoryCarousel({
    Key? key,
    required this.recentTrainings,
    required this.onTapTraining,
  }) : super(key: key);

  @override
  State<HistoryCarousel> createState() => _HistoryCarouselState();
}

class _HistoryCarouselState extends State<HistoryCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.85);

  @override
  Widget build(BuildContext context) {
    if (widget.recentTrainings.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 200, // Altura prominente
      child: PageView.builder(
        controller: _pageController,
        padEnds: false, // Empieza a la izquierda (con padding manual) o centrado? 
        // Mejor centrado con viewportFraction < 1 para ver el siguiente
        itemCount: widget.recentTrainings.length,
        itemBuilder: (context, index) {
          final training = widget.recentTrainings[index];
          // Añadir padding lateral solo al primero/último si fuera necesario, 
          // pero con viewportFraction ya se ve bien centrado.
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildTrainingCard(context, training),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
     return Container(
       height: 200,
       margin: const EdgeInsets.symmetric(horizontal: 20),
       decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
          border: Border.all(color: Theme.of(context).colorScheme.outline, style: BorderStyle.solid),
       ),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.history_toggle_off, size: 40, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
           const SizedBox(height: 12),
           Text(
             "Sin historial reciente",
             style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600),
           )
         ],
       ),
     );
  }

  Widget _buildTrainingCard(BuildContext context, Entrenamiento training) {
    // Calcular métricas
    final distKm = training.distanciaTotalM() / 1000.0;
    final timeMin = training.tiempoTotalSec() / 60.0;
    final pace = training.ritmoMedioTexto();
    final dateStr = _formatRelativeDate(training.fecha);

    return GestureDetector(
      onTap: () => widget.onTapTraining(training),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Fondo decorativo (Mapa abstracto o gradiente)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.brandSurface
                        : Colors.white,
                  ),
                ),
              ),
              
              // Círculo decorativo
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER: Fecha + Icono
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black, // Estilo "pill" negro minimalista
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            dateStr, 
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ),
                        Icon(
                          training.gps ? Icons.gps_fixed : Icons.timer, 
                          color: AppColors.brand.withOpacity(0.5),
                        ),
                      ],
                    ),
                    
                    const Spacer(),

                    // TITULO
                    Text(
                      training.titulo.isNotEmpty ? training.titulo : "Entrenamiento",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // METRICAS ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         _buildMetric(distKm.toStringAsFixed(1), "km"),
                         _buildVerticalDivider(),
                         _buildMetric(pace, "min/km"),
                         _buildVerticalDivider(),
                         _buildMetric(timeMin.toStringAsFixed(0), "min"),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0 && now.day == date.day) {
      return "HOY";
    } else if (diff.inDays == 1 || (diff.inDays == 0 && now.day != date.day)) {
      return "AYER";
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE', 'es').format(date).toUpperCase(); // "LUNES"
    } else {
      return DateFormat('d MMM', 'es').format(date).toUpperCase(); // "12 DIC"
    }
  }
}

