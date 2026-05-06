import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/core/theme/app_theme.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import '../models/avatar_config.dart';
import '../services/avatar_generator.dart';

class AvatarCustomizerView extends StatefulWidget {
  final AvatarConfig? initialConfig;

  const AvatarCustomizerView({super.key, this.initialConfig});

  @override
  State<AvatarCustomizerView> createState() => _AvatarCustomizerViewState();
}

class _AvatarCustomizerViewState extends State<AvatarCustomizerView> {
  late AvatarConfig _config;
  bool _saving = false;
  int _activeSection = 0;

  static const _sections = [
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
        Navigator.pop(context, _config);
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
            _Header(
              onBack: () => Navigator.pop(context),
              onSave: _saving ? null : _save,
              onRandom: () => _update(AvatarConfig.random()),
              saving: _saving,
            ),
            _Preview(config: _config),
            _SectionTabs(
              sections: _sections,
              active: _activeSection,
              onTap: (i) => setState(() => _activeSection = i),
            ),
            Expanded(
              child: Container(
                color: AppColors.surfaceOf(context),
                child: _buildSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection() {
    switch (_activeSection) {
      case 0:  return _FaceSection(config: _config, onChanged: _update);
      case 1:  return _EyesSection(config: _config, onChanged: _update);
      case 2:  return _EyebrowsSection(config: _config, onChanged: _update);
      case 3:  return _NoseSection(config: _config, onChanged: _update);
      case 4:  return _MouthSection(config: _config, onChanged: _update);
      case 5:  return _HairSection(config: _config, onChanged: _update);
      case 6:  return _FacialHairSection(config: _config, onChanged: _update);
      case 7:  return _ClothingSection(config: _config, onChanged: _update);
      case 8:  return _HatSection(config: _config, onChanged: _update);
      case 9:  return _AccessoriesSection(config: _config, onChanged: _update);
      case 10: return _BackgroundSection(config: _config, onChanged: _update);
      default: return const SizedBox();
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onSave;
  final VoidCallback onRandom;
  final bool saving;

  const _Header({
    required this.onBack,
    required this.onSave,
    required this.onRandom,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface2Of(context),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: onBack,
          ),
          const Expanded(
            child: Text(
              'PERSONALIZA TU AVATAR',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded, size: 22),
            onPressed: onRandom,
            tooltip: 'Aleatorio',
          ),
          const SizedBox(width: AppSpacing.xs),
          _SaveBtn(onSave: onSave, saving: saving),
        ],
      ),
    );
  }
}

class _SaveBtn extends StatelessWidget {
  final VoidCallback? onSave;
  final bool saving;
  const _SaveBtn({required this.onSave, required this.saving});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSave,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
        decoration: BoxDecoration(
          color: onSave != null ? AppColors.brand : AppColors.iconMutedOf(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: saving
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Guardar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

// ── Preview ───────────────────────────────────────────────────────────────────

class _Preview extends StatelessWidget {
  final AvatarConfig config;
  const _Preview({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface2Of(context),
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Center(
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(80),
            boxShadow: [BoxShadow(
              color: AppColors.brand.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )],
          ),
          child: ClipOval(
            child: SvgPicture.string(
              AvatarGenerator.generateSVG(config),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section Tabs ──────────────────────────────────────────────────────────────

class _SectionTabs extends StatelessWidget {
  final List<String> sections;
  final int active;
  final ValueChanged<int> onTap;
  const _SectionTabs({required this.sections, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceOf(context),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 4),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final isActive = i == active;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: AppSpacing.s),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              decoration: BoxDecoration(
                color: isActive ? AppColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? AppColors.brand : AppColors.borderOf(context)),
              ),
              alignment: Alignment.center,
              child: Text(
                sections[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? Colors.white : AppColors.textSecondary(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _OptionRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final String Function(String)? labelOf;

  const _OptionRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            itemCount: options.length,
            itemBuilder: (_, i) {
              final opt = options[i];
              final isSel = opt == selected;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: AppSpacing.s),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.brand : AppColors.surface2Of(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSel ? AppColors.brand : AppColors.borderOf(context)),
                  ),
                  child: Text(
                    labelOf != null ? labelOf!(opt) : opt,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSel ? Colors.white : AppColors.textPrimary(context),
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final List<String> palette;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ColorRow({
    required this.label,
    required this.palette,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            itemCount: palette.length,
            itemBuilder: (_, i) {
              final hex = palette[i];
              final color = _hex(hex);
              final isSel = hex == selected;
              return GestureDetector(
                onTap: () => onChanged(hex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: AppSpacing.s),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? AppColors.brand : AppColors.borderOf(context),
                      width: isSel ? 3 : 1.5,
                    ),
                    boxShadow: isSel
                        ? [BoxShadow(color: AppColors.brand.withOpacity(0.4), blurRadius: 6)]
                        : null,
                  ),
                  child: isSel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
}

class _BgColorRow extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _BgColorRow({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Color de fondo'),
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            itemCount: AvatarPalette.backgroundColors.length,
            itemBuilder: (_, i) {
              final color = Color(int.parse(
                  'FF${AvatarPalette.backgroundColors[i].replaceFirst('#', '')}',
                  radix: 16));
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
                      color: isSel ? AppColors.brand : AppColors.borderOf(context),
                      width: isSel ? 3 : 1.5,
                    ),
                    boxShadow: isSel
                        ? [BoxShadow(color: AppColors.brand.withOpacity(0.4), blurRadius: 6)]
                        : null,
                  ),
                  child: isSel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context))),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.brand),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.l, top: AppSpacing.l, bottom: AppSpacing.s),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context),
            fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }
}

// ── Section implementations ────────────────────────────────────────────────────

class _FaceSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _FaceSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Forma de cabeza',
        options: AvatarPalette.bodyShapes,
        selected: config.bodyShape,
        onChanged: (v) => onChanged(config.copyWith(bodyShape: v)),
        labelOf: (s) => const {
          'round': 'Redonda', 'oval': 'Oval',
          'square': 'Cuadrada', 'hexagon': 'Hexágono',
        }[s] ?? s,
      ),
      _ColorRow(
        label: 'Tono de piel',
        palette: AvatarPalette.skinTones,
        selected: config.bodyColor,
        onChanged: (v) => onChanged(config.copyWith(bodyColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _EyesSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _EyesSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Expresión',
        options: AvatarPalette.eyeStyles,
        selected: config.eyeStyle,
        onChanged: (v) => onChanged(config.copyWith(eyeStyle: v)),
        labelOf: (s) => const {
          'default': 'Normal', 'happy': 'Feliz', 'wink': 'Guiño',
          'closed': 'Cerrados', 'cry': 'Llorando', 'dizzy': 'Mareado',
          'angry': 'Enfadado', 'tired': 'Cansado',
        }[s] ?? s,
      ),
      _ColorRow(
        label: 'Color de pupila',
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

class _EyebrowsSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _EyebrowsSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Estilo',
        options: AvatarPalette.eyebrowStyles,
        selected: config.eyebrowStyle,
        onChanged: (v) => onChanged(config.copyWith(eyebrowStyle: v)),
        labelOf: (s) => const {
          'curved': 'Arqueadas', 'straight': 'Rectas',
          'thick': 'Gruesas', 'angry': 'Enfadadas',
        }[s] ?? s,
      ),
      _ColorRow(
        label: 'Color',
        palette: AvatarPalette.hairColors,
        selected: config.eyebrowColor,
        onChanged: (v) => onChanged(config.copyWith(eyebrowColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _NoseSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _NoseSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Forma',
        options: AvatarPalette.noseStyles,
        selected: config.noseStyle,
        onChanged: (v) => onChanged(config.copyWith(noseStyle: v)),
        labelOf: (s) => const {
          'button': 'Botón', 'round': 'Redonda',
          'pointed': 'Puntiaguda', 'long': 'Larga',
        }[s] ?? s,
      ),
      _ColorRow(
        label: 'Tono',
        palette: AvatarPalette.skinTones,
        selected: config.noseColor,
        onChanged: (v) => onChanged(config.copyWith(noseColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _MouthSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _MouthSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Expresión',
        options: AvatarPalette.mouthStyles,
        selected: config.mouthStyle,
        onChanged: (v) => onChanged(config.copyWith(mouthStyle: v)),
        labelOf: (s) => const {
          'smile': 'Sonrisa', 'grin': 'Sonrisa amplia',
          'grimace': 'Mueca', 'kiss': 'Beso',
          'surprised': 'Sorpresa', 'tongue': 'Lengua',
          'twinkle': 'Brillo', 'serious': 'Serio',
          'sad': 'Triste', 'neutral': 'Neutral',
          'concerned-teeth': 'Preocupado dientes', 'concerned': 'Preocupado',
        }[s] ?? s,
      ),
      _ColorRow(
        label: 'Color',
        palette: AvatarPalette.mouthColors,
        selected: config.mouthColor,
        onChanged: (v) => onChanged(config.copyWith(mouthColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _HairSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _HairSection({required this.config, required this.onChanged});

  static const _labels = {
    // Short
    'buzz': 'Rapado', 'crew': 'Crew cut', 'undercut': 'Undercut',
    'quiff': 'Quiff', 'pompadour': 'Pompadour', 'side-part': 'Raya lateral',
    'messy': 'Despeinado', 'slicked': 'Engominado', 'pixie': 'Pixie',
    'fade': 'Fade', 'textured': 'Texturizado', 'cornrows': 'Trenzas cortas',
    'wavy-short': 'Ondulado corto',
    // Long
    'straight': 'Liso', 'wavy': 'Ondulado', 'curly': 'Rizado',
    'braids': 'Trenzas', 'ponytail': 'Cola', 'bun': 'Moño',
    'half-bun': 'Medio moño', 'shag': 'Shag', 'fringe': 'Flequillo',
    // Special
    'bald': 'Calvo', 'afro': 'Afro', 'mohawk': 'Mohawk', 'spiky': 'Puntas',
  };

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Estilo',
        options: AvatarPalette.hairStyles,
        selected: config.hairStyle,
        onChanged: (v) => onChanged(config.copyWith(hairStyle: v)),
        labelOf: (s) => _labels[s] ?? s,
      ),
      if (config.hairStyle != 'bald')
        _ColorRow(
          label: 'Color',
          palette: AvatarPalette.hairColors,
          selected: config.hairColor,
          onChanged: (v) => onChanged(config.copyWith(hairColor: v)),
        ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _FacialHairSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _FacialHairSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Tipo',
        options: AvatarPalette.facialHairStyles,
        selected: config.facialHairStyle,
        onChanged: (v) => onChanged(config.copyWith(facialHairStyle: v)),
        labelOf: (s) => const {
          'none': 'Ninguna',
          'beard-huge': 'Barba grande', 'beard-large': 'Barba mediana',
          'beard-long': 'Barba corta',
          'moustache-chevron': 'Bigote chevron',
          'moustache-handlebar': 'Bigote handlebar',
          'moustache-horseshoe': 'Bigote herradura',
        }[s] ?? s,
      ),
      if (config.facialHairStyle != 'none')
        _ColorRow(
          label: 'Color',
          palette: AvatarPalette.hairColors,
          selected: config.facialHairColor,
          onChanged: (v) => onChanged(config.copyWith(facialHairColor: v)),
        ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _ClothingSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _ClothingSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Prenda',
        options: AvatarPalette.clothingStyles,
        selected: config.clothingStyle,
        onChanged: (v) => onChanged(config.copyWith(clothingStyle: v)),
        labelOf: (s) => const {
          'hoodie': 'Sudadera', 'shirt': 'Camisa', 'sweater': 'Jersey',
          't-shirt-crew': 'Camiseta crew', 't-shirt-v': 'Camiseta V',
          't-shirt-normal': 'Camiseta', 'turtleneck': 'Cuello alto',
        }[s] ?? s,
      ),
      _ColorRow(
        label: 'Color',
        palette: AvatarPalette.clothingColors,
        selected: config.clothingColor,
        onChanged: (v) => onChanged(config.copyWith(clothingColor: v)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _HatSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _HatSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _OptionRow(
        label: 'Gorro / sombrero',
        options: AvatarPalette.hatStyles,
        selected: config.hatStyle,
        onChanged: (v) => onChanged(config.copyWith(hatStyle: v)),
        labelOf: (s) => const {
          'none': 'Ninguno', 'cap': 'Gorra', 'hat': 'Sombrero',
          'hijab': 'Hijab', 'turban': 'Turbante', 'winter-cap': 'Gorro invierno',
        }[s] ?? s,
      ),
      if (config.hatStyle != 'none')
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Text(
            'El gorro usa el color del pelo.',
            style: TextStyle(fontSize: 12, color: AppColors.iconMutedOf(context)),
          ),
        ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}

class _AccessoriesSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _AccessoriesSection({required this.config, required this.onChanged});

  static const _all = ['glasses', 'earrings', 'scar'];
  static const _labels = {'glasses': 'Gafas', 'earrings': 'Pendientes', 'scar': 'Cicatriz'};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        _SectionLabel('Accesorios'),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: _all.map((acc) {
            final isOn = config.accessories.contains(acc);
            return FilterChip(
              label: Text(_labels[acc] ?? acc),
              selected: isOn,
              onSelected: (_) {
                final next = List<String>.from(config.accessories);
                isOn ? next.remove(acc) : next.add(acc);
                onChanged(config.copyWith(accessories: next));
              },
              selectedColor: AppColors.brand.withOpacity(0.2),
              checkmarkColor: AppColors.brand,
              side: BorderSide(color: isOn ? AppColors.brand : AppColors.borderOf(context)),
            );
          }).toList(),
        ),
        if (config.accessories.contains('glasses')) ...[
          _ColorRow(
            label: 'Color de gafas',
            palette: AvatarPalette.accessoryColors,
            selected: config.accessoryColor,
            onChanged: (v) => onChanged(config.copyWith(accessoryColor: v)),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _BackgroundSection extends StatelessWidget {
  final AvatarConfig config;
  final ValueChanged<AvatarConfig> onChanged;
  const _BackgroundSection({required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      _BgColorRow(
        selectedIndex: config.backgroundColorIndex,
        onChanged: (i) => onChanged(config.copyWith(backgroundColorIndex: i)),
      ),
      const SizedBox(height: AppSpacing.xl),
    ]);
  }
}
