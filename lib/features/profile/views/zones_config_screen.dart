import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/profile/viewmodels/zones_viewmodel.dart';

class ZonesConfigScreen extends StatefulWidget {
  final String uid;
  const ZonesConfigScreen({super.key, required this.uid});

  @override
  State<ZonesConfigScreen> createState() => _ZonesConfigScreenState();
}

class _ZonesConfigScreenState extends State<ZonesConfigScreen> {
  late final ZonesViewModel _vm;

  final _formKey = GlobalKey<FormState>();
  final _fcMaxCtrl = TextEditingController();
  final _fcReposoCtrl = TextEditingController();

  bool _onboardingShown = false;

  @override
  void initState() {
    super.initState();
    _vm = ZonesViewModel();
    _vm.loadProfile(widget.uid).then((_) {
      if (!mounted) return;
      _syncControllersFromProfile();
      if (_vm.needsBirthDate && !_onboardingShown) {
        _onboardingShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showOnboardingSheet();
        });
      }
    });
  }

  void _syncControllersFromProfile() {
    final p = _vm.state.value.profile;
    if (p == null) return;
    if (p.fcMax != null) _fcMaxCtrl.text = p.fcMax.toString();
    if (p.fcReposo != null) _fcReposoCtrl.text = p.fcReposo.toString();
  }

  @override
  void dispose() {
    _fcMaxCtrl.dispose();
    _fcReposoCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  // ── Onboarding bottom sheet ────────────────────────────────────────

  Future<void> _showOnboardingSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _OnboardingSheet(
        uid: widget.uid,
        onSave: (birthDate, sex) async {
          Navigator.pop(ctx);
          await _vm.saveFcConfig(
            uid: widget.uid,
            birthDate: birthDate,
            sex: sex,
          );
          if (!mounted) return;
          _syncControllersFromProfile();
        },
        onSkip: () => Navigator.pop(ctx),
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fcMax = _fcMaxCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_fcMaxCtrl.text.trim());
    final fcReposo = _fcReposoCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_fcReposoCtrl.text.trim());

    await _vm.saveFcConfig(
      uid: widget.uid,
      fcMax: fcMax,
      fcReposo: fcReposo,
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
      appBar: AppBar(
        title: const Text('Zonas de entrenamiento'),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<ZonesViewModelState>(
        valueListenable: _vm.state,
        builder: (context, vmState, _) {
          if (vmState.profile == null && vmState.errorMessage == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            );
          }

          final zones = _vm.currentZones;
          final estimated = _vm.effectiveFcMax;
          final profile = vmState.profile;
          final hasBirthDate = profile?.birthDate != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Campos de FC ──────────────────────────────────
                  _SectionTitle('Frecuencia cardíaca'),
                  const SizedBox(height: 12),

                  _FcField(
                    controller: _fcMaxCtrl,
                    label: 'FCmáx (lpm)',
                    hint: hasBirthDate && estimated != null
                        ? 'Estimada: $estimated bpm (220 − edad)'
                        : 'Ej. 185',
                    min: 100,
                    max: 220,
                    optional: true,
                  ),
                  const SizedBox(height: 12),

                  _FcField(
                    controller: _fcReposoCtrl,
                    label: 'FC reposo (lpm)',
                    hint: 'Ej. 55',
                    min: 30,
                    max: 100,
                    optional: true,
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
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
        fontWeight: FontWeight.w700,
        color:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        letterSpacing: 0.4,
      ),
    );
  }
}

class _FcField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int min;
  final int max;
  final bool optional;

  const _FcField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.min,
    required this.max,
    required this.optional,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixText: 'bpm',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return optional ? null : 'Campo requerido';
        }
        final n = int.tryParse(v.trim());
        if (n == null || n < min || n > max) {
          return 'Debe estar entre $min y $max';
        }
        return null;
      },
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
                    fontWeight: FontWeight.w700,
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year - 5),
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
              fontWeight: FontWeight.bold,
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
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.brand
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
