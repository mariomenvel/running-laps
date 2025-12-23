import 'package:flutter/material.dart';

/// Widget reutilizable para mostrar una etiqueta como chip
class TagChip extends StatelessWidget {
  final String tagName;
  final Color color;
  final bool small;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TagChip({
    Key? key,
    required this.tagName,
    required this.color,
    this.small = false,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 12,
          vertical: small ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(small ? 8 : 12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tagName,
              style: TextStyle(
                color: color,
                fontSize: small ? 11 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close_rounded,
                  size: small ? 14 : 16,
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
