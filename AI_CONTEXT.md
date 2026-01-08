# AI Context & Technical Documentation - Running Laps

> **Role**: This document serves as the primary context source for any AI agent working on the *Running Laps* project. It defines the strict architectural rules, data models, and operational constraints that must be followed.

## 1. Project Identity & Scope
**Name**: Running Laps
**Type**: Flutter Mobile Application (Android/iOS/Windows/macOS)
**Core Value Proposition**: Advanced running tracker focusing on **interval training (Series)** and **Rate of Perceived Exertion (RPE)**.
**Key Technology**: Flutter (Dart), Firebase (Auth, Firestore, Storage, Analytics).

> **Note**: For detailed human-readable explanations and diagrams, refer to `DOCUMENTACION_TECNICA.md`. This file (`AI_CONTEXT.md`) focuses on strict constraints and machine-parsable details.

## 2. Strict Architectural Rules
The project follows a **Feature-First + MVVM** architecture. Deviating from this structure is **strictly forbidden**.

### 2.1. Layer Separation
- **Presentation (`views/`)**: Pure UI widgets. *Must not* contain business logic.
- **State Management (`viewmodels/`)**: 
  - **MUST** use `ValueNotifier` / `ValueListenableBuilder` for state.
  - **MUST NOT** use `GetX` for state management (GetX is reserved for Navigation/Utils only, if at all).
  - DO NOT use `setState` for complex logic.
- **Domain/Data (`data/`)**: Repositories and clean data models.
  - **Repositories**: Handle all Firestore/API interactions.
  - **Models**: Immutable Dart classes with `fromMap`/`toMap` methods.

### 2.2. Directory Structure Convention
Every feature MUST follow this structure:
```
lib/features/feature_name/
├── data/
│   ├── model_name.dart         # Data classes
│   └── feature_repository.dart # Firestore/API logic
├── viewmodels/
│   └── feature_controller.dart # ValueNotifier state logic
├── views/
│   ├── feature_screen.dart     # Main screen
│   └── widgets/                # Feature-specific widgets
└── widgets/                    # (Optional) Shared widgets for this feature
```

## 3. Critical Business Logic & Invariants

### 3.1. Training Entity (`Entrenamiento`)
- **Distance**: Measured in **Meters** (integer).
- **Time**: Measured in **Seconds** (double).
- **Pace (Ritmo)**: Calculated as `seconds / km`. Displayed as `mm:ss /km`.
- **RPE**: Scale 1-10.
- **Constraints**:
  - A training session *must* have at least one series.
  - A series *cannot* have 0 meters unless it's a pure time-based stationary drill (edge case, usually 0 meters is invalid).
  - GPS points are optional (user might run indoors).

### 3.2. GPS Logic
- **Service**: `GPSService` (`lib/core/services/gps_service.dart`).
- **Precision**: Discard points with `accuracy > 20 meters`.
- **Distance Calculation**: Use Haversine formula between accepted points.
- **Pace Smoothing**: Use a sliding window (last 5 points) to avoid erratic pace display.

## 4. Data Models & Schemas (Firestore)

### 4.1. Collections Map
- `users/{uid}`: User profile.
- `users/{uid}/entrenamientos/{trainingId}`: Training sessions.
- `users/{uid}/tags/{tagId}`: User-defined tags.
- `groups/{groupId}`: Social groups.
- `groups/{groupId}/challenges/{challengeId}`: Group challenges.

### 4.2. JSON Schema: `Entrenamiento`
```json
{
  "id": "string (UUID)",
  "titulo": "string",
  "fecha": "timestamp (ISO 8601 string in local)",
  "gps": "boolean",
  "distanciaTotalM": "integer (checksum)",
  "tiempoTotalSec": "double (checksum)",
  "rpePromedio": "double",
  "tags": ["string (tagId)"],
  "series": [
    {
      "tiempoSec": "double",
      "distanciaM": "integer",
      "descansoSec": "integer",
      "rpe": "double",
      "usedGps": "boolean",
      "gpsPoints": [ // Optional, heavy data
        { "lat": double, "lng": double, "ts": "iso_string", "acc": double }
      ]
    }
  ]
}
```

## 5. Development Workflow

### 5.1. Creating a New Feature
1.  **Define Model**: Create the data structure in `features/name/data`.
2.  **Create Repository**: Implement Firestore CRUD.
3.  **Create ViewModel**: Initialize `ValueNotifiers`.
4.  **Create View**: Build UI, listening to ViewModel.

### 5.2. Testing
- **Unit Tests**: `flutter test` (in `test/unit/`).
- **Widget Tests**: `flutter test test/widget_test.dart`.
- **Mocking**: Use `mockito` if external calls are involved (though currently not heavily set up).

### 5.3. Common Pitfalls to Avoid
- **Context in Async**: Do not use `BuildContext` across async gaps. Check `if (mounted)` or use a service navigation key (if available).
- **Firestore Indexes**: Complex queries (e.g., filtering by Tag AND Date) require composite indexes. Check console logs for link to create them.
- **Assets**: All SVGs/Images must be declared in `pubspec.yaml`.

## 6. Key File Locations
- **Main Entry**: `lib/main.dart`
- **Routes/Navigation**: `lib/features/home/views/home_view.dart` (acts as a dashboard/router).
- **Global Styles**: `lib/app/tema.dart`.
- **Core Services**: `lib/core/services/`.

---
**Note for AI**: When analyzing code, trust the strict typing in `data/` folders over loose UI code. The `data` layer is the source of truth.
