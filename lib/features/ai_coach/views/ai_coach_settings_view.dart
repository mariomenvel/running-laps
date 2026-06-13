import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_weekly_feedback_view.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/core/services/user_service.dart';

class AiCoachSettingsView extends StatefulWidget {
  const AiCoachSettingsView({super.key});

  @override
  State<AiCoachSettingsView> createState() => _AiCoachSettingsViewState();
}

class _AiCoachSettingsViewState extends State<AiCoachSettingsView> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  final _goalDescriptionCtrl = TextEditingController();
  final _coachNotesCtrl = TextEditingController();
  final _strengthInputCtrl = TextEditingController();
  final _otherInputCtrl = TextEditingController();

  final _repo = AiCoachRepository();
  final _userService = UserService();

  bool _isLoading = true;
  bool _isSaving = false;
  AiCoachWeeklyState? _weeklyState;

  AiCoachGoalType _goal = AiCoachGoalType.improveEndurance;
  AiCoachAthleteLevel _level = AiCoachAthleteLevel.beginner;
  DateTime? _targetDate;
  int _preferredWeeklySessions = 3;
  int? _preferredLongRunWeekday;
  Set<int> _availableWeekdays = <int>{1, 3, 5};

  final List<String> _strengthConstraints = [];
  final List<String> _otherConstraints = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _goalDescriptionCtrl.dispose();
    _coachNotesCtrl.dispose();
    _strengthInputCtrl.dispose();
    _otherInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final isAthleteMode = await _userService.getIsAthleteMode(_uid);
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

      final results = await Future.wait([
        _repo.getProfile(uid: _uid),
        _repo.getWeeklyState(uid: _uid),
      ]);
      final profile = results[0] as AiCoachProfile?;
      _weeklyState = results[1] as AiCoachWeeklyState?;
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

        _strengthConstraints.clear();
        _strengthConstraints.addAll(
          profile.recurringConstraints
              .where((item) => item.type == AiCoachConstraintType.strengthTraining)
              .map((item) => item.label),
        );

        _otherConstraints.clear();
        _otherConstraints.addAll(
          profile.recurringConstraints
              .where((item) => item.type != AiCoachConstraintType.strengthTraining)
              .map((item) => item.label),
        );
      } else {
        _goalDescriptionCtrl.text = 'Mejorar la consistencia semanal';
      }
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

  String? _validateCoachText(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    const suspiciousPatterns = [
      'ignore', 'ignora', 'olvida', 'forget',
      'system prompt', 'instrucciones anteriores',
      'eres ahora', 'you are now', 'jailbreak',
      'dan mode', 'developer mode',
    ];
    if (suspiciousPatterns.any((p) => lower.contains(p))) {
      return 'Por favor escribe solo información de entrenamiento';
    }
    return null;
  }

  Future<void> _save() async {
    if (_availableWeekdays.isEmpty) {
      ModernSnackBar.showError(context, 'Selecciona al menos un día disponible');
      return;
    }
    final goalError = _validateCoachText(_goalDescriptionCtrl.text);
    final notesError = _validateCoachText(_coachNotesCtrl.text);
    final constraintError = [
      ..._strengthConstraints,
      ..._otherConstraints,
    ].map(_validateCoachText).firstWhere((e) => e != null, orElse: () => null);
    if (goalError != null || notesError != null || constraintError != null) {
      ModernSnackBar.showError(
        context,
        goalError ?? notesError ?? constraintError!,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final previousProfile = await _repo.getProfile(uid: _uid);
      final profile = AiCoachProfile(
        uid: _uid,
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

  String _feedbackButtonLabel() {
    final weekday = DateTime.now().weekday;
    if (weekday >= 6) return 'Cuéntale cómo fue esta semana';
    if (weekday <= 2) return 'Cuéntale cómo fue la semana pasada';
    return 'Enviar feedback al coach';
  }

  void _openFeedback() {
    final weekday = DateTime.now().weekday;
    final now = DateTime.now();
    late DateTime monday;
    if (weekday <= 2) {
      monday = now.subtract(Duration(days: now.weekday - 1 + 7));
    } else {
      monday = now.subtract(Duration(days: now.weekday - 1));
    }
    final weekStart = '${monday.year}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';

    Navigator.of(context).push(AppRoute(
      page: AiCoachWeeklyFeedbackView(
        weekStart: weekStart,
        generatePlanAfter: false,
        daysSinceLastTraining: _weeklyState?.daysSinceLastTraining ?? 0,
        consecutiveMissedWeeks: _weeklyState?.consecutiveMissedWeeks ?? 0,
        onCompleted: () => Navigator.of(context).pop(),
      ),
    ));
  }

  List<AiCoachRecurringConstraint> _buildRecurringConstraints() {
    final constraints = <AiCoachRecurringConstraint>[];
    for (final label in _strengthConstraints) {
      constraints.add(
        AiCoachRecurringConstraint(
          id: 'strength_${label.hashCode}',
          type: AiCoachConstraintType.strengthTraining,
          label: label,
        ),
      );
    }
    for (final label in _otherConstraints) {
      constraints.add(
        AiCoachRecurringConstraint(
          id: 'custom_${label.hashCode}',
          type: AiCoachConstraintType.custom,
          label: label,
        ),
      );
    }
    return constraints;
  }

  void _showGoalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona tu Objetivo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: AppColors.borderOf(context), thickness: 0.5),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: AiCoachGoalType.values.map((value) {
                    final isSelected = _goal == value;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                      title: Text(
                        _goalLabel(value),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppColors.brand : AppColors.textPrimary(context),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: AppColors.brand, size: 20)
                          : null,
                      onTap: () {
                        setState(() => _goal = value);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLongRunDayBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final availableDaysSorted = _availableWeekdays.toList()..sort();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Día de Tirada Larga',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: AppColors.borderOf(context), thickness: 0.5),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                      title: Text(
                        'Automático',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _preferredLongRunWeekday == null ? FontWeight.w600 : FontWeight.w400,
                          color: _preferredLongRunWeekday == null ? AppColors.brand : AppColors.textPrimary(context),
                        ),
                      ),
                      trailing: _preferredLongRunWeekday == null
                          ? const Icon(Icons.check_rounded, color: AppColors.brand, size: 20)
                          : null,
                      onTap: () {
                        setState(() => _preferredLongRunWeekday = null);
                        Navigator.pop(context);
                      },
                    ),
                    ...availableDaysSorted.map((day) {
                      final isSelected = _preferredLongRunWeekday == day;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                        title: Text(
                          _weekdayLabel(day),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppColors.brand : AppColors.textPrimary(context),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded, color: AppColors.brand, size: 20)
                            : null,
                        onTap: () {
                          setState(() => _preferredLongRunWeekday = day);
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: ShellEmbeddingScope.isEmbedded(context)
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        _sectionHeader(
                          'OBJETIVO',
                          subtitle: 'Define el contexto estable para que la IA planifique como un entrenador serio.',
                        ),
                        Divider(height: 1, color: AppColors.borderOf(context)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _buildGoalSelector(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormLabel(context, 'Descripción del objetivo'),
                              TextField(
                                controller: _goalDescriptionCtrl,
                                maxLength: 200,
                                decoration: _inputDecoration(context, hint: 'Ej. 10K sub 50 o volver a correr con constancia'),
                                style: TextStyle(fontSize: 15, color: AppColors.textPrimary(context)),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: _buildLevelSelector(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: _buildDatePicker(context),
                        ),
                        _sectionHeader(
                          'DISPONIBILIDAD',
                          subtitle: 'La IA usará estos días como marco para repartir la carga.',
                        ),
                        Divider(height: 1, color: AppColors.borderOf(context)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _buildWeekDaySelector(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _buildSessionsCountSelector(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormLabel(context, 'Día preferido de tirada larga'),
                              _buildLongRunDaySelector(context),
                            ],
                          ),
                        ),
                        _sectionHeader(
                          'RESTRICCIONES',
                          subtitle: 'Cosas que el entrenador IA debe recordar semana tras semana.',
                        ),
                        Divider(height: 1, color: AppColors.borderOf(context)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _buildConstraintsManager(
                            context: context,
                            title: 'Fuerza / gimnasio',
                            placeholder: 'Ej. Miércoles hago pierna',
                            items: _strengthConstraints,
                            inputController: _strengthInputCtrl,
                            onAdd: () {
                              final text = _strengthInputCtrl.text.trim();
                              if (text.isNotEmpty) {
                                if (_validateCoachText(text) != null) {
                                  ModernSnackBar.showError(context, _validateCoachText(text)!);
                                  return;
                                }
                                setState(() {
                                  _strengthConstraints.add(text);
                                  _strengthInputCtrl.clear();
                                });
                              }
                            },
                            onDelete: (idx) {
                              setState(() => _strengthConstraints.removeAt(idx));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _buildConstraintsManager(
                            context: context,
                            title: 'Otras restricciones',
                            placeholder: 'Ej. Domingo no corro temprano',
                            items: _otherConstraints,
                            inputController: _otherInputCtrl,
                            onAdd: () {
                              final text = _otherInputCtrl.text.trim();
                              if (text.isNotEmpty) {
                                if (_validateCoachText(text) != null) {
                                  ModernSnackBar.showError(context, _validateCoachText(text)!);
                                  return;
                                }
                                setState(() {
                                  _otherConstraints.add(text);
                                  _otherInputCtrl.clear();
                                });
                              }
                            },
                            onDelete: (idx) {
                              setState(() => _otherConstraints.removeAt(idx));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormLabel(context, 'Notas adicionales del entrenador'),
                              TextField(
                                controller: _coachNotesCtrl,
                                minLines: 3,
                                maxLines: 5,
                                maxLength: 300,
                                decoration: _inputDecoration(
                                  context,
                                  hint: 'Ej. Tolero mejor volumen que intensidad, prefiero calidad en jueves...',
                                ),
                                style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
                              ),
                            ],
                          ),
                        ),
                        _sectionHeader('FEEDBACK'),
                        Divider(height: 1, color: AppColors.borderOf(context)),
                        ListTile(
                          leading: const Icon(Icons.rate_review_outlined, color: AppColors.brand),
                          title: Text(_feedbackButtonLabel()),
                          subtitle: const Text('El coach lo tendrá en cuenta al generar tu próximo plan'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _openFeedback,
                        ),
                        Divider(height: 1, color: AppColors.borderOf(context)),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                                      'Guardar',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
    );
  }

  Widget _sectionHeader(String title, {String? subtitle}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.brand,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildFormLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary(context),
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildGoalSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormLabel(context, 'Objetivo principal'),
        InkWell(
          onTap: () => _showGoalBottomSheet(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _goalLabel(_goal),
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormLabel(context, 'Nivel actual'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context), width: 0.5),
          ),
          child: Row(
            children: AiCoachAthleteLevel.values.map((value) {
              final isSelected = _level == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _level = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brand.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : Colors.transparent,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _levelLabel(value),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.textSecondary(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final title = AppColors.textPrimary(context);
    final subtitle = AppColors.textSecondary(context);

    int? weeksLeft;
    int? daysLeft;
    if (_targetDate != null) {
      final diff = _targetDate!.difference(DateTime.now());
      daysLeft = diff.inDays;
      weeksLeft = (daysLeft / 7).ceil();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormLabel(context, 'Fecha objetivo'),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _targetDate == null
                        ? 'Sin fecha objetivo'
                        : DateFormat('dd/MM/yyyy').format(_targetDate!),
                    style: TextStyle(color: title, fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(Icons.calendar_month_rounded, color: subtitle),
              ],
            ),
          ),
        ),
        if (_targetDate != null && daysLeft != null && daysLeft > 0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.brand, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quedan $weeksLeft ${weeksLeft == 1 ? "semana" : "semanas"} ($daysLeft días) para tu objetivo.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.brand,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeekDaySelector(BuildContext context) {
    final subtitle = AppColors.textSecondary(context);
    final border = AppColors.borderOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormLabel(context, 'Días disponibles'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final day = index + 1;
            final selected = _availableWeekdays.contains(day);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _availableWeekdays.remove(day);
                  } else {
                    _availableWeekdays.add(day);
                  }
                  if (_preferredLongRunWeekday != null &&
                      !_availableWeekdays.contains(_preferredLongRunWeekday)) {
                    _preferredLongRunWeekday = null;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.brand.withValues(alpha: 0.08)
                      : AppColors.surfaceOf(context),
                  border: Border.all(
                    color: selected ? AppColors.brand : border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _weekdayLetter(day),
                  style: TextStyle(
                    color: selected ? AppColors.brand : subtitle,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSessionsCountSelector(BuildContext context) {
    final border = AppColors.borderOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormLabel(context, 'Sesiones objetivo por semana'),
        Row(
          children: List.generate(5, (index) {
            final count = index + 2;
            final selected = _preferredWeeklySessions == count;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _preferredWeeklySessions = count),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == 4 ? 0 : 4,
                  ),
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selected
                        ? AppColors.brand.withValues(alpha: 0.08)
                        : AppColors.surfaceOf(context),
                    border: Border.all(
                      color: selected ? AppColors.brand : border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? AppColors.brand : AppColors.textSecondary(context),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                      letterSpacing: -0.3,
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

  Widget _buildLongRunDaySelector(BuildContext context) {
    final labelText = _preferredLongRunWeekday == null
        ? 'Automático'
        : _weekdayLabel(_preferredLongRunWeekday!);

    return InkWell(
      onTap: () => _showLongRunDayBottomSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labelText,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildConstraintsManager({
    required BuildContext context,
    required String title,
    required String placeholder,
    required List<String> items,
    required TextEditingController inputController,
    required VoidCallback onAdd,
    required Function(int) onDelete,
  }) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormLabel(context, title),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Sin restricciones añadidas.',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.brand.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onDelete(idx),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.brand,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: inputController,
                maxLength: 100,
                decoration: _inputDecoration(context, hint: placeholder).copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  counterText: '',
                ),
                style: TextStyle(fontSize: 13, color: textPrimary),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onAdd,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(BuildContext context, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textSecondary(context).withValues(alpha: 0.6),
        fontSize: 14,
        letterSpacing: -0.3,
      ),
      filled: true,
      fillColor: AppColors.surfaceOf(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  String _weekdayLetter(int day) {
    switch (day) {
      case 1:
        return 'L';
      case 2:
        return 'M';
      case 3:
        return 'X';
      case 4:
        return 'J';
      case 5:
        return 'V';
      case 6:
        return 'S';
      default:
        return 'D';
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
