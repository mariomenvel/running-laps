import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:running_laps/features/avatar/data/assets.dart';
import 'package:running_laps/features/avatar/viewmodels/avatar_maker_controller.dart';
import 'package:running_laps/features/avatar/data/background_shape.dart';
import 'package:running_laps/features/avatar/widgets/avatar_color_picker.dart';
import 'package:running_laps/features/avatar/widgets/avatar_text_styles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:running_laps/core/widgets/modern_snackbar.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:flutter/gestures.dart';

class AvatarMakerScreen extends StatefulWidget {
  const AvatarMakerScreen({super.key});

  @override
  State<AvatarMakerScreen> createState() => _AvatarMakerScreenState();
}

class _AvatarMakerScreenState extends State<AvatarMakerScreen> {
  final GlobalKey _avatarKey = GlobalKey();

  // Colores Premium (Hardcoded para asegurar consistencia con la app principal)
  static const Color _brandPurple = Color(0xFF8E24AA);
  static const Color _bgGradientStart = Color(0xFFF3E5F5); // Purple 50
  static const Color _bgGradientEnd = Colors.white;

  // ===========================================================================
  // WIDGETS DE UI
  // ===========================================================================

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        border: Border(
          bottom: BorderSide(
            color: cs.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón Atrás
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface),
            style: IconButton.styleFrom(
              backgroundColor: cs.surface,
              elevation: 2,
              shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.black12,
            ),
          ),

          Text(
            "EDITOR DE AVATAR",
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),

          // Botón Guardar
          IconButton(
            onPressed: _buildSaveAvatarOptions,
            icon: const Icon(Icons.save_alt_rounded, color: _brandPurple),
            style: IconButton.styleFrom(
              backgroundColor: cs.surface,
              elevation: 2,
              shadowColor: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.black12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(AvatarMakerController controller) {
    return Container(
      color: AppColors.surface2Of(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: List.generate(category.length, (index) {
          final isSelected = controller.selectedCategory == index;
          return GestureDetector(
            onTap: () {
              controller.category = index;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _brandPurple : AppColors.surface2Of(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: _brandPurple.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.transparent
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                ],
              ),
              child: Text(
                category[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildColorSelector(AvatarMakerController controller) {
    final selectedCategory = category[controller.selectedCategory];
    final List<int>? colorList;
    
    if (selectedCategory == "ROPA") colorList = clothingColor;
    else if (selectedCategory == "ACCESORIOS") colorList = accessoryColor;
    else if (selectedCategory == "BELLO FACIAL") colorList = facialHairColor;
    else if (selectedCategory == "FONDO") colorList = backgroundColor;
    else if (selectedCategory == "PELO") colorList = hairColor;
    else if (selectedCategory == "OJOS") colorList = eyeColor;
    else colorList = null;

    if (colorList == null) return const SizedBox.shrink();

    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: colorList.length,
        separatorBuilder: (c, i) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final colorValue = colorList![index];
          final color = Color(colorValue);
          
          // Determinar si está seleccionado
          bool isSelected = false;
          if (selectedCategory == "ROPA") isSelected = (controller.selectedClothingColor == colorValue);
          else if (selectedCategory == "ACCESORIOS") isSelected = (controller.selectedAccessoryColor == colorValue);
          else if (selectedCategory == "BELLO FACIAL") isSelected = (controller.selectedFacialHairColor == colorValue);
          else if (selectedCategory == "FONDO") isSelected = (controller.selectedBackgroundColor == colorValue);
          else if (selectedCategory == "PELO") isSelected = (controller.selectedHairColor == colorValue);
          else if (selectedCategory == "OJOS") isSelected = (controller.selectedEyeColor == colorValue);

          return GestureDetector(
            onTap: () {
              if (selectedCategory == "ROPA") controller.clothingColor = colorValue;
              else if (selectedCategory == "ACCESORIOS") controller.accessoryColor = colorValue;
              else if (selectedCategory == "BELLO FACIAL") controller.facialHairColor = colorValue;
              else if (selectedCategory == "FONDO") controller.backgroundColor = colorValue;
              else if (selectedCategory == "PELO") controller.hairColor = colorValue;
              else if (selectedCategory == "OJOS") controller.eyeColor = colorValue;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 48 : 40,
              height: isSelected ? 48 : 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: isSelected 
                ? Icon(Icons.check, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, size: 20)
                : null,
            ),
          );
        },
      ),
    );
  }



  Widget _buildComponentPreview(dynamic component) {
    if (component is String && component.isNotEmpty) {
      return SvgPicture.asset(
        component,
        width: 60,
        height: 60,
        fit: BoxFit.contain,
      );
    } else if (component is BackgroundShape) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          shape: component == BackgroundShape.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: component == BackgroundShape.roundedSquare ? BorderRadius.circular(12) : null,
        ),
      );
    }
    return Icon(Icons.block, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4));
  }

  // ===========================================================================
  // LOGIC & HELPERS
  // ===========================================================================

  Widget replaceColorOrReturn(bool shouldReplace, SvgPicture picture, Color? src, Color rep) {
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

  String generateFileName() {
    final now = DateTime.now();
    return "${now.year}${now.month}${now.day}${now.hour}${now.minute}${now.second}${now.millisecond}";
  }

  void _saveAvatarToAppFolder() async {
    try {
      RenderRepaintBoundary boundary = _avatarKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // Higher quality
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${generateFileName()}.png');
      await file.writeAsBytes(pngBytes);
      
      if (mounted) {
        ModernSnackBar.showSuccess(context, "Avatar guardado en la app");
      }
    } catch (e) {

    }
  }

  void _saveAvatarToGallery() async {
    try {
      RenderRepaintBoundary boundary = _avatarKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        await Gal.putImageBytes(byteData.buffer.asUint8List());
        if (mounted) {
          ModernSnackBar.showSuccess(context, "Avatar guardado en Galería");
        }
      }
    } catch (e) {

    }
  }

  void _buildSaveAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              ListTile(
                onTap: () {
                  _saveAvatarToAppFolder();
                  Navigator.pop(context);
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.rest.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.folder_special, color: AppColors.rest),
                ),
                title: const Text("Guardar en la App"),
                subtitle: const Text("Para usarlo en tu perfil"),
              ),
              ListTile(
                onTap: () {
                  _saveAvatarToGallery();
                  Navigator.pop(context);
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.rpeLow.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.photo_library, color: AppColors.rpeLow),
                ),
                title: const Text("Guardar en Galería"),
                subtitle: const Text("Descargar imagen PNG"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // Intentamos buscarlo primero, si no lo creamos (por si el Wrapper no lo hizo por alguna razón)
    final AvatarMakerController controller = Get.isRegistered<AvatarMakerController>() 
      ? Get.find<AvatarMakerController>() 
      : Get.put(AvatarMakerController());
    final double screenHeight = MediaQuery.of(context).size.height;
    // Ajustar altura del avatar basado en la pantalla disponible
    final double avatarAreaHeight = screenHeight * 0.55;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: isDark
            ? BoxDecoration(color: Theme.of(context).colorScheme.surface)
            : const BoxDecoration(color: Colors.white),
        child: SafeArea(
          bottom: false, // Permitir que el sheet baje hasta el fondo
          child: Stack(
            children: [
              // 1. HEADER & AVATAR (Background Layer)
              Column(
                children: [
                  SizedBox(
                    height: avatarAreaHeight,
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80), // Padding extra abajo para el sheet inicial
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double size = constraints.biggest.shortestSide * 0.9;
                          return Center(
                            child: SizedBox(
                              width: size,
                              height: size,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Glow effect
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _brandPurple.withOpacity(0.2),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        )
                                      ]
                                    ),
                                  ),
                                  // Avatar
                                  FittedBox(
                                    fit: BoxFit.contain,
                                    child: RepaintBoundary(
                                      key: _avatarKey,
                                      child: _buildAvatarStack(controller),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                  ),
                ],
              ),

              // 2. CONTROLS (Draggable Sheet)
              DraggableScrollableSheet(
                initialChildSize: 0.45,
                minChildSize: 0.25,
                maxChildSize: 0.9,
                snap: true,
                snapSizes: const [0.25, 0.45, 0.9],
                builder: (context, scrollController) {
                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        boxShadow: Theme.of(context).brightness == Brightness.dark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, -4),
                                )
                              ]
                            : [
                                const BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 20,
                                  offset: Offset(0, -5),
                                )
                              ]
                      ),
                      child: CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          // Handle - Larger drag area
                          SliverToBoxAdapter(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              child: Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                  padding: const EdgeInsets.symmetric(vertical: 8), // Larger hit area
                                  child: Container(
                                    width: 60,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(2.5)
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        
                        // Categories
                        SliverToBoxAdapter(
                          child: GetBuilder<AvatarMakerController>(
                            id: "avatar_category",
                            builder: (ctrl) => _buildCategoryTabs(ctrl)
                          ),
                        ),

                        // Colors (Optional)
                        SliverToBoxAdapter(
                          child: GetBuilder<AvatarMakerController>(
                            id: "avatar_category",
                            builder: (ctrl) => _buildColorSelector(ctrl)
                          ),
                        ),

                        // Divider
                        const SliverToBoxAdapter(child: Divider(height: 1)),

                        // Components Grid (Sliver)
                        GetBuilder<AvatarMakerController>(
                          id: "avatar_category",
                          builder: (ctrl) {
                            return _buildComponentsForCategory(ctrl);
                          }
                        ),
                        
                        // Bottom Padding for FAB
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.randomizeForInterval(1000),
        backgroundColor: _brandPurple,
        elevation: 4,
        child: const Icon(Icons.casino_rounded, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildComponentsForCategory(AvatarMakerController controller) {
    final cat = category[controller.selectedCategory];
    
    switch (cat) {
      case "FONDO":
        return _buildComponentGrid(context, backgroundAssets, "avatar_background_shape", 
          (i) => controller.backgroundShape = backgroundAssets[i], 
          (i) => controller.selectedBackgroundShape == backgroundAssets[i]);
      case "CUERPO":
        return _buildComponentGrid(context, bodyAssets, "avatar_body", 
          (i) => controller.body = i, 
          (i) => controller.selectedBody == i);
      case "OJOS":
        return _buildComponentGrid(context, eyesAssets, "avatar_eyes", 
          (i) => controller.eyes = i, 
          (i) => controller.selectedEyes == i);
      case "NARIZ":
        return _buildComponentGrid(context, noseAssets, "avatar_nose", 
          (i) => controller.nose = i, 
          (i) => controller.selectedNose == i);
      case "BOCA":
        return _buildComponentGrid(context, mouthAssets, "avatar_mouth", 
          (i) => controller.mouth = i, 
          (i) => controller.selectedMouth == i);
      case "PELO":
        return _buildComponentGrid(context, hairAssets, "avatar_hair", 
          (i) => controller.hair = i, 
          (i) => controller.selectedHair == i);
      case "BELLO FACIAL":
        return _buildComponentGrid(context, facialHairAssets, "avatar_facial_hair", 
          (i) => controller.facialHair = i, 
          (i) => controller.selectedFacialHair == i);
      case "ROPA":
        return _buildComponentGrid(context, clothingAssets, "avatar_clothing", 
          (i) => controller.clothing = i, 
          (i) => controller.selectedClothing == i);
      case "GORROS":
        return _buildComponentGrid(context, hatAssets, "avatar_hat", 
          (i) => controller.hat = i, 
          (i) => controller.selectedHat == i);
      case "ACCESORIOS":
        return _buildComponentGrid(context, accessoryAssets, "avatar_accessory", 
          (i) => controller.accessory = i, 
          (i) => controller.selectedAccessory == i);
      default:
        return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  Widget _buildComponentGrid(
    BuildContext context,
    List<dynamic> components,
    String notifyId,
    void Function(int) onTap,
    bool Function(int) isSelected
  ) {
    return GetBuilder<AvatarMakerController>(
      id: notifyId,
      builder: (controller) {
        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 100, // Responsive grid
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final component = components[index];
                final selected = isSelected(index);

                return GestureDetector(
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: AppColors.surface2Of(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? _brandPurple : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.transparent
                              : Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        children: [
                          Center(child: _buildComponentPreview(component)),
                          if (selected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: _brandPurple,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: components.length,
            ),
          ),
        );
      }
    );
  }

  Widget _buildAvatarStack(AvatarMakerController controller) {
    return SizedBox(
      width: 200,
      height: 200,
      child: GetBuilder<AvatarMakerController>(
        id: "avatar_background",
        builder: (c) {
          return Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Color(c.selectedBackgroundColor == 0 ? 0xFF9292B3 : c.selectedBackgroundColor),
              shape: c.selectedBackgroundShape == BackgroundShape.circle
                  ? BoxShape.circle
                  : BoxShape.rectangle,
              borderRadius: c.selectedBackgroundShape == BackgroundShape.roundedSquare
                  ? BorderRadius.circular(32)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ]
            ),
            child: Stack(
              children: [
                // BODY
                GetBuilder<AvatarMakerController>(
                  id: "avatar_body",
                  builder: (cb) => Positioned.fill(
                    bottom: -30,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SvgPicture.asset(bodyAssets[cb.selectedBody], width: 180, height: 180)
                    )
                  )
                ),
                // CLOTHING
                GetBuilder<AvatarMakerController>(
                  id: "avatar_clothing",
                  builder: (cc) {
                    Color src = const Color(0xFF80C43B);
                    Color rep = cc.selectedClothingColor == 0 ? src : Color(cc.selectedClothingColor);
                    return Positioned.fill(
                      bottom: -30,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: replaceColorOrReturn(
                          cc.selectedClothingColor != 0,
                          SvgPicture.asset(clothingAssets[cc.selectedClothing], width: 180, height: 80),
                          src, rep
                        )
                      )
                    );
                  }
                ),
                // EYES
                GetBuilder<AvatarMakerController>(
                  id: "avatar_eyes",
                  builder: (ce) {
                    Color eyeRep = ce.selectedEyeColor == 0 ? Colors.transparent : Color(ce.selectedEyeColor);
                    return Positioned.fill(
                      top: 100,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: replaceColorOrReturn(
                          eyeRep != Colors.transparent,
                          SvgPicture.asset(eyesAssets[ce.selectedEyes], width: 55, height: 22),
                          null, eyeRep
                        )
                      )
                    );
                  }
                ),
                // NOSE
                GetBuilder<AvatarMakerController>(
                  id: "avatar_nose",
                  builder: (cn) => Positioned.fill(
                    top: 100,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SvgPicture.asset(noseAssets[cn.selectedNose], width: 22, height: 33)
                    )
                  )
                ),
                // MOUTH
                GetBuilder<AvatarMakerController>(
                  id: "avatar_mouth",
                  builder: (cm) => Positioned.fill(
                    top: 128,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SvgPicture.asset(mouthAssets[cm.selectedMouth], width: 44, height: 33)
                    )
                  )
                ),
                // HAIR
                GetBuilder<AvatarMakerController>(
                  id: "avatar_hair",
                  builder: (ch) {
                    if (hatAssets[ch.selectedHat] != "") return const SizedBox.shrink();
                    Color hairRep = ch.selectedHairColor == 0 ? Colors.transparent : Color(ch.selectedHairColor);
                    return Positioned(
                      top: 16,
                      left: 0, right: 0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: replaceColorOrReturn(
                          hairRep != Colors.transparent,
                          SvgPicture.asset(
                            hairAssets[ch.selectedHair],
                            width: 200, height: 215
                          ),
                          null, hairRep
                        )
                      )
                    );
                  }
                ),
                // FACIAL HAIR
                GetBuilder<AvatarMakerController>(
                  id: "avatar_facial_hair",
                  builder: (cf) {
                    final path = facialHairAssets[cf.selectedFacialHair];
                    Color rep = cf.selectedFacialHairColor == 0 ? Colors.transparent : Color(cf.selectedFacialHairColor);
                    if (path == "") return const SizedBox.shrink();
                    return Positioned.fill(
                      top: 116,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: replaceColorOrReturn(true, SvgPicture.asset(path, width: 100, height: 90), null, rep)
                      )
                    );
                  }
                ),
                // ACCESSORY
                GetBuilder<AvatarMakerController>(
                  id: "avatar_accessory",
                  builder: (ca) {
                    final path = accessoryAssets[ca.selectedAccessory];
                    Color rep = ca.selectedAccessoryColor == 0 ? Colors.transparent : Color(ca.selectedAccessoryColor);
                    if (path == "") return const SizedBox.shrink();
                    return Positioned.fill(
                      top: 90,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: replaceColorOrReturn(
                          ca.selectedAccessoryColor != 0,
                          SvgPicture.asset(path, width: 90, height: 45),
                          null, rep
                        )
                      )
                    );
                  }
                ),
                // HAT
                GetBuilder<AvatarMakerController>(
                  id: "avatar_hat",
                  builder: (ct) {
                    final path = hatAssets[ct.selectedHat];
                    if (path == "") return const SizedBox.shrink();
                    return Positioned(
                      top: 16,
                      left: 0, right: 0,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SvgPicture.asset(path, width: 200, height: 215)
                      )
                    );
                  }
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
