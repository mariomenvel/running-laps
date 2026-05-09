# DESIGN.md — Running Laps
> Versión 3.0 · Mayo 2026
> Decisiones de diseño actualizadas tras rediseño completo de UI

---

## 1. Visión del producto

Running Laps evoluciona de app social de running a herramienta seria para atletas que entrenan de verdad (2-3 días de pista + 2-3 días de carrera continua), sin abandonar su modo recreativo original.

**Principio central:** Una sola app, sin modos ni decisiones forzadas. Cada usuario usa lo que necesita. El recreativo no ve nada raro. El atleta serio tiene todo lo que necesita.

**Dos arquetipos de usuario:**
- **Recreativo:** Corre por diversión, quiere registrar entrenamientos y ver progreso
- **Atleta:** Entrena con plan, quiere cuantificar, analizar y mejorar

**Mismo app, contenido adaptado según `isAthleteMode`.**

---

## 2. Modelo de producto — 3 capas

### Capa 1 — Free (ahora)
- Entrenar libre o con plantillas
- Historial completo
- Analytics básicos
- Grupos recreativos
- Récords personales
- El atleta se autoplanifica. Zonas genéricas. Métricas básicas de progreso.

### Capa 2 — Premium (siguiente gran feature)
- Modo atleta completo con Coach IA
- Calendario de planificación avanzado
- ATL/CTL/TSB
- Comparador de entrenamientos
- Plan semanal automático (IA)
- Test de umbral individualizado

### Capa 3 — Business (futuro)
- Interfaz web para entrenadores con sus atletas
- Dashboard atletas
- Programación remota

---

## 3. Monetización

- **Modelo:** Freemium puro — Free para siempre, Premium de pago
- **Prueba:** 30 días de Premium gratis al registrarse
- **Ciclos:** Mensual + anual con descuento del 20-30%
- **Precio:** A definir antes del lanzamiento
- **Plataforma:** RevenueCat (pendiente implementar)

---

## 4. Navegación global

### Principio
**Header global (logo + avatar) y Footer (BottomNav) visibles en TODAS las pantallas excepto durante sesión activa.**

### Header global
- Logo (CircleAvatar r=22) a la izquierda
- Avatar customizable (r=20) a la derecha
- StreamBuilder sobre users/{uid} — actualización en tiempo real
- Siempre visible excepto: TrainingSessionView, TrainingSessionSummary, Auth, Splash

### Footer — tabs visibles
```
Inicio | Calendario | [FAB Entrenar] | Analytics | Historial | Perfil
```
- Footer oculto en: TrainingStartView (índice 15), TrainingSessionView

### Tabs ocultos (sin botón, accesibles via navegación)
Ver NAVIGATION_ARCHITECTURE.md para índices completos y API.

Principales:
- TrainingDetailView (5) — desde historial
- GroupsListScreen (6) — desde perfil
- AccountSettingsView (8) — desde perfil
- ZonesConfigScreen (9) — desde perfil
- HeartRateMonitorView (10) — desde perfil + training start
- TemplatesListView (11) — desde perfil + training start
- AvatarCustomizerView (14) — desde perfil
- TrainingStartView (15) — desde FAB

### Sin header ni footer (Navigator.push)
- TrainingSessionView
- TrainingSessionSummary
- SplashScreen
- AuthPage

### API de navegación
```dart
MainShell.shellKey.currentState?.navigateTo(int index, {dynamic params});
```

---

## 5. Datos disponibles

| Dato | Estado |
|------|--------|
| Ritmo (pace) via GPS | Disponible |
| Distancia | Disponible |
| Descansos entre series | Disponible |
| FC via Wear OS | Disponible |
| FC via pulsómetro BLE en móvil | Disponible |
| FC punto a punto (fcReadings) | Disponible por serie |

---

## 6. Tipos de sesión — taxonomía completa

### Carrera continua
| Tipo | Zona | Descripción |
|------|------|-------------|
| Regenerativo | Z1 | Recuperación activa muy suave |
| Rodaje base (Z2) | Z2 | 70-80% del volumen total |
| Tempo / umbral | Z3 | Esfuerzo sostenido en umbral láctico |
| Fartlek | Mixto | Cambios de ritmo no estructurados |
| Largo | Z2 | Rodaje largo de base |

### Series (pista / calle)
| Tipo | Zona | Descripción |
|------|------|-------------|
| Series largas | Z4 | VO2max y resistencia |
| Series cortas | Z5 | Velocidad pura |
| Series en cuestas | Z4 | Fuerza específica |
| Series mixtas | Mixto | Pirámides, progresivos |

### Especiales
| Tipo | Descripción |
|------|-------------|
| Competición | Carrera oficial. Badge especial. Morado en calendario. |
| Test / control | Cronometrado para medir forma |
| Libre | Sin estructura previa |

---

## 7. Sistema de etiquetas

Fusión de categorías predefinidas + etiquetas custom del usuario.

**Predefinidas (sistema):** rodaje, series, tempo, largo, fartlek, competición, recuperación
**Custom:** cualquier string creado por el usuario

Visual:
- Predefinidas: pill con `brand.withOpacity(0.1)` + texto `brand`
- Custom: pill con `surface2Of` + texto `textSecondary` + borde `borderOf` 0.5px

Almacenamiento: `users/{uid}/trainings/{id}.tags` como `List<String>` mixta.

---

## 8. Pantallas principales

### 8.1 HOME (2 estados según isAthleteMode)

#### Estado Atleta (con sesión planificada hoy)
```
SESIÓN DE HOY
├─ Título + tipo + bloques
├─ Pace objetivo + RPE
└─ [EMPEZAR ENTRENAMIENTO] → TrainingStartView

PRÓXIMOS ENTRENAMIENTOS (esta semana)

PROGRESO SEMANAL
├─ Volumen: 32/60km
├─ Zonas: Z1-Z2 60% | Z3-Z5 40%
└─ Estado: Fresco (TSB +8)

ÚLTIMOS ENTRENAMIENTOS (5)
└─ [Ver todos] → HistoryScreen
```

#### Estado Recreativo
```
[▶ ENTRENAR AHORA] → TrainingStartView
[◆ PASAR A MODO ATLETA] → Onboarding Wizard

ÚLTIMOS ENTRENAMIENTOS (5)
└─ [Ver todos] → HistoryScreen

TU PROGRESO
├─ TP 1km, 5km, 10km
└─ Mejor pace reciente
```

---

### 8.2 CALENDARIO

**Corazón del modo atleta.**

#### Vistas disponibles
- **Semanal** (default): días de la semana con sesiones
- **Mensual**: filas semanales con barra de carga TRIMP
- **Temporada**: cuadraditos por semana coloreados por carga

#### Sistema de colores semanal (basado en TRIMP)
Ver COLOR_SYSTEM.md sección "Calendario".

#### Regla de semanas cross-mes
Una semana que abarca 2 meses aparece **solo en el mes con más días**.
`_monthForWeek(DateTime weekStart)` determina a qué mes pertenece.

#### Vista semanal — cada día
```
LUN 4
● Rodaje base (Z2)   [✓ completado / ▷ empezar / + planificar]
  5669m

JUE 7
  Descanso            [+]
```

- Botón (✓/▷/+): centrado respecto al contenedor del día, margen derecho fijo
- Tap en cualquier parte del contenedor = tap en el botón
- Tick dentro de círculo: centrado con Center()

#### Código de colores de sesiones (puntos en vista semanal)
| Estado | Color |
|--------|-------|
| Completada | Verde (rpeLow) |
| Planificada | Morado (brand) |
| Competición | Rojo (rpeMax) |

---

### 8.3 TRAINING START

**Accesible via FAB central. Footer oculto en esta pantalla.**

#### Si modo atleta + sesión planificada hoy
```
Card sesión:
  [SESIÓN PLANIFICADA]
  Calentamiento → Bloques → Vuelta calma
  Pace objetivo + RPE objetivo por bloque

[Empezar sesión planificada] (brand, primario)
[Rellenar manualmente]       (textSecondary)
[Entrenar libre]             (textSecondary, pequeño)
```

#### Si no hay sesión / modo recreativo
```
¿Qué entrenamos hoy?

[Rodaje]  [Series]
[Tempo]   [Largo]
[Fartlek] [Libre]

[□ Cargar plantilla]
```

Al seleccionar tipo → AnimatedSwitcher con config específica:
- **Rodaje/Largo:** distancia objetivo + pace objetivo (NumberPickerField)
- **Series:** nº series + distancia/serie + descanso + pace (NumberPickerField)
- **Tempo:** duración + pace (NumberPickerField)
- **Fartlek:** duración + bloques (NumberPickerField)
- **Libre:** "Entrena sin restricciones"

#### Sensores
```
SENSORES
⊙ GPS              [toggle] — icono brand si activo
♡ Pulsómetro       [toggle si conectado / "Configurar" si no]
```

#### Alertas de ritmo (mantener implementación actual)
- Modo 1: cada X segundos (intervalos de 0.5s)
- Modo 2: pace objetivo + distancia referencia → calcula intervalo automáticamente
- Tipo: vibración / pitido / ambos

#### Botón EMPEZAR
Círculo 56×56, `brand`, play icon blanco, sin sombra.
Al tocar → countdown overlay 3-2-1 → TrainingSessionView (Navigator.push).

---

### 8.4 TRAINING SESSION

**Navigator.push — sin header ni footer.**

#### Durante serie activa
- Fondo: negro puro
- Métrica principal: tiempo O distancia (toggle tocando)
- Métricas secundarias: pace actual, FC, pace objetivo
- Indicador visual: dentro/fuera del objetivo
- Bloque actual + siguiente visible debajo
- [Completar serie] [Pausa]

#### Pantalla de descanso
- Fondo blanco que se tiñe de azul claro de abajo hacia arriba según progreso
- `_RestFillPainter` con `drawRect` (no sine wave — 60fps)
- `RepaintBoundary` en fondo y cada burbuja
- 8 burbujas flotantes azules translúcidas
- Temporizador grande central
- Resumen serie completada (distancia, tiempo, pace, FC)
- Slider RPE de la serie (se guarda al pasar a siguiente)
- "Siguiente: Serie X — Ydistancia a Zpace/km"
- [Saltar descanso] discreto
- Al llegar a 0: `HapticFeedback.mediumImpact()` + arranca automáticamente

#### Pausa
- Overlay semi-transparente
- [Continuar] [Terminar entrenamiento] [Cancelar y descartar]

---

### 8.5 TRAINING SUMMARY

**Tab oculto del MainShell — con header y footer.**

```
✓ ¡Completado!
  [título] · [duración]

Stats: distancia | tiempo | pace medio | RPE medio | FC media

[RPE slider] — solo si 1 serie o isManual

COMPARATIVA
  1. vs planificado (si existe)
  2. vs entrenamiento similar reciente (si no hay planificado)
  3. Oculto si no hay ninguno

ETIQUETAS
  [rodaje] [series] [tempo] ... (predefinidas inline)
  [+ Etiqueta] → TagSelectorSheet para custom

NOTAS
  TextField "¿Algo que destacar...?"

[Guardar entrenamiento]   (brand, full-width)
[Descartar entrenamiento] (rpeMax, con AlertDialog)
```

---

### 8.6 TRAINING DETAIL

**Tab oculto (índice 5). Con header y footer.**

#### Layout
```
CustomScrollView → SliverList:
  _buildHero()           — título + fecha + badge + tags
  _divider()
  _buildStats()          — números grandes protagonistas
  _divider()
  if (gps) _buildMap()   — mapa expandible
  _divider()
  _buildSeries()         — lista expandible con gráfica
  _divider()
  if (fc) _buildFcSection()
  _divider()
  if (comparison) _buildComparison()
  _divider()
  if (notas) _buildNotas()
```

#### Stats hero
- Si >1 serie: Nº series | Distancia | Pace medio | RPE medio | FC media
- Si 1 serie: igual + Tiempo total
- fontWeight w400–w500, sin cards/bordes, sobre background

#### Series expandibles
- Colapsada: badge nº | distancia | tiempo | pace (brand) | FC | RPE (effortColor)
- Si plannedComparison: objetivo encima en pequeño, real debajo con delta en color
- Expandida: fl_chart `LineChart` interactivo
  - Eje X: tiempo o distancia (toggle)
  - Línea pace: `brand`
  - Línea FC: `rpeMax` (si fcReadings disponibles)
  - Tooltips al tocar: pace + fecha

#### FC global
- Row: min / media / max — grandes y limpios
- Zonas Z1-Z5: barras horizontales con % tiempo

#### Notas
- Editable inline: tap → TextField
- Guarda automáticamente al perder foco

---

### 8.7 HISTORIAL

**Tab visible (índice 4). Con header y footer.**

```
Historial

[🔍 Buscar...]  [⊙ calendario]  [≡ filtros con badge]

[Chip filtros activos × ] [Borrar todo]

Lista paginada (20/página cursor-based):
  PremiumTrainingCard × n

[Cargar más / "Has visto todos..."]
```

#### PremiumTrainingCard
```
Container(surfaceOf, borderOf 0.5, radius 16):
  Header: [icono tipo / checkbox selección] [título w600] [badge GPS/Manual] [⋯ menú]
          fecha
          [tags]
  Stats:  distancia | tiempo | pace (brand) | RPE (effortColor)
  Footer: "Ver N series ▾" / "Ver menos ▴" (surface2Of bg)
  
  Expandido:
    Container(surface2Of, radius 12):
      "SERIES"
      por cada serie: nº | distancia | tiempo | pace | descanso
    [Ver análisis] → navigateTo(5, params: training)
```

---

### 8.8 ANALYTICS

**Tab visible (índice 2). Con header y footer.**

3 tabs: Rendimiento | Entrenamiento | Forma

#### Tab Rendimiento
- Récords personales (400m/1km/5km/10km): tiempo total + pace subtítulo
- Gráfica ritmo en series (fl_chart): puntos visibles, tooltips, hint "Toca un punto"
- Pace medio por período

#### Tab Entrenamiento
- Volumen semanal (barras adaptadas al rango seleccionado)
- Distribución intensidad 80/20
- Consistencia: semanas activas, racha, heatmap 56 días
- Sesiones por tipo

#### Tab Forma
- CTL/ATL/TSB LineChart (180 días, 12 puntos, muestreo cada 14 días)
- Botón (?) → bottom sheet explicación
- ACWR ratio con zona
- RPE trend 4 semanas
- Cargas semanales por color

---

### 8.9 PERFIL

**Tab visible (índice 3). Con header y footer.**

```
[Avatar customizable 80px]
[Nombre] · [email]
[Editar avatar] → navigateTo(14)

─ SOCIAL ─
Mis grupos → navigateTo(6)

─ PERSONAL ─
Mis plantillas → navigateTo(11)
Zonas de entrenamiento → navigateTo(9)
Pulsómetro BLE → navigateTo(10)

─ CUENTA ─
Configuración → navigateTo(8)
Modo oscuro/claro → toggle

─ ADMINISTRACIÓN ─ (solo si isAdmin)
Panel administrador

[Cerrar sesión]
[Generar datos de prueba] (solo si isAdmin)
```

---

### 8.10 AVATAR CUSTOMIZABLE

**Tab oculto (índice 14). Con header y footer.**
Generador SVG puro sin assets externos.

11 secciones: Cara | Ojos | Cejas | Nariz | Boca | Pelo | Barba | Ropa | Gorro | Accesorios | Fondo

Opciones:
- Cara: 4 formas + 6 tonos de piel
- Ojos: 8 expresiones + 5 colores pupila + eyesWide toggle
- Cejas: 4 estilos + paleta color
- Nariz: 4 formas
- Boca: 12 expresiones
- Pelo: 26 estilos + 10 colores (si gorro → pelo oculto automáticamente)
- Barba: 7 opciones (chevron, handlebar, horseshoe diferenciados) + color
- Ropa: 7 estilos + 8 colores
- Gorro: 5 tipos + color
- Accesorios: gafas + pendientes + cicatriz + color gafas
- Fondo: 8 colores pasteles

Guardado: `users/{uid}.generativeAvatarConfig` (Map en Firestore)
Actualización: `_LiveAvatarBadge` con StreamBuilder en tiempo real

---

### 8.11 ONBOARDING ATLETA (pendiente implementar)

Wizard 4 pasos para activar modo atleta desde modo recreativo:

**Paso 1 — Objetivo**
```
¿Cuál es tu objetivo?
○ 5K en menos de X min
○ 10K en menos de X min
○ Media maratón
○ Maratón
○ Mejorar mi ritmo
○ Mejorar resistencia
```

**Paso 2 — Competición (opcional)**
```
¿Cuándo es tu competición?
[📅 Seleccionar fecha]
[Nombre de la carrera]
[SIGUIENTE] [SALTAR]
```

**Paso 3 — Disponibilidad**
```
¿Cuántos días puedes entrenar?
[✓] Lun  [✗] Mar  [✓] Mié
[✗] Jue  [✓] Vie  [✓] Sáb  [✓] Dom
Total: 5 días
```

**Paso 4 — Resumen**
```
¡Casi listo!
Objetivo: 10K en <50 min
Competición: 15 junio
Disponibilidad: 5 días/semana
[ACTIVAR MODO ATLETA]
```

Al activar: `isAthleteMode = true` en Firestore → HOME vuelve a modo atleta.

---

## 9. Componentes globales

### Colores
Ver COLOR_SYSTEM.md como referencia única.

**Sistema:**
- Marca: Morado `#8E24AA` — identidad + competición en calendario
- Acento: Coral `#D85A30` — esfuerzo e intensidad
- Descanso: Azul `#378ADD` — recuperación
- RPE: escala verde→ámbar→coral→rojo

### Tipografía (General Sans)
```
H1: letterSpacing -0.4, w500
H2: letterSpacing -0.4, w500
Body: letterSpacing -0.3, w400
Small: letterSpacing -0.3, w400
Labels MAYÚSCULAS: letterSpacing 1.2-1.5, w500-w600 (no cambiar)
Título sesión: w600 (única negrita frecuente)
```

### Espaciado (AppSpacing tokens)
```
xs: 4px
s:  8px
m:  12px
l:  16px
xl: 24px
xxl: 32px
```

### Cards
```
fondo:  AppColors.surfaceOf(context)
borde:  AppColors.borderOf(context), thickness 0.5
radius: 16px
padding: AppSpacing.l (16px)
sombra: ninguna — solo borde sutil
```

### Botones
```
Primario:    brand, radius 12, elevation 0, full-width en formularios, h 48px
Secundario:  TextButton, textSecondary
Destructivo: rpeMax, con AlertDialog siempre
FAB:         círculo 56×56, brand, play icon, sin sombra
Inputs:      NumberPickerField para números, TextField solo para texto libre
```

### Separadores entre secciones
```dart
Widget _divider() => Padding(
  padding: EdgeInsets.symmetric(vertical: AppSpacing.l, horizontal: AppSpacing.l),
  child: Divider(color: AppColors.borderOf(context), thickness: 0.5),
);
```

---

## 10. Zonas de frecuencia cardíaca

### Free — Zonas genéricas por % FCmáx (5 zonas)
| Zona | Nombre | % FCmáx | Uso |
|------|--------|---------|-----|
| Z1 | Regenerativo | <60% | Recuperación activa |
| Z2 | Base aeróbica | 60-70% | Volumen y base |
| Z3 | Umbral | 70-80% | Tempo, resistencia |
| Z4 | VO2max | 80-90% | Series largas |
| Z5 | Máximo | >90% | Series cortas, velocidad |

FCmáx: el atleta la introduce o `220 − edad` como fallback.

### Premium — Zonas individualizadas
Test de umbral guiado. Calcula FCumbral real y recalibra las 5 zonas individualmente.

---

## 11. Métricas de progreso

### Free — Mejora aeróbica
- Pace en Z2 (tendencia 8 semanas, mín 4 sesiones)
- FC en esfuerzo fijo (comparativa mes a mes)
- Ratio pace/FC = `pace (s/km) ÷ FC media × 100`

### Free — Rendimiento alta intensidad
- Récords personales por distancia (400m, 1K, 5K, 10K)
- Detectados automáticamente con GPS activo
- Solo válidos si distancia entreno ≥ distancia récord + 10%

### Premium — Fatiga y carga (ATL/CTL/TSB)
| Métrica | Descripción | Período |
|---------|-------------|---------|
| CTL | Forma crónica (fitness acumulado) | 42 días |
| ATL | Fatiga aguda (carga reciente) | 7 días |
| TSB | CTL − ATL. Positivo = fresco | — |

Ideal competir: TSB entre +5 y +25.
No mostrar hasta mínimo 6 semanas de datos.

**Cálculo TRIMP simplificado:**
`Carga = duración (min) × factor de zona`
| Zona | Factor |
|------|--------|
| Z1 | 1 |
| Z2 | 2 |
| Z3 | 3 |
| Z4 | 4 |
| Z5 | 5 |

---

## 12. Grupos

### Grupo recreativo (existente)
- Retos y gamificación
- Feed de actividad compartida
- Ranking por distancia/tiempo
- Logros y badges
- Sin pace ni zonas visibles

### Grupo atleta (futuro)
- Ranking por volumen y progreso aeróbico
- Comparativa de entrenamientos equivalentes
- Feed con detalle de sesiones
- Privacidad configurable por atleta

---

## 13. Notificaciones

**Máximo 2 por día. Prioridad: competición > fatiga > logro > recordatorio.**

### Planificación (Free)
- Recordatorio entreno: 1h antes si hay hora asignada
- Competición próxima: 7 días antes y 1 día antes

### Progreso (Free)
- Récord personal: inmediatamente al detectar
- Resumen semanal: domingo 20:00
- Mejora aeróbica: una vez al mes si mejora ≥5%

### Fatiga (Premium)
- Carga alta acumulada: tras 3 semanas consecutivas
- TSB muy negativo con competición próxima
- Semana muy por debajo del objetivo: jueves si <40%

---

## 14. Integración con relojes

### Wear OS (activo)
- Base en Kotlin/Jetpack Compose
- Entrena con plantillas, FC, GPS
- Auth: bypass temporal con código de 6 dígitos (pendiente Cloud Function)

### Apple Watch (futuro)
- Por construir en Swift
- WatchConnectivity + HealthKit

### Colores en el reloj
- Morado: identidad de marca, UI general
- Verde: en zona / cumpliendo objetivo
- Ámbar: cerca del límite
- Rojo: fuera de zona / por encima del objetivo

---

## 15. Inputs y formularios

**Principio:** El teclado solo aparece para texto libre. Todo lo numérico usa controles nativos.

| Tipo de dato | Control | Razón |
|---|---|---|
| Distancia (m/km) | `NumberPickerField` (CupertinoPicker) | Sin teclado |
| Duración (min) | `NumberPickerField` | Sin teclado |
| Nº series | `NumberPickerField` | Sin teclado |
| Descanso (s) | `NumberPickerField` | Sin teclado |
| RPE (1-10) | Slider con `effortColor()` | Visual |
| FC máx / reposo | `NumberPickerField` | Sin teclado |
| Pace objetivo | `NumberPickerField` x2 (min + seg) | Sin teclado |
| Nombre / título | TextField | Requiere teclado |
| Notas | TextField multilínea | Requiere teclado |
| Búsqueda | TextField inline | Requiere teclado |

---

## 16. Pendientes

### Pendientes de implementar
- Onboarding atleta (wizard 4 pasos)
- Coach IA (Claude API, Premium)
- RevenueCat (suscripciones)
- Rediseño grupos, perfil secundarias, plantillas, atleta, auth, admin
- Eliminar archivos legacy cuando todo esté estable

### Aparcados conscientemente
- Temperatura y FC (afecta validez de métricas)
- Interfaz web del entrenador (Business)
- Precio exacto del Premium
- Tests automatizados

---

## 17. Documentos de referencia

- **COLOR_SYSTEM.md** — fuente de verdad para colores y tokens
- **NAVIGATION_ARCHITECTURE.md** — índices de tabs, API de navegación
- **PROMPTS_PENDIENTES.md** — prompts listos para Claude Code
- **PREMIUM_AI_COACH.md** — especificación del Coach IA
- **ANALYTICS_ROADMAP.md** — roadmap detallado de analytics
- **CLAUDE.md** — guía de desarrollo para Claude Code
- **CHANGELOG.md** — historial de cambios