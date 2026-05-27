import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_chat_service.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/core/services/user_service.dart';

class AiCoachSettingsView extends StatefulWidget {
  const AiCoachSettingsView({super.key, required this.uid});

  final String uid;

  @override
  State<AiCoachSettingsView> createState() => _AiCoachSettingsViewState();
}

class _AiCoachSettingsViewState extends State<AiCoachSettingsView> {
  final _goalDescriptionCtrl = TextEditingController();
  final _coachNotesCtrl = TextEditingController();
  final _strengthDaysCtrl = TextEditingController();
  final _otherConstraintsCtrl = TextEditingController();
  final _adjustmentCtrl = TextEditingController();

  final _repo = AiCoachRepository();
  final _chatService = AiCoachChatService();
  final _userService = UserService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSendingAdjustment = false;

  AiCoachGoalType _goal = AiCoachGoalType.improveEndurance;
  AiCoachAthleteLevel _level = AiCoachAthleteLevel.beginner;
  DateTime? _targetDate;
  int _preferredWeeklySessions = 3;
  int? _preferredLongRunWeekday;
  Set<int> _availableWeekdays = <int>{1, 3, 5};
  String _lastAdjustmentResponse = '';
  int _chatRemainingThisWeek = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _goalDescriptionCtrl.dispose();
    _coachNotesCtrl.dispose();
    _strengthDaysCtrl.dispose();
    _otherConstraintsCtrl.dispose();
    _adjustmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final isAthleteMode = await _userService.getIsAthleteMode(widget.uid);
      if (!isAthleteMode) {
        if (mounted) {
          ModernSnackBar.showError(
            context,
            'Activa modo atleta para usar el Entrenador IA.',
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final profile = await _repo.getProfile(uid: widget.uid);
      final usage = await _repo.getUsage(uid: widget.uid);
      if (!mounted) return;
      if (profile != null) {
        _goal = profile.goal;
        _level = profile.level;
        _targetDate = profile.targetDate;
        _preferredWeeklySessions = profile.preferredWeeklySessions;
        _preferredLongRunWeekday = profile.preferredLongRunWeekday;
        _availableWeekdays = profile.availableWeekdays.toSet();
        _goalDescriptionCtrl.text = profile.goalDescription;
        _coachNotesCtrl.text = profile.coachNotes ?? '';
        _strengthDaysCtrl.text = profile.recurringConstraints
            .where((item) => item.type == AiCoachConstraintType.strengthTraining)
            .map((item) => item.label)
            .join('\n');
        _otherConstraintsCtrl.text = profile.recurringConstraints
            .where((item) => item.type != AiCoachConstraintType.strengthTraining)
            .map((item) => item.label)
            .join('\n');
      } else {
        _goalDescriptionCtrl.text = 'Mejorar la consistencia semanal';
      }

      final now = DateTime.now();
      final isCurrentWeekUsage = usage != null &&
          !usage.periodStart.isAfter(now) &&
          !usage.periodEnd.isBefore(now);
      final used = isCurrentWeekUsage ? usage.messagesUsed : 0;
      _chatRemainingThisWeek = (3 - used).clamp(0, 3);
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(
        context,
        'No se pudo cargar la configuracion IA. '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_availableWeekdays.isEmpty) {
      ModernSnackBar.showError(context, 'Selecciona al menos un día disponible');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final previousProfile = await _repo.getProfile(uid: widget.uid);
      final profile = AiCoachProfile(
        uid: widget.uid,
        goal: _goal,
        goalDescription: _goalDescriptionCtrl.text.trim(),
        targetDate: _targetDate,
        level: _level,
        availableWeekdays: (_availableWeekdays.toList()..sort()),
        preferredWeeklySessions: _preferredWeeklySessions,
        preferredLongRunWeekday: _preferredLongRunWeekday,
        recurringConstraints: _buildRecurringConstraints(),
        coachNotes: _coachNotesCtrl.text.trim().isEmpty
            ? null
            : _coachNotesCtrl.text.trim(),
        createdAt: previousProfile?.createdAt ?? now,
        updatedAt: now,
      );
      await _repo.saveProfile(profile);
      if (!mounted) return;
      ModernSnackBar.showSuccess(context, 'Entrenador IA configurado');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(
        context,
        'No se pudo guardar la configuracion. '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: _targetDate ?? now.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() => _targetDate = picked);
  }

  Future<void> _sendAdjustment() async {
    final message = _adjustmentCtrl.text.trim();
    if (message.isEmpty) return;
    setState(() => _isSendingAdjustment = true);
    try {
      final result = await _chatService.adjustNextWeekPlan(
        widget.uid,
        athleteMessage: message,
      );
      if (!mounted) return;
      setState(() {
        _lastAdjustmentResponse = result.response;
        _adjustmentCtrl.clear();
        _chatRemainingThisWeek = (_chatRemainingThisWeek - 1).clamp(0, 3);
      });
      ModernSnackBar.showSuccess(
        context,
        result.decisionOverride != null
            ? 'Plan ajustado para la próxima semana'
            : 'La IA ha respondido sin cambiar el plan',
      );
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(
        context,
        'No se pudo enviar el ajuste. ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingAdjustment = false);
      }
    }
  }

  List<AiCoachRecurringConstraint> _buildRecurringConstraints() {
    final constraints = <AiCoachRecurringConstraint>[];
    for (final line in _splitLines(_strengthDaysCtrl.text)) {
      constraints.add(
        AiCoachRecurringConstraint(
          id: 'strength_${line.hashCode}',
          type: AiCoachConstraintType.strengthTraining,
          label: line,
        ),
      );
    }
    for (final line in _splitLines(_otherConstraintsCtrl.text)) {
      constraints.add(
        AiCoachRecurringConstraint(
          id: 'custom_${line.hashCode}',
          type: AiCoachConstraintType.custom,
          label: line,
        ),
      );
    }
    return constraints;
  }

  List<String> _splitLines(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final title = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final subtitle =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: background,
      body: Column(
        children: [
          AppHeader(
            title: const Text(
              'Entrenador IA',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _SectionCard(
                        title: 'Objetivo deportivo',
                        subtitle:
                            'Define el contexto estable para que la IA planifique como un entrenador serio.',
                        child: Column(
                          children: [
                            DropdownButtonFormField<AiCoachGoalType>(
                              value: _goal,
                              decoration: _inputDecoration('Objetivo principal'),
                              items: AiCoachGoalType.values
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(_goalLabel(value)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _goal = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _goalDescriptionCtrl,
                              decoration: _inputDecoration(
                                'Descripción del objetivo',
                                hint: 'Ej. 10K sub 50 o volver a correr con constancia',
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<AiCoachAthleteLevel>(
                              value: _level,
                              decoration: _inputDecoration('Nivel actual'),
                              items: AiCoachAthleteLevel.values
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(_levelLabel(value)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _level = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(16),
                              child: InputDecorator(
                                decoration: _inputDecoration('Fecha objetivo'),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _targetDate == null
                                            ? 'Sin fecha objetivo'
                                            : DateFormat('dd/MM/yyyy')
                                                .format(_targetDate!),
                                        style: TextStyle(color: title),
                                      ),
                                    ),
                                    Icon(Icons.calendar_month_rounded,
                                        color: subtitle),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Disponibilidad semanal',
                        subtitle:
                            'La IA usará estos días como marco para repartir la carga.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Días disponibles',
                              style: TextStyle(
                                color: title,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(7, (index) {
                                final day = index + 1;
                                final selected = _availableWeekdays.contains(day);
                                return FilterChip(
                                  selected: selected,
                                  label: Text(_weekdayShort(day)),
                                  onSelected: (value) {
                                    setState(() {
                                      if (value) {
                                        _availableWeekdays.add(day);
                                      } else {
                                        _availableWeekdays.remove(day);
                                      }
                                      if (_preferredLongRunWeekday != null &&
                                          !_availableWeekdays
                                              .contains(_preferredLongRunWeekday)) {
                                        _preferredLongRunWeekday = null;
                                      }
                                    });
                                  },
                                  selectedColor:
                                      _kAiSetupAccent.withValues(alpha: 0.22),
                                  checkmarkColor: AppColors.brandPurple,
                                  side: BorderSide(
                                    color: selected
                                        ? AppColors.brandPurple
                                        : border,
                                  ),
                                  labelStyle: TextStyle(
                                    color: selected ? title : subtitle,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _preferredWeeklySessions,
                                    decoration: _inputDecoration(
                                        'Sesiones objetivo por semana'),
                                    items: List.generate(5, (index) => index + 2)
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text('$value sesiones'),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(
                                          () => _preferredWeeklySessions = value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int?>(
                                    value: _preferredLongRunWeekday,
                                    decoration:
                                        _inputDecoration('Día preferido de tirada'),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Automático'),
                                      ),
                                      ...(_availableWeekdays.toList()..sort()).map(
                                        (day) => DropdownMenuItem<int?>(
                                          value: day,
                                          child: Text(_weekdayLabel(day)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(
                                          () => _preferredLongRunWeekday = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Restricciones recurrentes',
                        subtitle:
                            'Aquí van cosas que la IA debe recordar semana tras semana.',
                        child: Column(
                          children: [
                            TextField(
                              controller: _strengthDaysCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                'Fuerza / gimnasio',
                                hint:
                                    'Una línea por restricción. Ej. Miércoles hago pierna',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _otherConstraintsCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                'Otras restricciones',
                                hint:
                                    'Ej. Domingo no puedo correr temprano, viernes descanso fijo',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _coachNotesCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                'Notas del entrenador',
                                hint:
                                    'Ej. Tolero mejor volumen que intensidad, prefiero calidad en jueves',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Ajuste rápido de esta semana',
                        subtitle:
                            'Ejemplos: “miércoles hago pierna”, “esta semana solo tengo 2 días”, “tengo agujetas”.',
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Consultas restantes esta semana: $_chatRemainingThisWeek/3',
                                style: TextStyle(
                                  color: subtitle,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _adjustmentCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: _inputDecoration(
                                'Mensaje para la IA',
                                hint: 'Cuéntale el contexto que debe tener en cuenta',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSendingAdjustment ? null : _sendAdjustment,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.brandPurple,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _isSendingAdjustment
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                                label: Text(
                                  _isSendingAdjustment
                                      ? 'Ajustando…'
                                      : 'Enviar ajuste',
                                ),
                              ),
                            ),
                            if (_lastAdjustmentResponse.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _kAiSetupAccent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _kAiSetupAccent.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  _lastAdjustmentResponse,
                                  style: TextStyle(color: title, height: 1.35),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPurple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Guardar configuración IA',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceVariantDark
          : AppColors.surfaceVariantLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _goalLabel(AiCoachGoalType value) {
    switch (value) {
      case AiCoachGoalType.race5k:
        return 'Preparar 5K';
      case AiCoachGoalType.race10k:
        return 'Preparar 10K';
      case AiCoachGoalType.raceHalfMarathon:
        return 'Preparar media maratón';
      case AiCoachGoalType.raceMarathon:
        return 'Preparar maratón';
      case AiCoachGoalType.improvePace:
        return 'Mejorar ritmo';
      case AiCoachGoalType.improveEndurance:
        return 'Mejorar resistencia';
      case AiCoachGoalType.returnToRunning:
        return 'Volver a correr';
    }
  }

  String _levelLabel(AiCoachAthleteLevel value) {
    switch (value) {
      case AiCoachAthleteLevel.beginner:
        return 'Principiante';
      case AiCoachAthleteLevel.intermediate:
        return 'Intermedio';
      case AiCoachAthleteLevel.advanced:
        return 'Avanzado';
    }
  }

  String _weekdayShort(int day) {
    switch (day) {
      case 1:
        return 'Lun';
      case 2:
        return 'Mar';
      case 3:
        return 'Mié';
      case 4:
        return 'Jue';
      case 5:
        return 'Vie';
      case 6:
        return 'Sáb';
      default:
        return 'Dom';
    }
  }

  String _weekdayLabel(int day) {
    switch (day) {
      case 1:
        return 'Lunes';
      case 2:
        return 'Martes';
      case 3:
        return 'Miércoles';
      case 4:
        return 'Jueves';
      case 5:
        return 'Viernes';
      case 6:
        return 'Sábado';
      default:
        return 'Domingo';
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

const Color _kAiSetupAccent = Color(0xFFD8C8FF);
