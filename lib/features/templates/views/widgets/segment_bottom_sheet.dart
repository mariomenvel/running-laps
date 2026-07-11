import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/ios_picker.dart';
import 'package:running_laps/core/widgets/rpe_slider.dart';
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

  // Metrónomo
  bool _alertEnabled = false;
  bool _alertByTime = true; // true = time mode, false = pace mode
  double _alertTimeSec = 30;
  int _alertPaceMin = 5;
  int _alertPaceSec = 0;
  int _alertDistanceM = 400;

  static const _alertDistances = [100, 200, 300, 400, 500, 1000];
  static final List<double> _alertTimeSecOptions = [
    for (int i = 1; i <= 120; i++) i * 0.5,
  ];

  static final List<int> _distances = [
    for (int i = 50; i <= 1000; i += 50) i,
    for (int i = 1100; i <= 5000; i += 100) i,
    for (int i = 5500; i <= 42000; i += 500) i,
  ];
  static const _secOptions = [0, 5, 10, 15, 20, 25, 30, 45];
  static const _paceSecOptions = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  @override
  void initState() {
    super.initState();
    debugPrint('[Sheet] initialSegment=${widget.initialSegment}');
    debugPrint('[Sheet] initialSegment.alerts=${widget.initialSegment?.alerts}');
    if (widget.initialSegment?.alerts != null) {
      debugPrint('[Sheet] alerts.enabled=${widget.initialSegment!.alerts!.enabled}');
      debugPrint('[Sheet] alerts.mode=${widget.initialSegment!.alerts!.mode}');
      debugPrint('[Sheet] alerts.timeMin=${widget.initialSegment!.alerts!.timeMin}');
      debugPrint('[Sheet] alerts.timeSec=${widget.initialSegment!.alerts!.timeSec}');
    }
    final s = widget.initialSegment;
    _type = s?.type ?? SegmentType.interval;
    _byDistance = s == null ? true : s.distanceM != null;
    _distanceM = s?.distanceM ?? 1000;
    if (!_distances.contains(_distanceM)) _distanceM = 1000;
    final totalSec = s?.durationSec ?? 0;
    _durationMin = totalSec ~/ 60;
    _durationSec = _nearestSecOption(totalSec % 60);
    _recoveryType = s?.recoveryType ?? RecoveryType.active;

    final a = s?.alerts;
    if (a != null) {
      _alertEnabled = a.enabled;
      _alertByTime = a.mode == 'time';
      _alertTimeSec =
          _nearestAlertTimeSecOption(a.timeMin * 60 + a.timeSec);
      _alertPaceMin = a.paceMin;
      _alertPaceSec = a.paceSec;
      if (_alertDistances.contains(a.segmentDistanceM)) {
        _alertDistanceM = a.segmentDistanceM;
      }
    }

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

  double _nearestAlertTimeSecOption(num v) => _alertTimeSecOptions
      .reduce((a, b) => (a - v).abs() < (b - v).abs() ? a : b);

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

    final alerts = SegmentAlerts(
      enabled: _alertEnabled,
      mode: _alertByTime ? 'time' : 'pace',
      timeSec: _alertTimeSec,
      paceMin: _alertPaceMin,
      paceSec: _alertPaceSec,
      segmentDistanceM: _alertDistanceM,
    );

    debugPrint('[Sheet] guardando alerts: enabled=$_alertEnabled mode=${_alertByTime ? "time" : "pace"} timeSec=$_alertTimeSec');
    return WorkoutSegment(
      id: widget.initialSegment?.id ?? const Uuid().v4(),
      type: _type,
      durationSec: durationSec,
      distanceM: distanceM,
      recoveryType: _type == SegmentType.recovery ? _recoveryType : null,
      target: target,
      alerts: alerts,
    );
  }

  String _alertPreviewText() {
    if (!_alertEnabled) return '';
    final ms = SegmentAlerts(
      enabled: true,
      mode: _alertByTime ? 'time' : 'pace',
      timeSec: _alertTimeSec,
      paceMin: _alertPaceMin,
      paceSec: _alertPaceSec,
      segmentDistanceM: _alertDistanceM,
    ).toAlarmIntervalMs();
    final totalSec = ms / 1000.0;
    if (totalSec < 60) return '= beep cada ${totalSec.toStringAsFixed(1)} seg';
    final m = (totalSec ~/ 60);
    final s = (totalSec % 60).toStringAsFixed(0).padLeft(2, '0');
    return '= beep cada $m:$s min';
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
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.borderOf(context)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(children: [
                            Text('m',
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        AppColors.textSecondary(context))),
                            const SizedBox(height: 4),
                            _WheelPicker(
                              values: _distances,
                              selected: _distanceM,
                              suffix: '',
                              onChanged: (v) =>
                                  setState(() => _distanceM = v),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                  ] else ...[
                    _sectionLabel(context, 'DURACIÓN'),
                    const SizedBox(height: AppSpacing.s),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.borderOf(context)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(children: [
                            Text('min',
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        AppColors.textSecondary(context))),
                            const SizedBox(height: 4),
                            _WheelPicker(
                              values: List.generate(60, (i) => i),
                              selected: _durationMin,
                              suffix: '',
                              onChanged: (v) =>
                                  setState(() => _durationMin = v),
                            ),
                          ]),
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(' : ',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w300,
                                    color:
                                        AppColors.textSecondary(context))),
                          ),
                          Column(children: [
                            Text('seg',
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        AppColors.textSecondary(context))),
                            const SizedBox(height: 4),
                            _WheelPicker(
                              values: _secOptions,
                              selected: _durationSec,
                              suffix: '',
                              onChanged: (v) =>
                                  setState(() => _durationSec = v),
                            ),
                          ]),
                        ],
                      ),
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

                  // ── Objetivo + Metrónomo (ocultos en descanso pasivo) ──
                  if (!(_type == SegmentType.recovery &&
                      _recoveryType == RecoveryType.passive)) ...[
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
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.borderOf(context)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cardLabel(context, 'PACE'),
                          const SizedBox(height: 8),
                          _PaceRow(
                            minMin: _paceMinMin,
                            minSec: _paceMinSec,
                            maxMin: _paceMaxMin,
                            maxSec: _paceMaxSec,
                            onMinChanged: (min, sec) => setState(() {
                              _paceMinMin = min;
                              _paceMinSec = sec;
                            }),
                            onMaxChanged: (min, sec) => setState(() {
                              _paceMaxMin = min;
                              _paceMaxSec = sec;
                            }),
                            onClear: () => setState(() {
                              _paceMinMin =
                                  _paceMinSec = _paceMaxMin = _paceMaxSec = null;
                            }),
                            context: context,
                          ),
                        ],
                      ),
                    ),

                    // Zona FC
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.borderOf(context)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cardLabel(context, 'ZONA FC'),
                          const SizedBox(height: 8),
                          _ZoneRow(
                            selected: _zone,
                            onSelect: (z) =>
                                setState(() => _zone = _zone == z ? null : z),
                            context: context,
                          ),
                        ],
                      ),
                    ),

                    // RPE
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.borderOf(context)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cardLabel(context, 'RPE'),
                          const SizedBox(height: 8),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),

                    // ── Metrónomo ──
                    _AlertSection(
                      enabled: _alertEnabled,
                      byTime: _alertByTime,
                      timeSec: _alertTimeSec,
                      paceMin: _alertPaceMin,
                      paceSec: _alertPaceSec,
                      distanceM: _alertDistanceM,
                      previewText: _alertPreviewText(),
                      alertDistances: _alertDistances,
                      alertTimeSecOptions: _alertTimeSecOptions,
                      onToggleEnabled: (v) =>
                          setState(() => _alertEnabled = v),
                      onToggleMode: (byTime) =>
                          setState(() => _alertByTime = byTime),
                      onTimeSecChanged: (v) =>
                          setState(() => _alertTimeSec = v),
                      onPaceMinChanged: (v) =>
                          setState(() => _alertPaceMin = v),
                      onPaceSecChanged: (v) =>
                          setState(() => _alertPaceSec = v),
                      onDistanceChanged: (v) =>
                          setState(() => _alertDistanceM = v),
                      context: context,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

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
        fontSize: small ? 13 : 11,
        fontWeight: small ? FontWeight.w500 : FontWeight.w600,
        letterSpacing: small ? 0 : 0.08,
        color: AppColors.textSecondary(context),
      ),
    );

Widget _cardLabel(BuildContext context, String text) => Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.06,
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
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.brand
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
                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                color: sel ? AppColors.brand : AppColors.textSecondary(ctx),
              ),
            ),
          ),
        ),
      );
}

// ── IosPicker ahora vive en lib/core/widgets/ios_picker.dart ──────────────────

// ── _WheelPicker ──────────────────────────────────────────────────────────────

class _WheelPicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final initialIndex =
        values.indexOf(selected).clamp(0, values.length - 1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IosPicker(
          itemCount: values.length,
          initialItem: initialIndex,
          textBuilder: (i) => '${values[i]}',
          onChanged: (i) => onChanged(values[i]),
          itemExtent: 32,
          width: 60,
        ),
        if (suffix.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(suffix,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary(context))),
          ),
      ],
    );
  }
}

// ── _PaceRow ──────────────────────────────────────────────────────────────────

// ── _PacePill ─────────────────────────────────────────────────────────────────

class _PacePill extends StatelessWidget {
  final Widget minutesPicker;
  final Widget secondsPicker;

  const _PacePill({
    required this.minutesPicker,
    required this.secondsPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2Of(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderOf(context), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          minutesPicker,
          Text(' : ',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textSecondary(context))),
          secondsPicker,
        ],
      ),
    );
  }
}

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

  static const _mins = [2, 3, 4, 5, 6, 7, 8];
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
            _PacePill(
              minutesPicker: _MiniWheelPicker(
                values: _mins,
                selected: minMin ?? 4,
                onChanged: (v) => onMinChanged(v, minSec ?? 0),
                context: outerContext,
              ),
              secondsPicker: _MiniWheelPicker(
                values: _secs,
                selected: minSec ?? 0,
                onChanged: (v) => onMinChanged(minMin ?? 4, v),
                context: outerContext,
                pad: true,
              ),
            ),
            Text('  a  ',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(outerContext))),
            _PacePill(
              minutesPicker: _MiniWheelPicker(
                values: _mins,
                selected: maxMin ?? 4,
                onChanged: (v) => onMaxChanged(v, maxSec ?? 0),
                context: outerContext,
              ),
              secondsPicker: _MiniWheelPicker(
                values: _secs,
                selected: maxSec ?? 0,
                onChanged: (v) => onMaxChanged(maxMin ?? 4, v),
                context: outerContext,
                pad: true,
              ),
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

class _MiniWheelPicker extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final initialIndex =
        values.indexOf(selected).clamp(0, values.length - 1);

    return IosPicker(
      itemCount: values.length,
      initialItem: initialIndex,
      textBuilder: (i) =>
          pad ? '${values[i]}'.padLeft(2, '0') : '${values[i]}',
      onChanged: (i) => onChanged(values[i]),
      itemExtent: 28,
      width: 36,
    );
  }
}

// ── _AlertSection ─────────────────────────────────────────────────────────────

class _AlertSection extends StatelessWidget {
  const _AlertSection({
    required this.enabled,
    required this.byTime,
    required this.timeSec,
    required this.paceMin,
    required this.paceSec,
    required this.distanceM,
    required this.previewText,
    required this.alertDistances,
    required this.alertTimeSecOptions,
    required this.onToggleEnabled,
    required this.onToggleMode,
    required this.onTimeSecChanged,
    required this.onPaceMinChanged,
    required this.onPaceSecChanged,
    required this.onDistanceChanged,
    required this.context,
  });

  final bool enabled;
  final bool byTime;
  final double timeSec;
  final int paceMin;
  final int paceSec;
  final int distanceM;
  final String previewText;
  final List<int> alertDistances;
  final List<double> alertTimeSecOptions;
  final void Function(bool) onToggleEnabled;
  final void Function(bool) onToggleMode;
  final void Function(double) onTimeSecChanged;
  final void Function(int) onPaceMinChanged;
  final void Function(int) onPaceSecChanged;
  final void Function(int) onDistanceChanged;
  final BuildContext context;

  static const _paceMinOptions = [2, 3, 4, 5, 6, 7, 8, 9, 10];
  static const _paceSecOptions = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  @override
  Widget build(BuildContext outerContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con toggle ON/OFF
        Row(
          children: [
            _sectionLabel(outerContext, 'METRÓNOMO'),
            const SizedBox(width: AppSpacing.s),
            Text(
              '· opcional',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary(outerContext)),
            ),
            const Spacer(),
            CupertinoSwitch(
              value: enabled,
              onChanged: onToggleEnabled,
              activeTrackColor: AppColors.brand,
            ),
          ],
        ),

        if (enabled) ...[
          const SizedBox(height: AppSpacing.m),

          // Modo: Tiempo / Ritmo
          _BoolToggle(
            labelA: 'Por tiempo',
            labelB: 'Por ritmo',
            value: byTime,
            onChanged: onToggleMode,
            context: outerContext,
          ),
          const SizedBox(height: AppSpacing.m),

          if (byTime) ...[
            // Modo tiempo: beep cada MM:SS.S
            _sectionLabel(outerContext, 'Beep cada', small: true),
            const SizedBox(height: AppSpacing.s),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2Of(outerContext),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.borderOf(outerContext)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniWheelPickerDouble(
                    values: alertTimeSecOptions,
                    selected: timeSec,
                    onChanged: onTimeSecChanged,
                    context: outerContext,
                  ),
                  Text(
                    ' seg',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(outerContext)),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Modo ritmo: pace + distancia
            _sectionLabel(outerContext, 'Pace objetivo', small: true),
            const SizedBox(height: AppSpacing.s),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2Of(outerContext),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.borderOf(outerContext)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniWheelPicker(
                    values: _paceMinOptions,
                    selected: paceMin,
                    onChanged: onPaceMinChanged,
                    context: outerContext,
                  ),
                  Text(
                    ' : ',
                    style: TextStyle(fontSize: 16, color: AppColors.textPrimary(outerContext)),
                  ),
                  _MiniWheelPicker(
                    values: _paceSecOptions,
                    selected: paceSec,
                    onChanged: onPaceSecChanged,
                    context: outerContext,
                    pad: true,
                  ),
                  Text(
                    '  /km',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(outerContext)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            _sectionLabel(outerContext, 'Cada', small: true),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              children: alertDistances.map((d) {
                final isSelected = d == distanceM;
                return GestureDetector(
                  onTap: () => onDistanceChanged(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brand.withValues(alpha: 0.08)
                          : AppColors.surfaceOf(outerContext),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : AppColors.borderOf(outerContext),
                        width: isSelected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Text(
                      '${d}m',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.textSecondary(outerContext),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Preview en tiempo real
          if (previewText.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s),
            Text(
              previewText,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.brand,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ── _MiniWheelPickerDouble ────────────────────────────────────────────────────

class _MiniWheelPickerDouble extends StatelessWidget {
  const _MiniWheelPickerDouble({
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.context,
  });

  final List<double> values;
  final double selected;
  final void Function(double) onChanged;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    final initialIndex =
        values.indexOf(selected).clamp(0, values.length - 1);

    return IosPicker(
      itemCount: values.length,
      initialItem: initialIndex,
      textBuilder: (i) {
        final v = values[i];
        return v == v.roundToDouble()
            ? v.toInt().toString().padLeft(2, '0')
            : v.toStringAsFixed(1);
      },
      onChanged: (i) => onChanged(values[i]),
      itemExtent: 28,
      width: 36,
    );
  }
}

// ── _ZoneRow ──────────────────────────────────────────────────────────────────

Color _zoneSelectedColor(HeartRateZone z) {
  switch (z) {
    case HeartRateZone.z1: return const Color(0xFF639922);
    case HeartRateZone.z2: return const Color(0xFF378ADD);
    case HeartRateZone.z3: return const Color(0xFFEF9F27);
    case HeartRateZone.z4: return const Color(0xFFD85A30);
    case HeartRateZone.z5: return const Color(0xFFE24B4A);
  }
}

Color _darken(Color c) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - 0.18).clamp(0.0, 1.0)).toColor();
}

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
        final zoneColor = _zoneSelectedColor(z);
        return GestureDetector(
          onTap: () => onSelect(z),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: AppSpacing.s),
            width: 40,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? zoneColor.withValues(alpha: 0.15)
                  : AppColors.surfaceOf(outerContext),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? zoneColor
                    : AppColors.borderOf(outerContext),
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
                      ? _darken(zoneColor)
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
    return Row(
      children: [
        Expanded(
          child: RpeSlider(
            value: rpe?.toDouble() ?? 1.0,
            onChanged: onSliderChanged,
            showClear: rpe != null,
            onClear: onClear,
          ),
        ),
      ],
    );
  }
}
