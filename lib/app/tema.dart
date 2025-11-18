import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildPlaceholder(radius);

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final String tipo = data?['profilePicType'] ?? 'none';

        // 1. SI ES AVATAR
        if (tipo == 'avatar') {
          final config = data?['avatarConfig'] as Map<String, dynamic>? ?? {};
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.transparent, // El fondo lo pone el SVG
            child: ClipOval(
              child: SizedBox(
                width: radius * 2,
                height: radius * 2,
                // TRUCO DE ORO:
                // Forzamos al avatar a dibujarse en su tamaño nativo (180px)
                // y luego FittedBox lo reduce para que quepa en tu radio (24, 40, etc.)
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 180, // Ancho nativo del diseño del paquete
                    height: 180, // Alto nativo del diseño del paquete
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

  // --- LÓGICA DE CONSTRUCCIÓN (Pixel Perfect con el Editor) ---
  static Widget _construirStackAvatar(Map<String, dynamic> config) {
    // 1. Extraer índices con seguridad (0 por defecto)
    final int bodyIndex = config['body'] ?? 0;
    final int clothingIndex = config['clothing'] ?? 0;
    final int eyesIndex = config['eyes'] ?? 0;
    final int noseIndex = config['nose'] ?? 0;
    final int mouthIndex = config['mouth'] ?? 0;
    final int hatIndex = config['hat'] ?? 0;
    final int facialHairIndex = config['facialHair'] ?? 0;
    final int accessoryIndex = config['accessory'] ?? 0;
    
    // 2. Extraer Colores
    final int bgColorInt = config['backgroundColor'] ?? 0xFF65C9FF;
    final int clothingColorInt = config['clothingColor'] ?? 0;
    final int accessoryColorInt = config['accessoryColor'] ?? 0;
    // Ojo: facialHairColor a veces no se usa en el render del paquete original si es transparente
    // pero lo dejamos listo por si acaso.

    // 3. Lógica de Pelo
    final String hairTypeStr = config['hairType'] ?? 'short';
    final bool isShortHair = hairTypeStr.contains('short');
    final int shortHairIndex = config['shortHair'] ?? 0;
    final int longHairIndex = config['longHair'] ?? 0;
    
    // Verificar si hay sombrero (si hay, el pelo se oculta según lógica del paquete)
    final bool hasHat = hatAssets[hatIndex] != "";
    final bool hasFacialHair = facialHairAssets[facialHairIndex] != "";
    final bool hasAccessory = accessoryAssets[accessoryIndex] != "";

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Color(bgColorInt),
        shape: BoxShape.circle, // Forzamos círculo para el resultado final
      ),
      child: Stack(
        children: [
          // BODY
          Positioned.fill(
            bottom: -30,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SvgPicture.asset(bodyAssets[bodyIndex], width: 160, height: 160),
            ),
          ),

          // CLOTHING
          Positioned.fill(
            bottom: -30,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _replaceColorOrReturn(
                true,
                SvgPicture.asset(clothingAssets[clothingIndex], width: 160, height: 70),
                const Color(0xFF80C43B), // Color original del asset (Verde)
                clothingColorInt == 0 ? const Color(0xFF80C43B) : Color(clothingColorInt),
              ),
            ),
          ),

          // EYES
          Positioned.fill(
            top: 90,
            child: Align(
              alignment: Alignment.topCenter,
              child: SvgPicture.asset(eyesAssets[eyesIndex], width: 50, height: 20),
            ),
          ),

          // NOSE
          Positioned.fill(
            top: 90,
            child: Align(
              alignment: Alignment.topCenter,
              child: SvgPicture.asset(noseAssets[noseIndex], width: 20, height: 30),
            ),
          ),

          // MOUTH
          Positioned.fill(
            top: 115,
            child: Align(
              alignment: Alignment.topCenter,
              child: SvgPicture.asset(mouthAssets[mouthIndex], width: 40, height: 30),
            ),
          ),

          // HAIR (Solo si NO hay sombrero, lógica del paquete)
          if (!hasHat)
            Positioned(
              top: 15,
              left: 0, 
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: SvgPicture.asset(
                  isShortHair ? shortHairAssets[shortHairIndex] : longHairAssets[longHairIndex],
                  width: 180,
                  height: 195,
                ),
              ),
            ),

          // FACIAL HAIR
          if (hasFacialHair)
            Positioned.fill(
              top: 105,
              child: Align(
                alignment: Alignment.topCenter,
                // El paquete original no suele colorear la barba, pero si quieres, usa _replaceColorOrReturn aquí
                child: SvgPicture.asset(facialHairAssets[facialHairIndex], width: 90, height: 80),
              ),
            ),

          // ACCESSORY
          if (hasAccessory)
            Positioned.fill(
              top: 81,
              child: Align(
                alignment: Alignment.topCenter,
                child: _replaceColorOrReturn(
                  true,
                  SvgPicture.asset(accessoryAssets[accessoryIndex], width: 80, height: 40),
                  null, 
                  accessoryColorInt == 0 ? Colors.transparent : Color(accessoryColorInt),
                ),
              ),
            ),

          // HAT
          if (hasHat)
            Positioned(
              top: 15,
              left: 0, 
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: SvgPicture.asset(hatAssets[hatIndex], width: 180, height: 195),
              ),
            ),
        ],
      ),
    );
  }

  // --- UTILIDAD DE COLOR (Copiada exactamente del paquete) ---
  static Widget _replaceColorOrReturn(bool shouldReplace, SvgPicture picture, Color? src, Color rep) {
    if (!shouldReplace || rep == Colors.transparent) return picture;

    return ColorFiltered(
      colorFilter: src != null
          ? ColorFilter.matrix(<double>[
              rep.red / src.red, 0, 0, 0, 0,
              0, rep.green / src.green, 0, 0, 0,
              0, 0, rep.blue / src.blue, 0, 0,
              0, 0, 0, 1, 0,
            ])
          : ColorFilter.mode(rep, BlendMode.srcIn),
      child: picture,
    );
  }
}