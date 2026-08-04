import 'dart:async';
import 'package:running_laps/core/widgets/duration_picker_field.dart';
import 'package:running_laps/core/services/user_service.dart';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/constants/legal_policy.dart';
import 'package:running_laps/core/services/health_consent_service.dart';
import 'package:running_laps/core/services/health_screening_service.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/app_date_picker.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/ai_coach/views/health_safety_form.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_models_config.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:running_laps/features/ai_coach/data/openrouter_client.dart';

class AiCoachOnboardingView extends StatefulWidget {
  final String uid;
  final VoidCallback onCompleted;

  const AiCoachOnboardingView({
    super.key,
    required this.uid,
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

  // Paso 5 — marcas personales (opcionales, en segundos totales)
  int? _pb5kSeconds;
  int? _pb10kSeconds;
  int? _pbHalfMarathonSeconds;
  int? _pbMarathonSeconds;

  // Paso 6 — datos físicos (opcionales)
  DateTime? _birthDate;
  String? _biologicalSex;

  // Paso 7 — cribado de seguridad + consentimiento de datos de salud.
  // Ninguna respuesta bloquea nada; el consentimiento sí, porque sin él no
  // podemos mandar molestias ni lesiones al proveedor de IA (art. 9 RGPD).
  final Map<HealthScreeningQuestion, bool> _screeningAnswers = {
    ...HealthScreening.allNegative,
  };
  bool _healthConsent = false;

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
    if (_currentStep < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: AppMotion.snap,
      );
      setState(() => _currentStep++);
    } else {
      _processOnboarding();
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

  Future<void> _processOnboarding() async {
    final allInputs = [
      _step1Controller.text,
      _step2Controller.text,
      _step3Controller.text,
      _step4Controller.text,
    ];
    final inputError = allInputs
        .map(_validateCoachText)
        .firstWhere((e) => e != null, orElse: () => null);
    if (inputError != null) {
      ModernSnackBar.showError(context, inputError);
      return;
    }

    if (!_healthConsent) {
      ModernSnackBar.showWarning(
        context,
        'Necesito tu permiso para usar tus datos de salud.',
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Antes de la primera llamada al LLM, no después: el paso 4 del wizard
      // es texto libre sobre lesiones y va dentro de ese prompt. Guardar el
      // consentimiento después dejaría el dato ya enviado sin base legal.
      await HealthScreeningService().save(_screeningAnswers);
      await HealthConsentService().grant(HealthConsentScope.aiCoach);

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
        model: AiCoachModels.onboarding,
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
        schemaName: 'onboarding_profile',
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'La conexión tardó demasiado. '
          'Comprueba tu conexión e inténtalo de nuevo.',
        ),
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
        pb5kSeconds: _pb5kSeconds,
        pb10kSeconds: _pb10kSeconds,
        pbHalfMarathonSeconds: _pbHalfMarathonSeconds,
        pbMarathonSeconds: _pbMarathonSeconds,
        createdAt: now,
        updatedAt: now,
      );

      await AiCoachRepository().saveProfile(profile);

      // Guardar fecha de nacimiento y sexo en users/{uid} para que
      // ZonesConfigScreen no vuelva a pedir estos datos tras el onboarding
      if (_birthDate != null || _biologicalSex != null) {
        final updates = <String, dynamic>{};
        if (_birthDate != null) {
          updates['birthDate'] =
              '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';
        }
        if (_biologicalSex != null) updates['sex'] = _biologicalSex;
        await UserService().updateProfileFields(widget.uid, updates);
      }

      if (!mounted) return;
      ModernSnackBar.showSuccess(
        context,
        '¡Perfil creado! Generando tu primer plan...',
      );
      widget.onCompleted();
      // Si el widget sigue montado tras onCompleted, forzar navegación limpia al root
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('[AiCoachOnboarding] _processOnboarding error: $e');
      if (!mounted) return;
      final msg = e is TimeoutException
          ? 'La conexión tardó demasiado. Comprueba tu conexión e inténtalo de nuevo.'
          : 'No se pudo crear el perfil. Comprueba tu conexión e inténtalo de nuevo.';
      ModernSnackBar.showError(context, msg);
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
          const CupertinoActivityIndicator(color: AppColors.brand, radius: 12),
          const SizedBox(height: 24),
          const Text(
            'Analizando tu perfil...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Esto puede tardar unos segundos',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () {
              setState(() {
                _isProcessing = false;
                _currentStep = 0;
              });
              _pageController.jumpToPage(0);
            },
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizard(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 24),
        _StepIndicator(currentStep: _currentStep, totalSteps: 7),
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
              _BirthDateStepPage(
                birthDate: _birthDate,
                sex: _biologicalSex,
                onBirthDateChanged: (d) => setState(() => _birthDate = d),
                onSexChanged: (s) => setState(() => _biologicalSex = s),
              ),
              _PbStepPage(
                isDark: isDark,
                pb5kSeconds: _pb5kSeconds,
                pb10kSeconds: _pb10kSeconds,
                pbHalfMarathonSeconds: _pbHalfMarathonSeconds,
                pbMarathonSeconds: _pbMarathonSeconds,
                onChanged5k: (v) => setState(() => _pb5kSeconds = v),
                onChanged10k: (v) => setState(() => _pb10kSeconds = v),
                onChangedHalf: (v) => setState(() => _pbHalfMarathonSeconds = v),
                onChangedMarathon: (v) => setState(() => _pbMarathonSeconds = v),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                child: HealthSafetyForm(
                  answers: _screeningAnswers,
                  consentGranted: _healthConsent,
                  onAnswerChanged: (q, v) =>
                      setState(() => _screeningAnswers[q] = v),
                  onConsentChanged: (v) => setState(() => _healthConsent = v),
                ),
              ),
            ],
          ),
        ),
        if (_currentStep == 6)
          _CreatePlanButton(
            onCreate: _processOnboarding,
            enabled: _healthConsent,
          )
        else
          _NextButton(
            isLastStep: false,
            controller: _controllerForStep(_currentStep),
            // A partir del paso 3 todo es opcional (notas, datos físicos,
            // marcas): esos pasos no tienen un campo de texto que exigir, y
            // el controller que les toca por defecto suele venir vacío.
            isOptional: _currentStep >= 3,
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
      'goal': {
        'type': 'string',
        'enum': [
          'race_5k', 'race_10k', 'race_half_marathon',
          'race_marathon', 'improve_pace',
          'improve_endurance', 'return_to_running',
        ],
        'description': 'Objetivo principal del atleta '
            'como valor del enum. Elige el más cercano '
            'a lo que describe el usuario.',
      },
      'goalDescription': {
        'type': 'string',
        'description': 'Resumen en texto libre de lo que '
            'el atleta quiere conseguir, tal como lo ha '
            'expresado. Ejemplo: "Quiero bajar de 25 min '
            'en 5K antes de verano". NO pongas aquí el '
            'valor del enum — eso va en el campo goal.',
      },
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
  final int totalSteps;

  const _StepIndicator({required this.currentStep, this.totalSteps = 4});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
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
  final int maxLength;

  const _StepPage({
    required this.question,
    required this.hint,
    required this.controller,
    required this.isDark,
    this.optional = false,
    this.maxLength = 500,
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
              fontWeight: FontWeight.w600,
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
              maxLength: maxLength,
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PbStepPage — paso 5 (opcional): marcas personales
// ─────────────────────────────────────────────────────────────────────────────

class _PbStepPage extends StatelessWidget {
  final bool isDark;
  final int? pb5kSeconds;
  final int? pb10kSeconds;
  final int? pbHalfMarathonSeconds;
  final int? pbMarathonSeconds;
  final ValueChanged<int?> onChanged5k;
  final ValueChanged<int?> onChanged10k;
  final ValueChanged<int?> onChangedHalf;
  final ValueChanged<int?> onChangedMarathon;

  const _PbStepPage({
    required this.isDark,
    required this.pb5kSeconds,
    required this.pb10kSeconds,
    required this.pbHalfMarathonSeconds,
    required this.pbMarathonSeconds,
    required this.onChanged5k,
    required this.onChanged10k,
    required this.onChangedHalf,
    required this.onChangedMarathon,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Tienes marcas personales?\nSon opcionales, pero me ayudan\na calibrar mejor tu ritmo.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si no las tienes o no quieres añadirlas, pulsa "Crear mi plan".',
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 32),
          DurationPickerField(
            label: '5K',
            valueSeconds: pb5kSeconds,
            onChanged: onChanged5k,
          ),
          const SizedBox(height: 16),
          DurationPickerField(
            label: '10K',
            valueSeconds: pb10kSeconds,
            onChanged: onChanged10k,
          ),
          const SizedBox(height: 16),
          DurationPickerField(
            label: 'Media maratón',
            valueSeconds: pbHalfMarathonSeconds,
            onChanged: onChangedHalf,
          ),
          const SizedBox(height: 16),
          DurationPickerField(
            label: 'Maratón',
            valueSeconds: pbMarathonSeconds,
            onChanged: onChangedMarathon,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BirthDateStepPage — paso 6 (opcional): fecha de nacimiento + sexo biológico
// ─────────────────────────────────────────────────────────────────────────────

class _BirthDateStepPage extends StatelessWidget {
  final DateTime? birthDate;
  final String? sex;
  final ValueChanged<DateTime?> onBirthDateChanged;
  final ValueChanged<String?> onSexChanged;

  const _BirthDateStepPage({
    required this.birthDate,
    required this.sex,
    required this.onBirthDateChanged,
    required this.onSexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Un par de datos más\npara personalizar\ntu plan.',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Con tu edad estimamos tu FCmáx y ajustamos '
            'las zonas de entrenamiento. Puedes omitirlo.',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: AppSpacing.xl),
          GestureDetector(
            onTap: () async {
              final picked = await showAppDatePicker(
                context: context,
                title: 'Fecha de nacimiento',
                initialDate: birthDate ?? DateTime(DateTime.now().year - 30),
                minimumDate: DateTime(1940),
                // La rueda no llega a una edad por debajo del mínimo de los
                // términos en vez de aceptar la fecha y rechazarla después:
                // no tiene sentido recoger datos de salud de alguien que no
                // puede tener cuenta. Antes permitía declararse de 10 años.
                maximumDate: LegalPolicy.latestAllowedBirthDate(),
              );
              if (picked != null) onBirthDateChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined,
                      color: AppColors.textSecondary(context)),
                  const SizedBox(width: 12),
                  Text(
                    birthDate != null
                        ? '${birthDate!.day}/${birthDate!.month}/${birthDate!.year}'
                        : 'Fecha de nacimiento',
                    style: TextStyle(
                      color: birthDate != null
                          ? null
                          : AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'Sexo biológico (opcional)',
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              for (final option in [
                ('male', 'Hombre'),
                ('female', 'Mujer'),
                ('other', 'Otro'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: () => onSexChanged(option.$1),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: sex == option.$1
                            ? AppColors.brand.withValues(alpha: 0.1)
                            : null,
                        side: BorderSide(
                          color: sex == option.$1
                              ? AppColors.brand
                              : AppColors.borderOf(context),
                        ),
                      ),
                      child: Text(option.$2),
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

class _CreatePlanButton extends StatelessWidget {
  final VoidCallback onCreate;

  /// Sin el consentimiento de datos de salud no hay plan: el onboarding manda
  /// lesiones y molestias en texto libre al proveedor de IA.
  final bool enabled;

  const _CreatePlanButton({required this.onCreate, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onCreate : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.3),
            disabledForegroundColor: Colors.white70,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Crear mi plan →',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
