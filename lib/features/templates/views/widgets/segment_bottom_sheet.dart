import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/features/templates/data/target_config.dart';
import 'package:running_laps/features/templates/data/workout_segment.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';
import 'package:uuid/uuid.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

Future<WorkoutSegment?> showSegmentBottomSheet({
  required BuildContext context,
  required WorkoutType workoutType,
  WorkoutSegment? initialSegment,
  bool forceRecoveryType = false,
}) async {
  return showModalBottomSheet<WorkoutSegment>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceOf(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SegmentBottomSheet(
      workoutType: workoutType,
      initialSegment: initialSegment,
      forceRecoveryType: forceRecoveryType,
    ),
  );
}

// ── _SegmentBottomSheet ───────────────────────────────────────────────────────

class _SegmentBottomSheet extends StatefulWidget {
  const _SegmentBottomSheet({
    required this.workoutType,
    this.initialSegment,
    required this.forceRecoveryType,
  });

  final WorkoutType workoutType;
  final WorkoutSegment? initialSegment;
  final bool forceRecoveryType;

  @override
  State<_SegmentBottomSheet> createState() => _SegmentBottomSheetState();
}

class _SegmentBottomSheetState extends State<_SegmentBottomSheet> {
  late SegmentType _type;
  late bool _byDistance;
  late int _distanceM;
  late int _durationMin;
  late int _durationSec;
  late RecoveryType _recoveryType;

  // Target fields — null means "not set"
  int? _paceMinMin;
  int? _paceMinSec;
  int? _paceMaxMin;
  int? _paceMaxSec;
  HeartRateZone? _zone;
  int? _rpe;

  // Slider position independent of whether _rpe is actually set
  double _rpeSliderValue = 5;

  static const _distances = [
    100, 200, 300, 400, 500, 600, 800, 1000,
    1200, 1500, 2000, 3000, 5000, 10000,
  ];
  static const _secOptions = [0, 5, 10, 15, 20, 25, 30, 45];
  static const _paceSecOptions = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  @override
  void initState() {
    super.initState();
    final s = widget.initialSegment;
    _type = s?.type ?? SegmentType.interval;
    _byDistance = s == null ? true : s.distanceM != null;
    _distanceM = s?.distanceM ?? 1000;
    if (!_distances.contains(_distanceM)) _distanceM = 1000;
    final totalSec = s?.durationSec ?? 0;
    _durationMin = totalSec ~/ 60;
    _durationSec = _nearestSecOption(totalSec % 60);
    _recoveryType = s?.recoveryType ?? RecoveryType.active;

    final t = s?.target;
    if (t != null) {
      if (t.paceMinSecPerKm != null) {
        _paceMinMin = t.paceMinSecPerKm! ~/ 60;
        _paceMinSec = _nearestPaceSecOption(t.paceMinSecPerKm! % 60);
      }
      if (t.paceMaxSecPerKm != null) {
        _paceMaxMin = t.paceMaxSecPerKm! ~/ 60;
        _paceMaxSec = _nearestPaceSecOption(t.paceMaxSecPerKm! % 60);
      }
      _zone = t.zone;
      if (t.rpe != null) {
        _rpe = t.rpe;
        _rpeSliderValue = t.rpe!.toDouble();
      }
    }
  }

  int _nearestSecOption(int v) =>
      _secOptions.reduce((a, b) => (a - v).abs() < (b - v).abs() ? a : b);

  int _nearestPaceSecOption(int v) =>
      _paceSecOptions.reduce((a, b) => (a - v).abs() < (b - v).abs() ? a : b);

  bool get _saveDisabled {
    if (_type == SegmentType.interval) {
      if (_byDistance) return _distanceM == 0;
      return _durationMin == 0 && _durationSec == 0;
    }
    return _durationMin == 0 && _durationSec == 0;
  }

  WorkoutSegment _buildSegment() {
    final durationSec = _byDistance && _type == SegmentType.interval
        ? null
        : _durationMin * 60 + _durationSec;
    final distanceM =
        _byDistance && _type == SegmentType.interval ? _distanceM : null;

    TargetConfig? target;
    final hasPace = _paceMinMin != null || _paceMaxMin != null;
    if (hasPace || _zone != null || _rpe != null) {
      final paceMin = _paceMinMin != null
          ? _paceMinMin! * 60 + (_paceMinSec ?? 0)
          : null;
      final paceMax = _paceMaxMin != null
          ? _paceMaxMin! * 60 + (_paceMaxSec ?? 0)
          : null;
      int? finalPaceMin = paceMin;
      int? finalPaceMax = paceMax;
      if (paceMin != null && paceMax != null && paceMin > paceMax) {
        finalPaceMin = paceMax;
        finalPaceMax = paceMin;
      }
      target = TargetConfig(
        paceMinSecPerKm: finalPaceMin,
        paceMaxSecPerKm: finalPaceMax,
        zone: _zone,
        rpe: _rpe,
      );
    }

    return WorkoutSegment(
      id: widget.initialSegment?.id ?? const Uuid().v4(),
      type: _type,
      durationSec: durationSec,
      distanceM: distanceM,
      recoveryType: _type == SegmentType.recovery ? _recoveryType : null,
      target: target,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialSegment != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    isEdit ? 'Editar segmento' : 'Nuevo segmento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),

                  // ── Tipo ──
                  _sectionLabel(context, 'TIPO'),
                  const SizedBox(height: AppSpacing.s),
                  _TypeToggle(
                    options: const [
                      (SegmentType.interval, Icons.circle, 'Esfuerzo'),
                      (SegmentType.recovery, Icons.more_horiz, 'Descanso'),
                    ],
                    selected: _type,
                    onSelect: (t) => setState(() {
                      _type = t;
                      // reset mode to time when switching to recovery
                      if (t == SegmentType.recovery) _byDistance = false;
                    }),
                    context: context,
                  ),
                  const SizedBox(height: AppSpacing.l),

                  // ── Medida (solo interval) ──
                  if (_type == SegmentType.interval) ...[
                    _sectionLabel(context, 'MEDIDA'),
                    const SizedBox(height: AppSpacing.s),
                    _BoolToggle(
                      labelA: 'Por distancia',
                      labelB: 'Por tiempo',
                      value: _byDistance,
                      onChanged: (v) => setState(() => _byDistance = v),
                      context: context,
                    ),
                    const SizedBox(height: AppSpacing.l),
                  ],

                  // ── Valor ──
                  if (_type == SegmentType.interval && _byDistance) ...[
                    _sectionLabel(context, 'DISTANCIA'),
                    const SizedBox(height: AppSpacing.s),
                    _WheelPicker(
                      values: _distances,
                      selected: _distanceM,
                      suffix: 'm',
                      onChanged: (v) => setState(() => _distanceM = v),
                    ),
                    const SizedBox(height: AppSpacing.l),
                  ] else ...[
                    _sectionLabel(context, 'DURACIÓN'),
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      children: [
                        Expanded(
                          child: _WheelPicker(
                            values: List.generate(60, (i) => i),
                            selected: _durationMin,
                            suffix: 'min',
                            onChanged: (v) => setState(() => _durationMin = v),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: _WheelPicker(
                            values: _secOptions,
                            selected: _durationSec,
                            suffix: 'seg',
                            onChanged: (v) => setState(() => _durationSec = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                  ],

                  // ── Tipo descanso (solo recovery) ──
                  if (_type == SegmentType.recovery) ...[
                    _sectionLabel(context, 'TIPO DESCANSO'),
                    const SizedBox(height: AppSpacing.s),
                    if (widget.forceRecoveryType)
                      Text(
                        'Trotando (bajando)',
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 14),
                      )
                    else
                      _BoolToggle(
                        labelA: 'Activo — trotando',
                        labelB: 'Pasivo — parado',
                        value: _recoveryType == RecoveryType.active,
                        onChanged: (v) => setState(() => _recoveryType =
                            v ? RecoveryType.active : RecoveryType.passive),
                        context: context,
                      ),
                    const SizedBox(height: AppSpacing.l),
                  ],

                  // ── Objetivo (opcional) ──
                  Row(
                    children: [
                      _sectionLabel(context, 'OBJETIVO'),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        '· opcional',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),

                  // Pace
                  _sectionLabel(context, 'Pace', small: true),
                  const SizedBox(height: AppSpacing.s),
                  _PaceRow(
                    minMin: _paceMinMin,
                    minSec: _paceMinSec,
                    maxMin: _paceMaxMin,
                    maxSec: _paceMaxSec,
                    onMinChanged: (min, sec) =>
                        setState(() { _paceMinMin = min; _paceMinSec = sec; }),
                    onMaxChanged: (min, sec) =>
                        setState(() { _paceMaxMin = min; _paceMaxSec = sec; }),
                    onClear: () => setState(() {
                      _paceMinMin = _paceMinSec = _paceMaxMin = _paceMaxSec = null;
                    }),
                    context: context,
                  ),
                  const SizedBox(height: AppSpacing.m),

                  // Zona FC
                  _sectionLabel(context, 'Zona FC', small: true),
                  const SizedBox(height: AppSpacing.s),
                  _ZoneRow(
                    selected: _zone,
                    onSelect: (z) => setState(() => _zone = _zone == z ? null : z),
                    context: context,
                  ),
                  const SizedBox(height: AppSpacing.m),

                  // RPE
                  _sectionLabel(context, 'RPE', small: true),
                  const SizedBox(height: AppSpacing.s),
                  _RpeRow(
                    rpe: _rpe,
                    sliderValue: _rpeSliderValue,
                    onSliderChanged: (v) => setState(() {
                      _rpeSliderValue = v;
                      _rpe = v.round();
                    }),
                    onClear: () => setState(() => _rpe = null),
                    context: context,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed:
                          _saveDisabled ? null : () => Navigator.pop(context, _buildSegment()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _saveDisabled
                            ? AppColors.borderOf(context)
                            : AppColors.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Guardar segmento',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label helper ──────────────────────────────────────────────────────

Widget _sectionLabel(BuildContext context, String text,
    {bool small = false}) =>
    Text(
      text,
      style: TextStyle(
        fontSize: small ? 13 : 12,
        fontWeight: FontWeight.w500,
        letterSpacing: small ? 0 : 1.2,
        color: AppColors.textSecondary(context),
      ),
    );

// ── _TypeToggle ───────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.context,
  });

  final List<(SegmentType, IconData, String)> options;
  final SegmentType selected;
  final void Function(SegmentType) onSelect;
  final BuildContext context;

  @override
  Widget build(BuildContext outerContext) {
    return Row(
      children: options.map((opt) {
        final (type, icon, label) = opt;
        final isSelected = type == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: AppSpacing.s),
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.m, horizontal: AppSpacing.s),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand.withValues(alpha: 0.08)
                    : AppColors.surfaceOf(outerContext),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.borderOf(outerContext),
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 16,
                      color: isSelected
                          ? AppColors.brand
                          : AppColors.iconMutedOf(outerContext)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppColors.textPrimary(outerContext)
                          : AppColors.textSecondary(outerContext),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── _BoolToggle ───────────────────────────────────────────────────────────────

class _BoolToggle extends StatelessWidget {
  const _BoolToggle({
    required this.labelA,
    required this.labelB,
    required this.value,
    required this.onChanged,
    required this.context,
  });

  final String labelA;
  final String labelB;
  final bool value;
  final void Function(bool) onChanged;
  final BuildContext context;

  @override
  Widget build(BuildContext outerContext) {
    return Row(
      children: [
        Expanded(child: _chip(outerContext, labelA, value, () => onChanged(true))),
        const SizedBox(width: AppSpacing.s),
        Expanded(child: _chip(outerContext, labelB, !value, () => onChanged(false))),
      ],
    );
  }

  Widget _chip(BuildContext ctx, String label, bool sel, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.m, horizontal: AppSpacing.s),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.brand.withValues(alpha: 0.08)
                : AppColors.surfaceOf(ctx),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? AppColors.brand : AppColors.borderOf(ctx),
              width: sel ? 1.5 : 0.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: sel
                    ? AppColors.textPrimary(ctx)
                    : AppColors.textSecondary(ctx),
              ),
            ),
          ),
        ),
      );
}

// ── _WheelPicker ──────────────────────────────────────────────────────────────

class _WheelPicker extends StatefulWidget {
  const _WheelPicker({
    required this.values,
    required this.selected,
    required this.suffix,
    required this.onChanged,
  });

  final List<int> values;
  final int selected;
  final String suffix;
  final void Function(int) onChanged;

  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  late final FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    final idx = widget.values.indexOf(widget.selected);
    _ctrl = FixedExtentScrollController(initialItem: idx < 0 ? 0 : idx);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.borderOf(context), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: ListWheelScrollView.useDelegate(
              controller: _ctrl,
              itemExtent: 36,
              perspective: 0.003,
              diameterRatio: 1.4,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => widget.onChanged(widget.values[i]),
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (ctx, i) {
                  if (i < 0 || i >= widget.values.length) return null;
                  return Center(
                    child: Text(
                      '${widget.values[i]}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(ctx),
                      ),
                    ),
                  );
                },
                childCount: widget.values.length,
              ),
            ),
          ),
          Text(
            widget.suffix,
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}

// ── _PaceRow ──────────────────────────────────────────────────────────────────

class _PaceRow extends StatelessWidget {
  const _PaceRow({
    required this.minMin,
    required this.minSec,
    required this.maxMin,
    required this.maxSec,
    required this.onMinChanged,
    required this.onMaxChanged,
    required this.onClear,
    required this.context,
  });

  final int? minMin;
  final int? minSec;
  final int? maxMin;
  final int? maxSec;
  final void Function(int min, int sec) onMinChanged;
  final void Function(int min, int sec) onMaxChanged;
  final VoidCallback onClear;
  final BuildContext context;

  static const _mins = [3, 4, 5, 6, 7, 8];
  static const _secs = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  @override
  Widget build(BuildContext outerContext) {
    final hasPace = minMin != null || maxMin != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('De  ',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(outerContext))),
            _MiniWheelPicker(
              values: _mins,
              selected: minMin ?? 4,
              onChanged: (v) => onMinChanged(v, minSec ?? 0),
              context: outerContext,
            ),
            Text(' : ',
                style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary(outerContext))),
            _MiniWheelPicker(
              values: _secs,
              selected: minSec ?? 0,
              onChanged: (v) => onMinChanged(minMin ?? 4, v),
              context: outerContext,
              pad: true,
            ),
            Text('  a  ',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(outerContext))),
            _MiniWheelPicker(
              values: _mins,
              selected: maxMin ?? 4,
              onChanged: (v) => onMaxChanged(v, maxSec ?? 0),
              context: outerContext,
            ),
            Text(' : ',
                style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary(outerContext))),
            _MiniWheelPicker(
              values: _secs,
              selected: maxSec ?? 0,
              onChanged: (v) => onMaxChanged(maxMin ?? 4, v),
              context: outerContext,
              pad: true,
            ),
            Text('  /km',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(outerContext))),
            if (hasPace) ...[
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 16,
                    color: AppColors.iconMutedOf(outerContext)),
              ),
            ],
          ],
        ),
        Builder(builder: (context) {
          final minVal = (minMin ?? 4) * 60 + (minSec ?? 0);
          final maxVal = (maxMin ?? 4) * 60 + (maxSec ?? 0);
          final invalid = minMin != null && maxMin != null && minVal > maxVal;
          if (!invalid) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'El ritmo "De" debe ser más rápido (menor) que el "A"',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.rpeMax,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MiniWheelPicker extends StatefulWidget {
  const _MiniWheelPicker({
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.context,
    this.pad = false,
  });

  final List<int> values;
  final int selected;
  final void Function(int) onChanged;
  final BuildContext context;
  final bool pad;

  @override
  State<_MiniWheelPicker> createState() => _MiniWheelPickerState();
}

class _MiniWheelPickerState extends State<_MiniWheelPicker> {
  late final FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    final idx = widget.values.indexOf(widget.selected);
    _ctrl = FixedExtentScrollController(initialItem: idx < 0 ? 0 : idx);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 44,
      child: ListWheelScrollView.useDelegate(
        controller: _ctrl,
        itemExtent: 32,
        perspective: 0.003,
        diameterRatio: 1.8,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => widget.onChanged(widget.values[i]),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (ctx, i) {
            if (i < 0 || i >= widget.values.length) return null;
            final label = widget.pad
                ? widget.values[i].toString().padLeft(2, '0')
                : '${widget.values[i]}';
            return Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary(ctx),
                ),
              ),
            );
          },
          childCount: widget.values.length,
        ),
      ),
    );
  }
}

// ── _ZoneRow ──────────────────────────────────────────────────────────────────

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.selected,
    required this.onSelect,
    required this.context,
  });

  final HeartRateZone? selected;
  final void Function(HeartRateZone) onSelect;
  final BuildContext context;

  @override
  Widget build(BuildContext outerContext) {
    return Row(
      children: HeartRateZone.values.map((z) {
        final isSelected = z == selected;
        return GestureDetector(
          onTap: () => onSelect(z),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: AppSpacing.s),
            width: 40,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brand.withValues(alpha: 0.12)
                  : AppColors.surfaceOf(outerContext),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isSelected ? AppColors.brand : AppColors.borderOf(outerContext),
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Center(
              child: Text(
                z.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.brand
                      : AppColors.textSecondary(outerContext),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── _RpeRow ───────────────────────────────────────────────────────────────────

class _RpeRow extends StatelessWidget {
  const _RpeRow({
    required this.rpe,
    required this.sliderValue,
    required this.onSliderChanged,
    required this.onClear,
    required this.context,
  });

  final int? rpe;
  final double sliderValue;
  final void Function(double) onSliderChanged;
  final VoidCallback onClear;
  final BuildContext context;

  @override
  Widget build(BuildContext outerContext) {
    final activeColor = rpe != null
        ? AppColors.effortColor(rpe!.toDouble())
        : AppColors.iconMutedOf(outerContext);
    return Row(
      children: [
        Expanded(
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: sliderValue,
            activeColor: activeColor,
            inactiveColor: AppColors.borderOf(outerContext),
            onChanged: onSliderChanged,
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            rpe != null ? '$rpe' : '–',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: rpe != null ? activeColor : AppColors.textSecondary(outerContext),
            ),
          ),
        ),
        if (rpe != null)
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(Icons.close,
                  size: 16,
                  color: AppColors.iconMutedOf(outerContext)),
            ),
          ),
      ],
    );
  }
}
