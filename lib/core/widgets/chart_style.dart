import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';

/// Estilo unificado de tooltips e interacción táctil para todas las gráficas
/// (`fl_chart`) de la app. Punto único de verdad para que cualquier gráfica
/// nueva o existente se vea igual:
///
/// - **Fondo `surface`** (nunca el negro por defecto de fl_chart, ilegible en
///   modo claro).
/// - **Borde sutil** + radio 8 + padding consistente.
/// - **`fitInside`** horizontal y vertical → el tooltip nunca se recorta contra
///   el borde de la gráfica.
/// - **Indicador de punto tocado** (línea discontinua morca + punto) en las
///   líneas, para que sea obvio *dónde* se ha pulsado.
///
/// Contenido del tooltip: usar [lineItem] / [barItem], que dan una línea
/// principal en negrita (el dato) y una secundaria opcional en gris (fecha o
/// contexto).
class AppChartStyle {
  AppChartStyle._();

  static const double _radius = 8;
  static const EdgeInsets _padding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  /// `LineTouchData` estándar. Pasar el builder de items via [getTooltipItems]
  /// (habitualmente construidos con [lineItem]). [showIndicator] dibuja la línea
  /// discontinua + punto sobre el spot tocado (por defecto activo).
  static LineTouchData lineTouch(
    BuildContext context, {
    required List<LineTooltipItem?> Function(List<LineBarSpot>) getTooltipItems,
    bool showIndicator = true,
  }) {
    return LineTouchData(
      handleBuiltInTouches: true,
      getTouchedSpotIndicator: showIndicator
          ? (barData, spotIndexes) => spotIndexes
              .map((_) => TouchedSpotIndicatorData(
                    const FlLine(
                      color: AppColors.brand,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                    const FlDotData(show: true),
                  ))
              .toList()
          : null,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => AppColors.surfaceOf(context),
        tooltipBorder:
            BorderSide(color: AppColors.borderOf(context), width: 0.5),
        tooltipBorderRadius: BorderRadius.circular(_radius),
        tooltipPadding: _padding,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: getTooltipItems,
      ),
    );
  }

  /// `BarTouchData` estándar. Pasar el builder de item via [getTooltipItem]
  /// (habitualmente construido con [barItem]).
  static BarTouchData barTouch(
    BuildContext context, {
    required BarTooltipItem? Function(
            BarChartGroupData, int, BarChartRodData, int)
        getTooltipItem,
  }) {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (_) => AppColors.surfaceOf(context),
        tooltipBorder:
            BorderSide(color: AppColors.borderOf(context), width: 0.5),
        tooltipBorderRadius: BorderRadius.circular(_radius),
        tooltipPadding: _padding,
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItem: getTooltipItem,
      ),
    );
  }

  /// Item de tooltip para `LineChart`: [primary] en negrita (dato principal) y
  /// [secondary] opcional en gris (fecha / contexto) en una segunda línea.
  static LineTooltipItem lineItem(
    BuildContext context,
    String primary, {
    String? secondary,
  }) {
    return LineTooltipItem(
      secondary == null ? primary : '$primary\n',
      AppTypography.small.copyWith(
        color: AppColors.textPrimary(context),
        fontWeight: FontWeight.w600,
      ),
      children: secondary == null ? null : [_secondarySpan(context, secondary)],
    );
  }

  /// Item de tooltip para `BarChart` con el mismo estilo que [lineItem].
  static BarTooltipItem barItem(
    BuildContext context,
    String primary, {
    String? secondary,
  }) {
    return BarTooltipItem(
      secondary == null ? primary : '$primary\n',
      AppTypography.small.copyWith(
        color: AppColors.textPrimary(context),
        fontWeight: FontWeight.w600,
      ),
      children: secondary == null ? null : [_secondarySpan(context, secondary)],
    );
  }

  static TextSpan _secondarySpan(BuildContext context, String text) {
    return TextSpan(
      text: text,
      style: AppTypography.small.copyWith(
        color: AppColors.iconMutedOf(context),
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
