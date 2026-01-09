import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:intl/intl.dart';

class PdfGeneratorService {
  // Colores corporativos profesionales (tonos apagados)
  static const PdfColor _brandPurple = PdfColor.fromInt(0xFF8E24AA);
  static const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);
  static const PdfColor _mediumGray = PdfColor.fromInt(0xFF757575);
  static const PdfColor _lightGray = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor _veryLightGray = PdfColor.fromInt(0xFFF5F5F5);

  /// Genera un PDF profesional para un entrenamiento
  static Future<Uint8List> generateTrainingPdf(Entrenamiento training) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildHeader(training),
          pw.SizedBox(height: 25),
          _buildSummarySection(training),
          pw.SizedBox(height: 25),
          
          // Sección de gráficas
          _buildChartsSection(training),
          pw.SizedBox(height: 25),
          
          _buildSeriesTable(training),
          pw.SizedBox(height: 20),
          _buildPerformanceAnalysis(training),
        ],
        footer: (context) => _buildFooter(context),
      ),
    );

    return pdf.save();
  }

  /// HEADER: Profesional y minimalista
  static pw.Widget _buildHeader(Entrenamiento training) {
    final dateFormat = DateFormat('d MMMM yyyy', 'es');
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'REPORTE DE ENTRENAMIENTO',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _mediumGray,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    training.titulo,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkGray,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dateFormat.format(training.fecha),
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: _mediumGray,
                    ),
                  ),
                ],
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: training.gps ? _brandPurple : _mediumGray, width: 1.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                training.gps ? 'GPS' : 'MANUAL',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: training.gps ? _brandPurple : _mediumGray,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          height: 2,
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_brandPurple, _lightGray],
            ),
          ),
        ),
      ],
    );
  }

  /// SUMMARY: Grid profesional
  static pw.Widget _buildSummarySection(Entrenamiento training) {
    final distanceKm = (training.distanciaTotalM() / 1000.0).toStringAsFixed(2);
    final totalTime = _formatTime(training.tiempoTotalSec().round());
    final avgPace = training.ritmoMedioTexto();
    final avgRpe = training.rpePromedio().toStringAsFixed(1);

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _veryLightGray,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _lightGray, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('DISTANCIA', distanceKm, 'km'),
          _buildVerticalDivider(),
          _buildStatColumn('TIEMPO', totalTime, ''),
          _buildVerticalDivider(),
          _buildStatColumn('RITMO MEDIO', avgPace.replaceAll(' /km', ''), '/km'),
          _buildVerticalDivider(),
          _buildStatColumn('RPE PROMEDIO', avgRpe, 'RPE'),
        ],
      ),
    );
  }

  static pw.Widget _buildStatColumn(String label, String value, String unit) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _mediumGray,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _darkGray,
              ),
            ),
            if (unit.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 3, bottom: 2),
                child: pw.Text(
                  unit,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: _mediumGray,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildVerticalDivider() {
    return pw.Container(
      width: 1,
      height: 40,
      color: _lightGray,
    );
  }

  /// CHARTS SECTION: Visualizaciones profesionales
  static pw.Widget _buildChartsSection(Entrenamiento training) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildPaceChart(training),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: _buildRpeChart(training),
        ),
      ],
    );
  }

  /// Gráfica de ritmo por serie (línea simplificada)
  static pw.Widget _buildPaceChart(Entrenamiento training) {
    if (training.series.isEmpty) return pw.SizedBox();
    
    final maxPace = training.series.map((s) => s.ritmoSecPorKm()).reduce((a, b) => a > b ? a : b).toDouble();
    final minPace = training.series.map((s) => s.ritmoSecPorKm()).reduce((a, b) => a < b ? a : b).toDouble();
    final range = maxPace - minPace;
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'EVOLUCION DE RITMO',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _mediumGray,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          height: 120,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _lightGray, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: List.generate(training.series.length, (i) {
              final serie = training.series[i];
              final pace = serie.ritmoSecPorKm().toDouble();
              final normalizedHeight = range > 0 
                  ? ((pace - minPace) / range) * 96
                  : 48.0;
              
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    decoration: const pw.BoxDecoration(
                      color: _brandPurple,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.Container(
                    width: 2,
                    height: normalizedHeight,
                    color: _brandPurple,
                  ),
                ],
              );
            }),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Evolucion del ritmo por serie',
          style: const pw.TextStyle(
            fontSize: 7,
            color: _mediumGray,
          ),
        ),
      ],
    );
  }

  /// Gráfica de distribución de RPE (barras)
  static pw.Widget _buildRpeChart(Entrenamiento training) {
    if (training.series.isEmpty) return pw.SizedBox();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DISTRIBUCION DE INTENSIDAD',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _mediumGray,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          height: 120,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _lightGray, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: List.generate(training.series.length, (i) {
              final serie = training.series[i];
              final height = (serie.rpe / 10) * 96;
              final color = _getRpeColor(serie.rpe);
              
              return pw.Container(
                width: (training.series.length > 8) ? 12 : 16,
                height: height,
                decoration: pw.BoxDecoration(
                  color: color.shade(0.3),
                  border: pw.Border.all(color: color, width: 1),
                ),
              );
            }),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'RPE por serie (escala 1-10)',
          style: const pw.TextStyle(
            fontSize: 7,
            color: _mediumGray,
          ),
        ),
      ],
    );
  }

  /// SERIES TABLE: Tabla minimalista
  static pw.Widget _buildSeriesTable(Entrenamiento training) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DETALLE DE SERIES',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _mediumGray,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: const pw.BorderSide(color: _lightGray, width: 0.5),
            bottom: const pw.BorderSide(color: _lightGray, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.8),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.8),
            4: const pw.FlexColumnWidth(1.2),
            5: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _darkGray),
              children: [
                _buildTableHeader('#'),
                _buildTableHeader('DISTANCIA'),
                _buildTableHeader('TIEMPO'),
                _buildTableHeader('RITMO'),
                _buildTableHeader('RPE'),
                _buildTableHeader('DESCANSO'),
              ],
            ),
            // Data rows
            ...training.series.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final serie = entry.value;
              
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: index % 2 == 0 ? _veryLightGray : PdfColors.white,
                ),
                children: [
                  _buildTableCell('$index', isCenter: true),
                  _buildTableCell('${serie.distanciaM}m'),
                  _buildTableCell(_formatTime(serie.tiempoSec.round())),
                  _buildTableCell(serie.ritmoTexto().replaceAll(' /km', '')),
                  _buildTableCell(
                    serie.rpe.toStringAsFixed(1),
                    color: _getRpeColor(serie.rpe),
                    isBold: true,
                  ),
                  _buildTableCell('${serie.descansoSec}s', isCenter: true),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isCenter = false,
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _darkGray,
        ),
        textAlign: isCenter ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  /// PERFORMANCE ANALYSIS: Minimalista
  static pw.Widget _buildPerformanceAnalysis(Entrenamiento training) {
    final avgRpe = training.rpePromedio();
    String intensityLevel;
    String recommendation;

    if (avgRpe < 4) {
      intensityLevel = 'RECUPERACION';
      recommendation = 'Sesion de recuperacion activa. Ideal para mantener la forma sin fatiga.';
    } else if (avgRpe < 7) {
      intensityLevel = 'MODERADO';
      recommendation = 'Entrenamiento aerobico de base. Mejora resistencia y capacidad cardiovascular.';
    } else if (avgRpe < 9) {
      intensityLevel = 'INTENSO';
      recommendation = 'Sesion de alta intensidad. Programar descanso adecuado (24-48h).';
    } else {
      intensityLevel = 'MUY INTENSO';
      recommendation = 'Esfuerzo maximo alcanzado. Recuperacion completa requerida (48-72h).';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _lightGray, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 4,
            height: 60,
            decoration: pw.BoxDecoration(
              color: _getRpeColor(avgRpe),
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'ANALISIS DE CARGA: ',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _mediumGray,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.Text(
                      intensityLevel,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _getRpeColor(avgRpe),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  recommendation,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: _darkGray,
                    lineSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// FOOTER
  static pw.Widget _buildFooter(pw.Context context) {
    final now = DateTime.now();
    final dateFormat = DateFormat('d/MM/yyyy HH:mm', 'es');
    
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _lightGray, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Running Laps',
            style: pw.TextStyle(
              fontSize: 8,
              color: _mediumGray,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '${dateFormat.format(now)} | Pag. ${context.pageNumber}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: _mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  // HELPER METHODS

  static String _formatTime(int totalSeconds) {
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  static PdfColor _getRpeColor(double rpe) {
    if (rpe < 4) return PdfColors.green700;
    if (rpe < 7) return PdfColors.blue700;
    if (rpe < 9) return PdfColors.orange700;
    return PdfColors.red700;
  }
}

