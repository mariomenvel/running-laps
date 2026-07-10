import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import '../../data/models/result_notification_model.dart';
import '../../data/models/enums.dart';
import 'package:confetti/confetti.dart';

class ChallengeResultDialog extends StatefulWidget {
  final GroupResultNotification notification;
  final VoidCallback onClosed;

  const ChallengeResultDialog({
    Key? key,
    required this.notification,
    required this.onClosed,
  }) : super(key: key);

  @override
  State<ChallengeResultDialog> createState() => _ChallengeResultDialogState();
}

class _ChallengeResultDialogState extends State<ChallengeResultDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Si es meta completada o tiene medalla de oro/plata, celebramos con confeti
    if (widget.notification.type == GroupNotificationType.goalMet || 
        widget.notification.medal == MedalType.gold ||
        widget.notification.medal == MedalType.silver) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Dialog(
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
                    color: Colors.black.withValues(alpha: 0.15),
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
                          widget.notification.type == GroupNotificationType.goalMet 
                            ? "¡Meta Lograda!" 
                            : "¡Enhorabuena!",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: widget.notification.type == GroupNotificationType.goalMet 
                              ? AppColors.rpeLow 
                              : AppColors.brand,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.notification.type == GroupNotificationType.goalMet
                            ? "Has completado el objetivo de este reto. ¡Sigue así!"
                            : (widget.notification.hasBadge 
                              ? "Has completado el objetivo del reto y ganado un logro."
                              : "Has finalizado el reto en el podio."),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.iconMuted,
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
                            onPressed: widget.onClosed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.notification.type == GroupNotificationType.goalMet 
                                ? AppColors.rpeLow 
                                : AppColors.brand,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: (widget.notification.type == GroupNotificationType.goalMet 
                                ? AppColors.rpeLow 
                                : AppColors.brand).withValues(alpha: 0.4),
                            ),
                            child: Text(
                              widget.notification.type == GroupNotificationType.goalMet 
                                ? "¡VAMOS!" 
                                : "¡Genial!",
                              style: const TextStyle(
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
        ),
        
        // Confetti Widget
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            AppColors.rpeLow,
            AppColors.rest,
            AppColors.brand,
            AppColors.rpeMid,
            AppColors.brand,
            Colors.yellow,
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    Color iconColor;
    IconData icon;
    List<Color> gradient;

    if (widget.notification.type == GroupNotificationType.goalMet) {
      iconColor = AppColors.rpeMid;
      icon = Icons.stars_rounded;
      gradient = [AppColors.rpeMid, AppColors.effort];
    } else if (widget.notification.medal != null) {
      switch (widget.notification.medal!) {
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
        default:
          iconColor = const Color(0xFFCD7F32);
          icon = Icons.emoji_events_rounded;
          gradient = [const Color(0xFFD7CCC8), const Color(0xFF8D6E63)];
          break;
      }
    } else {
      iconColor = AppColors.rpeLow;
      icon = Icons.verified_rounded;
      gradient = [AppColors.rpeLow, AppColors.rpeLow];
    }

    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: gradient.first.withValues(alpha: 0.1),
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
                border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 2),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 2),
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
        color: AppColors.iconMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.iconMuted),
      ),
      child: Column(
        children: [
          _buildRow(Icons.groups_rounded, widget.notification.groupName),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _buildRow(Icons.timer_outlined, widget.notification.challengeTitle),
          if (widget.notification.rank != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _buildRow(Icons.format_list_numbered_rounded, "Posición #${widget.notification.rank}"),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.iconMuted),
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



