import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/openrouter_client.dart';

class AiCoachOnboardingView extends StatefulWidget {
  final String uid;
  final String apiKey;
  final String model;
  final VoidCallback onCompleted;

  const AiCoachOnboardingView({
    super.key,
    required this.uid,
    required this.apiKey,
    required this.model,
    required this.onCompleted,
  });

  @override
  State<AiCoachOnboardingView> createState() => _AiCoachOnboardingViewState();
}

class _AiCoachOnboardingViewState extends State<AiCoachOnboardingView> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isProcessing = false;

  final TextEditingController _step1Controller = TextEditingController();
  final TextEditingController _step2Controller = TextEditingController();
  final TextEditingController _step3Controller = TextEditingController();
  final TextEditingController _step4Controller = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _step1Controller.dispose();
    _step2Controller.dispose();
    _step3Controller.dispose();
    _step4Controller.dispose();
    super.dispose();
  }

  TextEditingController _controllerForStep(int step) {
    switch (step) {
      case 0:
        return _step1Controller;
      case 1:
        return _step2Controller;
      case 2:
        return _step3Controller;
      default:
        return _step4Controller;
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _processOnboarding();
    }
  }

  Future<void> _processOnboarding() async {
    setState(() => _isProcessing = true);

    try {
      final client = OpenRouterClient();
      final userPrompt =
          'Extrae la información de este runner y devuelve un JSON con esta estructura exacta:\n'
          '{\n'
          '  "goal": "race_5k|race_10k|race_half_marathon|race_marathon|improve_pace|improve_endurance|return_to_running",\n'
          '  "goalDescription": "descripción libre del objetivo",\n'
          '  "level": "beginner|intermediate|advanced",\n'
          '  "availableWeekdays": [1,2,3,4,5,6,7],\n'
          '  "preferredWeeklySessions": 3,\n'
          '  "preferredLongRunWeekday": 6,\n'
          '  "coachNotes": "restricciones, lesiones, preferencias"\n'
          '}\n\n'
          'Información del runner:\n'
          'Nivel y experiencia: ${_step1Controller.text}\n'
          'Objetivo: ${_step2Controller.text}\n'
          'Disponibilidad: ${_step3Controller.text}\n'
          'Restricciones y notas: ${_step4Controller.text}\n\n'
          'Reglas:\n'
          '- availableWeekdays: lista de enteros 1=lunes a 7=domingo\n'
          '- preferredWeeklySessions: entre 2 y 6\n'
          '- preferredLongRunWeekday: el día de la semana más largo (1-7), null si no se menciona\n'
          '- Si no se menciona algún campo, usa el valor más razonable\n'
          '- goal debe ser uno de los valores exactos indicados\n'
          '- level debe ser uno de los valores exactos indicados';

      final result = await client.createJsonCompletion(
        apiKey: widget.apiKey,
        model: widget.model,
        messages: [
          const OpenRouterChatMessage(
            role: 'system',
            content:
                'Eres un asistente que extrae información estructurada de '
                'descripciones en lenguaje natural de runners. '
                'Responde ÚNICAMENTE con un JSON válido, sin texto adicional, '
                'sin markdown, sin explicaciones.',
          ),
          OpenRouterChatMessage(role: 'user', content: userPrompt),
        ],
        jsonSchema: _profileExtractionSchema,
        temperature: 0.2,
      );

      final raw = jsonDecode(result.content) as Map<String, dynamic>;
      final now = DateTime.now();

      final weekdays = (raw['availableWeekdays'] as List<dynamic>?)
              ?.whereType<int>()
              .where((d) => d >= 1 && d <= 7)
              .toList() ??
          [1, 3, 5];

      final sessions =
          ((raw['preferredWeeklySessions'] as num?)?.toInt() ?? 3).clamp(2, 6);

      final longRunRaw = raw['preferredLongRunWeekday'];
      final longRunWeekday =
          longRunRaw is int && longRunRaw >= 1 && longRunRaw <= 7
              ? longRunRaw
              : null;

      final profile = AiCoachProfile(
        uid: widget.uid,
        goal: AiCoachGoalTypeX.fromValue(raw['goal'] as String? ?? ''),
        goalDescription: raw['goalDescription'] as String? ?? '',
        level:
            AiCoachAthleteLevelX.fromValue(raw['level'] as String? ?? ''),
        availableWeekdays: weekdays..sort(),
        preferredWeeklySessions: sessions,
        preferredLongRunWeekday: longRunWeekday,
        coachNotes: (raw['coachNotes'] as String?)?.trim().isEmpty ?? true
            ? null
            : raw['coachNotes'] as String?,
        createdAt: now,
        updatedAt: now,
      );

      await AiCoachRepository().saveProfile(profile);

      if (!mounted) return;
      ModernSnackBar.showSuccess(
        context,
        '¡Perfil creado! Generando tu primer plan...',
      );
      widget.onCompleted();
    } catch (e) {
      debugPrint('[AiCoachOnboarding] _processOnboarding error: $e');
      if (!mounted) return;
      ModernSnackBar.showError(
        context,
        'No se pudo crear el perfil. ${e.toString().replaceFirst('Exception: ', '')}',
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _isProcessing ? _buildProcessing() : _buildWizard(isDark),
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.brand),
          const SizedBox(height: 24),
          const Text(
            'Analizando tu perfil...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Preparando tu plan personalizado',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildWizard(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 24),
        _StepIndicator(currentStep: _currentStep),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentStep = i),
            children: [
              _StepPage(
                question:
                    'Hola, soy tu entrenador IA. Para empezar,\n¿cómo describirías tu nivel como runner?',
                hint:
                    'Ej: Llevo 2 años corriendo, hago unos 30km semanales, nunca he competido pero me gustaría hacer mi primera 10K...',
                controller: _step1Controller,
                isDark: isDark,
              ),
              _StepPage(
                question:
                    '¿Qué quieres conseguir? Cuéntamelo\ncon tus palabras, sin prisas.',
                hint:
                    'Ej: Quiero bajar de 50 minutos en 10K antes de verano, o simplemente mejorar mi resistencia y sentirme mejor...',
                controller: _step2Controller,
                isDark: isDark,
              ),
              _StepPage(
                question:
                    '¿Cuándo puedes entrenar?\nDime los días y cuánto tiempo tienes.',
                hint:
                    'Ej: Martes y jueves por las mañanas tengo 1 hora, los sábados puedo hacer una tirada más larga de 1.5-2h...',
                controller: _step3Controller,
                isDark: isDark,
              ),
              _StepPage(
                question:
                    '¿Hay algo más que quieras contarme?\nLesiones pasadas, limitaciones, preferencias...',
                hint:
                    'Ej: Tuve una tendinitis en el talón hace un año, prefiero no entrenar los lunes porque trabajo hasta tarde...\n(Puedes dejarlo en blanco si no hay nada)',
                controller: _step4Controller,
                isDark: isDark,
                optional: true,
              ),
            ],
          ),
        ),
        _NextButton(
          isLastStep: _currentStep == 3,
          controller: _controllerForStep(_currentStep),
          isOptional: _currentStep == 3,
          onNext: _nextStep,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static const Map<String, dynamic> _profileExtractionSchema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'goal',
      'goalDescription',
      'level',
      'availableWeekdays',
      'preferredWeeklySessions',
      'preferredLongRunWeekday',
      'coachNotes',
    ],
    'properties': {
      'goal': {'type': 'string'},
      'goalDescription': {'type': 'string'},
      'level': {'type': 'string'},
      'availableWeekdays': {
        'type': 'array',
        'items': {'type': 'integer'},
      },
      'preferredWeeklySessions': {'type': 'integer'},
      'preferredLongRunWeekday': {
        'anyOf': [
          {'type': 'integer'},
          {'type': 'null'},
        ],
      },
      'coachNotes': {
        'anyOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      },
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// _StepIndicator
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i == currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.brand
                : AppColors.borderOf(context),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StepPage
// ─────────────────────────────────────────────────────────────────────────────

class _StepPage extends StatelessWidget {
  final String question;
  final String hint;
  final TextEditingController controller;
  final bool isDark;
  final bool optional;

  const _StepPage({
    required this.question,
    required this.hint,
    required this.controller,
    required this.isDark,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);
    final fieldBg =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: controller,
              minLines: 4,
              maxLines: 8,
              style: TextStyle(fontSize: 16, color: textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: textSecondary,
                  height: 1.5,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NextButton
// ─────────────────────────────────────────────────────────────────────────────

class _NextButton extends StatefulWidget {
  final bool isLastStep;
  final bool isOptional;
  final TextEditingController controller;
  final VoidCallback onNext;

  const _NextButton({
    required this.isLastStep,
    required this.isOptional,
    required this.controller,
    required this.onNext,
  });

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(_NextButton old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final enabled = widget.isOptional || hasText;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? widget.onNext : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.3),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            widget.isLastStep ? 'Crear mi plan →' : 'Siguiente →',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
