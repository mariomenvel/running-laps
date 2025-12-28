import 'package:flutter/material.dart';

/// Container premium para gráficos con sombras y bordes redondeados
/// 
/// Usado en Analytics, Comparador, y Patterns screens
class ChartContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsets? padding;

  const ChartContainer({
    Key? key,
    required this.child,
    this.height,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Container premium con sombra más profunda (para analytics detail)
class ChartContainerDeep extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsets? padding;

  const ChartContainerDeep({
    Key? key,
    required this.child,
    this.height,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }
}
