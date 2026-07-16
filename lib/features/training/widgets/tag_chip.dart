import 'package:flutter/material.dart';
import 'package:running_laps/core/constants/training_tags.dart';
import 'package:running_laps/core/theme/app_theme.dart';

class TagChip extends StatelessWidget {
  final String tagName;
  final bool small;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TagChip({
    super.key,
    required this.tagName,
    this.small = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final style = TrainingTags.styleForTag(tagName, context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 12,
          vertical: small ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          border: style.border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tagName,
              style: TextStyle(
                color: style.text,
                fontSize: small ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close_rounded,
                  size: small ? 14 : 16,
                  color: style.text.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
