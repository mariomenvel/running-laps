import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_prompt_session_generator.dart';
import 'package:running_laps/features/ai_coach/data/ai_coach_repository.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AiCoachPromptView extends StatefulWidget {
  const AiCoachPromptView({super.key});

  @override
  State<AiCoachPromptView> createState() => _AiCoachPromptViewState();
}

class _AiCoachPromptViewState extends State<AiCoachPromptView> {
  final _controller = TextEditingController();
  final _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isGenerating = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speechToText.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
      return;
    }

    await _speechToText.listen(
      onResult: (result) {
        setState(() => _controller.text = result.recognizedWords);
        if (result.finalResult) {
          setState(() => _isListening = false);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'es_ES',
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    setState(() => _isListening = true);
  }

  Future<void> _generate() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    debugPrint('[Prompt] iniciando generación: ${_controller.text}');
    setState(() => _isGenerating = true);

    try {
      final providerConfig = await AiCoachRepository().getProviderConfig();
      if (!mounted) return;

      debugPrint('[Prompt] apiKey=${providerConfig?.apiKey?.substring(0, 8)}...');
      debugPrint('[Prompt] model=${providerConfig?.model}');

      if (providerConfig?.apiKey == null) {
        ModernSnackBar.showError(context, 'API key no configurada');
        return;
      }

      final profile = await AiCoachRepository().getProfile(uid: uid);
      if (!mounted) return;

      final session = await const AiCoachPromptSessionGenerator().generate(
        prompt: text,
        apiKey: providerConfig!.apiKey!,
        model: providerConfig.model,
        profile: profile,
      );

      debugPrint('[Prompt] resultado: ${session.title}');
      debugPrint('[Prompt] session obtenida: ${session.title}');
      debugPrint('[Prompt] abriendo dialog...');

      if (!mounted) return;

      final nav = Navigator.of(context);

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(session.title),
          content: Text(
            '${session.blocks.length} bloques · '
            '${session.blocks.fold(0, (sum, b) => sum + b.repetitions * b.segments.length)} segmentos',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cambiar'),
            ),
            FilledButton(
              onPressed: () {
                debugPrint('[Prompt] "Usar este plan" pulsado');
                Navigator.pop(context);
                debugPrint('[Prompt] dialog popped');
                nav.pop(session);
                debugPrint('[Prompt] nav popped con sesión');
              },
              child: const Text('Usar este plan'),
            ),
          ],
        ),
      );
      debugPrint('[Prompt] dialog cerrado');
    } catch (e) {
      if (!mounted) return;
      ModernSnackBar.showError(context, 'Error al generar: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Generar entrenamiento'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Describe tu entrenamiento',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Escribe o habla con naturalidad. '
                      'Tu coach lo convertirá en un plan.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface2Of(context),
                        borderRadius: BorderRadius.circular(20),
                        border: _isListening
                            ? Border.all(color: AppColors.brand, width: 2)
                            : null,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _controller,
                            maxLines: 6,
                            maxLength: 500,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText:
                                  'Ej: Quiero hacer una sesión de series '
                                  'cortas de 400m a ritmo 5K, con 90 '
                                  'segundos de descanso entre cada una...',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary(context),
                              ),
                              border: InputBorder.none,
                              counterStyle: TextStyle(
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),

                          if (_speechAvailable) ...[
                            const Divider(),
                            GestureDetector(
                              onTap:
                                  _isGenerating ? null : _toggleListening,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _isListening
                                      ? AppColors.brand.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: _isListening
                                        ? AppColors.brand
                                        : AppColors.borderOf(context),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isListening
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded,
                                      color: _isListening
                                          ? AppColors.brand
                                          : AppColors.textSecondary(context),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isListening
                                          ? 'Escuchando...'
                                          : 'Hablar',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _isListening
                                            ? AppColors.brand
                                            : AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'IDEAS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._examples.map(_buildExampleChip),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderOf(context).withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _isGenerating || _controller.text.trim().isEmpty
                          ? null
                          : _generate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isGenerating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Generando...'),
                          ],
                        )
                      : const Text(
                          'Generar entrenamiento',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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

  Widget _buildExampleChip(String text) => GestureDetector(
        onTap: () => setState(() => _controller.text = text),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface2Of(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      );

  static const _examples = [
    '5 series de 1km a ritmo de competición 10K con 2 minutos de descanso',
    'Rodaje suave de 45 minutos en zona 2',
    'Fartlek de 30 minutos alternando 1 min rápido y 2 min suave',
    'Entrenamiento de cuestas, 8 repeticiones subiendo fuerte',
  ];
}
