import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
// import 'package:running_laps/features/profile/views/avatar_editor_wrapper_view.dart';
import 'package:running_laps/features/history/viewmodels/history_controller.dart';

import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/views/training_start_view.dart';
import 'package:running_laps/features/profile/views/profile_menu_screen.dart';
import 'package:running_laps/features/home/views/home_view_legacy.dart';
import '../../training/data/serie.dart';
import '../../training/data/tag_model.dart';
import '../../training/data/tag_manager.dart';
import '../../training/widgets/tag_chip.dart';
import '../../training/widgets/tag_selector_sheet.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/empty_state_widget.dart';
import 'package:running_laps/core/widgets/gradient_banner.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/services/pdf_generator_service.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:running_laps/features/history/widgets/history_filter_sheet.dart';
import 'package:running_laps/features/history/widgets/history_calendar_widget.dart';
import 'package:running_laps/features/analytics/views/analytics_hub_screen.dart';
import 'package:universal_html/html.dart' as html;
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/history/widgets/premium_training_card.dart';
import 'package:running_laps/features/history/widgets/history_bottom_bar.dart';
import 'package:running_laps/features/history/widgets/history_search_bar.dart';
import 'package:running_laps/features/history/widgets/filter_badge_button.dart';
import 'package:running_laps/core/widgets/skeleton_shimmer.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() {
    return _HistoryScreenState();
  }
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  // Colores de la vista (Actualizados para estética premium)
  static const Color _bgCustomGrey = Color(0xFFF4F6F8);
  static const Color _brandDark = Color(0xFF2C3E50);

  late final HistoryController _controller;
  late final ScrollController _scrollController;

  // ── Entrance animation ──────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  bool _entrancePlayed = false;
  late final Animation<double> _aBanner;  // 0ms  – fade + slide left
  late final Animation<double> _aSearch;  // 80ms – fade + slide left
  late final Animation<double> _aItem0;   // 160ms – fade + slide bottom
  late final Animation<double> _aItem1;   // 220ms
  late final Animation<double> _aItem2;   // 280ms
  late final Animation<double> _aItem3;   // 340ms
  late final Animation<double> _aItem4;   // 400ms
  // ────────────────────────────────────────────────────────────────
  
  // VIEW MODE: List vs Calendar
  bool _isCalendarView = false;
  DateTime? _selectedCalendarDate;
  
  // SELECTION MODE
  final Set<String> _selectedTrainingIds = {};
  bool get _isSelectionMode => _selectedTrainingIds.isNotEmpty;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _controller.loadMore();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = HistoryController();
    _scrollController = ScrollController()..addListener(_onScroll);
    _controller.loadTrainings();
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _aBanner = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.000, 0.517, curve: Curves.easeOutQuart));
    _aSearch = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.067, 0.583, curve: Curves.easeOutQuart));
    _aItem0  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.133, 0.650, curve: Curves.easeOutQuart));
    _aItem1  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.183, 0.700, curve: Curves.easeOutQuart));
    _aItem2  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.233, 0.750, curve: Curves.easeOutQuart));
    _aItem3  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.283, 0.800, curve: Curves.easeOutQuart));
    _aItem4  = CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0.333, 0.850, curve: Curves.easeOutQuart));
    if (!_entrancePlayed) {
      _entrancePlayed = true;
      _entranceCtrl.forward();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _entranceCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedTrainingIds.contains(id)) {
        _selectedTrainingIds.remove(id);
      } else {
        _selectedTrainingIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTrainingIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: <Widget>[
            // 1. HEADER (Reutilizando AppHeader que ya tiene el gradiente)
            _buildHeader(),

            // 2. Gradient Banner
            _slideFromLeft(_aBanner, GradientBanner(
              title: 'Historial',
              subtitle: 'Todos tus entrenamientos',
              icon: Icons.history_rounded,
              accentColor: AppColors.effortSurfaceConst,
              height: 85,
              trailing: IconButton(
                 onPressed: _openAnalytics,
                 icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
                 style: IconButton.styleFrom(
                   backgroundColor: Colors.white.withOpacity(0.2),
                 ),
                 tooltip: 'Ver estadísticas',
              ),
            )),

            // 3. CONTENIDO PRINCIPAL
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // SEARCH BAR & CONTROLS
                  _slideFromLeft(_aSearch, Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _controller.searchQuery,
                      builder: (context, query, _) {
                        return Row(
                          children: [
                            // Search Bar (Expanded)
                            Expanded(
                              child: HistorySearchBar(
                                query: query,
                                onChanged: (val) => _controller.setSearchQuery(val),
                                onClear: () => _controller.setSearchQuery(''),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Filter Button (con badge reactivo)
                            ValueListenableBuilder<Set<String>>(
                              valueListenable: _controller.selectedTags,
                              builder: (context, tags, _) {
                                return ValueListenableBuilder<DateTime?>(
                                  valueListenable: _controller.filterStartDate,
                                  builder: (context, date, _) {
                                    return FilterBadgeButton(
                                      activeFiltersCount: _controller.activeFiltersCount,
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => HistoryFilterSheet(controller: _controller),
                                        );
                                      },
                                    );
                                  }
                                );
                              }
                            ),
                            
                            const SizedBox(width: 4),

                            // Calendar Toggle
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isCalendarView = !_isCalendarView;
                                });
                              },
                              icon: Icon(
                                _isCalendarView ? Icons.list_rounded : Icons.calendar_month_rounded,
                                color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                              ),
                              tooltip: _isCalendarView ? 'Ver lista' : 'Ver calendario',
                            ),
                          ],
                        );
                      }
                    ),
                  )),

                  // CALENDAR WIDGET (Expandible/Colapsable)
                  if (_isCalendarView)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: ValueListenableBuilder<List<Entrenamiento>>(
                        valueListenable: _controller.trainings,
                        builder: (context, _, __) {
                           return HistoryCalendarWidget(
                             events: _controller.eventsByDay,
                             selectedDay: _selectedCalendarDate,
                             getTagColor: _controller.getColorForTag,
                             onDaySelected: (date) {
                               setState(() {
                                 _selectedCalendarDate = date;
                               });
                               // Filtrar lista por este día
                               _controller.setDateRange(date, date); 
                             },
                           );
                        },
                      ),
                    ),

                  // CHIP DE FILTRO ACTIVO (cuando calendario está minimizado)
                  if (!_isCalendarView && _selectedCalendarDate != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.brand.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Filtrando: ${_formatDateLong(_selectedCalendarDate!)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.brandLight
                                    : AppColors.brand,
                              ),
                            ),
                            const Spacer(),
                            // Botón para limpiar filtro
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCalendarDate = null;
                                  _controller.setDateRange(null, null);
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // FILTROS ACTIVOS (CHIPS) - Solo si no estamos en vista calendario
                  if (!_isCalendarView) 
                    _buildActiveFilters(),

                  /*
                  // BARRA DE BÚSQUEDA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por título...',
                        hintStyle: TextStyle(color: AppColors.iconMuted),
                        prefixIcon: Icon(Icons.search, color: AppColors.iconMuted),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.iconMuted),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.brand, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: (value) => _controller.setSearchQuery(value),
                    ),
                  ),
                  */

                  // LISTA (scrollable)
                  Expanded(child: _buildTrainingList()),
                ],
              ),
            ),


          ],
        ), // Cierre Column
      ), // Cierre SafeArea

      // BOTTOM BAR
      Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<List<Entrenamiento>>(
              valueListenable: _controller.trainings,
              builder: (context, trainings, _) {
                return HistoryBottomBar(
                  selectedCount: _selectedTrainingIds.length,
                  filteredCount: trainings.length,
                  onViewDashboards: _controller.activeFiltersCount > 0 ? _openAnalytics : null,
                  onCompare: _selectedTrainingIds.length > 1 ? () {
                       ModernSnackBar.showInfo(context, "Comparador próximamente");
                  } : null,
                );
              }
          ),
      ),
    ], 
  ), 
);
  }

  // ── Entrance animation helpers ────────────────────────────────────
  Widget _slideFromLeft(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(-24 * (1 - anim.value), 0),
          child: child,
        ),
      ),
    );
  }

  Widget _slideFromBottom(Animation<double> anim, Widget child) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────

  // ============================
  // HEADER
  // ============================
  Widget _buildHeader() {
    return AppHeader(
      showBottomDivider: false,
      onTapRight: () {
        Navigator.push(
          context,
          AppRoute(page: const ProfileMenuView()),
        );
      },
    );
  }

  // ============================
  // FILTER MENU BUTTON & CHIPS
  // ============================
  Widget _buildFilterMenu() {
    // 1. Botón Principal de Filtro (Abre el Sheet)
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => HistoryFilterSheet(controller: _controller),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.iconMuted),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 18, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
                const SizedBox(width: 6),
                ValueListenableBuilder<int>( // Escuchar cambios en profile_controller para mostrar badge
                  valueListenable: ValueNotifier<int>(0), // TODO: Esto debería ser reactivo real, ver abajo
                  builder: (context, _, __) {
                    // Hack rápido: Usamos AnimatedBuilder para reconstruir cuando cambie ALGO en el controller
                    return AnimatedBuilder(
                      animation: Listenable.merge([
                        _controller.currentFilter,
                        _controller.searchQuery,
                        _controller.selectedTags,
                        _controller.filterStartDate,
                        _controller.filterEndDate,
                        _controller.filterMinDist,
                        _controller.filterMaxDist,
                        _controller.filterSeriesDistance,
                      ]),
                      builder: (context, _) {
                        final int count = _controller.activeFiltersCount;
                        if (count == 0) return const Text('Filtrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
                        
                        return Text(
                          'Filtros ($count)', 
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand, fontSize: 13)
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget para mostrar los chips de filtros activos debajo del título
  Widget _buildActiveFilters() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _controller.currentFilter,
        _controller.searchQuery,
        _controller.selectedTags,
        _controller.filterStartDate,
        _controller.filterEndDate,
        _controller.filterMinDist,
        _controller.filterMaxDist,
        _controller.filterSeriesDistance,
      ]),
      builder: (context, _) {
        final List<Widget> chips = [];

        // 1. Rando Fechas
        if (_controller.filterStartDate.value != null || _controller.filterEndDate.value != null) {
            String label = 'Fechas';
            if (_controller.filterStartDate.value != null && _controller.filterEndDate.value != null) {
              label = '${DateFormat('dd/MM').format(_controller.filterStartDate.value!)} - ${DateFormat('dd/MM').format(_controller.filterEndDate.value!)}';
            } else if (_controller.filterStartDate.value != null) {
              label = 'Desde ${DateFormat('dd/MM').format(_controller.filterStartDate.value!)}';
            } else {
              label = 'Hasta ${DateFormat('dd/MM').format(_controller.filterEndDate.value!)}';
            }
            chips.add(_buildChip(label, () => _controller.setDateRange(null, null)));
        }

        // 2. Distancia
        if (_controller.filterMinDist.value != null || _controller.filterMaxDist.value != null) {
           String label = 'Distancia';
           if (_controller.filterMinDist.value != null && _controller.filterMaxDist.value != null) {
             label = '${(_controller.filterMinDist.value!/1000).toStringAsFixed(1)}-${(_controller.filterMaxDist.value!/1000).toStringAsFixed(1)} km';
           } else if (_controller.filterMinDist.value != null) {
             label = '> ${(_controller.filterMinDist.value!/1000).toStringAsFixed(1)} km';
           } else {
             label = '< ${(_controller.filterMaxDist.value!/1000).toStringAsFixed(1)} km';
           }
           chips.add(_buildChip(label, () => _controller.setDistanceRange(null, null)));
        }

        // 3. Series
        if (_controller.filterSeriesDistance.value != null) {
          chips.add(_buildChip('Series ${_controller.filterSeriesDistance.value}m', () => _controller.setSeriesDistanceFilter(null)));
        }
        
        // 4. Tags
        for (var tag in _controller.selectedTags.value) {
          chips.add(_buildChip('#$tag', () => _controller.toggleTagFilter(tag)));
        }

        if (chips.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...chips,
              // Botón limpiar todo
              GestureDetector(
                onTap: _controller.clearAllFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.rpeMax.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Borrar todo', style: TextStyle(fontSize: 11, color: AppColors.rpeMax, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brand.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandLight
                  : AppColors.brand,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: Theme.of(context).brightness == Brightness.dark ? AppColors.brandLight : AppColors.brand),
          ),
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
        final showSkeleton = isLoading && _controller.trainings.value.isEmpty;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: showSkeleton
              ? _buildHistoryLoadingSkeleton()
              : ValueListenableBuilder<String?>(
                  key: const ValueKey('history_content'),
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
                        Icon(Icons.error_outline, size: 48, color: AppColors.rpeMax),
                        const SizedBox(height: 16),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _controller.loadTrainings,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      final hasSearch = _controller.searchQuery.value.isNotEmpty;
                      if (hasSearch) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 56,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Sin resultados',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay entrenamientos que coincidan con tu búsqueda',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const EmptyStateWidget(
                        icon: Icons.calendar_today_rounded,
                        title: 'Sin entrenamientos',
                        description:
                            'Tu historial aparecerá aquí cuando completes tu primera sesión',
                      );
                    }

                    final List<Animation<double>> _itemAnims = [_aItem0, _aItem1, _aItem2, _aItem3, _aItem4];
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 100.0),
                      itemCount: trainings.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        // Footer: spinner o mensaje de fin de lista
                        if (index == trainings.length) {
                          if (_controller.isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.brand,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          if (!_controller.hasMore && trainings.isNotEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Has visto todos tus entrenamientos',
                                  style: TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }

                        final Entrenamiento training = trainings[index];
                        final isSelected = _selectedTrainingIds.contains(training.id);

                        final Widget card = Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: PremiumTrainingCard(
                            training: training,
                            isSelected: isSelected,
                            selectionMode: _isSelectionMode,
                            onSelectionChanged: (selected) {
                              if (training.id != null) {
                                _toggleSelection(training.id!);
                              }
                            },
                            onUpdate: _controller.loadTrainings,
                          ),
                        );
                        if (index < 5) return _slideFromBottom(_itemAnims[index], card);
                        return card;
                      },
                    );
                      },
                    );
                  },
            ),
        );
      },
    );

  }
  Widget _buildHistoryLoadingSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SkeletonShimmer(
      key: const ValueKey('history_loading'),
      builder: (sv) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.transparent : Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLine(width: 140, shimmerValue: sv),
                    SkeletonBox(width: 60, height: 12, borderRadius: 6, shimmerValue: sv),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    SkeletonBox(width: 50, height: 12, borderRadius: 6, shimmerValue: sv),
                    const SizedBox(width: 16),
                    SkeletonBox(width: 50, height: 12, borderRadius: 6, shimmerValue: sv),
                    const SizedBox(width: 16),
                    SkeletonBox(width: 50, height: 12, borderRadius: 6, shimmerValue: sv),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}';
  }
  
  String _formatDateLong(DateTime date) {
    try {
      return DateFormat('d MMMM, y', 'es').format(date);
    } catch (e) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  /// Abre Analytics Hub con el dataset filtrado actual
  void _openAnalytics() {
    final hasFilters = _controller.activeFiltersCount > 0;
    
    // Si hay filtros, pasamos los datos filtrados. Si no, null (para que cargue todo)
    final filteredData = hasFilters ? _controller.trainings.value : null;

    Navigator.push(
      context,
      AppRoute(page: AnalyticsHubScreen(preFilteredData: filteredData)),
    );
  }
}

// ============================
// WIDGET: TARJETA ENTRENAMIENTO (REDISENADA)


