import 'package:running_laps/features/ai_coach/data/ai_coach_models.dart';

const String kAiCoachDefaultOpenRouterModel = '';
const String kAiCoachDefaultOpenRouterApiKey = '';
const bool kAiCoachForceFrontendTesting = false;

AiCoachProviderConfig defaultAiCoachProviderConfig() {
  return AiCoachProviderConfig(
    provider: 'openrouter',
    model: kAiCoachDefaultOpenRouterModel,
    apiKey: kAiCoachDefaultOpenRouterApiKey,
    weeklyPlanningEnabled: true,
    chatAdjustmentsEnabled: true,
  );
}
