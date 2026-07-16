# 🏃‍♂️ Running Laps
> **"Para los que van en serio."**

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Wear OS](https://img.shields.io/badge/Wear%20OS-4285F4?style=for-the-badge&logo=wearos&logoColor=white)

**Running Laps** es una aplicación multiplataforma para corredores que practican entrenamiento fraccionado (series/intervalos). A diferencia de las apps convencionales, el foco está en el **RPE (Rate of Perceived Exertion)** por serie individual y en la **precisión del tracking GPS** en cada intervalo.

---

## 📱 Plataformas

| Plataforma | Estado | Notas |
|---|---|---|
| Android | ✅ Funciona | App Check Play Integrity |
| iOS | ⚠️ Parcial | Google Sign-In pendiente de diagnóstico |
| Web | ✅ Funciona | App Check reCAPTCHA v3 |
| Wear OS | ⚠️ En desarrollo | Auth temporal vía código de 6 dígitos |

---

## ✨ Características Principales

### 🎯 Entrenamientos por Series
- **Modo Series / Intervalos**: Crea sesiones complejas con bloques de trabajo y descanso configurables
- **RPE por serie**: Registro del esfuerzo percibido (escala 1–10) para cada intervalo
- **Plantillas**: Guarda y reutiliza sesiones completas con alarmas de ritmo por bloque
- **Tags personalizados**: Etiqueta y filtra tus entrenamientos

### 📍 GPS y Métricas
- **Tracking GPS por serie individual**: Cada serie tiene su propia traza y métricas
- **Filtro Kalman + Haversine**: Suavizado de coordenadas y cálculo de distancia preciso
- **Pace en tiempo real**: Ventana deslizante de 5 puntos para evitar lecturas erráticas
- **Historial completo**: Mapa GPS, desglose por serie, exportación a PDF

### ⌚ Wear OS
- **Entrenamiento independiente**: Sin necesidad del móvil
- **Soporte de plantillas**: Carga y ejecuta tus plantillas directamente desde el reloj
- **Alarmas de ritmo**: Feedback en tiempo real durante cada serie
- **Overlay de completado**: Animación al finalizar una plantilla completa

### 🔴 iOS — Live Activity
- **Lock Screen + Dynamic Island**: Información en tiempo real sin abrir la app
- **Fases**: serie activa → descanso con countdown → botón "Saltar"
- **Acciones desde la notificación**: Finalizar serie, saltar descanso

### 👥 Social y Competitivo
- **Grupos**: Crea o únete a grupos de corredores
- **Desafíos**: Retos de distancia, tiempo y RPE entre miembros
- **Rankings y recompensas**: Medallas, badges y clasificaciones
- **Invitaciones**: Códigos de acceso a grupos

### 🔐 Perfil y Seguridad
- **Auth robusta**: Email/contraseña y Google Sign-In
- **Avatar personalizable**: Constructor de avatares SVG por capas
- **Firebase App Check**: Protección contra acceso no autorizado en todas las plataformas

---

## 🛠️ Stack Tecnológico

| Capa | Tecnología |
|---|---|
| App móvil | Flutter / Dart (Android, iOS, Web) |
| App reloj | Kotlin / Jetpack Compose (Wear OS) |
| Base de datos | Firebase Firestore |
| Autenticación | Firebase Auth |
| Almacenamiento | Firebase Storage |
| Seguridad | Firebase App Check |
| Estado | `ValueNotifier` + `ValueListenableBuilder` |
| Arquitectura | Feature-First + MVVM |

---

## 📂 Estructura del Proyecto

```
lib/
├── main.dart                       ← Firebase init, App Check, ThemeService
├── config/app_theme.dart           ← Tema global, AvatarHelper (alias legado)
├── core/
│   ├── theme/                      ← AppColors (tokens), AppTheme, ThemeService
│   ├── services/                   ← GPS, Live Activity iOS, WearAuth, Settings, User,
│   │                                  HeartRate, Notifications, ZonesService
│   ├── tracking/                   ← TrackingState, tipos, SensorFrame
│   └── utils/                      ← KalmanFilter, EKF2D, RDP, TagUtils
└── features/
    ├── auth/                       ← Login, registro, verificación, recuperación
    ├── training/                   ← Sesión activa, GPS por serie, tags
    ├── history/                    ← Historial, filtros, mapa, PDF
    ├── home/                       ← Dashboard con widgets arrastrables
    ├── analytics/                  ← Estadísticas, trends, patterns, coach insights
    ├── groups/                     ← Grupos, desafíos, ranking, recompensas
    ├── templates/                  ← Plantillas con bloques y alarmas
    ├── avatar/                     ← Constructor SVG por capas
    ├── profile/                    ← Perfil, foto, configuración, zonas FC
    ├── admin/                      ← Panel admin (requiere isAdmin == true)
    ├── ai_coach/                   ← Coach IA: sugerencias semanales, memoria atleta
    ├── athlete/                    ← Perfil atleta avanzado, planificación
    └── calendar/                   ← Calendario de entrenamientos

wear_os/app/src/main/kotlin/com/runninglaps/wear/
├── MainActivity.kt
├── SeriesTrainingService.kt        ← Foreground service: timer, GPS, alarmas
├── TemplatePickerScreen.kt
└── TemplateModels.kt
```

Cada feature sigue la estructura:

```
features/{nombre}/
├── data/           ← Repositorios + modelos (fuente de verdad)
├── viewmodels/     ← ValueNotifier, lógica de presentación
└── views/          ← Widgets UI puros, sin lógica de negocio
```

---

## 🗺️ Roadmap — Módulo Atleta

El módulo atleta se construye en fases incrementales. Cada fase entrega algo coherente y testeable.

| Fase | Nombre | Plan | Estado |
|---|---|---|---|
| 0 | Preparación y deuda técnica | — | ✅ Completada |
| 1 | Zonas de entrenamiento (FCmáx, 5 zonas) | Free | 🔄 En desarrollo |
| 2 | Plantillas de sesión completas | Free | ✅ Completada |
| 3 | Modo Atleta — calendario y planificación | Free | 🔄 En desarrollo |
| 4 | Competiciones y macrociclo | Free | ⏳ Pendiente |
| 5 | Métricas de progreso (RPs, pace Z2, ratio pace/FC) | Free | ⏳ Pendiente |
| 6 | Notificaciones | Free | ⏳ Pendiente |
| 7 | Grupos atleta (ranking por rendimiento real) | Free | ⏳ Pendiente |
| 8 | Wear OS mejorado (guía serie a serie) | Free | ⏳ Pendiente |
| 9 | Test de umbral y zonas individualizadas | Premium | ⏳ Pendiente |
| 10 | ATL / CTL / TSB — modelo de fatiga | Premium | ⏳ Pendiente |
| 11 | Apple Watch | Free / Premium | ⏳ Pendiente |
| 12 | Entrenador IA | Premium | ⏳ Pendiente |

---

## 🚀 Instalación

### Requisitos
- Flutter SDK `^3.9.2`
- Dart SDK
- Android Studio / Xcode para builds nativos
- Acceso al proyecto Firebase configurado

### Pasos

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-usuario/running-laps.git
cd running-laps

# 2. Instalar dependencias
flutter pub get

# 3. Configurar Firebase
# El proyecto usa flutterfire_cli. Necesitas acceso al proyecto Firebase vinculado.
# Si tienes tus propias credenciales, reemplaza firebase_options.dart:
flutterfire configure

# 4. Ejecutar
flutter run
```

### Wear OS

```bash
cd wear_os
./gradlew assembleDebug
```

> **Nota:** El build de Wear OS requiere `google-services.json` en `wear_os/app/`.

---

## 📚 Documentación

| Archivo | Contenido |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Referencia rápida para agentes IA — leer antes de cualquier cambio |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Arquitectura completa, Firebase, modelos de datos, seguridad |
| [`DESIGN.md`](DESIGN.md) | Visión de producto, taxonomía de sesiones, métricas, UX |
| [`COLOR_SYSTEM.md`](COLOR_SYSTEM.md) | Sistema de colores con tokens y reglas de uso |
| [`ROADMAP.md`](ROADMAP.md) | Plan de construcción del módulo atleta por fases |
| [`CHANGELOG.md`](CHANGELOG.md) | Historial de cambios significativos |
| [`GPS_Plan_RunningLaps.docx`](GPS_Plan_RunningLaps.docx) | Plan de mejora del GPS en 4 fases |

---

## 👥 Equipo

Proyecto desarrollado para el ciclo de **Desarrollo de Aplicaciones Multiplataforma (DAM) - 2025**.

| Desarrollador | Rol |
|:---:|:---:|
| **Mario** | Lead Developer |
| **Álvaro** | Lead Developer |

---

## 📄 Licencia

Proyecto académico con fines educativos.

© 2025 Running Laps Team.