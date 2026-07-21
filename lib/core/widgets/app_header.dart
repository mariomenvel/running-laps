import 'package:flutter/material.dart';
import 'package:running_laps/config/app_theme.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;
  final bool showBottomDivider;
  final Widget? title;
  final Widget? leading;
  final Widget? trailing;

  const AppHeader({
    super.key,
    this.onTapLeft,
    this.onTapRight,
    this.showBottomDivider = true,
    this.title,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (ShellEmbeddingScope.isEmbedded(context)) return const SizedBox.shrink();
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: topPadding),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // --- LOGO / LEADING ---
                leading ?? GestureDetector(
                  onTap: onTapLeft,
                  child: const CircleAvatar(
                    radius: 22.0,
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
                  child: AvatarHelper.construirImagenPerfil(radius: 20.0),
                ),
              ],
            ),
          ),

          if (showBottomDivider)
            Container(height: 0.5, color: AppColors.borderOf(context)),
        ],
      ),
    );
  }
}

