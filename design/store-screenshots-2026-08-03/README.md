# Capturas para la ficha de Google Play — 3 ago 2026

Sacadas del dispositivo real (Xiaomi M2102J20SG, Android 12) con la cuenta de
pruebas y ~55 sesiones generadas por `TestDataService`.

## Formato

`1080 × 2160`, PNG de 24 bits sin canal alfa.

⚠️ **No son la captura en crudo.** La pantalla es 1080×2400, que da una
proporción de 1:2,22 y **Play rechaza cualquier ratio mayor de 2:1**. Se recorta
la barra de estado (90 px arriba) y la barra de navegación del sistema (150 px
abajo), lo que deja exactamente 1:2 y conserva la barra inferior de la app.
El script está en el scratchpad de la sesión; el recorte es
`crop((0, 90, 1080, 2250))`.

También se activó el modo demo de Android para la batería y la cobertura, pero
MIUI no lo respeta del todo (ignora la hora fija y deja iconos de notificación)
— por eso se recorta la barra de estado en vez de intentar limpiarla.

## Las capturas

| # | Pantalla | Qué demuestra |
|---|---|---|
| 01 | Inicio | Sesión de hoy, próximos entrenos y últimas sesiones con RPE |
| 02 | Calendario | Semana planificada, con tipos de sesión y acciones por día |
| 03 | Analytics · Rendimiento | Récords personales y ritmos por periodo |
| 04 | Analytics · Entrenamiento | Volumen semanal y distribución de intensidad (80/20) |
| 05 | Historial | Lista de entrenos con distancia, ritmo y RPE |
| 06 | Detalle de sesión | Desglose serie a serie con ritmo y RPE por repetición |
| 07 | Cómo entrena tu coach | Los cuatro principios del Coach IA — el diferenciador |

Play pide un mínimo de 2 y recomienda entre 4 y 8. Si hay que quedarse con
cuatro, las que más venden el producto son **04, 06, 07 y 02**: carga, series,
método y planificación.

## Lo que falta

- **Mapa de ruta**: `TestDataService` no genera trazas GPS, así que el detalle
  de sesión enseña "Sin datos de mapa". Para una captura con mapa hace falta
  salir a correr de verdad con el GPS activado, o añadir trazas sintéticas al
  generador.
- **Feature graphic** (1024×500) e **icono** (512×512): no salen de una captura,
  hay que diseñarlos.
