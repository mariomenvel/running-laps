import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/ios_picker.dart';
import '../data/template_models.dart';
import 'alarm_config_sheet.dart';

class BlockEditorSheet extends StatefulWidget {
  final TemplateBlock? initialBlock;
  /// true si el usuario tiene fcMax configurado (muestra selector de zona FC).
  final bool hasFcConfig;

  const BlockEditorSheet({
    Key? key,
    this.initialBlock,
    this.hasFcConfig = false,
  }) : super(key: key);

  @override
  _BlockEditorSheetState createState() => _BlockEditorSheetState();
}

class _BlockEditorSheetState extends State<BlockEditorSheet> {
  int _distancia = 400;
  int _descanso = 60;

  // Alerts
  bool _alertsEnabled = false;
  TemplateAlerts _alerts = TemplateAlerts(enabled: false);

  // Objectives
  bool _objectivesExpanded = false;
  final _paceMinCtrl = TextEditingController();
  final _paceSecCtrl = TextEditingController();
  double _rpeValue = 5.0;
  bool _rpeSet = false;
  int? _selectedZone;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBlock;
    if (b != null) {
      _distancia = b.value;
      _descanso = b.restSeconds;
      _alerts = b.alerts;
      _alertsEnabled = _alerts.enabled;

      // Objectives — auto-expand if any value is set
      if (b.targetPaceMin != null) _paceMinCtrl.text = b.targetPaceMin.toString();
      if (b.targetPaceSec != null) _paceSecCtrl.text = b.targetPaceSec.toString();
      if (b.targetRpe != null) {
        _rpeValue = b.targetRpe!;
        _rpeSet = true;
      }
      _selectedZone = b.targetZone;
      _objectivesExpanded =
          b.targetPaceMin != null || b.targetRpe != null || b.targetZone != null;
    }
  }

  @override
  void dispose() {
    _paceMinCtrl.dispose();
    _paceSecCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final paceMin = _paceMinCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_paceMinCtrl.text.trim());
    final paceSec = _paceSecCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_paceSecCtrl.text.trim());

    final block = TemplateBlock(
      id: widget.initialBlock?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      order: widget.initialBlock?.order ?? 0,
      type: TemplateBlockType.distance,
      value: _distancia,
      restSeconds: _descanso,
      alerts: TemplateAlerts(
        enabled: _alertsEnabled,
        mode: _alerts.mode,
        timeMin: _alerts.timeMin,
        timeSec: _alerts.timeSec,
        paceMin: _alerts.paceMin,
        paceSec: _alerts.paceSec,
        segmentDistance: _alerts.segmentDistance,
      ),
      targetPaceMin: paceMin,
      targetPaceSec: paceSec,
      targetRpe: _rpeSet ? _rpeValue : null,
      targetZone: _selectedZone,
    );
    Navigator.pop(context, block);
  }

  void _showDistancePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Distancia (m)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: IosPicker(
                itemCount: 100,
                initialItem: (_distancia ~/ 50) - 1,
                onChanged: (idx) =>
                    setState(() => _distancia = (idx + 1) * 50),
                textBuilder: (i) => '${(i + 1) * 50}m',
                width: double.infinity,
                itemExtent: 36,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Listo', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Descanso',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: IosPicker(
                itemCount: 61,
                initialItem: _descanso ~/ 5,
                onChanged: (idx) => setState(() => _descanso = idx * 5),
                textBuilder: (i) => _formatMinSec(i * 5),
                width: double.infinity,
                itemExtent: 36,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Listo', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinSec(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final int m = totalSeconds ~/ 60;
    final int s = totalSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  void _openAlarmConfig() async {
    final result = await showModalBottomSheet<TemplateAlerts>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AlarmConfigSheet(initialAlerts: _alerts),
    );
    if (result != null) {
      setState(() => _alerts = result);
    }
  }

  // ── Helpers de color ────────────────────────────────────────────────

  /// Color semántico para un valor de RPE (1-10).
  Color _rpeColor(double rpe) {
    if (rpe <= 3) return AppColors.rpeLow;
    if (rpe <= 6) return AppColors.rpeMid;
    if (rpe <= 8) return AppColors.effort;
    return AppColors.rpeMax;
  }

  /// Color de zona FC (1-5) usando los tokens de AppColors.
  Color _zoneColor(int zone) {
    switch (zone) {
      case 1: return AppColors.rest;
      case 2: return AppColors.rpeLow;
      case 3: return AppColors.rpeMid;
      case 4: return AppColors.effort;
      case 5: return AppColors.rpeMax;
      default: return AppColors.rest;
    }
  }

  // ── Sección de objetivos ────────────────────────────────────────────

  Widget _buildObjectivesSection(ColorScheme cs) {
    final hasObjective = _paceMinCtrl.text.isNotEmpty ||
        _rpeSet ||
        _selectedZone != null;

    return Container(
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado colapsable
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _objectivesExpanded = !_objectivesExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _objectivesExpanded || hasObjective
                          ? AppColors.brand.withOpacity(0.1)
                          : cs.onSurface.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: _objectivesExpanded || hasObjective
                          ? AppColors.brand
                          : cs.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Objetivos del bloque',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (hasObjective)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Icon(
                    _objectivesExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: cs.onSurface.withOpacity(0.45),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Contenido colapsable
          if (_objectivesExpanded) ...[
            Divider(height: 1, color: cs.outline.withOpacity(0.3)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pace objetivo (solo si bloque de distancia)
                  _buildPaceField(cs),

                  const SizedBox(height: 20),

                  // RPE objetivo
                  _buildRpeSlider(cs),

                  // Zona FC objetivo (solo si hasFcConfig)
                  if (widget.hasFcConfig) ...[
                    const SizedBox(height: 20),
                    _buildZoneSelector(cs),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaceField(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PACE OBJETIVO (MIN/KM)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: cs.onSurface.withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PaceTextField(
                controller: _paceMinCtrl,
                label: 'Min',
                min: 0,
                max: 59,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            Expanded(
              child: _PaceTextField(
                controller: _paceSecCtrl,
                label: 'Seg',
                min: 0,
                max: 59,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRpeSlider(ColorScheme cs) {
    final color = _rpeSet ? _rpeColor(_rpeValue) : cs.onSurface.withOpacity(0.35);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'RPE OBJETIVO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withOpacity(0.5),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _rpeSet
                  ? Text(
                      _rpeValue.toStringAsFixed(1),
                      key: const ValueKey('rpe_value'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    )
                  : Text(
                      'Sin establecer',
                      key: const ValueKey('rpe_unset'),
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.4),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: cs.onSurface.withOpacity(0.12),
            thumbColor: color,
            overlayColor: color.withOpacity(0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: _rpeValue,
            min: 1.0,
            max: 10.0,
            divisions: 18,
            onChanged: (v) {
              setState(() {
                _rpeValue = v;
                _rpeSet = true;
              });
            },
          ),
        ),
        if (_rpeSet)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => setState(() {
                _rpeSet = false;
                _rpeValue = 5.0;
              }),
              child: Text(
                'Limpiar',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.45),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildZoneSelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ZONA FC OBJETIVO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: cs.onSurface.withOpacity(0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(5, (i) {
            final zone = i + 1;
            final isSelected = _selectedZone == zone;
            final zColor = _zoneColor(zone);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 4 ? 6 : 0),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedZone = isSelected ? null : zone;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? zColor.withOpacity(0.15)
                          : cs.onSurface.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? zColor.withOpacity(0.6)
                            : cs.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Z$zone',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? zColor
                                : cs.onSurface.withOpacity(0.4),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? zColor
                                : cs.onSurface.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black12,
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Scrollable form
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.initialBlock == null ? 'Nueva Serie' : 'Editar Serie',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Distancia / Descanso
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputCard(
                          label: 'Distancia',
                          value: '$_distancia m',
                          icon: Icons.straighten_rounded,
                          onTap: _showDistancePicker,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInputCard(
                          label: 'Descanso',
                          value: _formatMinSec(_descanso),
                          icon: Icons.timer_outlined,
                          onTap: _showRestPicker,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Objetivos del bloque ──────────────────────────
                  _buildObjectivesSection(cs),

                  const SizedBox(height: 16),

                  // ── Alertas de ritmo ──────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outline.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          value: _alertsEnabled,
                          onChanged: (v) =>
                              setState(() => _alertsEnabled = v),
                          activeColor: AppColors.brand,
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _alertsEnabled
                                  ? AppColors.brand.withOpacity(0.1)
                                  : cs.onSurface.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _alertsEnabled
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: _alertsEnabled
                                  ? (isDark
                                      ? AppColors.brandLight
                                      : AppColors.brand)
                                  : cs.onSurface.withOpacity(0.4),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Alertas de Ritmo',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        if (_alertsEnabled) ...[
                          const Divider(height: 1, indent: 60),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            title: Padding(
                              padding: const EdgeInsets.only(left: 44),
                              child: Text(
                                _alerts.mode == 'time'
                                    ? 'Frecuencia: Cada ${_formatMinSec((_alerts.timeMin * 60 + _alerts.timeSec).round())}'
                                    : 'Basado en Ritmo de Carrera',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurface.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.settings_suggest_rounded,
                                size: 20,
                                color: isDark
                                    ? AppColors.brandLight
                                    : AppColors.brand,
                              ),
                            ),
                            onTap: _openAlarmConfig,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botón guardar
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.brand,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'LISTO',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.transparent
                  : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5)),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TextField compacto para minutos/segundos de pace.
class _PaceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int min;
  final int max;
  final ValueChanged<String>? onChanged;

  const _PaceTextField({
    required this.controller,
    required this.label,
    required this.min,
    required this.max,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: '--',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        isDense: true,
        labelStyle: TextStyle(
          fontSize: 12,
          color: cs.onSurface.withOpacity(0.5),
        ),
      ),
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      onChanged: onChanged,
    );
  }
}
