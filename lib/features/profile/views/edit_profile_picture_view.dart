// lib/features/profile/views/edit_profile_picture_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Asumo que usas GetX para navegar
import 'package:image_picker/image_picker.dart';
// Importa tus otras vistas y viewmodels
import 'avatar_editor_wrapper_view.dart'; // Crearemos esta en el Paso 3
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:firebase_firestore/firebase_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:io';


class EditProfilePictureView extends StatelessWidget {
  const EditProfilePictureView({Key? key}) : super(key: key);

  // --- Lógica para SUBIR FOTO ---
  Future<void> _uploadFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return; // El usuario canceló

    // Aquí iría tu lógica para subir la imagen a Firebase Storage
    // y guardar la URL en Firestore.

    // 1. Obtener ID de usuario
    // final userId = FirebaseAuth.instance.currentUser!.uid;
    // 2. Crear referencia en Storage
    // final ref = FirebaseStorage.instance.ref('profile_pictures/$userId.jpg');
    // 3. Subir el archivo
    // await ref.putFile(File(image.path));
    // 4. Obtener la URL de descarga
    // final url = await ref.getDownloadURL();
    // 5. Guardar la URL en Firestore
    // await FirebaseFirestore.instance.collection('users').doc(userId).set({
    //   'profilePicType': 'photo',
    //   'profileImageUrl': url,
    // }, SetOptions(merge: true));

    Get.back(); // Volver al perfil
  }


  // --- Lógica para CREAR AVATAR ---
  void _createAvatar() {
    // Navegamos a la pantalla de edición de avatar
    // (La crearemos en el siguiente paso)
    Get.to(() => AvatarEditorWrapperView()); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cambiar foto de perfil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: Aquí deberías mostrar la foto/avatar actual

            SizedBox(height: 40),
            ElevatedButton.icon(
              icon: Icon(Icons.photo_library),
              label: Text('Subir desde galería'),
              onPressed: _uploadFromGallery,
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.person_search),
              label: Text('Crear/Editar Avatar'),
              onPressed: _createAvatar,
            ),
          ],
        ),
      ),
    );
  }
}