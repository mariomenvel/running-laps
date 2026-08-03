import 'package:flutter/material.dart';
// Force reload
import '../data/admin_repository.dart';
import '../../../core/services/pdf_generator_service.dart';
import 'package:printing/printing.dart';


enum AdminDateFilter { week, month, year, all, custom }

class AdminController extends ChangeNotifier {
  final AdminRepository _repository;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Map<String, dynamic> _stats = {};
  Map<String, dynamic> get stats => _stats;

  AdminDateFilter _currentFilter = AdminDateFilter.all;
  AdminDateFilter get currentFilter => _currentFilter;

  DateTimeRange? _customRange;
  DateTimeRange? get customRange => _customRange;

  AdminController({AdminRepository? repository})
      : _repository = repository ?? AdminRepository();

  /// Cambiar filtro de fecha y recargar
  void setDateFilter(AdminDateFilter filter) {
    if (filter != AdminDateFilter.custom) {
      _currentFilter = filter;
      _customRange = null; 
      loadDashboardStats();
    } else {
      _currentFilter = filter;
    }
  }

  /// Establecer rango personalizado
  void setCustomDateRange(DateTimeRange range) {
    _currentFilter = AdminDateFilter.custom;
    _customRange = range;
    loadDashboardStats();
  }

  /// Cargar estadísticas del dashboard
  Future<void> loadDashboardStats() async {
    _setLoading(true);
    try {
      DateTime? startDate;
      DateTime? endDate;
      final now = DateTime.now();
      
      switch (_currentFilter) {
        case AdminDateFilter.week:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case AdminDateFilter.month:
          startDate = now.subtract(const Duration(days: 30));
          break;
        case AdminDateFilter.year:
          startDate = now.subtract(const Duration(days: 365));
          break;
        case AdminDateFilter.all:
          startDate = null;
          break;
        case AdminDateFilter.custom:
           if (_customRange != null) {
             startDate = _customRange!.start;
             endDate = _customRange!.end;
             // Ajustar fin del día para endDate
             endDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
           }
          break;
      }
      
      _stats = await _repository.getGlobalStats(startDate: startDate, endDate: endDate);
    } catch (e) {
      // Error
    } finally {
      _setLoading(false);
    }
  }

  /// Crear un nuevo reto global
  Future<void> exportToPdf({
    required List<String> selectedMetrics,
    required DateTimeRange range,
  }) async {
    _setLoading(true);
    try {
      final pdfData = await PdfGeneratorService.generateAdminReportPdf(
        stats: _stats,
        selectedMetrics: selectedMetrics,
        range: range,
      );

      final fileName = 'Reporte_Admin_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      await Printing.sharePdf(
        bytes: pdfData,
        filename: fileName,
      );
    } catch (e) {
      // Error
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

}
