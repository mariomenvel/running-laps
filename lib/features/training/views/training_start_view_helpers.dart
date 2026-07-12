// Helper widgets for TrainingStartView
import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

Widget buildTemplateButtons(BuildContext context, VoidCallback onLoadTemplate, VoidCallback onQuickTemplate) {
  return Column(
    children: [
      // Load Template Button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onLoadTemplate,
          icon: Icon(Icons.folder_open, color: AppColors.brandOf(context)),
          label: Text(
            'Cargar Plantilla',
            style: TextStyle(color: AppColors.brandOf(context), fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: AppColors.brand, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Quick Template Button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onQuickTemplate,
          icon: Icon(Icons.flash_on, color: AppColors.brandOf(context)),
          label: Text(
            'Plantilla Rápida',
            style: TextStyle(color: AppColors.brandOf(context), fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: AppColors.brand, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ],
  );
}

Widget buildContinuousRunButton(BuildContext context, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.directions_run, color: Colors.white, size: 24),
      label: const Text(
        'Carrera Continua',
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    ),
  );
}
