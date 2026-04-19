import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

const List<int> _standardDistances = [
  50, 100, 150, 200, 250, 300, 400, 500, 600, 800,
  1000, 1200, 1500, 2000, 3000, 4000, 5000,
];

const List<int> _restValues = [
  0, 15, 30, 45, 60, 90, 120, 150, 180, 240, 300, 360, 420, 480, 600,
];

const List<double> _rpeValues = [
  1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5,
  6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10,
];

// ── Helpers ───────────────────────────────────────────────────────────────────

String _distanceLabel(int m) {
  if (m < 1000) return '${m}m';
  final km = m / 1000;
  return km == km.truncateToDouble() ? '${km.toInt()}km' : '${km}km';
}

String _restLabel(int v) {
  if (v == 0) return 'Sin desc.';
  if (v < 60) return '${v}s';
  final m = v ~/ 60;
  final s = v % 60;
  return s > 0 ? "${m}' ${s}s" : "${m}'";
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _ManualSerieData {
  int distanceM;
  int durationMinutes;
  int durationSeconds;
  double rpe;
  int restSeconds;

  _ManualSerieData({
    this.distanceM    = 400,
    this.durationMinutes = 2,
    this.durationSeconds = 0,
    this.rpe          = 6.0,
    this.restSeconds  = 60,
  });

  int get tiempoSec => durationMinutes * 60 + durationSeconds;
}

// ── ManualTrainingView ────────────────────────────────────────────────────────

class ManualTrainingView extends StatefulWidget {
  final DateTime? initialDate;

  const ManualTrainingView({super.key, this.initialDate});

  @override
  State<ManualTrainingView> createState() => _ManualTrainingViewState();
}

class _ManualTrainingViewState extends State<ManualTrainingView> {
  final _titleCtrl = TextEditingController(text: 'Entrenamiento manual');
  final _notasCtrl = TextEditingController();
  final _repo      = TrainingRepository();

  late DateTime _selectedDate;
  final List<_ManualSerieData> _series = [_ManualSerieData()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ─────────────────────────────────────────────────────────────────

  Future<void> _showDateSheet() async {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final txtColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    DateTime temp  = _selectedDate;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height:      340,
        margin:      const EdgeInsets.all(12),
        decoration:  BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Fecha', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: txtColor)),
            Expanded(
              child: CupertinoDatePicker(
                mode:           CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                maximumDate:    DateTime.now(),
                onDateTimeChanged: (d) => temp = d,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brandPurple),
                  onPressed: () {
                    setState(() => _selectedDate = temp);
                    Navigator.pop(context);
                  },
                  child: const Text('Confirmar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDistance(int idx) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DistancePickerSheet(initial: _series[idx].distanceM),
    );
    if (result != null && mounted) setState(() => _series[idx].distanceM = result);
  }

  Future<void> _pickDuration(int idx) async {
    final result = await showModalBottomSheet<(int, int)>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DurationPickerSheet(
        initialMinutes: _series[idx].durationMinutes,
        initialSeconds: _series[idx].durationSeconds,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _series[idx].durationMinutes = result.$1;
        _series[idx].durationSeconds = result.$2;
      });
    }
  }

  Future<void> _pickRpe(int idx) async {
    final result = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RpePickerSheet(initial: _series[idx].rpe),
    );
    if (result != null && mounted) setState(() => _series[idx].rpe = result);
  }

  Future<void> _pickRest(int idx) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestPickerSheet(initial: _series[idx].restSeconds),
    );
    if (result != null && mounted) setState(() => _series[idx].restSeconds = result);
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final titulo = _titleCtrl.text.trim();
    if (titulo.isEmpty) {
      ModernSnackBar.showWarning(context, 'Escribe un nombre para el entrenamiento');
      return;
    }
    if (_series.isEmpty) {
      ModernSnackBar.showWarning(context, 'Añade al menos una serie');
      return;
    }

    setState(() => _saving = true);
    try {
      final seriesList = _series.map((s) => Serie(
        distanciaM:  s.distanceM,
        tiempoSec:   s.tiempoSec.toDouble(),
        descansoSec: s.restSeconds,
        rpe:         s.rpe,
      )).toList();

      final notas = _notasCtrl.text.trim();
      final entrenamiento = Entrenamiento(
        titulo:   titulo,
        fecha:    _selectedDate,
        gps:      false,
        series:   seriesList,
        isManual: true,
        notas:    notas.isEmpty ? null : notas,
      );

      await _repo.createTraining(entrenamiento);
      if (!mounted) return;
      ModernSnackBar.showSuccess(context, 'Entrenamiento guardado');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final bgColor    = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F7);
    final cardColor  = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final txtColor   = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final hintColor  = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final fieldColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        foregroundColor: txtColor,
        elevation: 0,
        title: Text('Registro manual',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: txtColor)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: CupertinoActivityIndicator(),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Guardar',
                  style: TextStyle(color: AppColors.brandPurple, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Nombre ────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color:        cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller:           _titleCtrl,
              style:                TextStyle(color: txtColor, fontSize: 16),
              textCapitalization:   TextCapitalization.sentences,
              decoration: InputDecoration(
                border:      InputBorder.none,
                hintText:    'Nombre del entrenamiento',
                hintStyle:   TextStyle(color: hintColor),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Fecha ─────────────────────────────────────────────────────────
          GestureDetector(
            onTap: _showDateSheet,
            child: Container(
              decoration: BoxDecoration(
                color:        cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: AppColors.brandPurple, size: 18),
                  const SizedBox(width: 10),
                  Text('Fecha', style: TextStyle(color: txtColor, fontSize: 15)),
                  const Spacer(),
                  Text(_formatDate(_selectedDate),
                      style: TextStyle(color: hintColor, fontSize: 15)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: hintColor, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Series ────────────────────────────────────────────────────────
          Row(
            children: [
              Text('SERIES', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: hintColor, letterSpacing: 0.8)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _series.add(_ManualSerieData())),
                icon: const Icon(Icons.add_circle_rounded, size: 16, color: AppColors.brandPurple),
                label: const Text('Añadir', style: TextStyle(color: AppColors.brandPurple, fontSize: 13)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ..._series.asMap().entries.map((entry) {
            final idx  = entry.key;
            final serie = entry.value;
            return _ManualSerieCard(
              index:     idx,
              serie:     serie,
              cardColor: cardColor,
              txtColor:  txtColor,
              hintColor: hintColor,
              fieldColor: fieldColor,
              onPickDistance: () => _pickDistance(idx),
              onPickDuration: () => _pickDuration(idx),
              onPickRpe:      () => _pickRpe(idx),
              onPickRest:     () => _pickRest(idx),
              onDelete: _series.length > 1
                  ? () => setState(() => _series.removeAt(idx))
                  : null,
            );
          }),

          const SizedBox(height: 24),

          // ── Notas ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('NOTAS', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: hintColor, letterSpacing: 0.8)),
          ),
          Container(
            decoration: BoxDecoration(
              color:        cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller:         _notasCtrl,
              style:              TextStyle(color: txtColor, fontSize: 15),
              textCapitalization: TextCapitalization.sentences,
              maxLines:           4,
              decoration: InputDecoration(
                border:    InputBorder.none,
                hintText:  'Cómo fue el entrenamiento...',
                hintStyle: TextStyle(color: hintColor),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── _ManualSerieCard ──────────────────────────────────────────────────────────

class _ManualSerieCard extends StatelessWidget {
  final int              index;
  final _ManualSerieData serie;
  final Color            cardColor;
  final Color            txtColor;
  final Color            hintColor;
  final Color            fieldColor;
  final VoidCallback     onPickDistance;
  final VoidCallback     onPickDuration;
  final VoidCallback     onPickRpe;
  final VoidCallback     onPickRest;
  final VoidCallback?    onDelete;

  const _ManualSerieCard({
    required this.index,
    required this.serie,
    required this.cardColor,
    required this.txtColor,
    required this.hintColor,
    required this.fieldColor,
    required this.onPickDistance,
    required this.onPickDuration,
    required this.onPickRpe,
    required this.onPickRest,
    this.onDelete,
  });

  Color _rpeColor(double v) {
    if (v <= 3) return AppColors.rpeLow;
    if (v <= 6) return AppColors.rpeMid;
    if (v <= 8) return AppColors.effort;
    return AppColors.rpeMax;
  }

  String _durationLabel() {
    final m = serie.durationMinutes;
    final s = serie.durationSeconds;
    if (m == 0) return '${s}s';
    if (s == 0) return "${m}'";
    return "${m}' ${s}s";
  }

  @override
  Widget build(BuildContext context) {
    final rpeColor = _rpeColor(serie.rpe);
    final rpeLabel = serie.rpe == serie.rpe.truncateToDouble()
        ? serie.rpe.toInt().toString()
        : serie.rpe.toString();

    return Container(
      margin:      const EdgeInsets.only(bottom: 10),
      decoration:  BoxDecoration(
        color:        cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color:        AppColors.brandPurple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.brandPurple)),
                  ),
                ),
                const Spacer(),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: hintColor, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ),

          // Chips row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PickerChip(
                  icon:    Icons.straighten_rounded,
                  label:   _distanceLabel(serie.distanceM),
                  color:   AppColors.brandPurple,
                  onTap:   onPickDistance,
                ),
                _PickerChip(
                  icon:    Icons.timer_outlined,
                  label:   _durationLabel(),
                  color:   AppColors.brandPurple,
                  onTap:   onPickDuration,
                ),
                _PickerChip(
                  icon:    Icons.favorite_rounded,
                  label:   'RPE $rpeLabel',
                  color:   rpeColor,
                  onTap:   onPickRpe,
                ),
                _PickerChip(
                  icon:    Icons.pause_circle_outline_rounded,
                  label:   _restLabel(serie.restSeconds),
                  color:   hintColor,
                  onTap:   onPickRest,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _PickerChip ───────────────────────────────────────────────────────────────

class _PickerChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;

  const _PickerChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── _SheetContainer ───────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final double height;
  final Widget child;

  const _SheetContainer({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      height:      height,
      margin:      const EdgeInsets.all(12),
      decoration:  BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ── _DistancePickerSheet ──────────────────────────────────────────────────────

class _DistancePickerSheet extends StatefulWidget {
  final int? initial;
  const _DistancePickerSheet({this.initial});

  @override
  State<_DistancePickerSheet> createState() => _DistancePickerSheetState();
}

class _DistancePickerSheetState extends State<_DistancePickerSheet> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final idx = _standardDistances.indexOf(widget.initial!);
      _selectedIndex = idx >= 0 ? idx : 0;
    } else {
      _selectedIndex = 0;
    }
  }

  Future<void> _openCustom() async {
    Navigator.pop(context);
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Distancia personalizada'),
        content: TextField(
          controller:   ctrl,
          autofocus:    true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Metros (ej. 7500)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandPurple),
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx);
              if (v != null && v > 0 && context.mounted) {
                Navigator.pop(context, v);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final totalItems = _standardDistances.length + 1;

    return _SheetContainer(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text('Distancia', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor)),
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: _selectedIndex),
              itemExtent: 40,
              onSelectedItemChanged: (i) => setState(() => _selectedIndex = i),
              children: [
                ..._standardDistances.map((d) => Center(
                      child: Text(_distanceLabel(d),
                          style: TextStyle(fontSize: 18, color: labelColor)))),
                Center(
                  child: Text('Otra distancia →',
                      style: TextStyle(fontSize: 18, color: AppColors.brandPurple)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brandPurple),
                onPressed: () {
                  if (_selectedIndex == totalItems - 1) {
                    _openCustom();
                  } else {
                    Navigator.pop(context, _standardDistances[_selectedIndex]);
                  }
                },
                child: const Text('Confirmar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _DurationPickerSheet ──────────────────────────────────────────────────────

class _DurationPickerSheet extends StatefulWidget {
  final int? initialMinutes;
  final int? initialSeconds;
  const _DurationPickerSheet({this.initialMinutes, this.initialSeconds});

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  late int _minutes;
  late int _seconds;

  static const List<int> _secValues = [0, 15, 30, 45];

  @override
  void initState() {
    super.initState();
    _minutes = (widget.initialMinutes ?? 2).clamp(0, 180);
    final s  = widget.initialSeconds ?? 0;
    _seconds = _secValues.contains(s) ? s : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final hintColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return _SheetContainer(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text('Duración', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: _minutes),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => setState(() => _minutes = i),
                          children: List.generate(181, (i) => Center(
                              child: Text('$i', style: TextStyle(fontSize: 18, color: textColor)))),
                        ),
                      ),
                      Text('min', style: TextStyle(fontSize: 13, color: hintColor)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                              initialItem: _secValues.indexOf(_seconds)),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => setState(() => _seconds = _secValues[i]),
                          children: _secValues
                              .map((s) => Center(
                                    child: Text(s.toString().padLeft(2, '0'),
                                        style: TextStyle(fontSize: 18, color: textColor))))
                              .toList(),
                        ),
                      ),
                      Text('seg', style: TextStyle(fontSize: 13, color: hintColor)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brandPurple),
                onPressed: () => Navigator.pop(context, (_minutes, _seconds)),
                child: const Text('Confirmar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _RpePickerSheet ───────────────────────────────────────────────────────────

class _RpePickerSheet extends StatefulWidget {
  final double? initial;
  const _RpePickerSheet({this.initial});

  @override
  State<_RpePickerSheet> createState() => _RpePickerSheetState();
}

class _RpePickerSheetState extends State<_RpePickerSheet> {
  late int _idx;

  @override
  void initState() {
    super.initState();
    final v = widget.initial ?? 6.0;
    _idx    = _rpeValues.indexOf(v);
    if (_idx < 0) _idx = _rpeValues.indexOf(6.0);
  }

  Color _rpeColor(double v) {
    if (v <= 3) return AppColors.rpeLow;
    if (v <= 6) return AppColors.rpeMid;
    if (v <= 8) return AppColors.effort;
    return AppColors.rpeMax;
  }

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return _SheetContainer(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text('RPE (esfuerzo percibido)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: defaultColor)),
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: _idx),
              itemExtent: 40,
              onSelectedItemChanged: (i) => setState(() => _idx = i),
              children: _rpeValues.map((v) {
                final isSelected = _rpeValues[_idx] == v;
                final color      = isSelected ? _rpeColor(v) : defaultColor;
                final label      = v == v.truncateToDouble()
                    ? v.toInt().toString()
                    : v.toString();
                return Center(
                  child: Text(label,
                      style: TextStyle(
                        fontSize:   18,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color:      color,
                      )),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brandPurple),
                onPressed: () => Navigator.pop(context, _rpeValues[_idx]),
                child: const Text('Listo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _RestPickerSheet ──────────────────────────────────────────────────────────

class _RestPickerSheet extends StatefulWidget {
  final int? initial;
  const _RestPickerSheet({this.initial});

  @override
  State<_RestPickerSheet> createState() => _RestPickerSheetState();
}

class _RestPickerSheetState extends State<_RestPickerSheet> {
  late int _idx;

  @override
  void initState() {
    super.initState();
    final v = widget.initial ?? 60;
    _idx    = _restValues.indexOf(v);
    if (_idx < 0) _idx = _restValues.indexOf(60);
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return _SheetContainer(
      height: 300,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text('Descanso entre series',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: _idx),
              itemExtent: 40,
              onSelectedItemChanged: (i) => setState(() => _idx = i),
              children: _restValues
                  .map((v) => Center(
                        child: Text(_restLabel(v),
                            style: TextStyle(fontSize: 18, color: textColor))))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brandPurple),
                onPressed: () => Navigator.pop(context, _restValues[_idx]),
                child: const Text('Listo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

