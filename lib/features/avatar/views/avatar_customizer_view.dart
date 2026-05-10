import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/widgets/shell_embedding_scope.dart';
import 'package:running_laps/core/widgets/main_shell.dart';
import '../models/avatar_config.dart';
import '../services/avatar_generator.dart';

// ── Main screen ───────────────────────────────────────────────────────────────

class AvatarCustomizerView extends StatefulWidget {
  final AvatarConfig? initialConfig;
  const AvatarCustomizerView({super.key, this.initialConfig});

  @override
  State<AvatarCustomizerView> createState() => _AvatarCustomizerViewState();
}

class _AvatarCustomizerViewState extends State<AvatarCustomizerView> {
  late AvatarConfig _config;
  bool _saving = false;
  int _tab = 0;

  static const _tabs = [
    'Cara', 'Ojos', 'Cejas', 'Nariz', 'Boca',
    'Pelo', 'Barba', 'Ropa', 'Gorro', 'Accesorios', 'Fondo',
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? AvatarConfig.defaults;
  }

  void _update(AvatarConfig c) => setState(() => _config = c);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'profilePicType': 'generative_avatar',
        'generativeAvatarConfig': _config.toMap(),
      }, SetOptions(merge: true));
      if (mounted) {
        ModernSnackBar.showSuccess(context, 'Avatar guardado');
        if (ShellEmbeddingScope.isEmbedded(context)) {
          MainShell.shellKey.currentState?.navigateBack();
        } else {
          Navigator.pop(context, _config);
        }
      }
    } catch (e) {
      if (mounted) ModernSnackBar.showError(context, 'Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _AvatarHeader(
              onBack: ShellEmbeddingScope.isEmbedded(context)
                  ? () => MainShell.shellKey.currentState?.navigateBack()
                  : () => Navigator.pop(context),
              onShuffle: () => _update(AvatarConfig.random()),
              onSave: _saving ? null : _save,
              saving: _saving,
            ),
            _AvatarPreview(config: _config),
            _CategoryTabs(
              tabs: _tabs,
              selected: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
            Divider(height: 0.5, thickness: 0.5, color: AppColors.borderOf(context)),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: _buildTab(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 0:  return _FaceTab(config: _config, onChanged: _update);
      case 1:  return _EyesTab(config: _config, onChanged: _update);
      case 2:  return _EyebrowsTab(config: _config, onChanged: _update);
      case 3:  return _NoseTab(config: _config, onChanged: _update);
      case 4:  return _MouthTab(config: _config, onChanged: _update);
      case 5:  return _HairTab(config: _config, onChanged: _update);
      case 6:  return _FacialHairTab(config: _config, onChanged: _update);
      case 7:  return _ClothingTab(config: _config, onChanged: _update);
      case 8:  return _HatTab(config: _config, onChanged: _update);
      case 9:  return _AccessoriesTab(config: _config, onChanged: _update);
      case 10: return _BackgroundTab(config: _config, onChanged: _update);
      default: return const SizedBox();
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onShuffle;
  final VoidCallback? onSave;
  final bool saving;

  const _AvatarHeader({
    required this.onBack,
    required this.onShuffle,
    required this.onSave,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded,
                  size: 28, color: AppColors.textPrimary(context)),
              onPressed: onBack,
              splashRadius: 20,
            ),
            Expanded(
              child: Text(
                'PERSONALIZA TU AVATAR',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.shuffle_rounded,
                  size: 22, color: AppColors.iconMutedOf(context)),
              onPressed: onShuffle,
              splashRadius: 20,
              tooltip: 'Aleatorio',
            ),
            saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.m),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.brand, strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: onSave,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Guardar',
                      style: AppTypography.body.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar preview ────────────────────────────────────────────────────────────

class _AvatarPreview extends StatelessWidget {
  final AvatarConfig config;
  const _AvatarPreview({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      color: AppColors.background(context),
      alignment: Alignment.center,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface2Of(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: SvgPicture.string(
            AvatarGenerator.generateSVG(config),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

// ── Category tabs ─────────────────────────────────────────────────────────────

class _CategoryTabs extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onTap;

  const _CategoryTabs({
    required this.tabs,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l, vertical: AppSpacing.s),
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(right: AppSpacing.s),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[i],
                style: AppTypography.small.copyWith(
                  color: active ? Colors.white : AppColors.iconMutedOf(context),
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.l, top: AppSpacing.l, bottom: AppSpacing.s),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.small.copyWith(
          color: AppColors.iconMutedOf(context),
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

/// 3-column grid of selectable options, each showing an SVG avatar preview.
///
/// [configBuilder] receives the option value and returns the preview config
/// (current config with only that field swapped).
class _PreviewGrid extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final AvatarConfig Function(String) configBuilder;
  final String Function(String)? label;

  const _PreviewGrid({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.configBuilder,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.s,
          crossAxisSpacing: AppSpacing.s,
          childAspectRatio: 0.95,
        ),
        itemCount: options.length,
        itemBuilder: (context, i) {
          final opt = options[i];
          final isSel = opt == selected;
          final previewConfig = configBuilder(opt);
          return RepaintBoundary(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppColors.brand.withOpacity(0.09)
                      : AppColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? AppColors.brand : AppColors.borderOf(context),
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipOval(
                      child: SvgPicture.string(
                        AvatarGenerator.generateSVG(previewConfig),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label != null ? label!(opt) : opt,
                      style: AppTypography.small.copyWith(
                        color: isSel
                            ? AppColors.brand
                            : AppColors.iconMutedOf(context),
                        fontWeight:
                            isSel ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal scroll of color circles (36 × 36)
class _ColorStrip extends StatelessWidget {
  final List<String> palette;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ColorStrip({
    required this.palette,
    required this.selected,
    required this.onChanged,
  });

  static Color _toColor(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        itemCount: palette.length,
        itemBuilder: (_, i) {
          final hex = palette[i];
          final isSel = hex == selected;
          return GestureDetector(
            onTap: () => onChanged(hex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: AppSpacing.s),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _toColor(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: _toColor(hex).withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                        const BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                        ),
                      ]
                    : [
                        const BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                        ),
                      ],
              ),
              child: isSel
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal scroll of background color circles (by index)
class _BgColorStrip extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _BgColorStrip({required this.selectedIndex, required this.onChanged});

  static Color _toColor(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        itemCount: AvatarPalette.backgroundColors.length,
        itemBuilder: (_, i) {
          final color = _toColor(AvatarPalette.backgroundColors[i]);
          final isSel = i == selectedIndex;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: AppSpacing.s),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                            color: color.withOpacity(0.5), blurRadius: 8),
                        const BoxShadow(color: Colors.black26, blurRadius: 4),
                      ]
                    : [const BoxShadow(color: Colors.black12, blurRadius: 2)],
              ),
              child: isSel
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// Simple iOS-style toggle row
class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l, vertical: AppSpacing.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body
                .copyWith(color: AppColors.textPrimary(context)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.brand,
          ),
        ],
      ),
    );
  }
}

/// Multi-select accessory toggle chips
class _AccessoryChips extends StatelessWidget {
  final List<String> all;
  final Map<String, String> labels;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _AccessoryChips({
    required this.all,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Wrap(
        spacing: AppSpacing.s,
        runSpacing: AppSpacing.s,
        children: all.map((acc) {
          final isOn = selected.contains(acc);
          return GestureDetector(
            onTap: () {
              final next = List<String>.from(selected);
              isOn ? next.remove(acc) : next.add(acc);
              onChanged(next);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m, vertical: AppSpacing.s),
              decoration: BoxDecoration(
                color: isOn
                    ? AppColors.brand.withOpacity(0.09)
                    : AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOn ? AppColors.brand : AppColors.borderOf(context),
                  width: isOn ? 1.5 : 1,
                ),
              ),
              child: Text(
                labels[acc] ?? acc,
                style: AppTypography.small.copyWith(
                  color:
                      isOn ? AppColors.brand : AppColors.textPrimary(context),
                  fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

class _FaceTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _FaceTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Forma de cabeza'),
      _PreviewGrid(
        options: AvatarPalette.bodyShapes,
        selected: config.bodyShape,
        configBuilder: (s) => config.copyWith(bodyShape: s),
        onChanged: (v) => onChanged(config.copyWith(bodyShape: v)),
        label: (s) => const {
          'round': 'Redonda', 'oval': 'Oval',
          'square': 'Cuadrada', 'hexagon': 'Hexágono',
        }[s] ?? s,
      ),
      const _Label('Tono de piel'),
      _ColorStrip(
        palette: AvatarPalette.skinTones,
        selected: config.bodyColor,
        onChanged: (v) => onChanged(config.copyWith(bodyColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _EyesTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _EyesTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Expresión'),
      _PreviewGrid(
        options: AvatarPalette.eyeStyles,
        selected: config.eyeStyle,
        configBuilder: (s) => config.copyWith(eyeStyle: s),
        onChanged: (v) => onChanged(config.copyWith(eyeStyle: v)),
        label: (s) => const {
          'default': 'Normal', 'happy': 'Feliz', 'wink': 'Guiño',
          'closed': 'Cerrados', 'cry': 'Llorando',
          'dizzy': 'Mareado', 'angry': 'Enfadado', 'tired': 'Cansado',
        }[s] ?? s,
      ),
      const _Label('Color de pupila'),
      _ColorStrip(
        palette: AvatarPalette.pupilColors,
        selected: config.pupilColor,
        onChanged: (v) => onChanged(config.copyWith(pupilColor: v)),
      ),
      _ToggleRow(
        label: 'Ojos más separados',
        value: config.eyesWide,
        onChanged: (v) => onChanged(config.copyWith(eyesWide: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _EyebrowsTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _EyebrowsTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Estilo'),
      _PreviewGrid(
        options: AvatarPalette.eyebrowStyles,
        selected: config.eyebrowStyle,
        configBuilder: (s) => config.copyWith(eyebrowStyle: s),
        onChanged: (v) => onChanged(config.copyWith(eyebrowStyle: v)),
        label: (s) => const {
          'curved': 'Arqueadas', 'straight': 'Rectas',
          'thick': 'Gruesas', 'angry': 'Enfadadas',
        }[s] ?? s,
      ),
      const _Label('Color'),
      _ColorStrip(
        palette: AvatarPalette.hairColors,
        selected: config.eyebrowColor,
        onChanged: (v) => onChanged(config.copyWith(eyebrowColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _NoseTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _NoseTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Forma'),
      _PreviewGrid(
        options: AvatarPalette.noseStyles,
        selected: config.noseStyle,
        configBuilder: (s) => config.copyWith(noseStyle: s),
        onChanged: (v) => onChanged(config.copyWith(noseStyle: v)),
        label: (s) => const {
          'button': 'Botón', 'round': 'Redonda',
          'pointed': 'Puntiaguda', 'long': 'Larga',
        }[s] ?? s,
      ),
      const _Label('Tono'),
      _ColorStrip(
        palette: AvatarPalette.skinTones,
        selected: config.noseColor,
        onChanged: (v) => onChanged(config.copyWith(noseColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _MouthTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _MouthTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Expresión'),
      _PreviewGrid(
        options: AvatarPalette.mouthStyles,
        selected: config.mouthStyle,
        configBuilder: (s) => config.copyWith(mouthStyle: s),
        onChanged: (v) => onChanged(config.copyWith(mouthStyle: v)),
        label: (s) => const {
          'smile': 'Sonrisa', 'grin': 'Amplia',
          'grimace': 'Mueca', 'kiss': 'Beso',
          'surprised': 'Sorpresa', 'tongue': 'Lengua',
          'twinkle': 'Brillo', 'serious': 'Serio',
          'sad': 'Triste', 'neutral': 'Neutral',
          'concerned-teeth': 'Preocupado', 'concerned': 'Inquieto',
        }[s] ?? s,
      ),
      const _Label('Color'),
      _ColorStrip(
        palette: AvatarPalette.mouthColors,
        selected: config.mouthColor,
        onChanged: (v) => onChanged(config.copyWith(mouthColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _HairTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _HairTab({required this.config, required this.onChanged});

  static const _labels = {
    'buzz': 'Rapado', 'crew': 'Crew cut', 'undercut': 'Undercut',
    'quiff': 'Quiff', 'pompadour': 'Pompadour', 'side-part': 'Raya lat.',
    'messy': 'Despeinado', 'slicked': 'Engominado', 'pixie': 'Pixie',
    'fade': 'Fade', 'textured': 'Texturizado', 'cornrows': 'Cornrows',
    'wavy-short': 'Ondulado',
    'straight': 'Liso', 'wavy': 'Ondulado L', 'curly': 'Rizado',
    'braids': 'Trenzas', 'ponytail': 'Cola', 'bun': 'Moño',
    'half-bun': 'Medio moño', 'shag': 'Shag', 'fringe': 'Flequillo',
    'bald': 'Calvo', 'afro': 'Afro', 'mohawk': 'Mohawk', 'spiky': 'Puntas',
  };

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Estilo'),
      _PreviewGrid(
        options: AvatarPalette.hairStyles,
        selected: config.hairStyle,
        configBuilder: (s) => config.copyWith(hairStyle: s),
        onChanged: (v) => onChanged(config.copyWith(hairStyle: v)),
        label: (s) => _labels[s] ?? s,
      ),
      if (config.hairStyle != 'bald') ...[
        const _Label('Color'),
        _ColorStrip(
          palette: AvatarPalette.hairColors,
          selected: config.hairColor,
          onChanged: (v) => onChanged(config.copyWith(hairColor: v)),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _FacialHairTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _FacialHairTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Tipo'),
      _PreviewGrid(
        options: AvatarPalette.facialHairStyles,
        selected: config.facialHairStyle,
        configBuilder: (s) => config.copyWith(facialHairStyle: s),
        onChanged: (v) => onChanged(config.copyWith(facialHairStyle: v)),
        label: (s) => const {
          'none': 'Ninguna', 'beard-huge': 'Barba gde',
          'beard-large': 'Barba med', 'beard-long': 'Barba cta',
          'moustache-chevron': 'Chevron',
          'moustache-handlebar': 'Handlebar',
          'moustache-horseshoe': 'Herradura',
        }[s] ?? s,
      ),
      if (config.facialHairStyle != 'none') ...[
        const _Label('Color'),
        _ColorStrip(
          palette: AvatarPalette.hairColors,
          selected: config.facialHairColor,
          onChanged: (v) => onChanged(config.copyWith(facialHairColor: v)),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _ClothingTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _ClothingTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Prenda'),
      _PreviewGrid(
        options: AvatarPalette.clothingStyles,
        selected: config.clothingStyle,
        configBuilder: (s) => config.copyWith(clothingStyle: s),
        onChanged: (v) => onChanged(config.copyWith(clothingStyle: v)),
        label: (s) => const {
          'hoodie': 'Sudadera', 'shirt': 'Camisa',
          'sweater': 'Jersey', 't-shirt-crew': 'Camiseta',
          't-shirt-v': 'Camiseta V',
          't-shirt-normal': 'Básica', 'turtleneck': 'Cuello alto',
        }[s] ?? s,
      ),
      const _Label('Color'),
      _ColorStrip(
        palette: AvatarPalette.clothingColors,
        selected: config.clothingColor,
        onChanged: (v) => onChanged(config.copyWith(clothingColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _HatTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _HatTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Gorro / sombrero'),
      _PreviewGrid(
        options: AvatarPalette.hatStyles,
        selected: config.hatStyle,
        configBuilder: (s) => config.copyWith(hatStyle: s),
        onChanged: (v) => onChanged(config.copyWith(hatStyle: v)),
        label: (s) => const {
          'none': 'Ninguno', 'cap': 'Gorra',
          'hat': 'Sombrero', 'hijab': 'Hijab',
          'turban': 'Turbante', 'winter-cap': 'Invierno',
        }[s] ?? s,
      ),
      if (config.hatStyle != 'none')
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.l, AppSpacing.m, AppSpacing.l, 0),
          child: Text(
            'El gorro usa el color del pelo.',
            style: AppTypography.small
                .copyWith(color: AppColors.iconMutedOf(context)),
          ),
        ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _AccessoriesTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _AccessoriesTab({required this.config, required this.onChanged});

  static const _all = ['glasses', 'earrings', 'scar'];
  static const _labels = {
    'glasses': 'Gafas', 'earrings': 'Pendientes', 'scar': 'Cicatriz',
  };

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Activar'),
      _AccessoryChips(
        all: _all,
        labels: _labels,
        selected: config.accessories,
        onChanged: (next) => onChanged(config.copyWith(accessories: next)),
      ),
      if (config.accessories.contains('glasses')) ...[
        const _Label('Color de gafas'),
        _ColorStrip(
          palette: AvatarPalette.accessoryColors,
          selected: config.accessoryColor,
          onChanged: (v) => onChanged(config.copyWith(accessoryColor: v)),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _BackgroundTab extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _BackgroundTab({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const _Label('Color de fondo'),
      _BgColorStrip(
        selectedIndex: config.backgroundColorIndex,
        onChanged: (i) => onChanged(config.copyWith(backgroundColorIndex: i)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}
