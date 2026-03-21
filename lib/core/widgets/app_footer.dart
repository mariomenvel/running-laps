import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/theme/app_colors.dart';

class AppFooter extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const AppFooter({Key? key, required this.onTap, this.isLoading = false})
      : super(key: key);

  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter>
    with SingleTickerProviderStateMixin {
  static const Color _bgGradientColor = Color(0xFFF9F5FB);
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Start pulse animation if not loading
    if (!widget.isLoading) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AppFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _pulseController.stop();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.9);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
    if (!widget.isLoading) {
      widget.onTap();
    }
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? null : const RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.2,
          colors: <Color>[_bgGradientColor, Colors.white],
          stops: <double>[0.0, 1.0],
        ),
        color: isDark ? Theme.of(context).colorScheme.surface : null,
        image: isDark ? null : const DecorationImage(
          image: AssetImage('assets/images/fondo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(height: 0.3, color: Theme.of(context).colorScheme.outline),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 10.0,
              horizontal: 40.0,
            ),
            child: _buildButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : _onTapDown,
      onTapUp: widget.isLoading ? null : _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isLoading ? 1.0 : _scale * _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(15.0),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surface,
                  ],
                  stops: const [0.0, 1.0],
                ),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Tema.brandPurple.withOpacity(0.2),
                    blurRadius: 20.0,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.transparent
                        : Colors.black.withOpacity(0.08),
                    blurRadius: 15.0,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Tema.brandPurple),
                      ),
                    )
                  : const Icon(Icons.play_arrow, color: Tema.brandPurple, size: 40.0),
            ),
          );
        },
      ),
    );
  }
}
