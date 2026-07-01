# Arquitectura de Monetización — Running Laps

> Estado: DISEÑO. No implementado. Durante la beta
> todo es gratuito. Este documento es la guía para
> cuando se integre Stripe.

## Los tres niveles de acceso

### Nivel 1 — Recreativo (`isAthleteMode: false`)
Corre por diversión. Registra entrenamientos, ve
historial, récords, analytics básicos, grupos.
No ve calendario ni planificación.

### Nivel 2 — Atleta (`isAthleteMode: true`, gratis)
Se autoplanifica. Calendario, crea sus propias
sesiones manualmente, plantillas, zonas, seguimiento
planificado vs ejecutado. GRATIS para siempre.
Es el atleta que se programa solo.

### Nivel 3 — Atleta + Coach IA (de pago, Stripe)
Todo lo del nivel 2, más: generación automática del
plan semanal, chat con el coach, ajustes inteligentes,
ATL/CTL/TSB avanzado, test de umbral individualizado.
DE PAGO vía Stripe.

## Separación conceptual crítica

isAthleteMode y el coach premium son DOS COSAS
DISTINTAS. Un usuario puede estar en modo atleta
(nivel 2) sin pagar — simplemente se planifica solo.
El plan premium desbloquea el ENTRENADOR IA, no el
modo atleta.

El calendario y la planificación manual NUNCA deben
depender del acceso premium. Solo dependen de
isAthleteMode.

## Campos de Firestore

### users/{uid}
| Campo | Tipo | Controla |
|-------|------|----------|
| isAthleteMode | bool | Nivel 2 — modo atleta (gratis) |
| hasPremiumCoach | bool | Nivel 3 — coach IA (Stripe). Default false. Lo escribe el webhook de Stripe. |

### appConfig/global (doc de config global)
| Campo | Tipo | Controla |
|-------|------|----------|
| betaFreeAccess | bool | Durante beta: true → todos tienen coach gratis sin tocar hasPremiumCoach por usuario. El día del lanzamiento: false → se activa el gate real. |

### users/{uid}/settings/providerConfig (ya existe)
| Campo | Controla |
|-------|----------|
| weeklyPlanningEnabled | Kill-switch global del coach (por si falla OpenRouter) |
| provider | Debe ser 'openrouter' |
| apiKey | No vacío |

## Servicio centralizado a crear: AiCoachAccessService

Lógica pura (sin dependencias externas, como
ZonesService). Dos métodos:

```dart
class AiCoachAccessService {
  /// Nivel 2 — modo atleta gratis
  static bool canUseAthleteMode({
    required bool isAthleteMode,
  }) => isAthleteMode;

  /// Nivel 3 — coach IA premium
  static bool canUseCoach({
    required bool isAthleteMode,
    required bool weeklyPlanningEnabled,
    required String provider,
    required String apiKey,
    required bool hasPremiumCoach,
    required bool betaFreeAccess,
  }) {
    final userHasAccess = isAthleteMode &&
        (betaFreeAccess || hasPremiumCoach);
    final serverReady = weeklyPlanningEnabled &&
        provider == 'openrouter' &&
        apiKey.isNotEmpty;
    return userHasAccess && serverReady;
  }
}
```

## Gates a migrar (cuando se implemente)

Estos gates hoy comprueban campos sueltos.
Deben migrar a AiCoachAccessService:

| Archivo | Gate actual | Nuevo método |
|---------|-------------|--------------|
| calendar_view_model.dart:99,106,121 | isAthleteMode | canUseAthleteMode |
| ai_coach_chat_service.dart:49 | isAthleteMode | canUseCoach |
| ai_coach_weekly_planner_service.dart:50 | isAthleteMode | canUseCoach |
| ai_coach_automation_service.dart:155,174 | isAthleteMode + weeklyPlanningEnabled | canUseCoach |
| ai_coach_settings_view.dart:72 | isAthleteMode | canUseCoach |
| athlete_hub_view.dart:933 | weeklyPlanningEnabled + provider + apiKey | canUseCoach |
| ai_coach_onboarding_launcher.dart:25 | weeklyPlanningEnabled | canUseCoach |
| ai_coach_decision_service.dart:29 | weeklyPlanningEnabled + provider | canUseCoach |

IMPORTANTE: calendar_view_model usa canUseAthleteMode
(NO canUseCoach) — el calendario es gratis y no debe
bloquearse nunca por premium.

## Integración Stripe (Fase 2, futuro)

El cliente NUNCA habla con Stripe para validar acceso.
Solo lee users/{uid}.hasPremiumCoach (bool).

Flujo:
```
Cliente Flutter → lee hasPremiumCoach (bool)
                  nunca calcula fechas ni valida trials
Stripe → webhook → Cloud Function → escribe hasPremiumCoach
  checkout.session.completed      → true
  customer.subscription.deleted   → false
  invoice.payment_failed          → false (tras reintentos)
```

Stripe gestiona el trial de 30 días nativamente.
El cliente no calcula fechas de expiración.

Componentes a construir en Fase 2:
1. Cloud Function con webhook de Stripe (verificar firma)
2. Paywall UI (pantalla de suscripción)
3. Cambiar betaFreeAccess a false
4. CTA "Desbloquear Coach IA" en el sitio del actual
   botón de activar coach

## Toggle modo atleta (cambio de UX pendiente)

El toggle bidireccional del header (icono sync) era
para pruebas de desarrollo. Para usuario real:
- Mover a Perfil → Ajustes con showAppConfirmDialog
- Desactivar modo atleta → confirmación "¿Seguro?
  Perderás acceso a tu plan y coach IA"
- El botón "PASAR A MODO ATLETA" (modo recreativo)
  es el CTA correcto para el futuro paywall
