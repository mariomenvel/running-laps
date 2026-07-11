import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/history/viewmodels/history_controller.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/history/widgets/history_filter_sheet.dart';
import 'package:running_laps/features/history/widgets/history_calendar_widget.dart';
import 'package:running_laps/features/history/widgets/premium_training_card.dart';
import 'package:running_laps/core/widgets/skeleton_shimmer.dart';
import 'package:running_laps/core/widgets/empty_state_widget.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final HistoryController _controller;
  late final ScrollController _scrollController;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _aItem0;
  late final Animation<double> _aItem1;
  late final Animation<double> _aItem2;
  late final Animation<double> _aItem3;
  late final Animation<double> _aItem4;

  bool _isCalendarView = false;
  DateTime? _selectedCalendarDate;

  final Set<String> _selectedTrainingIds = {};
  bool get _isSelectionMode => _selectedTrainingIds.isNotEmpty;

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _controller.loadMore();
    }
  }

  void _onNeedsReload() {
    _controller.loadTrainings();
  }

  @override
  void initState() {
    super.initState();
    _controller = HistoryController();
    _scrollController = ScrollController()..addListener(_onScroll);
    HistoryController.needsReload.addListener(_onNeedsReload);
    _controller.loadWhenReady();
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _aItem0 = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutQuart));
    _aItem1 = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutQuart));
    _aItem2 = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutQuart));
    _aItem3 = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutQuart));
    _aItem4 = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutQuart));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    HistoryController.needsReload.removeListener(_onNeedsReload);
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

  void _clearSelection() => setState(() => _selectedTrainingIds.clear());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchAndFilters(),
          if (_isCalendarView)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: ValueListenableBuilder<List<Entrenamiento>>(
                valueListenable: _controller.trainings,
                builder: (context, _, __) => HistoryCalendarWidget(
                  events: _controller.eventsByDay,
                  selectedDay: _selectedCalendarDate,
                  getTagColor: _controller.getColorForTag,
                  onDaySelected: (date) {
                    setState(() => _selectedCalendarDate = date);
                    _controller.setDateRange(date, date);
                  },
                ),
              ),
            ),
          _buildActiveFilters(),
          Expanded(child: _buildTrainingList()),
        ],
      ),
    );
  }

  // ── Search / filter row ──────────────────────────────────────────────────────

  Widget _buildSearchAndFilters() {
    if (_isSelectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: _clearSelection,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.close_rounded,
                    color: AppColors.textPrimary(context), size: 24),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${_selectedTrainingIds.length} seleccionados',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      child: ValueListenableBuilder<String>(
        valueListenable: _controller.searchQuery,
        builder: (context, query, _) {
          return Row(
            children: [
              // Search pill
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.borderOf(context), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search_rounded,
                          color: AppColors.iconMutedOf(context), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: query)
                            ..selection = TextSelection.collapsed(
                                offset: query.length),
                          onChanged: _controller.setSearchQuery,
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary(context)),
                          decoration: InputDecoration(
                            hintText: 'Buscar...',
                            hintStyle: TextStyle(
                                color: AppColors.iconMutedOf(context),
                                fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (query.isNotEmpty)
                        GestureDetector(
                          onTap: () => _controller.setSearchQuery(''),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.close_rounded,
                                size: 16,
                                color: AppColors.iconMutedOf(context)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Filter icon with badge
              AnimatedBuilder(
                animation: Listenable.merge([
                  _controller.currentFilter,
                  _controller.selectedTags,
                  _controller.filterStartDate,
                  _controller.filterEndDate,
                  _controller.filterMinDist,
                  _controller.filterMaxDist,
                  _controller.filterSeriesDistance,
                ]),
                builder: (context, _) {
                  final count = _controller.activeFiltersCount;
                  return IconButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            HistoryFilterSheet(controller: _controller),
                      );
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.tune_rounded,
                            color: count > 0
                                ? AppColors.brand
                                : AppColors.iconMutedOf(context),
                            size: 22),
                        if (count > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text('$count',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: 'Filtros',
                  );
                },
              ),
              // Calendar toggle
              IconButton(
                onPressed: () =>
                    setState(() => _isCalendarView = !_isCalendarView),
                icon: Icon(
                  _isCalendarView
                      ? Icons.list_rounded
                      : Icons.calendar_month_outlined,
                  color: _isCalendarView
                      ? AppColors.brand
                      : AppColors.iconMutedOf(context),
                  size: 22,
                ),
                tooltip: _isCalendarView ? 'Ver lista' : 'Ver calendario',
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Active filter chips ──────────────────────────────────────────────────────

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
        final chips = <_FilterChipData>[];

        if (_selectedCalendarDate != null && !_isCalendarView) {
          chips.add(_FilterChipData(
            label: _formatDateShort(_selectedCalendarDate!),
            icon: Icons.calendar_today_rounded,
            onRemove: () {
              setState(() => _selectedCalendarDate = null);
              _controller.setDateRange(null, null);
            },
          ));
        } else if (_controller.filterStartDate.value != null ||
            _controller.filterEndDate.value != null) {
          final s = _controller.filterStartDate.value;
          final e = _controller.filterEndDate.value;
          String label;
          if (s != null && e != null) {
            label =
                '${DateFormat('dd/MM').format(s)} – ${DateFormat('dd/MM').format(e)}';
          } else if (s != null) {
            label = 'Desde ${DateFormat('dd/MM').format(s)}';
          } else {
            label = 'Hasta ${DateFormat('dd/MM').format(e!)}';
          }
          chips.add(_FilterChipData(
              label: label,
              onRemove: () => _controller.setDateRange(null, null)));
        }

        if (_controller.filterMinDist.value != null ||
            _controller.filterMaxDist.value != null) {
          final mn = _controller.filterMinDist.value;
          final mx = _controller.filterMaxDist.value;
          String label;
          if (mn != null && mx != null) {
            label =
                '${(mn / 1000).toStringAsFixed(1)}–${(mx / 1000).toStringAsFixed(1)} km';
          } else if (mn != null) {
            label = '> ${(mn / 1000).toStringAsFixed(1)} km';
          } else {
            label = '< ${(mx! / 1000).toStringAsFixed(1)} km';
          }
          chips.add(_FilterChipData(
              label: label,
              onRemove: () => _controller.setDistanceRange(null, null)));
        }

        if (_controller.filterSeriesDistance.value != null) {
          chips.add(_FilterChipData(
            label: 'Series ${_controller.filterSeriesDistance.value}m',
            onRemove: () => _controller.setSeriesDistanceFilter(null),
          ));
        }

        for (final tag in _controller.selectedTags.value) {
          chips.add(_FilterChipData(
              label: '#$tag',
              onRemove: () => _controller.toggleTagFilter(tag)));
        }

        if (chips.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...chips.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildChip(c),
                    )),
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedCalendarDate = null);
                    _controller.clearAllFilters();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.rpeMax.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Borrar todo',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.rpeMax,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(_FilterChipData data) {
    final brandColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.brandLight
        : AppColors.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.brand.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.icon != null) ...[
            Icon(data.icon!, size: 12, color: brandColor),
            const SizedBox(width: 4),
          ],
          Text(data.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: brandColor)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: data.onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: brandColor),
          ),
        ],
      ),
    );
  }

  // ── Training list ────────────────────────────────────────────────────────────

  Widget _buildTrainingList() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isLoading,
      builder: (context, isLoading, _) {
        final showSkeleton =
            isLoading && _controller.trainings.value.isEmpty;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: showSkeleton
              ? _buildHistoryLoadingSkeleton()
              : ValueListenableBuilder<String?>(
                  key: const ValueKey('history_content'),
                  valueListenable: _controller.error,
                  builder: (context, error, _) {
                    if (error != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: AppColors.rpeMax),
                              const SizedBox(height: 16),
                              Text(error,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppColors.textSecondary(
                                          context))),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _controller.loadTrainings,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Reintentar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ValueListenableBuilder<List<Entrenamiento>>(
                      valueListenable: _controller.trainings,
                      builder: (context, trainings, _) {
                        if (trainings.isEmpty && !isLoading) {
                          if (_controller.searchQuery.value.isNotEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded,
                                        size: 56,
                                        color:
                                            AppColors.iconMutedOf(context)),
                                    const SizedBox(height: 20),
                                    Text('Sin resultados',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary(
                                                context))),
                                    const SizedBox(height: 8),
                                    Text(
                                        'No hay entrenamientos que coincidan con tu búsqueda',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary(
                                                context),
                                            height: 1.5),
                                        textAlign: TextAlign.center),
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

                        final itemAnims = [
                          _aItem0,
                          _aItem1,
                          _aItem2,
                          _aItem3,
                          _aItem4,
                        ];
                        return ListView.builder(
                          controller: _scrollController,
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 16),
                          itemCount: trainings.length + 1,
                          itemBuilder: (context, index) {
                            if (index == trainings.length) {
                              if (_controller.isLoadingMore) {
                                return const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.brand,
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              if (!_controller.hasMore &&
                                  trainings.isNotEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Has visto todos tus entrenamientos',
                                      style: TextStyle(
                                          color: AppColors.iconMutedOf(
                                              context),
                                          fontSize: 13),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }

                            final training = trainings[index];
                            final isSelected = _selectedTrainingIds
                                .contains(training.id);
                            final card = Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PremiumTrainingCard(
                                training: training,
                                isSelected: isSelected,
                                selectionMode: _isSelectionMode,
                                onSelectionChanged: (_) {
                                  if (training.id != null) {
                                    _toggleSelection(training.id!);
                                  }
                                },
                                onUpdate: _controller.loadTrainings,
                              ),
                            );
                            if (index < 5) {
                              return _slideFromBottom(
                                  itemAnims[index], card);
                            }
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
    return SkeletonShimmer(
      key: const ValueKey('history_loading'),
      builder: (sv) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.borderOf(context), width: 0.5),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLine(width: 140, shimmerValue: sv),
                    SkeletonBox(
                        width: 60,
                        height: 12,
                        borderRadius: 6,
                        shimmerValue: sv),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    SkeletonBox(
                        width: 50,
                        height: 12,
                        borderRadius: 6,
                        shimmerValue: sv),
                    const SizedBox(width: 16),
                    SkeletonBox(
                        width: 50,
                        height: 12,
                        borderRadius: 6,
                        shimmerValue: sv),
                    const SizedBox(width: 16),
                    SkeletonBox(
                        width: 50,
                        height: 12,
                        borderRadius: 6,
                        shimmerValue: sv),
                  ],
                ),
              ],
            ),
          ),
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
          offset: Offset(0, 20 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    try {
      return DateFormat('d MMM', 'es').format(date);
    } catch (_) {
      return '${date.day}/${date.month}';
    }
  }
}

class _FilterChipData {
  final String label;
  final IconData? icon;
  final VoidCallback onRemove;
  const _FilterChipData(
      {required this.label, this.icon, required this.onRemove});
}
