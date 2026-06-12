import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/app_header.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/utils/app_transitions.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_chat_service.dart';
import 'package:running_laps/features/ai_coach/views/ai_coach_weekly_feedback_view.dart';
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
  final _strengthInputCtrl = TextEditingController();
  final _otherInputCtrl = TextEditingController();
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

  String _currentWeekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
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
    final background = AppColors.background(context);

    return Scaffold(
      backgroundColor: background,
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const AppHeader(
              title: Text(
                'Entrenador IA',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface2Of(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderOf(context), width: 0.5),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.borderOf(context).withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                labelColor: AppColors.brand,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.3),
                unselectedLabelColor: AppColors.textSecondary(context),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, letterSpacing: -0.3),
                tabs: const [
                  Tab(text: 'Bases del Plan'),
                  Tab(text: 'Ajuste Semanal'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildBasesTab(context),
                        _buildAjustesTab(context),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasesTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _SectionCard(
          title: 'Objetivo deportivo',
          subtitle: 'Define el contexto estable para que la IA planifique como un entrenador serio.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGoalSelector(context),
              const SizedBox(height: 16),
              _buildFormLabel(context, 'Descripción del objetivo'),
              TextField(
                controller: _goalDescriptionCtrl,
                decoration: _inputDecoration(context, hint: 'Ej. 10K sub 50 o volver a correr con constancia'),
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary(context)),
              ),
              const SizedBox(height: 16),
              _buildLevelSelector(context),
              const SizedBox(height: 16),
              _buildDatePicker(context),
            ],
          ),
        ),
        _SectionCard(
          title: 'Disponibilidad semanal',
          subtitle: 'La IA usará estos días como marco para repartir la carga.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeekDaySelector(context),
              const SizedBox(height: 16),
              _buildSessionsCountSelector(context),
              const SizedBox(height: 16),
              _buildFormLabel(context, 'Día preferido de tirada larga'),
              _buildLongRunDaySelector(context),
            ],
          ),
        ),
        _SectionCard(
          title: 'Restricciones recurrentes',
          subtitle: 'Cosas específicas que el entrenador IA debe recordar semana tras semana.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConstraintsManager(
                context: context,
                title: 'Fuerza / gimnasio',
                placeholder: 'Ej. Miércoles hago pierna',
                items: _strengthConstraints,
                inputController: _strengthInputCtrl,
                onAdd: () {
                  final text = _strengthInputCtrl.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      _strengthConstraints.add(text);
                      _strengthInputCtrl.clear();
                    });
                  }
                },
                onDelete: (idx) {
                  setState(() {
                    _strengthConstraints.removeAt(idx);
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildConstraintsManager(
                context: context,
                title: 'Otras restricciones',
                placeholder: 'Ej. Domingo no corro temprano',
                items: _otherConstraints,
                inputController: _otherInputCtrl,
                onAdd: () {
                  final text = _otherInputCtrl.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      _otherConstraints.add(text);
                      _otherInputCtrl.clear();
                    });
                  }
                },
                onDelete: (idx) {
                  setState(() {
                    _otherConstraints.removeAt(idx);
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildFormLabel(context, 'Notas adicionales del entrenador'),
              TextField(
                controller: _coachNotesCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration(
                  context,
                  hint: 'Ej. Tolero mejor volumen que intensidad, prefiero calidad en jueves...',
                ),
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
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
                  'Guardar bases del plan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                ),
        ),
      ],
    );
  }

  Widget _buildAjustesTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _SectionCard(
          title: 'Feedback semanal',
          subtitle: 'Cuéntale al coach cómo fue la semana para que ajuste los próximos entrenamientos.',
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Enviar feedback al coach'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.brand),
                foregroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                AppRoute(
                  page: AiCoachWeeklyFeedbackView(
                    weekStart: _currentWeekStart(),
                    generatePlanAfter: false,
                    onCompleted: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
        ),
        _SectionCard(
          title: 'Ajuste rápido de esta semana',
          subtitle: 'Comunícale cambios temporales a tu Coach para la planificación de la siguiente semana. Ej. "tengo dolor en la rodilla", "esta semana viajo y solo tengo 2 días".',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMessageLimitIndicator(context),
              const SizedBox(height: 16),
              _buildFormLabel(context, 'Mensaje para tu Coach'),
              TextField(
                controller: _adjustmentCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: _inputDecoration(
                  context,
                  hint: 'Cuéntale a la IA el contexto específico o imprevistos de tu semana...',
                ),
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSendingAdjustment || _chatRemainingThisWeek <= 0
                      ? null
                      : _sendAdjustment,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
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
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSendingAdjustment
                        ? 'Ajustando plan...'
                        : _chatRemainingThisWeek <= 0
                            ? 'Sin consultas disponibles'
                            : 'Enviar ajuste al Coach',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.3),
                  ),
                ),
              ),
              if (_lastAdjustmentResponse.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildCoachResponseBubble(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

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
              color: AppColors.surface2Of(context),
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
            color: AppColors.surface2Of(context),
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
              color: AppColors.surface2Of(context),
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
                      : AppColors.surface2Of(context),
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
                        : AppColors.surface2Of(context),
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
          color: AppColors.surface2Of(context),
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
                decoration: _inputDecoration(context, hint: placeholder).copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _buildMessageLimitIndicator(BuildContext context) {
    final remaining = _chatRemainingThisWeek;
    return Row(
      children: [
        Text(
          'Consultas de la semana:',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 10),
        Row(
          children: List.generate(3, (index) {
            final active = index < remaining;
            return Container(
              margin: const EdgeInsets.only(right: 6),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? AppColors.brand
                    : AppColors.borderOf(context),
              ),
            );
          }),
        ),
        const Spacer(),
        Text(
          '$remaining/3 restantes',
          style: TextStyle(
            color: remaining > 0 ? AppColors.brand : AppColors.textSecondary(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCoachResponseBubble(BuildContext context) {
    if (_lastAdjustmentResponse.isEmpty) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.brandSurface : const Color(0xFFF9F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.brandBorder : const Color(0xFFEADBFF),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.brand,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Respuesta del Coach IA',
                style: TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _lastAdjustmentResponse,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              height: 1.4,
              fontSize: 13.5,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
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
      fillColor: AppColors.surface2Of(context),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderOf(context),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary(context),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
