import 'package:flutter/material.dart';

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
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Name skeleton
              Row(
                children: [
                  _buildShimmerBox(36, 36, isCircle: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildShimmerBox(80, 12, borderRadius: 6),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Leader section skeleton
              _buildShimmerBox(60, 8, borderRadius: 4),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildShimmerBox(24, 24, isCircle: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShimmerBox(70, 10, borderRadius: 4),
                        const SizedBox(height: 2),
                        _buildShimmerBox(40, 8, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Button skeleton
              _buildShimmerBox(double.infinity, 28, borderRadius: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox(double width, double height,
      {bool isCircle = false, double borderRadius = 0}) {
    final shimmerGradient = LinearGradient(
      colors: [
        Colors.grey.shade200,
        Colors.grey.shade100,
        Colors.grey.shade200,
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
