import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Slider de RPE con track de gradiente verde→rojo
/// y thumb que cambia de color según el valor.
/// Reutilizable en cualquier pantalla de captura de RPE.
class RpeSlider extends StatelessWidget {
  final double value; // 1.0 – 10.0
  final ValueChanged<double> onChanged;
  final VoidCallback? onClear;
  final bool showClear;

  const RpeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onClear,
    this.showClear = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.effortColor(value);
    const double thumbRadius = 12.0;
    const double trackHeight = 4.0;
    const double totalHeight = 36.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slider con gradiente
        SizedBox(
          height: totalHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Track con gradiente (detrás)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: thumbRadius),
                child: Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                        trackHeight / 2),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF639922), // verde  RPE 1
                        Color(0xFFEF9F27), // ámbar  RPE ~5
                        Color(0xFFD85A30), // coral  RPE ~8
                        Color(0xFFE24B4A), // rojo   RPE 10
                      ],
                      stops: [0.0, 0.45, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // Slider encima con track invisible
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: trackHeight,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: color,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: thumbRadius,
                    elevation: 2,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                  overlayColor: color.withValues(alpha: 0.12),
                ),
                child: Slider(
                  min: 1,
                  max: 10,
                  divisions: 18,
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
        // Fila: valor numérico + clear opcional
        Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Suave',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context))),
                  Text(value.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  Text('Máximo',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context))),
                ],
              ),
            ),
            if (showClear && onClear != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 16,
                    color: AppColors.textSecondary(context)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
