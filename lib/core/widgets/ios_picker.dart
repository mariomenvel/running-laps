import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Picker numérico estilo iOS: rueda con pill de
/// selección central, ítem activo en negrita/blanco,
/// fade superior e inferior. Sustituye implementaciones
/// ad-hoc de CupertinoPicker/ListWheelScrollView
/// repartidas por la app.
///
/// El mapeo índice→texto lo decide el caller via
/// [textBuilder], lo que permite cubrir rangos
/// consecutivos, decimales, zero-pad o lookup tables
/// no consecutivas sin cambiar la API.
class IosPicker extends StatefulWidget {
  final int itemCount;
  final int initialItem;
  final String Function(int index) textBuilder;
  final ValueChanged<int> onChanged;
  final double itemExtent;
  final double width;
  final int visibleItems;
  final String? label;

  /// Si se proporciona, añade un ítem extra al final
  /// de la rueda con este texto (ej. "Otro...") que,
  /// al seleccionarse, dispara [onExtraSelected] en
  /// lugar de [onChanged].
  final String? extraItemLabel;
  final VoidCallback? onExtraSelected;

  /// Si se proporciona, sustituye el color blanco/negro
  /// fijo del ítem seleccionado por uno dependiente del
  /// valor (ej. escala de color RPE).
  final Color Function(int index)? selectedColorBuilder;

  const IosPicker({
    super.key,
    required this.itemCount,
    required this.initialItem,
    required this.textBuilder,
    required this.onChanged,
    this.itemExtent = 32,
    this.width = 60,
    this.visibleItems = 3,
    this.label,
    this.extraItemLabel,
    this.onExtraSelected,
    this.selectedColorBuilder,
  });

  @override
  State<IosPicker> createState() => _IosPickerState();
}

class _IosPickerState extends State<IosPicker> {
  late final FixedExtentScrollController _ctrl;
  late int _selectedIndex;

  int get _totalCount =>
      widget.itemCount + (widget.extraItemLabel != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialItem;
    _ctrl = FixedExtentScrollController(
        initialItem: widget.initialItem);
  }

  @override
  void didUpdateWidget(IosPicker old) {
    super.didUpdateWidget(old);
    if (old.initialItem != widget.initialItem &&
        _ctrl.hasClients &&
        _ctrl.selectedItem != widget.initialItem) {
      _ctrl.jumpToItem(widget.initialItem);
      _selectedIndex = widget.initialItem;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _labelFor(int index) {
    if (widget.extraItemLabel != null &&
        index == widget.itemCount) {
      return widget.extraItemLabel!;
    }
    return widget.textBuilder(index);
  }

  void _handleSelected(int index) {
    setState(() => _selectedIndex = index);
    if (widget.extraItemLabel != null &&
        index == widget.itemCount) {
      widget.onExtraSelected?.call();
    } else {
      widget.onChanged(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.borderOf(context).withValues(alpha: 0.6);
    final selectedColor = isDark ? Colors.white : Colors.black;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.35);

    final totalHeight = widget.itemExtent * widget.visibleItems;

    final wheel = SizedBox(
      width: widget.width,
      height: totalHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: (totalHeight - widget.itemExtent) / 2,
            left: 4,
            right: 4,
            child: Container(
              height: widget.itemExtent,
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.25, 0.75, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ListWheelScrollView.useDelegate(
              controller: _ctrl,
              itemExtent: widget.itemExtent,
              perspective: 0.002,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: _handleSelected,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _totalCount,
                builder: (ctx, i) {
                  final isSelected = i == _selectedIndex;
                  return Center(
                    child: Text(
                      _labelFor(i),
                      style: TextStyle(
                        fontSize: isSelected ? 15 : 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? (widget.selectedColorBuilder?.call(i) ??
                                selectedColor)
                            : unselectedColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.label == null) return wheel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label!,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context))),
        const SizedBox(height: 4),
        wheel,
      ],
    );
  }
}
