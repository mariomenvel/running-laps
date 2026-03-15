import 'package:flutter/material.dart';

/// Provides a single shimmer AnimationController to all [SkeletonBox] children
/// via [builder]. Use ONE SkeletonShimmer per loading area — never nest them.
class SkeletonShimmer extends StatefulWidget {
  final Widget Function(double shimmerValue) builder;

  const SkeletonShimmer({super.key, required this.builder});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => widget.builder(_ctrl.value),
    );
  }
}

/// Rectangular shimmer placeholder. Pass [shimmerValue] from [SkeletonShimmer].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final double shimmerValue;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 12,
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.0 - shimmerValue * 2, 0.0),
          end: Alignment(1.0 - shimmerValue * 2, 0.0),
        ),
      ),
    );
  }
}

/// Shortcut for text-like skeleton lines (height=12, borderRadius=6).
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double shimmerValue;

  const SkeletonLine({
    super.key,
    this.width,
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: 12,
      borderRadius: 6,
      shimmerValue: shimmerValue,
    );
  }
}
