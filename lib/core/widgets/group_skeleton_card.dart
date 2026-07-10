import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';

/// Skeleton loader card for groups list
/// Shows animated shimmer effect while groups are loading
class GroupSkeletonCard extends StatefulWidget {
  const GroupSkeletonCard({Key? key}) : super(key: key);

  @override
  State<GroupSkeletonCard> createState() => _GroupSkeletonCardState();
}

class _GroupSkeletonCardState extends State<GroupSkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: 195,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: isDark ? 0.2 : 0.4),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Name skeleton
              Row(
                children: [
                  _buildShimmerBox(context, 36, 36, isCircle: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildShimmerBox(context, 80, 12, borderRadius: 6),
                  ),
                ],
              ),

              const Spacer(),

              // Leader section skeleton
              _buildShimmerBox(context, 60, 8, borderRadius: 4),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildShimmerBox(context, 24, 24, isCircle: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBox(context, 70, 10, borderRadius: 4),
                        const SizedBox(height: 2),
                        _buildShimmerBox(context, 40, 8, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Button skeleton
              _buildShimmerBox(context, double.infinity, 28, borderRadius: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox(BuildContext context, double width, double height,
      {bool isCircle = false, double borderRadius = 0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerGradient = LinearGradient(
      colors: [
        isDark ? AppColors.skeletonBaseDark  : AppColors.skeletonBaseLight,
        isDark ? AppColors.skeletonShineDark : AppColors.skeletonShineLight,
        isDark ? AppColors.skeletonBaseDark  : AppColors.skeletonBaseLight,
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment(-1.0 - _shimmerController.value * 2, 0.0),
      end: Alignment(1.0 - _shimmerController.value * 2, 0.0),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: shimmerGradient,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}
