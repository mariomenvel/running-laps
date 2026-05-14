# Generador de entrenamientos por prompt

## Visión general
Permite al usuario describir un entrenamiento por texto o audio
y la IA genera la sesión completa con bloques y segmentos
configurados, lista para editar y guardar.

## Acceso
- Botón "Generar con IA" en WorkoutEditorScreen
- Cuadro de texto + botón de micrófono
- Disponible para usuarios free y premium con cuotas diferentes

## Cuotas
- Free: 8 generaciones/mes
- Premium: 60 generaciones/mes
- Contador resetea el día 1 de cada mes

## Input

### Texto
- Máximo 500 caracteres
- Cualquier idioma soportado por Claude

### Audio
- Transcripción local con `speech_to_text` del dispositivo
- Máximo 60 segundos de audio
- Tras transcribir, el texto va al campo editable antes de enviar

## Procesamiento

### Modelo
- Claude Haiku 4.5 (rápido, barato)

### Comportamiento ante ambigüedad
- Usuarios free: genera con asunciones por defecto y deja
  comentario tipo "He asumido 5×400m, ajústalo si quieres"
- Usuarios premium: la IA puede pedir aclaraciones en chat

## Output
- Se cargan los bloques generados directamente en el editor
- Usuario revisa, edita, guarda normal

## Errores y fallos
- Sin conexión: mensaje claro, no genera
- Cuota agotada: pantalla de upgrade premium
- API error: reintenta automáticamente 1 vez, luego mensaje
- Respuesta inválida (no JSON): mensaje + reintentar manual

## Ejemplo de prompt
"Ponme un calentamiento de 2km, luego 4×400m a 4:30 con 90
segundos de descanso y metrónomo, y 1km de vuelta a la calma
a RPE 5"

## Output esperado
WorkoutSession con:
- Bloque warmup: 1 segmento de 2000m
- Bloque main (4 reps): segmento 400m con pace 4:30 y metrónomo +
  segmento rest 90s
- Bloque cooldown: 1 segmento de 1000m con RPE objetivo 5
