# NAVIGATION_ARCHITECTURE.md — Running Laps
> Mayo 2026 — Arquitectura de navegación global tras rediseño completo
 
---
 
## Principio fundamental
 
**Header (logo + avatar) y Footer (BottomNav 5 tabs) visibles en TODAS las pantallas excepto durante sesión activa.**
 
Implementado mediante tabs ocultos en MainShell — todas las pantallas secundarias están en el IndexedStack pero sin botón en el BottomNav.
 
---
 
## Tabs visibles (con botón en BottomNav)
 
| Índice | Pantalla | Botón |
|---|---|---|
| 0 | HomeView | Inicio |
| 1 | CalendarView | Calendario |
| 2 | AnalyticsHubScreen | Analytics |
| 3 | ProfileView | Perfil |
| 4 | HistoryScreen | Historial |
 
El FAB central (Entrenar) no tiene índice fijo — navega a índice 15.
 
---
 
## Tabs ocultos (sin botón en BottomNav)
 
| Índice | Pantalla | Accesible desde |
|---|---|---|
| 5 | TrainingDetailView | premium_training_card.dart |
| 6 | GroupsListScreen | ProfileView |
| 7 | GroupScreen | GroupsListScreen |
| 8 | AccountSettingsView | ProfileView |
| 9 | ZonesConfigScreen | ProfileView |
| 10 | HeartRateMonitorView | ProfileView + TrainingStartView |
| 11 | TemplatesListView | ProfileView + TrainingStartView |
| 12 | TemplateEditorView | TemplatesListView |
| 13 | AthleteSessionEditorView | CalendarView |
| 14 | AvatarCustomizerView | ProfileView |
| 15 | TrainingStartView | FAB central |
| 16 | PreExecutionScreen | CalendarView + HomeView |
 
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
MainShell.shellKey.currentState?.navigateTo(5, params: training);
MainShell.shellKey.currentState?.navigateTo(7, params: groupId);
MainShell.shellKey.currentState?.navigateTo(12, params: template); // null para nueva
 
// Volver a tab anterior o home
MainShell.shellKey.currentState?.navigateBack();
```
 
## Casos especiales
 
### Footer oculto en TrainingStartView y PreExecutionScreen
```dart
// En main_shell.dart
bottomNavigationBar: (_tabIndex == 15 || _tabIndex == 16)
    ? const SizedBox.shrink()
    : _NavBar(fabActive: _tabIndex == 15)
```
El footer se oculta en índice 15 (TrainingStartView) y 16 (PreExecutionScreen).
 
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