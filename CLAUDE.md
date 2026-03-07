# CLAUDE.md — Running Laps

> Guía de referencia rápida para Claude Code. Lee esto antes de tocar cualquier archivo.

## Identidad del proyecto

**Running Laps** — App Flutter multiplataforma para runners que practican entrenamiento fraccionado (series/intervalos). Enfoque diferencial: RPE (Rate of Perceived Exertion) + tracking GPS por serie individual.

- Nombre paquete: `running_laps`
- Versión: 1.0.0+1 | SDK: `^3.9.2`
- Branch principal: `main` | Branch activo en desarrollo: `login`

---

## Arquitectura: Feature-First + MVVM

```
lib/
├── config/app_theme.dart       ← Tema global. Clase Tema + AvatarHelper
├── core/                       ← Transversal (services, widgets, utils)
├── features/                   ← Módulos funcionales (ver lista abajo)
├── firebase_options.dart
└── main.dart                   ← AuthWrapper → HomeView o AuthPage
```

**Reglas estrictas:**
- `views/` → solo UI, sin lógica de negocio
- `viewmodels/` → DEBE usar `ValueNotifier` / `ValueListenableBuilder`. NUNCA GetX para estado
- `data/` → repositorios + modelos (fuente de verdad)
- GetX solo para navegación/utilidades si se usa

---

## Features implementadas

| Feature | Carpeta | Descripción |
|---------|---------|-------------|
| Auth | `features/auth/` | Login email/pass + Google, registro, verificación email, recuperar contraseña |
| Training | `features/training/` | Sesión de entrenamiento, GPS por serie, tags |
| History | `features/history/` | Historial completo, filtros, calendario, mapa GPS, exportar PDF |
| Home | `features/home/` | Dashboard configurable con widgets arrastrables |
| Profile | `features/profile/` | Menú perfil, foto/avatar, configuración cuenta |
| Analytics | `features/analytics/` | Hub avanzado: overview, trends, distribution, patterns, coach insights |
| Groups | `features/groups/` | Grupos sociales, desafíos, ranking, recompensas, invitaciones, auto-join |
| Templates | `features/templates/` | Plantillas de entrenamiento con bloques y alarmas de ritmo/tiempo |
| Avatar | `features/avatar/` | Constructor de avatares SVG por capas |
| Admin | `features/admin/` | Panel de administración (desafíos, dashboard) — solo admins |

---

## Servicios Core

| Servicio | Ruta | Función |
|----------|------|---------|
| `GPSService` | `core/services/gps_service.dart` | Tracking GPS: Haversine + KalmanFilter, ventana 5 puntos, descarta acc >20m |
| `SensorService` | `core/services/sensor_service.dart` | Pedómetro/pasos (pedometer) |
| `PDFGeneratorService` | `core/services/pdf_generator_service.dart` | Generación y exportación de PDFs |
| `SettingsService` | `core/services/settings_service.dart` | Preferencias: `getAlarmEnabled()`, `getGpsDefault()` — usa SharedPreferences |
| `UserService` | `core/services/user_service.dart` | Gestión usuario: updateNombre, reauthenticate, updatePassword, deleteAccount, isGoogleUser |

---

## Theme y estilos

```dart
// lib/config/app_theme.dart
class Tema {
  static const Color brandPurple = Color(0xFF8E24AA);
}
class AvatarHelper {
  static Widget construirImagenPerfil({double radius = 24.0}) // Stream Firestore
  static Widget construirAvatar({...}) // Estático con config dada
}
```

⚠️ El archivo tema está en `lib/config/app_theme.dart`, NO en `lib/app/tema.dart`.

---

## Modelos clave

### Entrenamiento (`features/training/data/entrenamiento.dart`)
- `distanciaTotalM` → metros (int)
- `tiempoTotalSec` → segundos (double)
- `rpePromedio` → 1-10 (double)
- `ritmoMedioSecPorKm()` → calculado
- Debe tener ≥1 serie

### Serie (`features/training/data/serie.dart`)
- `tiempoSec`, `distanciaM`, `descansoSec`, `rpe`
- `usedGps`, `gpsPoints` → opcionales
- 0 metros = inválido (salvo drill estático)

### TemplateBlock (`features/templates/data/template_models.dart`)
- `type`: `distance` | `time`
- `value`: metros o segundos
- `alerts`: `TemplateAlerts` con modo `time` o `pace`

---

## Firebase / Firestore

**Colecciones:**
```
users/{uid}                          → perfil usuario
users/{uid}/entrenamientos/{id}      → entrenamientos
users/{uid}/tags/{id}               → etiquetas
groups/{groupId}                    → grupos
groups/{groupId}/challenges/{id}    → desafíos
```

**Auth:** Email/password + Google Sign-In.
Login requiere email verificado (usuarios email/pass).
Google users → `isGoogleUser()` en `UserService`.

---

## Autenticación — flujo actual (branch `login`)

1. `main.dart` → `AuthWrapper` → `StreamBuilder<User?>` decide `HomeView` o `AuthPage`
2. `AuthController` delega en `AuthRepository` (Firebase) y `UserService` (gestión de cuenta)
3. Email/pass: requiere verificación de email antes de entrar
4. Google: sin verificación
5. `signUp()`: valida min 8 chars + 1 mayúscula + 1 dígito
6. `AccountSettingsView` permite: cambiar nombre, cambiar contraseña, borrar cuenta, toggle ajustes (alarma/GPS default)

---

## Tracking — arquitectura nueva

```
core/tracking/
├── tracking_state.dart    → estados del tracking activo
├── tracking_types.dart    → tipos/enums
└── sensor_frame.dart      → frame de datos sensor (GPS + pedómetro combinados)

core/utils/
└── kalman_filter.dart     → filtro Kalman para suavizado GPS
```

`GpsStatus`: uninitialized → permissionDenied → disabled → ready → active → paused → error

---

## Admin

`features/admin/` — Solo accesible si `AuthController.isUserAdmin()` → `AuthRepository.isUserAdmin()`.
Tabs: `AdminDashboardTab`, `AdminChallengesTab`.
`AdminRepository` para operaciones de admin en Firestore.

---

## Convenciones de código

- Clases: `PascalCase` | Archivos: `snake_case` | Variables/métodos: `camelCase`
- Constantes: `lowerCamelCase`
- Imports: dart → flutter → firebase → paquetes → locales
- Siempre `if (!mounted) return;` tras awaits en widgets
- Snackbars: usar `ModernSnackBar.showSuccess/showError/showWarning(context, msg)`

---

## Commits recientes relevantes

- `79059ff` Keystore
- `95ed7f4` Mejoras visuales
- `488191e` Preferencias del usuario (`SettingsService`)
- `78563ed` Configuración de perfil valores predeterminados
- `ce14ac6` Configurar cuenta y borrar cuenta (`AccountSettingsView`)
- `32e1b9f` Login con Google (`signInWithGoogle`, `UserService.isGoogleUser`)

---

## Assets importantes

```
assets/images/logo.png     → logo app
assets/images/Icon.png     → icono login screen
assets/images/fondo.png    → fondo login screen
assets/avatar/**           → SVGs por categoría (body, eyes, hair/long, hair/short, etc.)
```
