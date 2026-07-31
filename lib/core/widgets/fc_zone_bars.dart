import 'package:flutter/material.dart';

import '../services/zones_service.dart';
import '../theme/app_colors.dart';
import '../../features/training/data/fc_analytics.dart';
import '../../features/training/data/serie.dart';

/// Reparto del tiempo por zona de FC, en barras.
///
/// Único punto donde se pinta esta distribución: el resumen post-entreno y el
/// detalle del historial la comparten para que no puedan contar cosas
/// distintas — y el reparto sale de `FcAnalytics`, el mismo cálculo que recibe
/// el Coach IA. Antes el historial contaba **lecturas** en vez de tiempo, así
/// que una serie muestreada más densa se comía el porcentaje.
class FcZoneBars extends StatelessWidget {
  final List<Serie> series;
  final int? fcMax;

  /// Muestra los minutos además del porcentaje.
  final bool showMinutes;

  const FcZoneBars({
    super.key,
    required this.series,
    required this.fcMax,
    this.showMinutes = true,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = FcAnalytics.zoneMinutes(series, fcMax);
    final percentages = FcAnalytics.zonePercentages(series, fcMax);
    if (minutes == null || percentages == null) return const SizedBox.shrink();

    final zones = ZonesService().zonesFor(fcMax!);

    return Column(
      children: List.generate(5, (i) {
        if (percentages[i] <= 0) return const SizedBox.shrink();
        final color = zones[i].color;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  'Z${i + 1}',
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.borderOf(context),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (percentages[i] / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: showMinutes ? 74 : 38,
                child: Text(
                  showMinutes
                      ? '${percentages[i].round()}% · ${_fmtMinutes(minutes[i])}'
                      : '${percentages[i].round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  static String _fmtMinutes(double minutes) {
    if (minutes < 1) return '${(minutes * 60).round()}s';
    return '${minutes.round()} min';
  }
}
