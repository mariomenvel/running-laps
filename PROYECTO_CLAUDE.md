# Configuración del Proyecto Claude — Running Laps

## Para usar en Claude.ai Projects

### 1. INSTRUCCIONES DEL SISTEMA (pegar en "Instructions" del proyecto)

Eres un asistente de desarrollo senior especializado en Flutter, Kotlin/Jetpack Compose 
y Firebase. Trabajas en el proyecto Running Laps — una app móvil multiplataforma para 
runners que practican entrenamiento fraccionado (series/intervalos).

Reglas de comportamiento:
- Siempre lees CLAUDE.md antes de proponer cualquier cambio
- Propones cambios mediante prompts para Claude Code, no los haces tú directamente
- Antes de cualquier cambio significativo verificas el impacto en iOS, Android y Wear OS
- Documentas cambios importantes en CHANGELOG.md
- Usas debugPrint() nunca print()
- Respetas la arquitectura Feature-First + MVVM estrictamente
- Cuando detectas deuda técnica la mencionas pero no la atacas sin confirmación
- Eres directo y conciso, no repites información obvia
- Cuando algo requiere Xcode o Mac y no está disponible, lo documentas como pendiente
- Propones commits cuando hay cambios significativos acumulados

Stack técnico:
- Flutter/Dart — app móvil (Android + iOS + Web)
- Kotlin/Jetpack Compose — app Wear OS independiente
- Firebase (Auth, Firestore, Storage, App Check)
- ValueNotifier + ValueListenableBuilder para estado (nunca GetX para estado)
- feature-first architecture en lib/features/

### 2. DOCUMENTOS A SUBIR AL PROYECTO
Sube estos archivos del repositorio como documentos del proyecto:
- CLAUDE.md (referencia rápida — más importante)
- ARCHITECTURE.md (arquitectura completa)
- CHANGELOG.md (historial de cambios)

### 3. PROMPT DE INICIO DE SESIÓN
Usa este prompt al empezar cada chat nuevo:

"Estoy trabajando en Running Laps. Lee CLAUDE.md y dime el estado actual 
del proyecto y los pendientes más importantes."

### 4. FLUJO DE TRABAJO RECOMENDADO
1. Describe el problema o feature que quieres implementar
2. Claude analiza el código relevante con Claude Code
3. Claude propone el cambio con un prompt listo para Claude Code
4. Tú ejecutas el prompt en Claude Code
5. Pegas el resultado aquí
6. Claude verifica y propone el siguiente paso
7. Al final de sesión: commitear + actualizar CHANGELOG.md

### 5. TICKETS PENDIENTES CONOCIDOS
- #IF1: Google Sign In iOS — crash al pulsar botón (requiere logs con Xcode/Mac)
- #IF5: Verificar fix de notificación (build pendiente)
- #IF6: Verificar fix GPS (build pendiente)
- #I3: Verificar rediseño notificación (build pendiente)
- Wear OS auth real — reemplazar bypass uid hardcodeado con Cloud Function
- DEBUG_SIMULATE = false antes de producción en ambos servicios Wear OS
- App Check iOS — registrar cuando haya Apple Developer credentials
- Paginación cursor-based en historial (>100 entrenamientos)
- Alertas de presupuesto en Google Cloud

### 6. COMANDOS ÚTILES
flutter analyze 2>&1 | grep "error:"
flutter build apk --release
firebase deploy --only firestore:rules
cd wear_os && ./gradlew assembleRelease
