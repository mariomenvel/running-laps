import '../models/avatar_config.dart';

/// Sistema de coordenadas de referencia
/// Canvas 200×200 | Cabeza round: cx=100 cy=100 r=82 → top y=18, bottom y=182
/// Cara oval: top y=12 | square: top y=22 | hexagon: top y=18
/// Ojos: y=96 | Cejas: y=80 | Nariz: cy=116 | Boca: y=130–142 | Cuello: y=150–182
class AvatarGenerator {
  static String generateSVG(AvatarConfig c) {
    final hasHat = c.hatStyle != 'none';
    return '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
  ${_drawBackground(c)}
  ${hasHat ? '' : _drawHairBack(c)}
  ${_drawBody(c)}
  ${_drawNeck(c)}
  ${_drawClothing(c)}
  ${_drawEyes(c)}
  ${_drawEyebrows(c)}
  ${_drawNose(c)}
  ${_drawMouth(c)}
  ${hasHat ? '' : _drawHairFront(c)}
  ${_drawFacialHair(c)}
  ${_drawAccessories(c)}
  ${hasHat ? _drawHat(c) : ''}
</svg>''';
  }

  // ── Background ────────────────────────────────────────────────────────────

  static String _drawBackground(AvatarConfig c) {
    final color = AvatarPalette.backgroundColors[
        c.backgroundColorIndex.clamp(0, AvatarPalette.backgroundColors.length - 1)];
    return '<rect x="0" y="0" width="200" height="200" fill="$color" rx="16"/>';
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  static String _drawBody(AvatarConfig c) {
    final f = c.bodyColor;
    switch (c.bodyShape) {
      case 'square':   return '<rect x="22" y="22" width="156" height="156" rx="12" fill="$f"/>';
      case 'hexagon':  return '<polygon points="100,18 172,57 172,143 100,182 28,143 28,57" fill="$f"/>';
      case 'oval':     return '<ellipse cx="100" cy="100" rx="72" ry="88" fill="$f"/>';
      default:         return '<circle cx="100" cy="100" r="82" fill="$f"/>';
    }
  }

  static String _drawNeck(AvatarConfig c) =>
      '<rect x="88" y="150" width="24" height="34" fill="${c.bodyColor}" rx="4"/>';

  // ── Clothing ──────────────────────────────────────────────────────────────

  static String _drawClothing(AvatarConfig c) {
    final cl = c.clothingColor;
    final sk = c.bodyColor;
    switch (c.clothingStyle) {
      case 'turtleneck':
        return '''
  <path d="M48 200 L48 170 Q72 158 100 156 Q128 158 152 170 L152 200Z" fill="$cl"/>
  <rect x="82" y="148" width="36" height="24" rx="10" fill="$cl"/>''';

      case 'shirt':
        return '''
  <path d="M48 200 L48 170 Q70 158 100 156 Q130 158 152 170 L152 200Z" fill="$cl"/>
  <path d="M87 156 L76 170 L100 162Z" fill="white" opacity="0.9"/>
  <path d="M113 156 L124 170 L100 162Z" fill="white" opacity="0.9"/>
  <line x1="100" y1="162" x2="100" y2="200" stroke="rgba(0,0,0,0.08)" stroke-width="1"/>
  <circle cx="100" cy="172" r="1.5" fill="rgba(0,0,0,0.25)"/>
  <circle cx="100" cy="182" r="1.5" fill="rgba(0,0,0,0.25)"/>
  <circle cx="100" cy="192" r="1.5" fill="rgba(0,0,0,0.25)"/>''';

      case 'sweater':
        return '''
  <path d="M46 200 L46 170 Q70 156 100 154 Q130 156 154 170 L154 200Z" fill="$cl"/>
  <path d="M87 154 Q100 160 113 154" fill="none" stroke="$cl" stroke-width="3"/>
  <line x1="46" y1="193" x2="154" y2="193" stroke="rgba(0,0,0,0.08)" stroke-width="2"/>
  <line x1="46" y1="186" x2="154" y2="186" stroke="rgba(0,0,0,0.08)" stroke-width="2"/>
  <line x1="46" y1="179" x2="154" y2="179" stroke="rgba(0,0,0,0.08)" stroke-width="2"/>''';

      case 't-shirt-v':
        return '''
  <path d="M48 200 L48 172 Q70 160 100 158 Q130 160 152 172 L152 200Z" fill="$cl"/>
  <path d="M88 158 L100 173 L112 158" fill="$sk"/>
  <path d="M88 158 L100 173 L112 158" fill="none" stroke="$cl" stroke-width="1.5"/>''';

      case 't-shirt-crew':
        return '''
  <path d="M48 200 L48 172 Q70 160 100 158 Q130 160 152 172 L152 200Z" fill="$cl"/>
  <ellipse cx="100" cy="162" rx="16" ry="9" fill="$sk"/>
  <ellipse cx="100" cy="162" rx="16" ry="9" fill="none" stroke="$cl" stroke-width="1.5"/>''';

      case 'hoodie':
        return '''
  <path d="M44 200 L44 168 Q66 154 100 152 Q134 154 156 168 L156 200Z" fill="$cl"/>
  <line x1="100" y1="152" x2="100" y2="200" stroke="rgba(0,0,0,0.12)" stroke-width="2"/>
  <circle cx="94" cy="170" r="3" fill="rgba(0,0,0,0.15)"/>
  <circle cx="106" cy="170" r="3" fill="rgba(0,0,0,0.15)"/>
  <ellipse cx="100" cy="158" rx="14" ry="8" fill="$sk"/>''';

      default: // t-shirt-normal
        return '''
  <path d="M48 200 L48 172 Q70 160 100 158 Q130 160 152 172 L152 200Z" fill="$cl"/>
  <ellipse cx="100" cy="163" rx="13" ry="7" fill="$sk"/>''';
    }
  }

  // ── Hair — back layer (rendered behind body) ──────────────────────────────
  // Only long/afro/spiky styles need a visible back layer.

  static String _drawHairBack(AvatarConfig c) {
    final f = c.hairColor;
    switch (c.hairStyle) {
      case 'straight':
        return '<path fill="$f" d="M20 90 Q14 132 20 172 Q52 194 100 196 Q148 194 180 172 Q186 132 180 90 Q158 70 100 66 Q42 70 20 90Z"/>';
      case 'wavy':
        return '<path fill="$f" d="M18 90 Q10 130 16 170 Q48 196 100 198 Q152 196 184 170 Q190 130 182 90 Q160 68 100 64 Q40 68 18 90Z"/>';
      case 'curly':
        return '''
  <path fill="$f" d="M18 90 Q10 128 18 168 Q50 196 100 198 Q150 196 182 168 Q190 128 182 90 Q160 68 100 64 Q40 68 18 90Z"/>
  <circle cx="22" cy="148" r="12" fill="$f"/>
  <circle cx="178" cy="148" r="12" fill="$f"/>
  <circle cx="16" cy="122" r="10" fill="$f"/>
  <circle cx="184" cy="122" r="10" fill="$f"/>''';
      case 'braids':
        return '''
  <path fill="$f" d="M22 88 Q14 112 20 152 Q50 192 100 194 Q150 192 180 152 Q186 112 178 88 Q156 68 100 64 Q44 68 22 88Z"/>
  <rect x="66" y="162" width="16" height="42" rx="8" fill="$f"/>
  <rect x="118" y="162" width="16" height="42" rx="8" fill="$f"/>''';
      case 'ponytail':
        return '''
  <path fill="$f" d="M26 86 Q18 112 24 150 Q54 190 100 192 Q146 190 176 150 Q182 112 174 86 Q154 66 100 62 Q46 66 26 86Z"/>
  <rect x="86" y="162" width="28" height="52" rx="14" fill="$f"/>
  <ellipse cx="100" cy="160" rx="20" ry="10" fill="$f" opacity="0.7"/>''';
      case 'half-bun':
        return '<path fill="$f" d="M26 90 Q18 122 24 162 Q54 192 100 194 Q146 192 176 162 Q182 122 174 90 Q154 70 100 66 Q46 70 26 90Z"/>';
      case 'shag':
        return '''
  <path fill="$f" d="M18 90 Q10 130 16 170 Q48 196 100 198 Q152 196 184 170 Q190 130 182 90 Q160 68 100 64 Q40 68 18 90Z"/>
  <path d="M16 104 Q12 88 18 76" stroke="$f" stroke-width="10" stroke-linecap="round" fill="none"/>
  <path d="M184 104 Q188 88 182 76" stroke="$f" stroke-width="10" stroke-linecap="round" fill="none"/>''';
      case 'fringe':
        return '<path fill="$f" d="M22 88 Q14 122 20 162 Q52 192 100 194 Q148 192 180 162 Q186 122 178 88 Q156 68 100 64 Q44 68 22 88Z"/>';
      case 'afro':
        // More exaggerated ellipse so afro clearly sticks out past face edges
        return '<ellipse cx="100" cy="62" rx="92" ry="72" fill="$f"/>';
      default:
        return '';
    }
  }

  // ── Hair — front layer (rendered in front of everything except hat) ────────
  // RULE: outer boundary must reach y=18 (head top for round/hex/square).

  static String _drawHairFront(AvatarConfig c) {
    final f = c.hairColor;

    // Shared outer arc for most styles: M[lx] [ly] Q[lx] 18 100 18 Q[rx] 18 [rx] [ly]
    // where lx≈36, ly≈78, rx≈164 — hair meeting points at the sides of the forehead

    switch (c.hairStyle) {

      // ── BUZZ: ultra-thin strip at very top ──
      case 'buzz':
        return '<ellipse cx="100" cy="18" rx="60" ry="8" fill="$f"/>';

      // ── CREW: clean rounded cap from y=18 to forehead ──
      case 'crew':
        return '<path fill="$f" d="M36 78 Q34 18 100 18 Q166 18 164 78 Q136 58 100 54 Q64 58 36 78Z"/>';

      // ── UNDERCUT: narrow crown only, shaved sides implied ──
      case 'undercut':
        return '<path fill="$f" d="M52 62 Q50 18 100 18 Q150 18 148 62 Q130 50 100 48 Q70 50 52 62Z"/>';

      // ── QUIFF: full cap + swept spike at front-top ──
      case 'quiff':
        return '''
  <path fill="$f" d="M36 76 Q34 18 100 18 Q166 18 164 76 Q138 56 100 52 Q62 56 36 76Z"/>
  <path fill="$f" d="M88 18 Q100 2 112 18 Q106 22 100 20 Q94 22 88 18Z"/>''';

      // ── POMPADOUR: large front volume ──
      case 'pompadour':
        return '''
  <path fill="$f" d="M34 76 Q32 18 100 18 Q168 18 166 76 Q140 54 100 50 Q60 54 34 76Z"/>
  <ellipse cx="100" cy="14" rx="44" ry="20" fill="$f"/>
  <path fill="$f" d="M70 12 Q100 -2 130 12 Q114 6 100 4 Q86 6 70 12Z"/>''';

      // ── SIDE-PART: asymmetric, swept to left ──
      case 'side-part':
        return '''
  <path fill="$f" d="M36 78 Q34 18 100 18 Q166 18 164 78 Q140 56 100 52 Q62 56 36 78Z"/>
  <path fill="$f" d="M36 78 Q52 46 88 32 L100 52 Q68 54 36 78Z"/>''';

      // ── MESSY: spiky irregular ──
      case 'messy':
        return '''
  <path fill="$f" d="M36 78 Q34 18 100 18 Q166 18 164 78 Q138 56 100 52 Q62 56 36 78Z"/>
  <polygon fill="$f" points="52,54 44,34 58,48 64,26 72,44 80,22 87,42 94,18 100,38 106,18 113,42 120,22 128,44 136,26 142,48 156,34 148,54"/>''';

      // ── SLICKED: smooth backward sweep ──
      case 'slicked':
        return '''
  <path fill="$f" d="M36 78 Q34 18 124 22 Q148 28 166 56 Q144 50 100 50 Q62 54 36 78Z"/>''';

      // ── PIXIE: short with fringe ear bits ──
      case 'pixie':
        return '''
  <path fill="$f" d="M36 76 Q34 18 100 18 Q166 18 164 76 Q140 56 100 52 Q60 56 36 76Z"/>
  <path fill="$f" d="M36 78 Q40 68 50 64 Q52 74 50 80Z"/>
  <path fill="$f" d="M164 78 Q160 68 150 64 Q148 74 150 80Z"/>
  <rect x="40" y="62" width="34" height="10" rx="5" fill="$f"/>''';

      // ── FADE: crown cap + fading side strips ──
      case 'fade':
        return '''
  <path fill="$f" d="M50 68 Q48 18 100 18 Q152 18 150 68 Q130 52 100 50 Q70 52 50 68Z"/>
  <rect x="22" y="52" width="16" height="56" rx="6" fill="$f" opacity="0.35"/>
  <rect x="22" y="52" width="12" height="36" rx="6" fill="$f" opacity="0.55"/>
  <rect x="162" y="52" width="16" height="56" rx="6" fill="$f" opacity="0.35"/>
  <rect x="166" y="52" width="12" height="36" rx="6" fill="$f" opacity="0.55"/>''';

      // ── TEXTURED: layered top ──
      case 'textured':
        return '''
  <path fill="$f" d="M36 78 Q34 18 100 18 Q166 18 164 78 Q140 58 100 54 Q60 58 36 78Z"/>
  <path d="M54 62 Q66 52 78 56 Q90 50 100 52 Q110 50 122 56 Q134 52 146 62" stroke="$f" stroke-width="4" fill="none" opacity="0.5"/>
  <path d="M48 70 Q64 62 80 66 Q92 60 100 62 Q108 60 120 66 Q136 62 152 70" stroke="$f" stroke-width="4" fill="none" opacity="0.4"/>''';

      // ── CORNROWS: parallel lines on cap ──
      case 'cornrows':
        return '''
  <path fill="$f" d="M36 76 Q34 18 100 18 Q166 18 164 76 Q140 56 100 52 Q60 56 36 76Z"/>
  <path d="M58 70 L62 34" stroke="$f" stroke-width="3.5" stroke-linecap="round" opacity="0.65"/>
  <path d="M72 66 L75 28" stroke="$f" stroke-width="3.5" stroke-linecap="round" opacity="0.65"/>
  <path d="M86 64 L88 24" stroke="$f" stroke-width="3.5" stroke-linecap="round" opacity="0.65"/>
  <path d="M100 64 L100 22" stroke="$f" stroke-width="3.5" stroke-linecap="round" opacity="0.65"/>
  <path d="M114 64 L112 24" stroke="$f" stroke-width="3.5" stroke-linecap="round" opacity="0.65"/>
  <path d="M128 66 L125 28" stroke="$f" stroke-width="3.5" stroke-linecap="round" opacity="0.65"/>
  <path d="M142 70 L138 34" stroke="$f" stroke-width="3.5" stroke-linecap="round" opacity="0.65"/>''';

      // ── WAVY-SHORT: short wavy ──
      case 'wavy-short':
        return '''
  <path fill="$f" d="M36 78 Q34 18 100 18 Q166 18 164 78 Q140 58 100 54 Q60 58 36 78Z"/>
  <path d="M40 72 Q52 62 64 66 Q76 60 88 64 Q100 58 112 62 Q124 58 136 64 Q148 60 160 72" stroke="$f" stroke-width="5" fill="none" opacity="0.5" stroke-linecap="round"/>''';

      // ── STRAIGHT (long): cap + long back already drawn ──
      case 'straight':
        return '<path fill="$f" d="M24 86 Q22 18 100 18 Q178 18 176 86 Q156 64 100 60 Q44 64 24 86Z"/>';

      // ── WAVY (long) ──
      case 'wavy':
        return '<path fill="$f" d="M24 86 Q22 18 100 18 Q178 18 176 86 Q156 62 126 58 Q112 54 100 56 Q88 54 74 58 Q44 62 24 86Z"/>';

      // ── CURLY (long) ──
      case 'curly':
        return '''
  <path fill="$f" d="M26 84 Q24 18 100 18 Q176 18 174 84 Q154 62 100 58 Q46 62 26 84Z"/>
  <circle cx="38" cy="70" r="12" fill="$f"/>
  <circle cx="162" cy="70" r="12" fill="$f"/>
  <circle cx="30" cy="86" r="10" fill="$f"/>
  <circle cx="170" cy="86" r="10" fill="$f"/>''';

      // ── BRAIDS (long) ──
      case 'braids':
        return '''
  <path fill="$f" d="M26 84 Q24 18 100 18 Q176 18 174 84 Q152 62 100 58 Q48 62 26 84Z"/>
  <path d="M68 158 Q72 172 68 184 Q75 172 80 184 Q76 172 77 158" stroke="$f" stroke-width="5" fill="none" stroke-linecap="round"/>
  <path d="M122 158 Q126 172 122 184 Q129 172 134 184 Q130 172 131 158" stroke="$f" stroke-width="5" fill="none" stroke-linecap="round"/>''';

      // ── PONYTAIL ──
      case 'ponytail':
        return '<path fill="$f" d="M28 84 Q26 18 100 18 Q174 18 172 84 Q152 62 100 58 Q48 62 28 84Z"/>';

      // ── BUN ──
      case 'bun':
        return '''
  <path fill="$f" d="M30 80 Q28 18 100 18 Q172 18 170 80 Q150 60 100 56 Q50 60 30 80Z"/>
  <circle cx="100" cy="6" r="22" fill="$f"/>
  <circle cx="100" cy="6" r="14" fill="$f" opacity="0.6"/>''';

      // ── HALF-BUN ──
      case 'half-bun':
        return '''
  <path fill="$f" d="M28 84 Q26 18 100 18 Q174 18 172 84 Q152 62 100 58 Q48 62 28 84Z"/>
  <circle cx="100" cy="10" r="18" fill="$f"/>''';

      // ── SHAG ──
      case 'shag':
        return '''
  <path fill="$f" d="M26 82 Q24 18 100 18 Q176 18 174 82 Q152 60 100 56 Q48 60 26 82Z"/>
  <path d="M40 78 Q52 64 64 68 Q76 62 88 66" stroke="$f" stroke-width="6" stroke-linecap="round" fill="none"/>
  <path d="M112 66 Q124 62 136 68 Q148 62 160 78" stroke="$f" stroke-width="6" stroke-linecap="round" fill="none"/>
  <path d="M46 86 Q58 74 70 78" stroke="$f" stroke-width="5" stroke-linecap="round" fill="none"/>
  <path d="M130 78 Q142 74 154 86" stroke="$f" stroke-width="5" stroke-linecap="round" fill="none"/>''';

      // ── FRINGE ──
      case 'fringe':
        return '''
  <path fill="$f" d="M26 84 Q24 18 100 18 Q176 18 174 84 Q152 62 100 58 Q48 62 26 84Z"/>
  <rect x="52" y="54" width="96" height="18" rx="5" fill="$f"/>''';

      // ── AFRO: front overlay (subtle highlight on top) ──
      case 'afro':
        return '<ellipse cx="100" cy="62" rx="92" ry="72" fill="$f" opacity="0.15"/>';

      // ── MOHAWK: central strip ──
      case 'mohawk':
        return '<rect fill="$f" x="88" y="10" width="24" height="72" rx="12"/>';

      // ── SPIKY: spiked polygon on top ──
      case 'spiky':
        return '<polygon fill="$f" points="56,52 48,30 62,44 66,20 74,40 82,16 89,38 96,14 100,32 104,14 111,38 118,16 126,40 134,20 138,44 152,30 144,52 100,66"/>';

      case 'bald':
        return '';

      default:
        return '';
    }
  }

  // ── Eyes ──────────────────────────────────────────────────────────────────

  static String _drawEyes(AvatarConfig c) {
    final lx = c.eyesWide ? 62 : 72;
    final rx = c.eyesWide ? 138 : 128;
    const ey = 96;
    final wh = c.eyeColor;
    final pu = c.pupilColor;

    switch (c.eyeStyle) {
      case 'happy':
        return '''
  <path d="M ${lx-14} $ey Q $lx ${ey-16} ${lx+14} $ey" fill="$wh"/>
  <path d="M ${rx-14} $ey Q $rx ${ey-16} ${rx+14} $ey" fill="$wh"/>
  <path d="M ${lx-14} $ey Q $lx ${ey+8} ${lx+14} $ey" fill="none" stroke="$pu" stroke-width="2.5"/>
  <path d="M ${rx-14} $ey Q $rx ${ey+8} ${rx+14} $ey" fill="none" stroke="$pu" stroke-width="2.5"/>''';

      case 'wink':
        return '''
  <circle cx="$lx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$lx" cy="$ey" r="7" fill="$pu"/>
  <circle cx="${lx+3}" cy="${ey-3}" r="3" fill="#FFFFFF" opacity="0.7"/>
  <path d="M ${rx-13} $ey Q $rx ${ey+10} ${rx+13} $ey" stroke="$pu" stroke-width="3" stroke-linecap="round" fill="none"/>''';

      case 'closed':
        return '''
  <path d="M ${lx-13} $ey Q $lx ${ey+10} ${lx+13} $ey" stroke="$pu" stroke-width="3" stroke-linecap="round" fill="none"/>
  <path d="M ${rx-13} $ey Q $rx ${ey+10} ${rx+13} $ey" stroke="$pu" stroke-width="3" stroke-linecap="round" fill="none"/>''';

      case 'cry':
        return '''
  <circle cx="$lx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$rx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$lx" cy="$ey" r="7" fill="$pu"/>
  <circle cx="$rx" cy="$ey" r="7" fill="$pu"/>
  <circle cx="${lx+3}" cy="${ey-3}" r="3" fill="#FFFFFF" opacity="0.7"/>
  <circle cx="${rx+3}" cy="${ey-3}" r="3" fill="#FFFFFF" opacity="0.7"/>
  <ellipse cx="${lx-5}" cy="${ey+20}" rx="4" ry="9" fill="#90CAF9" opacity="0.85"/>
  <ellipse cx="${rx-5}" cy="${ey+20}" rx="4" ry="9" fill="#90CAF9" opacity="0.85"/>''';

      case 'dizzy':
        return '''
  <circle cx="$lx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$rx" cy="$ey" r="13" fill="$wh"/>
  <line x1="${lx-6}" y1="${ey-6}" x2="${lx+6}" y2="${ey+6}" stroke="$pu" stroke-width="3" stroke-linecap="round"/>
  <line x1="${lx+6}" y1="${ey-6}" x2="${lx-6}" y2="${ey+6}" stroke="$pu" stroke-width="3" stroke-linecap="round"/>
  <line x1="${rx-6}" y1="${ey-6}" x2="${rx+6}" y2="${ey+6}" stroke="$pu" stroke-width="3" stroke-linecap="round"/>
  <line x1="${rx+6}" y1="${ey-6}" x2="${rx-6}" y2="${ey+6}" stroke="$pu" stroke-width="3" stroke-linecap="round"/>''';

      case 'angry':
        return '''
  <circle cx="$lx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$rx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$lx" cy="$ey" r="7" fill="$pu"/>
  <circle cx="$rx" cy="$ey" r="7" fill="$pu"/>
  <path d="M ${lx-13} ${ey-8} Q $lx ${ey-15} ${lx+13} ${ey-8}" fill="${c.eyebrowColor}" opacity="0.55"/>
  <path d="M ${rx-13} ${ey-8} Q $rx ${ey-15} ${rx+13} ${ey-8}" fill="${c.eyebrowColor}" opacity="0.55"/>''';

      case 'tired':
        return '''
  <circle cx="$lx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$rx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$lx" cy="$ey" r="7" fill="$pu"/>
  <circle cx="$rx" cy="$ey" r="7" fill="$pu"/>
  <path d="M ${lx-13} ${ey-2} Q $lx ${ey-14} ${lx+13} ${ey-2}" fill="${c.bodyColor}" opacity="0.72"/>
  <path d="M ${rx-13} ${ey-2} Q $rx ${ey-14} ${rx+13} ${ey-2}" fill="${c.bodyColor}" opacity="0.72"/>''';

      default: // default — round
        return '''
  <circle cx="$lx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$rx" cy="$ey" r="13" fill="$wh"/>
  <circle cx="$lx" cy="$ey" r="7" fill="$pu"/>
  <circle cx="$rx" cy="$ey" r="7" fill="$pu"/>
  <circle cx="${lx+3}" cy="${ey-3}" r="3" fill="#FFFFFF" opacity="0.7"/>
  <circle cx="${rx+3}" cy="${ey-3}" r="3" fill="#FFFFFF" opacity="0.7"/>''';
    }
  }

  // ── Eyebrows ──────────────────────────────────────────────────────────────

  static String _drawEyebrows(AvatarConfig c) {
    final lx = c.eyesWide ? 62 : 72;
    final rx = c.eyesWide ? 138 : 128;
    final col = c.eyebrowColor;
    final w = c.eyebrowStyle == 'thick' ? '4' : '3';
    switch (c.eyebrowStyle) {
      case 'straight':
      case 'thick':
        return '''
  <line x1="${lx-13}" y1="80" x2="${lx+13}" y2="80" stroke="$col" stroke-width="$w" stroke-linecap="round"/>
  <line x1="${rx-13}" y1="80" x2="${rx+13}" y2="80" stroke="$col" stroke-width="$w" stroke-linecap="round"/>''';
      case 'angry':
        return '''
  <line x1="${lx-13}" y1="77" x2="${lx+13}" y2="83" stroke="$col" stroke-width="$w" stroke-linecap="round"/>
  <line x1="${rx-13}" y1="83" x2="${rx+13}" y2="77" stroke="$col" stroke-width="$w" stroke-linecap="round"/>''';
      default:
        return '''
  <path d="M ${lx-13} 82 Q $lx 74 ${lx+13} 82" stroke="$col" stroke-width="$w" stroke-linecap="round" fill="none"/>
  <path d="M ${rx-13} 82 Q $rx 74 ${rx+13} 82" stroke="$col" stroke-width="$w" stroke-linecap="round" fill="none"/>''';
    }
  }

  // ── Nose ──────────────────────────────────────────────────────────────────

  static String _drawNose(AvatarConfig c) {
    final col = c.noseColor;
    switch (c.noseStyle) {
      case 'pointed': return '<path d="M100 108 L94 122 L106 122Z" fill="$col" opacity="0.5"/>';
      case 'long':    return '<path d="M98 108 Q96 118 94 122 Q97 124 100 123 Q103 124 106 122 Q104 118 102 108Z" fill="$col" opacity="0.45"/>';
      case 'round':   return '<ellipse cx="100" cy="116" rx="9" ry="7" fill="$col" opacity="0.45"/>';
      default:        return '<circle cx="100" cy="116" r="6" fill="$col" opacity="0.45"/>';
    }
  }

  // ── Mouth ─────────────────────────────────────────────────────────────────

  static String _drawMouth(AvatarConfig c) {
    final col = c.mouthColor;
    switch (c.mouthStyle) {
      case 'grin':
        return '''
  <path d="M80 130 Q100 148 120 130" stroke="$col" stroke-width="3" stroke-linecap="round" fill="none"/>
  <path d="M84 132 Q100 146 116 132 Q100 142 84 132Z" fill="$col" opacity="0.25"/>''';
      case 'grimace':
        return '''
  <rect x="82" y="126" width="36" height="14" rx="4" fill="white" stroke="$col" stroke-width="2"/>
  <line x1="82" y1="133" x2="118" y2="133" stroke="$col" stroke-width="1.5"/>
  <line x1="90" y1="126" x2="90" y2="140" stroke="$col" stroke-width="1" opacity="0.5"/>
  <line x1="100" y1="126" x2="100" y2="140" stroke="$col" stroke-width="1" opacity="0.5"/>
  <line x1="110" y1="126" x2="110" y2="140" stroke="$col" stroke-width="1" opacity="0.5"/>''';
      case 'kiss':
        return '''
  <ellipse cx="100" cy="133" rx="8" ry="10" fill="$col"/>
  <ellipse cx="100" cy="130" rx="6" ry="5" fill="$col" opacity="0.6"/>''';
      case 'surprised':
        return '''
  <ellipse cx="100" cy="134" rx="14" ry="12" fill="$col"/>
  <ellipse cx="100" cy="134" rx="10" ry="8" fill="#8B2020"/>''';
      case 'tongue':
        return '''
  <path d="M84 128 Q100 142 116 128" fill="$col"/>
  <ellipse cx="100" cy="142" rx="9" ry="8" fill="#FF8080"/>
  <line x1="100" y1="138" x2="100" y2="150" stroke="#CC6060" stroke-width="1.5"/>''';
      case 'twinkle':
        return '''
  <path d="M86 130 Q100 142 114 130" stroke="$col" stroke-width="3" stroke-linecap="round" fill="none"/>
  <circle cx="118" cy="126" r="2" fill="#FFCC00"/>
  <circle cx="122" cy="122" r="1.5" fill="#FFCC00"/>
  <circle cx="124" cy="128" r="1" fill="#FFCC00"/>''';
      case 'serious':
        return '<line x1="85" y1="132" x2="115" y2="132" stroke="$col" stroke-width="3" stroke-linecap="round"/>';
      case 'neutral':
        return '<line x1="87" y1="132" x2="113" y2="132" stroke="$col" stroke-width="2.5" stroke-linecap="round" opacity="0.8"/>';
      case 'sad':
        return '<path d="M86 136 Q100 126 114 136" stroke="$col" stroke-width="3" stroke-linecap="round" fill="none"/>';
      case 'concerned-teeth':
        return '''
  <path d="M84 132 Q100 126 116 132" stroke="$col" stroke-width="2" fill="none"/>
  <rect x="88" y="132" width="24" height="8" rx="2" fill="white" stroke="$col" stroke-width="1"/>
  <line x1="96" y1="132" x2="96" y2="140" stroke="$col" stroke-width="0.8" opacity="0.6"/>
  <line x1="104" y1="132" x2="104" y2="140" stroke="$col" stroke-width="0.8" opacity="0.6"/>''';
      case 'concerned':
        return '<path d="M84 134 Q92 128 100 131 Q108 128 116 134" stroke="$col" stroke-width="3" stroke-linecap="round" fill="none"/>';
      default: // smile
        return '<path d="M86 130 Q100 142 114 130" stroke="$col" stroke-width="3" stroke-linecap="round" fill="none"/>';
    }
  }

  // ── Facial Hair ───────────────────────────────────────────────────────────

  static String _drawFacialHair(AvatarConfig c) {
    final col = c.facialHairColor;
    switch (c.facialHairStyle) {
      case 'beard-huge':
        return '<path fill="$col" opacity="0.8" d="M60 140 Q56 170 100 177 Q144 170 140 140 Q122 152 100 154 Q78 152 60 140Z"/>';
      case 'beard-large':
        return '<path fill="$col" opacity="0.75" d="M68 140 Q66 164 100 170 Q134 164 132 140 Q116 150 100 152 Q84 150 68 140Z"/>';
      case 'beard-long':
        return '<path fill="$col" opacity="0.7" d="M76 140 Q74 157 100 162 Q126 157 124 140 Q114 147 100 149 Q86 147 76 140Z"/>';
      case 'moustache-chevron':
        return '<path fill="$col" d="M78 127 Q89 120 100 124 Q111 120 122 127 Q112 130 100 128 Q88 130 78 127Z"/>';
      case 'moustache-handlebar':
        return '''
  <path fill="$col" d="M82 127 Q91 120 100 124 Q109 120 118 127 Q112 130 100 128 Q88 130 82 127Z"/>
  <path d="M82 127 Q74 124 70 130" stroke="$col" stroke-width="3" stroke-linecap="round" fill="none"/>
  <path d="M118 127 Q126 124 130 130" stroke="$col" stroke-width="3" stroke-linecap="round" fill="none"/>''';
      case 'moustache-horseshoe':
        return '<path d="M80 124 Q90 118 100 122 Q110 118 120 124 Q118 130 118 142 Q118 148 112 148 Q106 148 106 142 L106 132 Q100 130 94 132 L94 142 Q94 148 88 148 Q82 148 82 142 Q82 130 80 124Z" fill="$col" opacity="0.8"/>';
      default:
        return '';
    }
  }

  // ── Accessories ───────────────────────────────────────────────────────────

  static String _drawAccessories(AvatarConfig c) {
    final buf = StringBuffer();
    final lx = c.eyesWide ? 62 : 72;
    final rx = c.eyesWide ? 138 : 128;
    final acCol = c.accessoryColor;

    if (c.accessories.contains('glasses')) {
      buf.write('''
  <circle cx="$lx" cy="96" r="16" fill="none" stroke="$acCol" stroke-width="2.5"/>
  <circle cx="$rx" cy="96" r="16" fill="none" stroke="$acCol" stroke-width="2.5"/>
  <line x1="${lx+16}" y1="96" x2="${rx-16}" y2="96" stroke="$acCol" stroke-width="2.5"/>
  <line x1="${lx-16}" y1="96" x2="${lx-26}" y2="92" stroke="$acCol" stroke-width="2.5" stroke-linecap="round"/>
  <line x1="${rx+16}" y1="96" x2="${rx+26}" y2="92" stroke="$acCol" stroke-width="2.5" stroke-linecap="round"/>''');
    }
    if (c.accessories.contains('earrings')) {
      buf.write('''
  <circle cx="18" cy="100" r="7" fill="#FFD700"/>
  <circle cx="182" cy="100" r="7" fill="#FFD700"/>''');
    }
    if (c.accessories.contains('scar')) {
      buf.write('<line x1="118" y1="88" x2="126" y2="106" stroke="#C0392B" stroke-width="2.5" stroke-linecap="round"/>');
    }
    return buf.toString();
  }

  // ── Hat ───────────────────────────────────────────────────────────────────
  // All hats are designed to reach y≤18 so they sit flush on the head top.
  // Hat color uses hairColor (or clothingColor for contrasting style — kept as hair).

  static String _drawHat(AvatarConfig c) {
    final f = c.hairColor;
    switch (c.hatStyle) {

      // Baseball cap: dome + band + full brim
      case 'cap':
        return '''
  <path fill="$f" d="M24 68 Q22 8 100 6 Q178 8 176 68 Q156 50 100 48 Q44 50 24 68Z"/>
  <rect x="20" y="62" width="160" height="14" rx="4" fill="$f" opacity="0.7"/>
  <ellipse cx="100" cy="76" rx="78" ry="11" fill="$f"/>
  <path d="M22 72 Q100 80 178 72" fill="none" stroke="rgba(0,0,0,0.15)" stroke-width="2"/>''';

      // Brimmed hat: tall crown + wide flat brim
      case 'hat':
        return '''
  <rect x="42" y="28" width="116" height="44" rx="6" fill="$f"/>
  <ellipse cx="100" cy="28" rx="54" ry="16" fill="$f"/>
  <rect x="14" y="66" width="172" height="16" rx="8" fill="$f"/>''';

      // Hijab: full head wrap + chin drape
      case 'hijab':
        return '''
  <path fill="$f" d="M14 84 Q12 6 100 4 Q188 6 186 84 Q186 152 100 162 Q14 152 14 84Z" opacity="0.93"/>
  <ellipse cx="100" cy="175" rx="64" ry="22" fill="$f" opacity="0.9"/>''';

      // Turban: wrapped layers from top of head
      case 'turban':
        return '''
  <path fill="$f" d="M20 72 Q18 10 100 8 Q182 10 180 72 Q160 54 100 52 Q40 54 20 72Z"/>
  <path d="M22 72 Q26 56 48 46 Q72 38 100 36 Q128 38 152 46 Q174 56 178 72" fill="none" stroke="$f" stroke-width="10" opacity="0.55"/>
  <path d="M24 82 Q28 66 52 54 Q76 44 100 42 Q124 44 148 54 Q172 66 176 82" fill="none" stroke="$f" stroke-width="10" opacity="0.42"/>
  <circle cx="100" cy="32" r="11" fill="$f"/>
  <circle cx="100" cy="32" r="6" fill="rgba(255,255,255,0.3)"/>''';

      // Winter cap: dome + ribbed band + pompom
      case 'winter-cap':
        return '''
  <path fill="$f" d="M24 76 Q22 10 100 6 Q178 10 176 76 Q156 58 100 56 Q44 58 24 76Z"/>
  <rect x="22" y="68" width="156" height="18" rx="9" fill="$f" opacity="0.72"/>
  <circle cx="100" cy="6" r="16" fill="white" opacity="0.92"/>
  <circle cx="100" cy="6" r="10" fill="$f" opacity="0.3"/>''';

      default:
        return '';
    }
  }
}
