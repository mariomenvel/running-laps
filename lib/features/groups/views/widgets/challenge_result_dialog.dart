import 'package:flutter/material.dart';
import '../../../../app/tema.dart';
import '../../data/result_notification_model.dart';
import '../../data/enums.dart';

class ChallengeResultDialog extends StatelessWidget {
  final GroupResultNotification notification;
  final VoidCallback onClosed;

  const ChallengeResultDialog({
    Key? key,
    required this.notification,
    required this.onClosed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Section with Gradient and Icon
              _buildHeader(),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      "¡Enhorabuena!",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Tema.brandPurple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      notification.hasBadge 
                        ? "Has completado el objetivo del reto y ganado un logro."
                        : "Has finalizado el reto en el podio.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Detail Card
                    _buildDetailCard(),
                    
                    const SizedBox(height: 32),
                    
                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: onClosed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Tema.brandPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: Tema.brandPurple.withOpacity(0.4),
                        ),
                        child: const Text(
                          "¡Genial!",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    Color iconColor;
    IconData icon;
    List<Color> gradient;

    if (notification.medal != null) {
      switch (notification.medal!) {
        case MedalType.gold:
          iconColor = const Color(0xFFFFD700);
          icon = Icons.emoji_events_rounded;
          gradient = [const Color(0xFFFFD700), const Color(0xFFFFA000)];
          break;
        case MedalType.silver:
          iconColor = const Color(0xFFC0C0C0);
          icon = Icons.emoji_events_rounded;
          gradient = [const Color(0xFFE0E0E0), const Color(0xFF9E9E9E)];
          break;
        case MedalType.bronze:
          iconColor = const Color(0xFFCD7F32);
          icon = Icons.emoji_events_rounded;
          gradient = [const Color(0xFFD7CCC8), const Color(0xFF8D6E63)];
          break;
      }
    } else {
      iconColor = Colors.green.shade400;
      icon = Icons.verified_rounded;
      gradient = [Colors.green.shade300, Colors.green.shade600];
    }

    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient.map((c) => c.withOpacity(0.1)).toList(),
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative Rings
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.2), width: 2),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withOpacity(0.4), width: 2),
              ),
            ),
            
            // Icon
            Icon(icon, size: 60, color: iconColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildRow(Icons.groups_rounded, notification.groupName),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildRow(Icons.timer_outlined, notification.challengeTitle),
          if (notification.rank != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _buildRow(Icons.format_list_numbered_rounded, "Posición #${notification.rank}"),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
