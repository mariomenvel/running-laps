# 🏃‍♂️ Running Laps

> **"Cada paso cuenta."**

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)

**Running Laps** es una aplicación móvil avanzada para corredores, diseñada específicamente para el registro y análisis de entrenamientos por **series (intervalos)**. A diferencia de las apps de running convencionales, nos enfocamos en el esfuerzo percibido (RPE) y la precisión en entrenamientos fraccionados.

---

## ✨ Características Principales

### 🎯 Gestión de Entrenamientos
- **Modo Series**: Crea entrenamientos complejos con intervalos de trabajo y descanso.
- **Registro RPE**: Escala de esfuerzo percibido para cada serie, permitiendo un análisis subjetivo del rendimiento.
- **Historial Detallado**: Visualiza tus entrenamientos pasados con métricas clave.

### 📍 Geolocalización y Métricas
- **GPS Tracking**: Rastreo de ruta, distancia y ritmo en tiempo real.
- **Estadísticas Visuales**: Gráficas de rendimiento impulsadas por `fl_chart`.

### 👥 Social y Competitivo
- **Grupos de Corredores**: Únete a grupos y compite con amigos.
- **Rankings**: Clasificaciones basadas en distancia total y consistencia.

### 🔐 Seguridad y Perfil
- **Autenticación Robusta**: Inicio de sesión seguro con correo/contraseña (Firebase Auth).
- **Perfil Personalizable**: Avatar, estadísticas personales y configuración.

---

## 🛠️ Stack Tecnológico

El proyecto está construido sobre una arquitectura escalable y moderna:

- **Frontend**: [Flutter](https://flutter.dev/) (Dart)
- **Backend (BaaS)**: [Firebase](https://firebase.google.com/)
  - **Auth**: Gestión de usuarios.
  - **Firestore**: Base de datos NoSQL en tiempo real.
  - **Storage**: (Planificado) Almacenamiento de imágenes.
- **Estado**: MVVM con `ValueNotifier` y controladores nativos.
- **Arquitectura**: Feature-First (Modular y mantenible).

---

## 📱 Captures de Pantalla

| Inicio de Sesión | Entrenamiento | Estadísticas |
|:---:|:---:|:---:|
| *[Inserte captura aquí]* | *[Inserte captura aquí]* | *[Inserte captura aquí]* |

---

##  Instalación y Uso

### Requisitos Previos
- Flutter SDK (3.x o superior)
- Dart SDK
- Un dispositivo físico o emulador (Android/iOS)

### Pasos

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/tu-usuario/running-laps.git
   cd running-laps
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configuración de Firebase**
   - Este proyecto utiliza `flutterfire_cli`. Necesitas tener acceso al proyecto de Firebase vinculado.
   - Si tienes tus propias credenciales, reemplaza `firebase_options.dart`.

4. **Ejecutar la App**
   ```bash
   flutter run
   ```

---

## 📂 Estructura del Proyecto

```
lib/
├── core/            # Utilidades, temas y widgets compartidos
├── features/        # Módulos principales (Auth, Training, Groups, etc.)
│   ├── auth/
│   ├── training/
│   └── ...
├── main.dart        # Punto de entrada
└── firebase_options.dart
```

---

## 👥 Equipo

Proyecto académico desarrollado para el ciclo de **Desarrollo de Aplicaciones Multiplataforma (DAM) - 2025**.

| Desarrollador | Rol |
|:-------------:|:---:|
| **Mario** | Lead Developer |
| **Álvaro** | Lead Developer |

---

## 📄 Licencia

Este proyecto es para fines educativos y académicos.
© 2025 Running Laps Team.
