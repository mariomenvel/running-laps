import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/chart_style.dart';

/// Bombea un árbol mínimo y devuelve un BuildContext real (necesario porque el
/// helper resuelve colores dependientes del tema via AppColors.xxxOf(context)).
Future<BuildContext> pumpContext(WidgetTester tester) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(builder: (context) {
        captured = context;
        return const SizedBox();
      }),
    ),
  );
  return captured;
}

void main() {
  group('AppChartStyle.lineItem', () {
    testWidgets('sin secundario: una sola línea, sin children', (tester) async {
      final context = await pumpContext(tester);
      final item = AppChartStyle.lineItem(context, '5:30/km');
      expect(item.text, '5:30/km');
      expect(item.children, isNull);
      expect(item.textStyle?.fontWeight, FontWeight.w600);
      expect(item.textStyle?.color, AppColors.textPrimary(context));
    });

    testWidgets('con secundario: primary con salto + span gris', (tester) async {
      final context = await pumpContext(tester);
      final item =
          AppChartStyle.lineItem(context, '5:30/km', secondary: '12/7');
      expect(item.text, '5:30/km\n');
      expect(item.children, isNotNull);
      expect(item.children!.length, 1);
      final span = item.children!.first as TextSpan;
      expect(span.text, '12/7');
      expect(span.style?.color, AppColors.iconMutedOf(context));
    });
  });

  group('AppChartStyle.barItem', () {
    testWidgets('sin secundario: una sola línea, sin children', (tester) async {
      final context = await pumpContext(tester);
      final item = AppChartStyle.barItem(context, '12 km');
      expect(item.text, '12 km');
      expect(item.children, isNull);
      expect(item.textStyle?.fontWeight, FontWeight.w600);
    });

    testWidgets('con secundario: primary con salto + span gris', (tester) async {
      final context = await pumpContext(tester);
      final item = AppChartStyle.barItem(context, '12 km', secondary: 'Ene');
      expect(item.text, '12 km\n');
      final span = item.children!.first as TextSpan;
      expect(span.text, 'Ene');
    });
  });

  group('AppChartStyle.lineTouch', () {
    testWidgets('usa borde de tema y fitInside en ambos ejes', (tester) async {
      final context = await pumpContext(tester);
      final touch =
          AppChartStyle.lineTouch(context, getTooltipItems: (spots) => const []);
      final tip = touch.touchTooltipData;
      expect(tip.tooltipBorder.width, 0.5);
      expect(tip.tooltipBorder.color, AppColors.borderOf(context));
      expect(tip.fitInsideHorizontally, isTrue);
      expect(tip.fitInsideVertically, isTrue);
    });

    testWidgets('showIndicator true dibuja indicador de punto tocado',
        (tester) async {
      final context = await pumpContext(tester);
      final touch =
          AppChartStyle.lineTouch(context, getTooltipItems: (spots) => const []);
      expect(touch.getTouchedSpotIndicator, isNotNull);
      final indicators =
          touch.getTouchedSpotIndicator!(LineChartBarData(), [0]);
      expect(indicators.length, 1);
      expect(indicators.first?.indicatorBelowLine.color, AppColors.brand);
    });

    testWidgets('showIndicator false no dibuja indicador', (tester) async {
      final context = await pumpContext(tester);
      final touch = AppChartStyle.lineTouch(
        context,
        getTooltipItems: (spots) => const [],
        showIndicator: false,
      );
      expect(touch.getTouchedSpotIndicator, isNull);
    });
  });
}
