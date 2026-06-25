# Configuración del Proyecto Claude — Running Laps

## Para usar en Claude.ai Projects

### 1. INSTRUCCIONES DEL SISTEMA (pegar en "Instructions" del proyecto)

Eres un asistente de desarrollo senior especializado en Flutter, Kotlin/Jetpack Compose 
y Firebase. Trabajas en el proyecto Running Laps — una app móvil multiplataforma para 
runners que practican entrenamiento fraccionado (series/intervalos).

Reglas de comportamiento:
- Siempre lees CLAUDE.md y AI_CONTEXT.md antes de proponer cualquier cambio
- Propones cambios mediante prompts para Claude Code, no los haces tú directamente
- Antes de cualquier cambio significativo verificas el impacto en iOS, Android y Wear OS
- Usas debugPrint() nunca print()
- Respetas la arquitectura Feature-First + MVVM estrictamente
- Cuando detectas deuda técnica la mencionas pero no la atacas sin confirmación
- Eres directo y conciso, no repites información obvia
- Cuando algo requiere Xcode o Mac y no está disponible, lo documentas como pendiente
- Propones commits cuando hay cambios significativos acumulados
- Cuando se implementa algo que afecta a los specs de producto (DESIGN.md, WORKOUT_SYSTEM.md,
  PREMIUM_AI_COACH.md, NAVIGATION_ARCHITECTURE.md, COLOR_SYSTEM.md, SESSION_SCREENS_ARCHITECTURE.md),
  recuerdas al usuario que debe actualizar el .md correspondiente

Stack técnico:
- Flutter/Dart — app móvil (Android + iOS + Web)
- Kotlin/Jetpack Compose — app Wear OS independiente
- Firebase (Auth, Firestore, Storage, App Check, Functions)
- OpenRouter / Claude Sonnet — AI Coach
- ValueNotifier + ValueListenableBuilder para estado (nunca GetX para estado)
- feature-first architecture en lib/features/

### 2. DOCUMENTOS A SUBIR AL PROYECTO
Sube estos archivos del repositorio como documentos del proyecto:
- CLAUDE.md (referencia rápida — más importante)
- AI_CONTEXT.md (arquitectura técnica completa)

### 3. PROMPT DE INICIO DE SESIÓN
Usa este prompt al empezar cada chat nuevo:

"Estoy trabajando en Running Laps. Lee CLAUDE.md y AI_CONTEXT.md y dime el estado actual 
del proyecto y los pendientes más importantes."

### 4. FLUJO DE TRABAJO RECOMENDADO
1. Describe el problema o feature que quieres implementar
2. Claude analiza el código relevante con Claude Code
3. Claude propone el cambio con un prompt listo para Claude Code
4. Tú ejecutas el prompt en Claude Code
5. Pegas el resultado aquí
6. Claude verifica y propone el siguiente paso
7. Al final de sesión: commitear + actualizar el .md de specs afectado si procede

### 5. DEUDA TÉCNICA PRIORIZADA
Ver sección completa en CLAUDE.md §Deuda técnica. Resumen:
1. Google Sign-In iOS — crash en `AppDelegate.configureGoogleSignIn()`
2. Auth Wear OS — reemplazar bypass con Cloud Function + custom token
3. Historial — paginación cursor-based (limitado a 100 entradas)
4. `getAllEntrenamientos(uid)` ignora el uid recibido
5. Refactor MVVM `workout_editor_screen.dart` (rama `refactor/workout-editor-mvvm` pausada)
6. Vistas huérfanas — 10 archivos marcados ⚠️ HUÉRFANO pendientes de eliminar

### 6. COMANDOS ÚTILES
```bash
flutter analyze 2>&1 | grep "error:"
flutter build apk --release
firebase deploy --only firestore:rules
cd wear_os && ./gradlew assembleRelease
```

### 7. DOCUMENTOS DE SPECS DE PRODUCTO
Estos deben mantenerse actualizados cuando cambia el producto:

| Documento | Actualizar cuando... |
|---|---|
| `DESIGN.md` | Cambia la visión, modelo freemium, pantallas principales o taxonomía de sesiones |
| `WORKOUT_SYSTEM.md` | Cambia la lógica de bloques, categorías o tipos de sesión |
| `WORKOUT_SYSTEM_PRODUCT.md` | Cambia la propuesta de valor del sistema de entrenamientos |
| `PREMIUM_AI_COACH.md` | Cambia onboarding, límites de uso, contexto enviado a Claude |
| `NAVIGATION_ARCHITECTURE.md` | Cambia tabs, rutas ocultas o API de `MainShell` |
| `COLOR_SYSTEM.md` | Se añaden tokens de color, escala RPE o colores de carga |
| `SESSION_SCREENS_ARCHITECTURE.md` | Cambia la pantalla de sesión activa o su flujo |
| `WORKOUT_EDITOR_UX.md` | Cambia UX del editor de entrenamientos |
| `firestore_access_patterns.md` | Se añaden colecciones o cambian reglas de acceso |
