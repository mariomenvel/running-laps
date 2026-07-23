# Project Structure
Generated: 2026-06-15 (actualizar con `find lib -name "*.dart" | sort`)

## lib/ — raíz

- `lib/main.dart` — entry point: Firebase init, App Check, ThemeService, AuthWrapper
- `lib/firebase_options.dart` — generado por flutterfire CLI, no editar
- `lib/scripts/generate_test_workouts.dart` — script de datos de prueba

---

## lib/config/
- `app_theme.dart` — clase `Tema` (alias legado: `brandPurple`, `AvatarHelper`)

---

## lib/core/

### core/services/
- `gps_service.dart` — GPSService: Haversine + KalmanFilter, ventana 5 pts, descarta accuracy >20m
- `sensor_service.dart` — SensorService: pedómetro
- `pdf_generator_service.dart` — PDFGeneratorService: exportar entrenamientos a PDF
- `settings_service.dart` — SettingsService: SharedPreferences (alarmas, GPS defaults)
- `user_service.dart` — UserService: nombre, contraseña, borrar cuenta, reauth, isGoogleUser
- `wear_auth_service.dart` — WearAuthService: código de sesión 6 dígitos para Wear OS
- `heart_rate_service.dart` — HeartRateService: frecuencia cardiaca BLE
- `notification_service.dart` — NotificationService: push + resumen semanal programado
- `ios_live_activity_service.dart` — IOSLiveActivityService: MethodChannel/EventChannel Swift↔Dart
- `foreground_tracking_handler.dart` — handler para tracking en foreground (Android)
- `rate_limit_service.dart` — RateLimitService: throttling de llamadas a IA/API
- `session_recovery_service.dart` — SessionRecoveryService: recuperar sesión tras crash
- `training_load_service.dart` — TrainingLoadService: carga de entrenamiento (TRIMP/TSS)
- `zones_service.dart` — ZonesService: zonas de FC por usuario

### core/theme/
- `app_colors.dart` — AppColors: tokens de color actuales (`AppColors.brand`, etc.)
- `app_theme.dart` — ThemeData claro/oscuro basado en AppColors
- `theme_service.dart` — ThemeService: persiste tema en SharedPreferences

### core/tracking/
- `tracking_state.dart` — GpsStatus enum: uninitialized → ready → active → paused → error
- `tracking_types.dart` — tipos y enums de tracking
- `sensor_frame.dart` — SensorFrame: frame combinado GPS + pedómetro

### core/utils/
- `kalman_filter.dart` — KalmanFilter para suavizado de coordenadas GPS
- `tag_utils.dart` — utilidades para tags
- `ekf2d.dart` — Extended Kalman Filter 2D
- `rdp_smoother.dart` — Ramer-Douglas-Peucker para simplificar trazados GPS
- `app_transitions.dart` — transiciones de navegación
- `exponential_backoff.dart` — retry con backoff exponencial
- `rate_limit_decorator.dart` — decorador de rate limiting

### core/constants/
- `app_help_content.dart` — textos de ayuda en app
- `training_tags.dart` — tags predefinidos de entrenamiento

### core/widgets/
- `modern_snackbar.dart` — ModernSnackBar.showSuccess/showError/showWarning
- `app_header.dart` — AppHeader reutilizable con gradiente
- `app_page_scaffold.dart` — scaffold estándar de la app
- `chart_style.dart` — AppChartStyle: tooltips e interacción táctil unificados para todas las gráficas fl_chart
- `main_shell.dart` — MainShell: shell con tabs de navegación
- `shell_embedding_scope.dart` — scope para embeber en shell
- `empty_state_widget.dart` — empty state genérico
- `gradient_banner.dart` — banner con gradiente
- `info_tooltip.dart` — tooltip de información
- `number_picker_field.dart` — campo selector numérico
- `premium_date_range_picker.dart` — selector de rango de fechas
- `skeleton_shimmer.dart` — shimmer loader genérico
- `standard_table_calendar.dart` — calendario estándar (TableCalendar)

---

## lib/features/

### features/auth/
- `data/auth_remote.dart` — comunicación directa con Firebase Auth
- `data/auth_repository.dart` — AuthRepository: signIn, signUp, signOut, Google Sign-In
- `viewmodels/auth_controller.dart` — AuthController: estado de la UI de auth + isUserAdmin()
- `views/auth_page.dart` — AuthPage: login/registro
- `views/auth_wrapper.dart` — AuthWrapper: StreamBuilder<User?> → HomeView | AuthPage
- `views/email_verification_pending_view.dart` — pantalla de verificación de email pendiente
- `views/welcome_view.dart` — pantalla de bienvenida

### features/training/
- `data/entrenamiento.dart` — modelo Entrenamiento (distanciaTotalM: int metros, tiempoTotalSec: double)
- `data/serie.dart` — modelo Serie (tiempoSec, distanciaM, descansoSec, rpe, gpsPoints)
- `data/tag_model.dart` — TagModel (id, name, color ARGB)
- `data/tag_manager.dart` — TagManager: CRUD de tags en Firestore
- `data/training_repository.dart` — TrainingRepository: CRUD trainings + contadores atómicos
- `data/entrenamiento_utils.dart` — utilidades de cálculo
- `data/fc_reading.dart` — FcReading: lectura de FC durante entrenamiento
- `data/serie.dart` — modelo Serie
- `data/summary_stats_calculator.dart` — cálculo de estadísticas de resumen
- `data/temporal_data_extractor.dart` — extractor de datos temporales de series
- `data/workout_execution_controller.dart` — WorkoutExecutionController: lógica de ejecución de bloque
- `data/workout_execution_state.dart` — WorkoutExecutionState: estado de la ejecución
- `services/training_analysis_service.dart` — análisis post-entrenamiento
- `viewmodels/training_viewmodel.dart` — TrainingViewModel: estado de la sesión activa
- `views/training_start_view.dart` — pantalla de inicio de entrenamiento
- `views/training_session_view.dart` — sesión de entrenamiento activa (modo libre)
- `views/manual_training_view.dart` — entrenamiento manual (sin GPS)
- `views/training_summary_screen.dart` — resumen post-entrenamiento
- `views/pre_execution_screen.dart` — pantalla previa a ejecución de bloque
- `views/block_transition_screen.dart` — transición entre bloques
- `views/workout_execution_screen.dart` — ejecución de workout por bloques
- `views/session_screens/` — pantallas por tipo: interval, continuous, fartlek, free, hills, competition + rest
- `views/session_screens/shared/` — métricas compartidas: distance, fc, pace, time, progress_bar
- `views/session_screens/summary_cards/` — cards de resumen por tipo de sesión
- `widgets/` — create_tag_dialog, tag_chip, tag_selector_sheet

### features/history/
- `viewmodels/history_controller.dart` — HistoryController: carga 100 entrenamientos, filtros en memoria
- `viewmodels/history_analytics_view_model.dart` — analíticas del historial
- `views/history_screen.dart` — HistoryScreen: lista + filtros + calendario
- `views/training_detail_view.dart` — detalle de entrenamiento con GPS
- `views/widgets/temporal_chart.dart` — gráfica temporal
- `widgets/` — history_calendar_widget, history_filter_sheet, premium_training_card, training_map_view

### features/home/
- `data/home_estadistica_repository.dart` — HomeEstadisticaRepository (singleton + caché 5min)
- `viewmodels/home_view_model.dart` — HomeViewModel
- `views/home_view.dart` — HomeView: dashboard principal
- `widgets/home_race_countdown.dart` — cuenta atrás a la próxima competición de prioridad alta

### features/analytics/
- `viewmodels/analytics_hub_controller.dart` — AnalyticsHubController
- `viewmodels/analytics_view_model.dart` — AnalyticsViewModel
- `views/analytics_hub_screen.dart` — AnalyticsHubScreen (versión actual)

### features/groups/
- `data/models/` — challenge_models, group_models, group_stats_model, rewards_models, result_notification_model, enums
- `data/repositories/` — challenges_repository, group_detail_repository, groups_repository, invites_repository, rewards_repository, templates_repository, user_groups_repository, group_prefs_repository
- `data/services/` — gamification_service, challenge_calculator, challenge_finalize_service, training_challenge_sync_service, auto_join_service, ensure_auto_challenges_service, user_lookup_service
- `data/helpers/` — challenge_color_helper, challenge_helpers, challenge_ranking_helper, invite_token_helper, period_helper
- `viewmodels/` — challenge_detail_controller, group_challenges_controller, group_rewards_controller
- `views/` — group_screen, groups_list_screen, challenge_detail_screen, group_rewards_screen, participant_profile_screen
- `views/widgets/` — create_challenge_modal

### features/templates/
- `data/template_models.dart` — TemplateBlock, TemplateAlerts
- `data/workout_session.dart` — WorkoutSession: sesión estructurada por bloques
- `data/workout_block.dart` — WorkoutBlock: bloque de tipo distance|time
- `data/workout_segment.dart` — WorkoutSegment: segmento dentro de un bloque
- `data/target_config.dart` — TargetConfig: configuración de objetivo (pace/time/HR)
- `data/saved_block.dart` — SavedBlock: bloque guardado reutilizable
- `data/templates_repository.dart` — TemplatesRepository: CRUD plantillas Firestore
- `data/saved_blocks_repository.dart` — SavedBlocksRepository
- `data/athlete_session_mapper.dart` — mapeo entre AthleteSession y WorkoutSession
- `views/templates_list_view.dart` — lista de plantillas
- `views/template_editor_view.dart` — editor de plantilla
- `views/workout_editor_screen.dart` — editor visual de workout
- `views/widgets/` — blocks_list_section, segment_bottom_sheet, workout_type_selector
- `widgets/` — alarm_config_sheet, block_editor_sheet

### features/avatar/
- `data/assets.dart` — gestión de assets SVG por capa
- `data/background_shape.dart` — formas de fondo
- `models/avatar_config.dart` — AvatarConfig: configuración de capas
- `services/avatar_generator.dart` — AvatarGenerator: renderiza SVG
- `viewmodels/avatar_maker_controller.dart` — AvatarMakerController
- `views/avatar_maker_screen.dart` — pantalla de creación de avatar
- `views/avatar_customizer_view.dart` — vista de personalización

### features/profile/
- `data/user_profile_model.dart` — UserProfileModel
- `data/zones_repository.dart` — ZonesRepository: zonas de FC en Firestore
- `viewmodels/zones_viewmodel.dart` — ZonesViewModel
- `views/profile_menu_screen.dart` — menú de perfil principal
- `views/profile_view.dart` — vista de perfil
- `views/account_settings_view.dart` — cambiar nombre, contraseña, borrar cuenta
- `views/edit_profile_picture_view.dart` — editar foto/avatar de perfil
- `views/avatar_editor_wraper_view.dart` — wrapper del editor de avatar
- `views/heart_rate_monitor_view.dart` — monitor de FC en tiempo real
- `views/zones_config_screen.dart` — configuración de zonas de FC

### features/admin/
- `data/admin_repository.dart` — AdminRepository: acceso a colecciones admin
- `viewmodels/admin_controller.dart` — AdminController
- `views/admin_panel_screen.dart` — panel admin (isAdmin=true)
- `views/admin_dashboard_tab.dart` — tab dashboard de admin
- `views/admin_challenges_tab.dart` — tab desafíos de admin

### features/ai_coach/
- `data/ai_coach_models.dart` — AiCoachWeeklyDecision, AiCoachAthleteMemory, AiCoachAutomation, CoachInsight
- `data/ai_coach_repository.dart` — AiCoachRepository: persistencia en Firestore
- `data/ai_coach_context_builder.dart` — construye contexto del atleta para el prompt
- `data/ai_coach_prompt_builder.dart` — construye prompts para el LLM
- `data/ai_coach_decision_service.dart` — AiCoachDecisionService: toma de decisiones semanales
- `data/ai_coach_automation_service.dart` — AiCoachAutomationService: automatización de sugerencias
- `data/ai_coach_weekly_planner_service.dart` — planificador semanal
- `data/ai_coach_chat_service.dart` — chat con el coach
- `data/ai_coach_session_generator.dart` — generador de sesiones de entrenamiento por IA
- `data/ai_coach_prompt_session_generator.dart` — generador de sesiones por prompt
- `data/ai_coach_defaults.dart` — configuración por defecto del coach
- `data/ai_coach_models_config.dart` — configuración de modelos LLM
- `data/openrouter_client.dart` — cliente HTTP para OpenRouter (LLM gateway)
- `data/race_goal.dart` — RaceGoal: competición objetivo (fecha + distancia + prioridad alta/media/baja)
- `data/race_goal_repository.dart` — RaceGoalRepository: CRUD en `users/{uid}/raceGoals`
- `views/ai_coach_onboarding_view.dart` — onboarding del coach
- `views/ai_coach_onboarding_launcher.dart` — launcher del onboarding
- `views/ai_coach_settings_view.dart` — configuración del coach
- `views/ai_coach_weekly_feedback_view.dart` — feedback semanal del coach
- `views/race_goals_section.dart` — sección "Tus objetivos" embebida en AiCoachSettingsView

### features/athlete/
- `data/athlete_session_model.dart` — AthleteSession: sesión planificada del atleta
- `data/athlete_session_repository.dart` — AthleteSessionRepository
- `data/progress_repository.dart` — ProgressRepository: progreso del atleta (récords personales)

### features/calendar/
- `viewmodels/calendar_view_model.dart` — CalendarViewModel: entrenamientos por fecha
- `views/calendar_view.dart` — CalendarView: calendario de entrenamientos planificados

---

## wear_os/ (Kotlin/Compose — app independiente)
- `MainActivity.kt` — entry point, SwipeDismissableNavHost, App Check
- `HomeScreen.kt` — dashboard con stats desde Firestore
- `SeriesPageScreen.kt` — configuración de serie
- `SeriesActiveScreen.kt` — pantalla activa durante la serie
- `SeriesTrainingService.kt` — Foreground service: timer, GPS, alarmas (⚠️ DEBUG_SIMULATE debe ser false en release)
- `TemplatePickerScreen.kt` — selector de plantilla
- `TemplateModels.kt` — modelos de datos para plantillas

---

## functions/src/ (Cloud Functions — Node.js/TypeScript)
- `index.ts` — entry point de Cloud Functions
- `auth.ts` — funciones de autenticación (custom tokens, etc.)
- `openrouter.ts` — proxy seguro para llamadas a OpenRouter (LLM)
- `waitlist.ts` — gestión de lista de espera
