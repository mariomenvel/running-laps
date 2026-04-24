import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/analytics/data/coach_insight_service.dart';

class CoachInsightWidget extends StatelessWidget {
  final CoachInsight insight;
  // slim: collapses the card to a single-line 56px banner
  final bool slim;

  const CoachInsightWidget({super.key, required this.insight, this.slim = false});

  @override
  Widget build(BuildContext context) {
    return slim ? _buildSlimBanner() : _buildFullCard();
  }

  Widget _buildSlimBanner() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1530),
        border: Border(
          left: BorderSide(color: AppColors.brandPurple, width: 3),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_rounded, color: AppColors.brandPurpleLight, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.7), size: 18),
        ],
      ),
    );
  }

  Widget _buildFullCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1530),
        border: Border(
          left: BorderSide(color: AppColors.brandPurple, width: 4),
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              insight.icon,
              size: 100,
              color: AppColors.brandPurple.withOpacity(0.12),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandPurple.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.brandPurple.withOpacity(0.4)),
                ),
                child: Icon(
                  insight.icon,
                  color: AppColors.brandPurpleLight,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brandPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        insight.typeLabel,
                        style: const TextStyle(
                          color: AppColors.brandPurpleLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      insight.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight.message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

