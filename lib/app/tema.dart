import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Asegúrate de que la ruta de este import sea correcta en tu proyecto
import 'package:flutter_avatar_maker/assets.dart';

class Tema {
  static const Color brandPurple = Color(0xFF8E24AA);
}

class AvatarHelper {
  /// Muestra el avatar del usuario actual
  static Widget construirImagenPerfil({double radius = 24.0}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return _buildPlaceholder(radius);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildPlaceholder(radius);

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final String tipo = data?['profilePicType'] ?? 'none';

        // 1. SI ES AVATAR
        if (tipo == 'avatar') {
          final config = data?['avatarConfig'] as Map<String, dynamic>? ?? {};
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.transparent,
            child: ClipOval(
              child: SizedBox(
                width: radius * 2,
                height: radius * 2,
                // TRUCO: Forzamos renderizado a 180px y escalamos
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: _construirStackAvatar(config),
                  ),
                ),
              ),
            ),
          );
        }
        // 2. SI ES FOTO DE GOOGLE/SUBIDA
        else if (tipo == 'photo') {
          final String url = data?['profileImageUrl'] ?? '';
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[200],
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: url.isEmpty ? const Icon(Icons.person) : null,
          );
        }

        // 3. DEFECTO
        return _buildPlaceholder(radius);
      },
    );
  }

  static Widget _buildPlaceholder(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      child: Icon(Icons.person, size: radius, color: Colors.grey[600]),
    );
  }

  // --- LÓGICA DE CONSTRUCCIÓN ---
  static Widget _construirStackAvatar(Map<String, dynamic> config) {
    // --- HELPERS ---
    int toInt(dynamic val) {
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    int safeIndex(int index, List list) {
      if (index < 0 || index >= list.length) return 0;
      return index;
    }

    // --- DIAGNÓSTICO DE GAFAS (MIRA TU CONSOLA) ---
    final rawAccessory = config['accessory'];
    final int parsedIndex = toInt(rawAccessory);
    // Asegúrate de tener importado assets.dart para que esto no de error
    final int safeIdx = safeIndex(parsedIndex, accessoryAssets);
    final String path = accessoryAssets[safeIdx];
    final bool hasAcc = path != "";
    // ... El resto de tus variables (bodyIndex, clothingIndex, etc.) ...
    final int bodyIndex = safeIndex(toInt(config['body']), bodyAssets);
    final int clothingIndex = safeIndex(
      toInt(config['clothing']),
      clothingAssets,
    );
    final int eyesIndex = safeIndex(toInt(config['eyes']), eyesAssets);
    final int noseIndex = safeIndex(toInt(config['nose']), noseAssets);
    final int mouthIndex = safeIndex(toInt(config['mouth']), mouthAssets);
    final int hatIndex = safeIndex(toInt(config['hat']), hatAssets);
    final int facialHairIndex = safeIndex(
      toInt(config['facialHair']),
      facialHairAssets,
    );
    final int accessoryIndex = safeIdx; // Usamos el que calculamos arriba

    // ... Resto de variables de color ...
    final int bgColorInt = toInt(config['backgroundColor']) == 0
        ? 0xFF65C9FF
        : toInt(config['backgroundColor']);
    final int clothingColorInt = toInt(config['clothingColor']);
    final int accessoryColorInt = toInt(config['accessoryColor']);
    final int facialHairColorInt = toInt(config['facialHairColor']);

    // ... Lógica de Pelo ...
    final String hairTypeStr = config['hairType'] ?? 'short';
    final bool isShortHair = hairTypeStr.contains('short');
    final int shortHairIndex = safeIndex(
      toInt(config['shortHair']),
      shortHairAssets,
    );
    final int longHairIndex = safeIndex(
      toInt(config['longHair']),
      longHairAssets,
    );

    // Variables booleanas finales
    final bool hasHat = hatAssets[hatIndex] != "";
    final bool hasFacialHair = facialHairAssets[facialHairIndex] != "";
    final bool hasAccessory = hasAcc; // Usamos la del diagnóstico

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Color(bgColorInt),
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          // 1. BODY
          Positioned.fill(
            bottom: -30,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SvgPicture.asset(
                bodyAssets[bodyIndex],
                width: 160,
                height: 160,
              ),
            ),
          ),

          // 2. CLOTHING
          Positioned.fill(
            bottom: -30,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _replaceColorOrReturn(
                true,
                SvgPicture.asset(
                  clothingAssets[clothingIndex],
                  width: 160,
                  height: 70,
                ),
                const Color(0xFF80C43B), // Color verde original de los assets
                clothingColorInt == 0
                    ? const Color(0xFF80C43B)
                    : Color(clothingColorInt),
              ),
            ),
          ),

          // 3. EYES
          Positioned.fill(
            top: 90,
            child: Align(
              alignment: Alignment.topCenter,
              child: SvgPicture.asset(
                eyesAssets[eyesIndex],
                width: 50,
                height: 20,
              ),
            ),
          ),

          // 4. NOSE
          Positioned.fill(
            top: 90,
            child: Align(
              alignment: Alignment.topCenter,
              child: SvgPicture.asset(
                noseAssets[noseIndex],
                width: 20,
                height: 30,
              ),
            ),
          ),

          // 5. MOUTH
          Positioned.fill(
            top: 115,
            child: Align(
              alignment: Alignment.topCenter,
              child: SvgPicture.asset(
                mouthAssets[mouthIndex],
                width: 40,
                height: 30,
              ),
            ),
          ),

          // 6. HAIR (Solo si no lleva gorro que lo cubra todo)
          if (!hasHat)
            Positioned(
              top: 15,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: SvgPicture.asset(
                  isShortHair
                      ? shortHairAssets[shortHairIndex]
                      : longHairAssets[longHairIndex],
                  width: 180,
                  height: 195,
                ),
              ),
            ),

          // 7. FACIAL HAIR (Barba)
          if (hasFacialHair)
            Positioned.fill(
              top: 105,
              child: Align(
                alignment: Alignment.topCenter,
                child: _replaceColorOrReturn(
                  true,
                  SvgPicture.asset(
                    facialHairAssets[facialHairIndex],
                    width: 90,
                    height: 80,
                  ),
                  null,
                  // Si el color es 0 o null, lo deja transparente (original) o por defecto
                  facialHairColorInt == 0
                      ? Colors.transparent
                      : Color(facialHairColorInt),
                ),
              ),
            ),

          // 8. ACCESSORY (Gafas)
          if (hasAccessory)
            Positioned.fill(
              top: 81,
              child: Align(
                alignment: Alignment.topCenter,
                child: _replaceColorOrReturn(
                  true,
                  SvgPicture.asset(
                    accessoryAssets[accessoryIndex],
                    width: 80,
                    height: 40,
                  ),
                  null,
                  accessoryColorInt == 0
                      ? Colors.transparent
                      : Color(accessoryColorInt),
                ),
              ),
            ),

          // 9. HAT (Sombrero va encima de todo)
          if (hasHat)
            Positioned(
              top: 15,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: SvgPicture.asset(
                  hatAssets[hatIndex],
                  width: 180,
                  height: 195,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- UTILIDAD DE COLOR ---
  static Widget _replaceColorOrReturn(
    bool shouldReplace,
    SvgPicture picture,
    Color? src,
    Color rep,
  ) {
    if (!shouldReplace || rep == Colors.transparent) return picture;

    return ColorFiltered(
      colorFilter: src != null
          ? ColorFilter.matrix(<double>[
              rep.red / src.red,
              0,
              0,
              0,
              0,
              0,
              rep.green / src.green,
              0,
              0,
              0,
              0,
              0,
              rep.blue / src.blue,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ])
          : ColorFilter.mode(rep, BlendMode.srcIn),
      child: picture,
    );
  }
}
