import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;
  final bool showBottomDivider;
  final Widget? title;
  final Widget? leading;
  final Widget? trailing;

  const AppHeader({
    Key? key,
    this.onTapLeft,
    this.onTapRight,
    this.showBottomDivider = true,
    this.title,
    this.leading,
    this.trailing,
  }) : super(key: key);

  static const Color _bgGradientColor = Color(0xFFF9F5FB);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      decoration: isDark
          ? BoxDecoration(color: Theme.of(context).colorScheme.surface)
          : const BoxDecoration(
              color: Colors.white,
              image: DecorationImage(
                image: AssetImage('assets/images/fondo.png'),
                fit: BoxFit.cover,
              ),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: topPadding),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // --- LOGO / LEADING ---
                leading ?? GestureDetector(
                  onTap: onTapLeft,
                  child: const CircleAvatar(
                    radius: 24.0,
                    backgroundColor: AppColors.brand,
                    backgroundImage: AssetImage('assets/images/logo.png'),
                  ),
                ),

                // --- TITLE ---
                if (title != null) Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(child: title!),
                  ),
                ) else const Spacer(),

                // --- AVATAR / TRAILING ---
                trailing ?? GestureDetector(
                  onTap: onTapRight,
                  child: AvatarHelper.construirImagenPerfil(radius: 24.0),
                ),
              ],
            ),
          ),

          if (showBottomDivider)
            Container(height: 1.0, color: Theme.of(context).colorScheme.outline),
        ],
      ),
    );
  }
}

