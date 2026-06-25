class AiCoachModels {
  /// Decisión semanal — razonamiento complejo, contexto rico
  static const String decision = 'anthropic/claude-sonnet-4.5';

  /// Generador de sesión por prompt — JSON estructurado
  static const String promptGenerator = 'anthropic/claude-haiku-4.5';

  /// Chat de ajuste — clasificación de intents (rápido y barato)
  static const String chatClassify = 'anthropic/claude-haiku-4.5';

  /// Onboarding — interpretar respuestas libres del atleta
  static const String onboarding = 'anthropic/claude-haiku-4.5';

  AiCoachModels._();
}
