import 'dart:math';

class AvatarConfig {
  // ── Cara ──────────────────────────────────────────────────────────────────
  final String bodyShape;        // round | oval | square | hexagon
  final String bodyColor;        // hex skin tone
  final int backgroundColorIndex; // 0-7

  // ── Ojos ──────────────────────────────────────────────────────────────────
  final String eyeStyle;   // default | happy | wink | closed | cry | dizzy | angry | tired
  final String eyeColor;   // hex sclera
  final String pupilColor; // hex pupil
  final bool eyesWide;

  // ── Cejas ─────────────────────────────────────────────────────────────────
  final String eyebrowStyle; // curved | straight | thick | angry
  final String eyebrowColor; // hex

  // ── Nariz ─────────────────────────────────────────────────────────────────
  final String noseStyle; // button | round | pointed | long
  final String noseColor; // hex

  // ── Boca ──────────────────────────────────────────────────────────────────
  final String mouthStyle; // smile | grin | grimace | kiss | surprised | tongue |
                            // twinkle | serious | sad | neutral | concerned-teeth | concerned
  final String mouthColor; // hex

  // ── Pelo ──────────────────────────────────────────────────────────────────
  // Short: buzz | crew | undercut | quiff | pompadour | side-part | messy |
  //        slicked | pixie | fade | textured | cornrows | wavy-short
  // Long:  straight | wavy | curly | braids | ponytail | bun | half-bun | shag | fringe
  // Special: bald | afro | mohawk | spiky
  final String hairStyle;
  final String hairColor; // hex

  // ── Vello facial ──────────────────────────────────────────────────────────
  // none | beard-huge | beard-large | beard-long |
  // moustache-chevron | moustache-handlebar | moustache-horseshoe
  final String facialHairStyle;
  final String facialHairColor; // hex

  // ── Ropa ──────────────────────────────────────────────────────────────────
  // hoodie | shirt | sweater | t-shirt-crew | t-shirt-v | t-shirt-normal | turtleneck
  final String clothingStyle;
  final String clothingColor; // hex

  // ── Gorro ─────────────────────────────────────────────────────────────────
  // none | cap | hat | hijab | turban | winter-cap
  final String hatStyle;

  // ── Accesorios ────────────────────────────────────────────────────────────
  final List<String> accessories; // glasses | earrings | scar
  final String accessoryColor;    // hex (principalmente para gafas)

  const AvatarConfig({
    required this.bodyShape,
    required this.bodyColor,
    required this.backgroundColorIndex,
    required this.eyeStyle,
    required this.eyeColor,
    required this.pupilColor,
    required this.eyesWide,
    required this.eyebrowStyle,
    required this.eyebrowColor,
    required this.noseStyle,
    required this.noseColor,
    required this.mouthStyle,
    required this.mouthColor,
    required this.hairStyle,
    required this.hairColor,
    required this.facialHairStyle,
    required this.facialHairColor,
    required this.clothingStyle,
    required this.clothingColor,
    required this.hatStyle,
    required this.accessories,
    required this.accessoryColor,
  });

  // ── Defaults ───────────────────────────────────────────────────────────────

  static const AvatarConfig defaults = AvatarConfig(
    bodyShape: 'round',
    bodyColor: '#FFD1B3',
    backgroundColorIndex: 2,
    eyeStyle: 'default',
    eyeColor: '#FFFFFF',
    pupilColor: '#3B2314',
    eyesWide: false,
    eyebrowStyle: 'curved',
    eyebrowColor: '#5C3317',
    noseStyle: 'button',
    noseColor: '#F5B8A0',
    mouthStyle: 'smile',
    mouthColor: '#C45F5F',
    hairStyle: 'crew',
    hairColor: '#2C1810',
    facialHairStyle: 'none',
    facialHairColor: '#5C3317',
    clothingStyle: 'hoodie',
    clothingColor: '#8E24AA',
    hatStyle: 'none',
    accessories: [],
    accessoryColor: '#555555',
  );

  // ── copyWith ───────────────────────────────────────────────────────────────

  AvatarConfig copyWith({
    String? bodyShape,
    String? bodyColor,
    int? backgroundColorIndex,
    String? eyeStyle,
    String? eyeColor,
    String? pupilColor,
    bool? eyesWide,
    String? eyebrowStyle,
    String? eyebrowColor,
    String? noseStyle,
    String? noseColor,
    String? mouthStyle,
    String? mouthColor,
    String? hairStyle,
    String? hairColor,
    String? facialHairStyle,
    String? facialHairColor,
    String? clothingStyle,
    String? clothingColor,
    String? hatStyle,
    List<String>? accessories,
    String? accessoryColor,
  }) {
    return AvatarConfig(
      bodyShape: bodyShape ?? this.bodyShape,
      bodyColor: bodyColor ?? this.bodyColor,
      backgroundColorIndex: backgroundColorIndex ?? this.backgroundColorIndex,
      eyeStyle: eyeStyle ?? this.eyeStyle,
      eyeColor: eyeColor ?? this.eyeColor,
      pupilColor: pupilColor ?? this.pupilColor,
      eyesWide: eyesWide ?? this.eyesWide,
      eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
      eyebrowColor: eyebrowColor ?? this.eyebrowColor,
      noseStyle: noseStyle ?? this.noseStyle,
      noseColor: noseColor ?? this.noseColor,
      mouthStyle: mouthStyle ?? this.mouthStyle,
      mouthColor: mouthColor ?? this.mouthColor,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      facialHairStyle: facialHairStyle ?? this.facialHairStyle,
      facialHairColor: facialHairColor ?? this.facialHairColor,
      clothingStyle: clothingStyle ?? this.clothingStyle,
      clothingColor: clothingColor ?? this.clothingColor,
      hatStyle: hatStyle ?? this.hatStyle,
      accessories: accessories ?? this.accessories,
      accessoryColor: accessoryColor ?? this.accessoryColor,
    );
  }

  // ── Serialización ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'bodyShape': bodyShape,
        'bodyColor': bodyColor,
        'backgroundColorIndex': backgroundColorIndex,
        'eyeStyle': eyeStyle,
        'eyeColor': eyeColor,
        'pupilColor': pupilColor,
        'eyesWide': eyesWide,
        'eyebrowStyle': eyebrowStyle,
        'eyebrowColor': eyebrowColor,
        'noseStyle': noseStyle,
        'noseColor': noseColor,
        'mouthStyle': mouthStyle,
        'mouthColor': mouthColor,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'facialHairStyle': facialHairStyle,
        'facialHairColor': facialHairColor,
        'clothingStyle': clothingStyle,
        'clothingColor': clothingColor,
        'hatStyle': hatStyle,
        'accessories': accessories,
        'accessoryColor': accessoryColor,
      };

  factory AvatarConfig.fromMap(Map<String, dynamic> m) => AvatarConfig(
        bodyShape: m['bodyShape'] as String? ?? defaults.bodyShape,
        bodyColor: m['bodyColor'] as String? ?? defaults.bodyColor,
        backgroundColorIndex:
            m['backgroundColorIndex'] as int? ?? defaults.backgroundColorIndex,
        eyeStyle: m['eyeStyle'] as String? ?? defaults.eyeStyle,
        eyeColor: m['eyeColor'] as String? ?? defaults.eyeColor,
        pupilColor: m['pupilColor'] as String? ?? defaults.pupilColor,
        eyesWide: m['eyesWide'] as bool? ?? defaults.eyesWide,
        eyebrowStyle: m['eyebrowStyle'] as String? ?? defaults.eyebrowStyle,
        eyebrowColor: m['eyebrowColor'] as String? ?? defaults.eyebrowColor,
        noseStyle: m['noseStyle'] as String? ?? defaults.noseStyle,
        noseColor: m['noseColor'] as String? ?? defaults.noseColor,
        mouthStyle: m['mouthStyle'] as String? ?? defaults.mouthStyle,
        mouthColor: m['mouthColor'] as String? ?? defaults.mouthColor,
        hairStyle: m['hairStyle'] as String? ?? defaults.hairStyle,
        hairColor: m['hairColor'] as String? ?? defaults.hairColor,
        facialHairStyle:
            m['facialHairStyle'] as String? ?? defaults.facialHairStyle,
        facialHairColor:
            m['facialHairColor'] as String? ?? defaults.facialHairColor,
        clothingStyle: m['clothingStyle'] as String? ?? defaults.clothingStyle,
        clothingColor: m['clothingColor'] as String? ?? defaults.clothingColor,
        hatStyle: m['hatStyle'] as String? ?? defaults.hatStyle,
        accessories:
            List<String>.from(m['accessories'] as List? ?? []),
        accessoryColor:
            m['accessoryColor'] as String? ?? defaults.accessoryColor,
      );

  // ── Random ─────────────────────────────────────────────────────────────────

  factory AvatarConfig.random() {
    final rng = Random();
    T pick<T>(List<T> list) => list[rng.nextInt(list.length)];

    final hat = pick(AvatarPalette.hatStyles);
    final facial = pick(AvatarPalette.facialHairStyles);
    final accList = rng.nextBool()
        ? (hat == 'none' ? ['glasses'] : <String>[])
        : <String>[];

    return AvatarConfig(
      bodyShape: pick(AvatarPalette.bodyShapes),
      bodyColor: pick(AvatarPalette.skinTones),
      backgroundColorIndex: rng.nextInt(8),
      eyeStyle: pick(AvatarPalette.eyeStyles),
      eyeColor: '#FFFFFF',
      pupilColor: pick(AvatarPalette.pupilColors),
      eyesWide: rng.nextBool(),
      eyebrowStyle: pick(AvatarPalette.eyebrowStyles),
      eyebrowColor: pick(AvatarPalette.hairColors),
      noseStyle: pick(AvatarPalette.noseStyles),
      noseColor: pick(AvatarPalette.skinTones),
      mouthStyle: pick(AvatarPalette.mouthStyles),
      mouthColor: pick(AvatarPalette.mouthColors),
      hairStyle: hat != 'none' ? 'buzz' : pick(AvatarPalette.hairStyles),
      hairColor: pick(AvatarPalette.hairColors),
      facialHairStyle: facial,
      facialHairColor: pick(AvatarPalette.hairColors),
      clothingStyle: pick(AvatarPalette.clothingStyles),
      clothingColor: pick(AvatarPalette.clothingColors),
      hatStyle: hat,
      accessories: accList,
      accessoryColor: pick(AvatarPalette.accessoryColors),
    );
  }
}

// ── Palettes ────────────────────────────────────────────────────────────────

class AvatarPalette {
  static const List<String> bodyShapes = ['round', 'oval', 'square', 'hexagon'];

  static const List<String> backgroundColors = [
    '#9BC5FF', // Azul
    '#C2E3A1', // Verde
    '#FD9DAA', // Rosa
    '#E5B1FF', // Lila
    '#FFEAA1', // Amarillo
    '#FFD4A1', // Naranja
    '#A1EFE5', // Turquesa
    '#D4D4D4', // Gris
  ];

  static const List<String> skinTones = [
    '#FDDBB4', '#F5C5A3', '#E8B399', '#D4956A', '#C07F50', '#8D5524',
  ];

  static const List<String> hairColors = [
    '#2C1810', '#5C3317', '#A0522D', '#D2691E', '#DAA520',
    '#F4E04D', '#C0392B', '#E91E8C', '#4169E1', '#228B22',
  ];

  static const List<String> pupilColors = [
    '#3B2314', '#1A3A6B', '#1B5E20', '#7B1FA2', '#000000',
  ];

  static const List<String> mouthColors = [
    '#C45F5F', '#E07070', '#D84D4D', '#B03030',
  ];

  static const List<String> eyeStyles = [
    'default', 'happy', 'wink', 'closed', 'cry', 'dizzy', 'angry', 'tired',
  ];

  static const List<String> eyebrowStyles = [
    'curved', 'straight', 'thick', 'angry',
  ];

  static const List<String> noseStyles = ['button', 'round', 'pointed', 'long'];

  static const List<String> mouthStyles = [
    'smile', 'grin', 'grimace', 'kiss', 'surprised', 'tongue',
    'twinkle', 'serious', 'sad', 'neutral', 'concerned-teeth', 'concerned',
  ];

  static const List<String> hairStyles = [
    // Short (13)
    'buzz', 'crew', 'undercut', 'quiff', 'pompadour',
    'side-part', 'messy', 'slicked', 'pixie', 'fade',
    'textured', 'cornrows', 'wavy-short',
    // Long (9)
    'straight', 'wavy', 'curly', 'braids', 'ponytail',
    'bun', 'half-bun', 'shag', 'fringe',
    // Special (4)
    'bald', 'afro', 'mohawk', 'spiky',
  ];

  static const List<String> facialHairStyles = [
    'none',
    'beard-huge', 'beard-large', 'beard-long',
    'moustache-chevron', 'moustache-handlebar', 'moustache-horseshoe',
  ];

  static const List<String> clothingStyles = [
    'hoodie', 'shirt', 'sweater', 't-shirt-crew', 't-shirt-v',
    't-shirt-normal', 'turtleneck',
  ];

  static const List<String> clothingColors = [
    '#000066', '#DBDBE6', '#2384F5', '#80C43B',
    '#FFCA00', '#FB344F', '#FF64C8', '#AE0BFF',
  ];

  static const List<String> hatStyles = [
    'none', 'cap', 'hat', 'hijab', 'turban', 'winter-cap',
  ];

  static const List<String> accessoryColors = [
    '#555555', '#000066', '#DBDBE6', '#2384F5',
    '#FFCA00', '#FB344F', '#FF64C8', '#AE0BFF', '#80C43B',
  ];
}
