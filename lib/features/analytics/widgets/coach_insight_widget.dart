import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/features/analytics/data/coach_insight_service.dart';

class CoachInsightWidget extends StatelessWidget {
  final CoachInsight insight;
  final bool slim;

  const CoachInsightWidget({super.key, required this.insight, this.slim = false});

  @override
  Widget build(BuildContext context) {
    return slim ? _buildSlimBanner(context) : _buildFullCard(context);
  }

  Widget _buildSlimBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.brandSurface : const Color(0xFFF3EFFE);
    final textColor = isDark ? Colors.white : const Color(0xFF3C3489);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(left: BorderSide(color: AppColors.brand, width: 3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              insight.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.brandSurface : const Color(0xFFF3EFFE);
    final messageColor = isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF3C3489);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 100),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(left: BorderSide(color: AppColors.brand, width: 3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              insight.typeLabel,
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight.message,
            style: TextStyle(
              color: messageColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

