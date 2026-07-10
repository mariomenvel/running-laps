# NAVIGATION_ARCHITECTURE.md — Running Laps
> Mayo 2026 — Arquitectura de navegación global tras rediseño completo
 
---
 
## Principio fundamental
 
**Header (logo + avatar) y Footer (BottomNav 5 tabs) visibles en TODAS las pantallas excepto durante sesión activa.**
 
Implementado mediante tabs ocultos en MainShell — todas las pantallas secundarias están en el IndexedStack pero sin botón en el BottomNav.
 
---
 
## Tabs visibles (con botón en BottomNav)

BottomNav: **4 tabs + FAB central** (sin tab de Historial visible).

| Índice | Pantalla | Botón |
|---|---|---|
| 0 | HomeView | Inicio |
| 1 | CalendarView | Calendario |
| — | FAB | Entrenar → navega a índice 15 |
| 2 | AnalyticsHubScreen | Analytics |
| 3 | ProfileView | Perfil |
 
---
 
## Tabs ocultos (sin botón en BottomNav)

| Índice | Pantalla | Accesible desde | Params |
|---|---|---|---|
| 4 | HistoryScreen | — (sin acceso directo desde nav) | — |
| 5 | TrainingDetailView | `premium_training_card.dart` | `Entrenamiento` |
| 6 | GroupsListScreen | ProfileView | — |
| 7 | GroupScreen | GroupsListScreen | `String groupId` |
| 8 | AccountSettingsView | ProfileView | `Map<String, dynamic>` |
| 9 | ZonesConfigScreen | ProfileView | — |
| 10 | HeartRateMonitorView | ProfileView + TrainingStartView | — |
| 11 | TemplatesListView | ProfileView + TrainingStartView | — |
| 12 | TemplateEditorView | TemplatesListView | `TemplateEditorShellParams` |
| 13 | WorkoutEditorScreen | CalendarView | `AthleteSessionShellParams` |
| 14 | AvatarCustomizerView | ProfileView | `AvatarConfig?` |
| 15 | TrainingStartView | FAB central | — |
| 16 | AiCoachSettingsView | HomeView (modo atleta) | — |
 
---
 
## Pantallas fuera del MainShell (Navigator.push)
 
Estas pantallas NO tienen header ni footer — comportamiento intencional:
 
| Pantalla | Razón |
|---|---|
| TrainingSessionView | Sin distracciones durante sesión activa |
| TrainingSessionSummary | Flujo post-entreno sin navegación |
| SplashScreen | Pre-auth |
| AuthPage | Pre-auth |
 
---
 
## API de navegación
 
```dart
// Navegar a un tab (visible u oculto)
MainShell.shellKey.currentState?.navigateTo(int index);
 
// Navegar con parámetros (pantallas que necesitan datos)
MainShell.shellKey.currentState?.navigateTo(5, params: training);         // Entrenamiento
MainShell.shellKey.currentState?.navigateTo(7, params: groupId);           // String
MainShell.shellKey.currentState?.navigateTo(8, params: {'name': n, 'onUpdated': cb});
MainShell.shellKey.currentState?.navigateTo(12, params: TemplateEditorShellParams(...));
MainShell.shellKey.currentState?.navigateTo(13, params: AthleteSessionShellParams(...));
MainShell.shellKey.currentState?.navigateTo(14, params: avatarConfig);     // AvatarConfig?
 
// Volver a tab anterior o home
MainShell.shellKey.currentState?.navigateBack();
```
 
## Toggle modo atleta

El toggle bidireccional de desarrollo (icono `sync` en el header) fue **eliminado** (commit `e78dbdd`). Flujo actual:

- **Activar modo atleta:** tutorial de bienvenida post-registro (`welcome_view.dart`) o completando el onboarding del Coach IA.
- **Desactivar modo atleta:** Perfil → sección Cuenta → tile "Volver a modo recreativo" (solo visible si `isAthleteMode == true`). Requiere confirmación con `showAppConfirmDialog` destructivo.

---

## Dispatch de tap en tarjetas de sesión — Home y Calendario ✅ corregido

**Regla general:** un día/sesión ya **completado** nunca debe navegar al creador/editor de sesiones (tab 13). Antes había varios sitios donde tocar una sesión completada, o directamente no hacía nada, o mandaba por error a crear una sesión nueva.

- **`calendar_view.dart` → `_buildWeekDayCard` (vista semanal en lista):** `onDayTap()` ahora distingue explícitamente: sesión planificada (acciones en línea, ver abajo) → sesión completada (`openCompletedTraining()`, navega a `TrainingDetailView` vía `completedTrainingId`, tab 5) → día vacío (crear sesión). Si solo quedan sesiones `skipped`, no navega a ningún sitio.
- **`calendar_view.dart` → acciones en línea (sin sheet):** cada sesión de la vista semanal muestra su fila de iconos **en la misma línea horizontal que el título** (eliminar / editar / completar manualmente / empezar, o "Ver detalle" si está completada) — se eliminó `_showDaySessionsSheet` por completo, ya no hay bottom sheet intermedio para sesiones planificadas.
- **`home_view.dart` → card "SESIÓN DE HOY" (completada):** ahora tappable, navega a `TrainingDetailView` igual que el calendario.
- **`home_view.dart` → "Últimos entrenamientos":** cada fila tappable → `TrainingDetailView` directo (ya se tiene el `Entrenamiento` completo en memoria, sin fetch).
- **`home_view.dart` → "Próximos entrenamientos":** cada fila tappable → editor de sesión (tab 13, `AthleteSessionShellParams`).

---

## Casos especiales
 
### BottomNav visible en TrainingStartView (jul 2026)
```dart
// En main_shell.dart — la barra NO se oculta en el tab 15
bottomNavigationBar: _NavBar(fabActive: _tabIndex == 15)
```
Antes el footer se ocultaba en TrainingStartView, pero al ser una pestaña del
IndexedStack (sin ruta que hacer pop ni gesto de volver) el usuario quedaba
atrapado sin ninguna forma de salir. La barra permanece visible con el FAB en
estado activo.

### Quick-start desde el FAB (jul 2026)
FAB → tab 15 (`TrainingStartView`) → elegir tipo → `WorkoutEditorScreen`
(`isQuickStart: true`) → "Empezar entrenamiento" → el callback `onSave` empuja
`PreExecutionScreen(session)` → EMPEZAR → `WorkoutExecutionScreen` →
`TrainingSummaryScreen` (guarda el entrenamiento y navega al historial).
Antes el `onSave` era un TODO con debugPrint: la sesión generada no se
ejecutaba ni se guardaba.
 
### Pantallas con parámetros
Las pantallas que necesitan datos del tab anterior reciben params via `_shellParams`:
```dart
void navigateTo(int index, {dynamic params}) {
  setState(() {
    _shellParams = params;
    _currentIndex = index;
  });
}
```
El IndexedStack construye el widget condicionalmente según `_shellParams`.
 
---
 
## Reglas para añadir nuevas pantallas
 
1. **¿Necesita header + footer?** → Tab oculto en MainShell
2. **¿Es un flujo sin retorno (sesión, onboarding)?** → Navigator.push
3. **¿Necesita parámetros?** → Usar `navigateTo(index, params: datos)`
4. **¿Tiene botón en BottomNav?** → Solo si es un tab principal (máx 5)
5. **NUNCA** usar Navigator.push para pantallas que necesiten header/footer
---
 
## Back navigation
 
Cada pantalla secundaria tiene su propio back button que llama:
```dart
MainShell.shellKey.currentState?.navigateTo(tabAnterior);
```
 
No usar `Navigator.pop()` en tabs ocultos — no tiene efecto en IndexedStack.