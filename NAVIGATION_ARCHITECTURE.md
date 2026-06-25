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
 
## Casos especiales
 
### Footer oculto en TrainingStartView
```dart
// En main_shell.dart
bottomNavigationBar: _tabIndex == 15
    ? const SizedBox.shrink()
    : _NavBar(fabActive: _tabIndex == 15)
```
El footer se oculta durante TrainingStartView para no confundir al usuario antes de iniciar.
 
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