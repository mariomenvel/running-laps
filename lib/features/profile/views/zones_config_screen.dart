import 'package:flutter/material.dart';
import 'package:running_laps/core/services/zones_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_date_picker.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/widgets/number_picker_field.dart';
import 'package:running_laps/features/profile/viewmodels/zones_viewmodel.dart';

class ZonesConfigScreen extends StatefulWidget {
  final String uid;
  const ZonesConfigScreen({super.key, required this.uid});

  @override
  State<ZonesConfigScreen> createState() => _ZonesConfigScreenState();
}

class _ZonesConfigScreenState extends State<ZonesConfigScreen> {
  late final ZonesViewModel _vm;

  // Enteros, no TextEditingController: los valores se eligen en una rueda
  // (convención del proyecto — ningún número se teclea). null = sin definir,
  // que para FCmáx significa "usa la estimación por edad" (220 − edad).
  int? _fcMax;
  int? _fcReposo;

  @override
  void initState() {
    super.initState();
    _vm = ZonesViewModel();
    _vm.loadProfile(widget.uid).then((_) {
      if (!mounted) return;
      _syncFromProfile();
    });
  }

  void _syncFromProfile() {
    final p = _vm.state.value.profile;
    if (p == null) return;
    setState(() {
      _fcMax = p.fcMax;
      _fcReposo = p.fcReposo;
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  // ── Onboarding bottom sheet ────────────────────────────────────────

  // ── Save ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Sin validador: la rueda solo ofrece valores dentro de rango, así que un
    // valor fuera de [min, max] ya no puede llegar hasta aquí.
    await _vm.saveFcConfig(
      uid: widget.uid,
      fcMax: _fcMax,
      fcReposo: _fcReposo,
    );

    if (!mounted) return;

    final err = _vm.state.value.errorMessage;
    if (err != null) {
      ModernSnackBar.showError(context, err);
    } else {
      ModernSnackBar.showSuccess(context, 'Configuración guardada');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Se oculta solo cuando la vista está embebida en el shell.
          const AppHeader(showBottomDivider: false),
          Expanded(
            child: ValueListenableBuilder<ZonesViewModelState>(
        valueListenable: _vm.state,
        builder: (context, vmState, _) {
          if (vmState.profile == null && vmState.errorMessage == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          }

          final profile = vmState.profile;
          final hasBirthDate = profile?.birthDate != null;

          // La previsualización sigue al valor que hay **en pantalla**, no al
          // guardado en el perfil: eligiendo 197 en la rueda, la tabla de abajo
          // seguía diciendo "FCmáx 194 bpm" hasta pulsar Guardar, y la pantalla
          // se contradecía a sí misma mientras la usabas.
          //
          // `fcMaxEffective` da justo esta semántica: el valor manual manda y,
          // si se limpia, vuelve la estimación por edad. Así el botón de
          // limpiar también se ve: las zonas saltan de vuelta a las estimadas.
          final estimated =
              ZonesService().fcMaxEffective(_fcMax, profile?.birthDate);
          final zones = ZonesService().zonesFor(estimated ?? 180);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Campos de FC ──────────────────────────────────
                  _SectionTitle('Frecuencia cardíaca'),
                  const SizedBox(height: 12),

                  _FcField(
                    value: _fcMax,
                    label: 'FCmáx',
                    emptyLabel: hasBirthDate && estimated != null
                        ? 'Estimada: $estimated (220 − edad)'
                        : 'Sin definir',
                    min: 100,
                    max: 220,
                    fallback: estimated ?? 185,
                    onChanged: (v) => setState(() => _fcMax = v),
                  ),
                  const SizedBox(height: 12),

                  _FcField(
                    value: _fcReposo,
                    label: 'FC reposo',
                    emptyLabel: 'Sin definir',
                    min: 30,
                    max: 100,
                    fallback: 55,
                    onChanged: (v) => setState(() => _fcReposo = v),
                  ),
                  const SizedBox(height: 28),

                  // ── Tabla de zonas ────────────────────────────────
                  _SectionTitle(
                    estimated != null
                        ? 'Tus zonas  •  FCmáx $estimated bpm'
                        : 'Zonas de referencia  •  FCmáx 180 bpm (estimado)',
                  ),
                  const SizedBox(height: 4),
                  if (estimated == null)
                    Text(
                      'Introduce tu FCmáx o tu fecha de nacimiento para personalizar.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  const SizedBox(height: 12),

                  ...zones.map((z) => _ZoneRow(zone: z)),

                  const SizedBox(height: 32),

                  // ── Botón guardar ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: vmState.isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: vmState.isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Guardar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subwidgets ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        letterSpacing: 0.4,
      ),
    );
  }
}

/// Campo de pulsaciones: rueda (NumberPickerField) en vez de teclado.
///
/// Ambos campos son opcionales y el vacío significa algo: sin FCmáx, las zonas
/// se calculan con la estimación por edad. Como una rueda no puede devolver
/// "nada", el botón de limpiar es la única forma de volver a ese estado —
/// no es decorativo.
class _FcField extends StatelessWidget {
  final int? value;
  final String label;

  /// Qué mostrar cuando no hay valor (ej. la FCmáx estimada por edad).
  final String emptyLabel;

  /// Dónde arranca la rueda la primera vez, sin valor previo.
  final int fallback;

  final int min;
  final int max;
  final ValueChanged<int?> onChanged;

  const _FcField({
    required this.value,
    required this.label,
    required this.emptyLabel,
    required this.fallback,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: NumberPickerField(
            label: label,
            value: (value ?? fallback).clamp(min, max),
            min: min,
            max: max,
            step: 1,
            unit: 'bpm',
            displayOverride: value == null ? emptyLabel : null,
            onChanged: onChanged,
          ),
        ),
        if (value != null)
          IconButton(
            icon: const Icon(Icons.backspace_outlined, size: 18),
            tooltip: 'Quitar $label',
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}


class _ZoneRow extends StatelessWidget {
  final dynamic zone; // ZoneRange
  const _ZoneRow({required this.zone});

  @override
  Widget build(BuildContext context) {
    final maxLabel = zone.maxBpm >= 999 ? '∞' : '${zone.maxBpm}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (zone.color as Color).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (zone.color as Color).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(
              color: zone.color as Color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Z${zone.zone} · ${zone.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${zone.minBpm} – $maxLabel bpm',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onboarding sheet ───────────────────────────────────────────────────

class _OnboardingSheet extends StatefulWidget {
  final String uid;
  final Future<void> Function(String? birthDate, String? sex) onSave;
  final VoidCallback onSkip;

  const _OnboardingSheet({
    required this.uid,
    required this.onSave,
    required this.onSkip,
  });

  @override
  State<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<_OnboardingSheet> {
  DateTime? _selectedDate;
  String? _selectedSex; // 'M' | 'F' | 'X'
  bool _saving = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      title: 'Fecha de nacimiento',
      initialDate: _selectedDate ?? DateTime(now.year - 25),
      minimumDate: DateTime(1930),
      maximumDate: DateTime(now.year - 5),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final birthDate = _selectedDate != null
        ? '${_selectedDate!.year.toString().padLeft(4, '0')}'
          '-${_selectedDate!.month.toString().padLeft(2, '0')}'
          '-${_selectedDate!.day.toString().padLeft(2, '0')}'
        : null;
    await widget.onSave(birthDate, _selectedSex);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Personaliza tus zonas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Con tu fecha de nacimiento calculamos tu FCmáx estimada '
            'y ajustamos las zonas automáticamente.',
            style: TextStyle(
              fontSize: 14,
              color: onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Fecha de nacimiento
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined,
                      color: AppColors.brand, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Fecha de nacimiento',
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedDate != null
                          ? onSurface
                          : onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sexo biológico
          Text(
            'Sexo biológico (opcional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final opt in [('M', 'Hombre'), ('F', 'Mujer'), ('X', 'Otro')])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SexButton(
                      label: opt.$2,
                      value: opt.$1,
                      selected: _selectedSex == opt.$1,
                      onTap: () =>
                          setState(() => _selectedSex = opt.$1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onSkip,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Omitir'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Continuar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SexButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _SexButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : Colors.transparent;
    final borderColor = selected
        ? AppColors.brand
        : Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.12 : 0),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? AppColors.brand
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
