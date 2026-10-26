# RoadSense — Phase 0 Codebase Audit Report

**Date:** 2026-10-26  
**Auditor:** Senior Flutter/Dart Engineer  
**Branch:** `chore/audit`  
**Git Head Commit:** `fe5a88e` ("authentication and backend setup")  
**Environment:** Flutter 3.47.5 (Channel stable), Dart 3.13.4, Windows 10/11  

---

## 1. Inventory

The project contains **78 tracked files** across `docs/`, `lib/`, and `test/` (plus root config, binary assets, and reference papers).

### 1.1 Documentation (`docs/`)
| Path | Lines | One-line Purpose |
| :--- | :---: | :--- |
| `docs/backend/firestore-schema.md` | 254 | Canonical schema specification and field constraints for Cloud Firestore collections. |
| `docs/backend/firestore-security-rules.md` | 124 | Security rules documentation, permission model, and role verification rationale. |
| `docs/backend/offline-queue-sync.md` | 173 | Technical design and failure modes for offline FIFO sync queue and quarantine logic. |

### 1.2 Production Code (`lib/`)

#### 1.2.1 Root Application & Services
| Path | Lines | One-line Purpose |
| :--- | :---: | :--- |
| `lib/main.dart` | 337 | Application entrypoint, Firebase initialization, web options, and main navigation shell. |
| `lib/admin.dart` | 701 | Admin login screen, operations dashboard shell, metric tiles, and navigation cards. |
| `lib/admin_detection.dart` | 370 | Admin inspection screen for raw/processed detection events with filtering. |
| `lib/admin_hazards.dart` | 352 | Admin management table and filter panel for confirmed and candidate road hazards. |
| `lib/admin_sensor_data.dart` | 487 | Admin inspector for high-frequency sensor readings, feature windows, and telemetry charts. |
| `lib/admin_verification.dart` | 342 | Admin triage screen for crowd cluster verification and reviewer decision submission. |
| `lib/auth.dart` | 275 | Core auth interfaces (`RoadSenseUser`, `UserRepository`, `AuthenticationService`, `MockAuthenticationService`). |
| `lib/auth_screens.dart` | 742 | UI screens and controllers for login, registration, password recovery, and email verification. |
| `lib/backend.dart` | 892 | Repository interfaces, Firestore collection constants, and Firebase repository implementations. |
| `lib/design_system.dart` | 417 | Unified UI palette, typography scales, card styling, and RoadSense theme definitions. |
| `lib/detection.dart` | 106 | Detection models, classification enum, and mock threshold classifier (`MockDetectionModel`). |
| `lib/explore.dart` | 1224 | Interactive FlutterMap screen, OSM tile provider, hazard markers, and legacy mock data source. |
| `lib/firebase_auth_service.dart` | 187 | Concrete Firebase Auth service implementation mapping `fb.User` to `RoadSenseUser`. |
| `lib/firestore_gateway.dart` | 277 | Low-level Firestore CRUD gateway converting timestamps and catching Firebase exceptions. |
| `lib/navigation_services.dart` | 493 | Nominatim place search, OSRM/ORS route calculation, and SharedPreferences recent place storage. |
| `lib/onboarding.dart` | 290 | First-run permission explanation carousel and onboarding gate controller. |
| `lib/permissions.dart` | 79 | Permission abstractions, state machine, and in-memory mock permission service. |
| `lib/profile.dart` | 379 | User profile summary, contribution counters, settings screen, and sign-out dialogs. |
| `lib/reports.dart` | 384 | Manual hazard report submission wizard (`ManualReportFlow`) and in-memory repository. |
| `lib/route_planning.dart` | 1413 | Turn-by-turn route planning UI, destination autocomplete, and hazard overlay warnings. |
| `lib/routing.dart` | 121 | Route scoring algorithms, risk calculation interfaces, and hazard impact assessment. |
| `lib/sensors.dart` | 481 | Sensor fusion engine, device orientation transforms, and mock sensor/GPS streams. |
| `lib/sync.dart` | 738 | Offline sync engine, JSON file persistence (`JsonFilePendingSyncStore`), and upload worker. |
| `lib/trips.dart` | 398 | Driver trip history screen, trip card summaries, and mock trip repository. |
| `lib/verification.dart` | 205 | Spatial/temporal crowd clustering algorithm (`VerificationService`) and verification rules. |

#### 1.2.2 Domain Layer (`lib/domain/`)
| Path | Lines | One-line Purpose |
| :--- | :---: | :--- |
| `lib/domain/classifier/hazard_classifier.dart` | 6 | Abstract interface for classification models taking `SensorWindow` to `HazardResult`. |
| `lib/domain/models/gps_fix.dart` | 27 | Immutable GPS fix data model with JSON serialization. |
| `lib/domain/models/hazard_event.dart` | 63 | Core hazard event model including geohash, severity, and verification counters. |
| `lib/domain/models/hazard_result.dart` | 28 | Detection output container holding `HazardType`, `SeverityLevel`, and confidence score. |
| `lib/domain/models/hazard_status.dart` | 1 | Enumeration of hazard lifecycle states (`unverified`, `verified`, `repaired`). |
| `lib/domain/models/hazard_type.dart` | 1 | Enumeration of core hazard types (`pothole`, `speedBump`, `unclassified`). |
| `lib/domain/models/sensor_sample.dart` | 39 | 6-DOF raw sensor sample (`ax, ay, az, gx, gy, gz`) with UTC timestamp. |
| `lib/domain/models/sensor_window.dart` | 32 | Window container grouping `SensorSample` list with associated `GpsFix`. |
| `lib/domain/models/severity_level.dart` | 1 | Enumeration of severity levels (`low`, `medium`, `high`). |
| `lib/domain/preprocessing/sensor_preprocessor.dart` | 50 | Abstract preprocessor and exponential moving average gravity vector removal filter. |
| `lib/domain/route_hazard_matcher.dart` | 402 | Spatial point-to-polyline matcher and corridor bounding-box filter for route hazards. |
| `lib/domain/route_risk.dart` | 212 | Route segment risk scoring, severity weighting, and detour recommendation heuristics. |
| `lib/domain/schema/hazard_document.dart` | 198 | Firestore document mapper for shared map hazards (`hazards` collection). |
| `lib/domain/schema/hazard_observation_document.dart` | 179 | Firestore document mapper for user/sensor hazard observations (`hazardObservations` collection). |
| `lib/domain/schema/model_prediction_document.dart` | 171 | Firestore document mapper for raw machine learning predictions (`modelPredictions` collection). |
| `lib/domain/schema/road_segment_document.dart` | 67 | Firestore document mapper for GIS road segments (`roadSegments` collection). |
| `lib/domain/schema/schema_documents.dart` | 10 | Barrel export file bundling all Firestore document schema classes. |
| `lib/domain/schema/schema_helpers.dart` | 157 | Shared Firestore serialization helpers, coordinate validators, and parsing guards. |
| `lib/domain/schema/sensor_window_document.dart` | 129 | Firestore document mapper for buffered window batches (`sensorWindows` collection). |
| `lib/domain/schema/trip_document.dart` | 174 | Firestore document mapper for recorded user trips (`trips` collection). |
| `lib/domain/schema/user_profile_document.dart` | 122 | Firestore document mapper for user account profiles (`users` collection). |
| `lib/domain/schema/user_report_document.dart` | 163 | Firestore document mapper for citizen manual hazard reports (`reports` collection). |
| `lib/domain/schema/verification_decision_document.dart` | 118 | Firestore document mapper for reviewer audit decisions (`verificationDecisions` collection). |

#### 1.2.3 Map Support Layer (`lib/map/`)
| Path | Lines | One-line Purpose |
| :--- | :---: | :--- |
| `lib/map/hazard_adapter.dart` | 58 | Adapter converting explore `Hazard` models into immutable `RouteHazardPoint` instances. |
| `lib/map/hazard_source.dart` | 103 | Injected data source interface with empty and debug implementations for navigation hazards. |
| `lib/map/navigation_controller.dart` | 305 | Route tracking controller, off-route detection, distance-to-next-hazard alerts, and rerouting. |

### 1.3 Test Suite (`test/`)
| Path | Lines | One-line Purpose |
| :--- | :---: | :--- |
| `test/admin_hazards_test.dart` | 37 | Unit tests verifying mock hazard source metadata and segment-backed statuses. |
| `test/admin_test.dart` | 135 | Widget tests checking admin dashboard navigation, role gating, and metric layout. |
| `test/auth_test.dart` | 538 | Unit and widget tests for auth controller, validation, and login/signup UI forms. |
| `test/backend_test.dart` | 107 | Contract and repository tests for mock backend services. |
| `test/detection_test.dart` | 89 | Unit tests for `DetectionService` and `MockDetectionModel` prediction logic. |
| `test/domain/models_test.dart` | 101 | JSON serialization and deserialization round-trip tests for `lib/domain/models/`. |
| `test/domain/route_hazard_matcher_test.dart` | 205 | Unit tests for route hazard spatial matching, distance-along-route, and corridor filtering. |
| `test/domain/route_risk_test.dart` | 125 | Unit tests for route risk index calculation, severity weights, and safety categorization. |
| `test/firestore_repository_test.dart` | 695 | Integration unit tests for Firestore repositories against fake gateway. |
| `test/map/hazard_adapter_test.dart` | 100 | Unit tests for hazard-to-route-point adapter and severity weight mappings. |
| `test/map/navigation_controller_test.dart` | 485 | Controller unit tests for user progress tracking, off-route detection, and hazard warnings. |
| `test/map/ors_routing_test.dart` | 298 | Unit and mock tests for OpenRouteService and OSRM API response parsing and fallbacks. |
| `test/persistent_sync_queue_test.dart` | 406 | Unit tests for JSON file queue persistence, retry exponential backoff, and quarantine logic. |
| `test/profile_test.dart` | 49 | Widget tests for user profile screen and settings dialogs. |
| `test/reports_test.dart` | 76 | Widget and validation tests for `ManualReportFlow` category selection. |
| `test/routing_test.dart` | 125 | Unit tests for route planning and hazard-avoidance routing services. |
| `test/rules/firestore_rules.test.js` | 216 | Node.js / Jest unit test suite for Firestore security rules using Firebase emulator. |
| `test/schema_models_test.dart` | 771 | Comprehensive document mapper tests verifying Firestore map conversion and validation. |
| `test/security_rules_test.dart` | 386 | Dart-based assertions validating Firestore security rules semantics and permission matrices. |
| `test/sensors_test.dart` | 175 | Unit tests for sensor fusion, window feature extraction, and battery state throttling. |
| `test/sync_test.dart` | 99 | Contract tests for sync engine upload state machine. |
| `test/trips_test.dart` | 49 | Unit and widget tests for trip history screens and repositories. |
| `test/verification_test.dart` | 133 | Unit tests for crowd clustering, spatial thresholding, and consensus qualification. |
| `test/widget_test.dart` | 143 | End-to-end smoke test for app startup, authentication gate, and shell rendering. |

### 1.4 Non-Code & Root Artifacts
| Path | Size | Purpose / Notes |
| :--- | :---: | :--- |
| `pubspec.yaml` | 4.2 KB | Project package definition, SDK constraints (`^3.13.4`), and dependencies. |
| `pubspec.lock` | 30.7 KB | Pinned lockfile of resolved package versions. |
| `analysis_options.yaml` | 1.5 KB | Static analysis rules based on `package:flutter_lints`. |
| `firebase.json` | 223 B | Firebase emulator and Firestore configuration. |
| `firestore.rules` | 9.0 KB | Security rules for Cloud Firestore database. |
| `Readme.md` | 2.3 KB | Stale top-level project overview (labels project "RoadLoop"). |
| `Main Project - Beginner Setup Guide.md` | 5.1 KB | Setup documentation containing spaces in filename and tracking `utm_` URLs. |
| `assets/welcome_road.png` | 2.7 MB | Welcome splash screen raster image asset. |
| `Abstract/Crowd-Sourced... (2).pdf` | 224 KB | Project proposal abstract PDF. |
| `Reference Papers/002.pdf` | 602 KB | Reference academic paper PDF. |

---

## 2. Dependency Graph & Import Analysis

### 2.1 Complete Import Graph (Internal `lib/` Dependencies)
```
lib/main.dart
  ├── lib/auth.dart
  ├── lib/auth_screens.dart
  ├── lib/admin.dart
  ├── lib/design_system.dart
  ├── lib/firebase_auth_service.dart
  ├── lib/navigation_services.dart
  ├── lib/onboarding.dart
  ├── lib/permissions.dart
  ├── lib/profile.dart
  ├── lib/route_planning.dart
  └── lib/trips.dart

lib/admin.dart
  ├── lib/auth.dart
  ├── lib/admin_sensor_data.dart
  ├── lib/admin_detection.dart
  ├── lib/admin_verification.dart
  ├── lib/admin_hazards.dart
  └── lib/design_system.dart

lib/backend.dart
  ├── lib/auth.dart
  ├── lib/detection.dart
  ├── lib/domain/schema/schema_documents.dart
  ├── lib/explore.dart
  ├── lib/reports.dart
  ├── lib/sensors.dart
  ├── lib/trips.dart
  └── lib/verification.dart

lib/detection.dart
  ├── lib/sensors.dart
  └── lib/explore.dart

lib/explore.dart ◄──┐ (Circular: explore ↔ routing)
  ├── lib/design_system.dart
  ├── lib/routing.dart ──────┘
  └── lib/reports.dart ◄─────┐ (Circular: explore ↔ reports)
                             └───┘

lib/routing.dart
  ├── lib/domain/route_risk.dart
  ├── lib/explore.dart
  └── lib/map/hazard_adapter.dart ──► lib/explore.dart

lib/sync.dart
  ├── lib/backend.dart
  ├── lib/design_system.dart
  ├── lib/explore.dart
  ├── lib/reports.dart
  └── lib/sensors.dart

lib/route_planning.dart
  ├── lib/design_system.dart
  ├── lib/domain/route_hazard_matcher.dart
  ├── lib/domain/route_risk.dart
  ├── lib/map/hazard_source.dart
  ├── lib/map/navigation_controller.dart
  └── lib/navigation_services.dart
```

### 2.2 Dead / Unreferenced Files in `lib/`
| File | Status | Technical Evidence |
| :--- | :---: | :--- |
| `lib/domain/classifier/hazard_classifier.dart` | **Completely Unreferenced** | Imported by 0 files across `lib/` and `test/`. Defines an abstract `HazardClassifier` never implemented. |
| `lib/domain/preprocessing/sensor_preprocessor.dart` | **Completely Unreferenced** | Imported by 0 files across `lib/` and `test/`. Contains `GravityVectorRemovalPreprocessor` which is never wired into the pipeline. |
| `lib/domain/models/hazard_event.dart` | **Test Only** | Imported by 0 files in `lib/`; imported solely by `test/domain/models_test.dart`. |
| `lib/firestore_gateway.dart` | **Test Only** | Concrete `FirestoreFirebaseGateway` is imported by 0 files in `lib/`; imported solely by `test/firestore_repository_test.dart`. Never wired into `main.dart`. |

### 2.3 The Isolated Domain Subsystem
A critical architectural finding: **The entire `lib/domain/models/` tree is an isolated island**.
- `lib/domain/models/` (`SensorSample`, `GpsFix`, `SensorWindow`, `HazardEvent`, `HazardType`, `HazardStatus`, `SeverityLevel`, `HazardResult`) is imported **only** by `test/domain/models_test.dart`, `hazard_classifier.dart`, and `sensor_preprocessor.dart`.
- The live application completely ignores `lib/domain/models/` and instead relies on ad-hoc duplicate types declared directly in `lib/sensors.dart`, `lib/detection.dart`, `lib/explore.dart`, and `lib/reports.dart`.
- Meanwhile, the Firestore schema mappers in `lib/domain/schema/` import `lib/explore.dart` instead of `lib/domain/models/`!

### 2.4 Circular Imports
Analysis detected **3 circular import cycles**:
1. `lib/explore.dart` ↔ `lib/routing.dart`
2. `lib/explore.dart` → `lib/routing.dart` → `lib/map/hazard_adapter.dart` → `lib/explore.dart`
3. `lib/explore.dart` ↔ `lib/reports.dart`

---

## 3. Reality Table

| Feature Area | Status | File & Line Evidence | Technical Reality |
| :--- | :---: | :--- | :--- |
| **Permission requests** | **MOCK** | `lib/permissions.dart:20-46`<br>`lib/main.dart:106-107` | Only `MockPermissionService` exists in the entire project. It stores an in-memory map and auto-grants permissions. No `permission_handler` plugin in `pubspec.yaml`. Motion and notification permissions are completely missing. |
| **Accelerometer / gyroscope collection** | **MOCK** | `lib/sensors.dart:115-173`<br>`pubspec.yaml:30-45` | Only `MockSensorService` exists. Hardware collection package `sensors_plus` is NOT installed. No hardware streams are registered. |
| **GPS collection** | **PARTIAL** | `lib/sensors.dart:175-225`<br>`lib/explore.dart:344-349` | `geolocator` is installed. Map centers on user using one-off `Geolocator.getCurrentPosition()` (`explore.dart:344`). However, the sensor fusion pipeline uses `MockGPSService` (`sensors.dart:175`); continuous tracking for trips is purely simulated. |
| **Windowing / preprocessing** | **PARTIAL** | `lib/sensors.dart:436-467`<br>`lib/domain/preprocessing/sensor_preprocessor.dart:8-48` | Live pipeline in `sensors.dart` flushes fixed, non-overlapping batches of 20 samples and computes simple scalar arithmetic means. No gravity vector removal, sliding stride, or speed gating. `GravityVectorRemovalPreprocessor` exists in `domain/` but is dead code. |
| **Hazard detection** | **MOCK** | `lib/detection.dart:49-82`<br>`lib/domain/classifier/hazard_classifier.dart:4-6` | `MockDetectionModel` uses trivial threshold checks (`magnitude > 14` -> pothole; `gyro > 4` -> rough road) and returns a constant hardcoded confidence of `0.5`. No real ML model, TFLite runtime, or dynamic confidence calculation exists. |
| **Local persistence & offline queue** | **PARTIAL** | `lib/sync.dart:296-323`<br>`lib/profile.dart:159-164` | `JsonFilePendingSyncStore` and `SyncService` are fully implemented and tested with quarantine and retry backoff. However, `SettingsScreen` defaults to `InMemoryPendingSyncStore` and `MockSyncBackend`. It is not instantiated in `main.dart` or connected to the collection engine. |
| **Upload to Firestore** | **PARTIAL** | `lib/backend.dart:457-789`<br>`lib/firestore_gateway.dart:14-100`<br>`lib/main.dart:47-58` | `FirestoreFirebaseGateway` and `FirebaseRoadSenseBackend` contain working Firestore document mappers and queries. However, `FirestoreFirebaseGateway` is never instantiated in production code (`main.dart` only instantiates `FirebaseAuthService`). Repositories are not wired to the UI. |
| **Multi-user consensus / clustering** | **PARTIAL** | `lib/verification.dart:65-180`<br>`firebase.json:1-17` | `VerificationService` contains an in-memory spatial clustering algorithm (`_haversineDistance <= 35m`) and qualification logic (`uniqueUsers >= 5`). However, it only runs on mock data in `AdminVerificationScreen`. There are no Cloud Functions, scheduled jobs, or Firestore triggers. |
| **Hazard map display from Firestore** | **MOCK** | `lib/explore.dart:108-260`<br>`lib/map/hazard_source.dart:32-90` | Map displays hardcoded static hazard lists (`MockRoadMapDataSource` in London; `DebugHazardSource` along routes). No Firestore query or listener is wired to any map layer. |
| **Report submission & repair confirmation** | **PARTIAL** (submission)<br>**MISSING** (repair) | `lib/reports.dart:91-357`<br>`lib/explore.dart:319` | `ManualReportFlow` UI exists and validates coordinates, but writes to `InMemoryReportRepository`. Repair confirmation flow ("Confirm repair") is completely non-existent across code, schema, and rules. |
| **Auth (user) & role gating** | **REAL** (auth)<br>**BROKEN** (roles) | `lib/firebase_auth_service.dart:14-141`<br>`lib/main.dart:197-216`<br>`firestore.rules:17-28` | Firebase email/password sign-in and sign-up are fully functional with proper error mapping. However: (1) `FirebaseAuthService` hardcodes `role: UserRole.user` for all accounts, making `AdminLoginScreen` inaccessible to real admins. (2) `main.dart` features an unauthenticated FAB providing immediate root admin access via "Preview Admin Dashboard". |
| **Trips history** | **MOCK** | `lib/trips.dart:63-120`<br>`lib/main.dart:312` | `TripsScreen` defaults to `MockTripHistoryRepository`. In `main.dart`, it is invoked as `const TripsScreen()`, rendering static mock trips. `FirebaseTripRepository` in `backend.dart` is never wired to the screen. |
| **Admin screens** | **MOCK** | `lib/admin.dart:145-212`<br>`lib/admin_sensor_data.dart:60-120`<br>`lib/admin_detection.dart:42-63`<br>`lib/admin_verification.dart:19-66`<br>`lib/admin_hazards.dart:18-30` | All admin screens (`AdminDashboard`, `AdminSensorDataScreen`, `AdminDetectionEventsScreen`, `AdminVerificationScreen`, `AdminHazardsScreen`) rely entirely on `Mock*DataSource` classes with zero Firestore connections. |

---

## 4. Duplication Report

The codebase suffers from acute domain fragmentation, with parallel type definitions created by different sub-teams:

### 4.1 GPS & Geographic Coordinates
1. `GpsFix` (`lib/domain/models/gps_fix.dart`): `lat, lng, speed, timestamp`
2. `GpsReading` (`lib/sensors.dart`): `latitude, longitude, altitude, accuracy, speedMps, timestamp`
3. `RoadLocation` (`lib/explore.dart`): `latitude, longitude`
4. `GeoCoordinates` (`lib/domain/schema/schema_helpers.dart`): `latitude, longitude`
5. `LatLng` (`package:latlong2/latlong.dart`): `latitude, longitude` (used in navigation & routing)
6. `RoutePlace` (`lib/navigation_services.dart`): `name, subtitle, latitude, longitude`

### 4.2 Sensor Readings & Windows
1. `SensorSample` (`lib/domain/models/sensor_sample.dart`): `ax, ay, az, gx, gy, gz, timestamp`
2. `SensorReading` (`lib/sensors.dart`): `Vector3 accelerometer, Vector3 gyroscope, GpsReading gps, double speedMps, DateTime timestamp`
3. `SensorWindow` (`lib/domain/models/sensor_window.dart`): Container of `List<SensorSample>` and `GpsFix`
4. `WindowFeatures` (`lib/sensors.dart`): Aggregated statistics container (`averageAccelerationMagnitude`, `averageGyroscopeMagnitude`, etc.)
5. `SensorWindowDocument` (`lib/domain/schema/sensor_window_document.dart`): Firestore schema representation with serialized samples
6. `AdminSensorRecord` / `AdminFeatureWindow` (`lib/admin_sensor_data.dart`): Duplicate models for admin UI

### 4.3 Hazard Categories & Classifications
1. `HazardType` (`lib/domain/models/hazard_type.dart`): `{ pothole, speedBump, unclassified }`
2. `HazardType` (`lib/explore.dart`): `{ pothole, roughSurface, debris, unknown }` (lacks speed breaker!)
3. `DetectionClassification` (`lib/detection.dart`): `{ pothole, speedBreaker, roughRoad, roadCrack, waterlogging, debris, other }`
4. `ReportCategory` (`lib/reports.dart`): `{ pothole, speedBreaker, roughRoad, roadCrack, openManhole, waterlogging, debris, other }`

### 4.4 Hazard Severity
1. `SeverityLevel` (`lib/domain/models/severity_level.dart`): `{ low, medium, high }`
2. `HazardSeverity` (`lib/explore.dart`): `{ possible, moderate, high }`

### 4.5 Hazard Verification & Lifecycle States
1. `HazardStatus` (`lib/domain/models/hazard_status.dart`): `{ unverified, verified, repaired }`
2. `VerificationStatus` (`lib/explore.dart`): `{ possible, underVerification, verified, rejected, resolved }`
3. `ReportStatus` (`lib/domain/schema/user_report_document.dart`): `{ submitted, triaged, verified, rejected, resolved }`

### 4.6 Hazard Entity Definitions
1. `HazardEvent` (`lib/domain/models/hazard_event.dart`)
2. `Hazard` (`lib/explore.dart`)
3. `HazardDocument` (`lib/domain/schema/hazard_document.dart`)
4. `RouteHazardPoint` (`lib/domain/route_hazard_matcher.dart`)
5. `AdminHazardRecord` (`lib/admin_hazards.dart`)

---

## 5. Security & Rule Integrity Review

### 5.1 Client-Side Privilege Escalation & Admin Gating
- **Unauthenticated Admin Backdoor:** In `lib/main.dart` lines 253–257, a `FloatingActionButton` on the root shell triggers `_showAdminOptions()`. Line 199 provides a button labeled **"Preview Admin Dashboard"** that pushes `AdminDashboard` with a hardcoded administrative user:
  ```dart
  AdminDashboard(
    user: const RoadSenseUser(
      id: 'demo-admin',
      name: 'Demo Administrator',
      email: 'admin@roadsense.demo',
      role: UserRole.administrator,
    ),
  )
  ```
  This is accessible to any unauthenticated or standard user without login or credentials.
- **Admin Login Deadlock:** In `lib/firebase_auth_service.dart` lines 149–165, `FirebaseAuthService.mapFirebaseUser` hardcodes `role: UserRole.user` for every authenticated Firebase account. It never inspects `IdTokenResult.claims['role']`. Consequently, even if a user has an `admin` custom claim in Firebase, `AdminLoginScreen` (`lib/admin.dart:46`) rejects the login with *"This account does not have admin or research access."*

### 5.2 Firestore Security Rules vs Client Behaviour
- **`detection_events` Wildcard Create:** In `firestore.rules` lines 202–207:
  ```javascript
  match /detection_events/{eventId} {
    allow read: if isAuthenticated();
    allow create: if isAuthenticated();
    allow update, delete: if false;
  }
  ```
  Any authenticated user can write arbitrary JSON payloads to `detection_events` without schema validation, geographic coordinate boundary checks, or rate limits.
- **`modelPredictions` Validation Gaps:** Lines 190–200 allow creation with coordinate validation, but fail to enforce: (1) ownership binding (`ownerUid == request.auth.uid`), (2) confidence range `[0.0, 1.0]`, and (3) realistic timestamps.
- **`hazards` Write Lock:** Lines 160–168 strictly require `isReviewer() || isTrustedAdmin()` for writes. While secure, this means any client-side code attempting to directly persist a verified hazard from the phone will be rejected with `permission-denied`.
- **Role Token Claim Assumption:** Rules rely on `request.auth.token.role` or `request.auth.token.admin == true`. There is no script or documentation in the repository explaining how administrators or reviewers obtain these custom claims.

### 5.3 Secrets & Repository Exposure
- **Google Services & API Keys:** `android/app/google-services.json` and `lib/main.dart:38-45` contain production Firebase Project ID (`roadsense-cc1f5`), OAuth Client IDs, and Web API Key (`AIzaSyBX8Rf1Cs3KLQUADtEcOPagkiyotafZXeY`). While Firebase client API keys are public by design, this key is not restricted to package names/SHA-1 fingerprints or web HTTP referrers in Google Cloud Console.
- **`.gitignore` Gaps:** The repository's `.gitignore` does not ignore:
  - Android release keystores: `*.jks`, `*.keystore`
  - Environment variable files: `.env`, `*.env`
  - Firebase service account private keys: `*service-account*.json`

---

## 6. Baseline Health & Verification

### 6.1 `flutter pub get` (Unedited Output)
```
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (110.0.0 available)
  analyzer 13.3.0 (14.6.0 available)
  coverage 1.15.1 (1.16.0 available)
  cupertino_icons 1.0.9 (2.0.0 available)
  dbus 0.7.15 (0.8.0 available)
  frontend_server_client 4.0.0 (4.2.0 available)
  geolocator_apple 2.4.2 (2.4.3 available)
  gsettings 0.2.8 (0.2.9 available)
  http_multi_server 3.2.2 (3.2.3 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  package_config 2.2.0 (3.0.0 available)
  shared_preferences_android 2.5.1 (2.5.3 available)
  shelf 1.4.2 (1.4.3 available)
  shelf_static 1.1.3 (1.2.0 available)
  test 1.31.1 (1.33.0 available)
  test_api 0.7.12 (0.7.15 available)
  test_core 0.6.18 (0.6.21 available)
  vm_service 15.3.0 (15.4.0 available)
  web 1.1.1 (1.1.2 available)
Got dependencies!
19 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
```
*Result: Exit code 0.*

### 6.2 `flutter analyze` (Unedited Output)
```
Analyzing Main-Project...                                       

warning - Unused import: 'package:road_loop/domain/route_risk.dart'. Try removing the import directive - test\map\navigation_controller_test.dart:7:8 - unused_import

1 issue found. (ran in 137.3s)
```
*Result: Exit code 1. Exactly 1 unused import warning in `test\map\navigation_controller_test.dart`.*

### 6.3 `flutter test` (Summary & End Output)
```
00:00 +0: loading D:/4th year/Main-Project/test/admin_hazards_test.dart
...
00:45 +171: All tests passed!
```
*Result: Exit code 0. 171 tests passed in 45.8 seconds.*

---

## 7. Repository Hygiene

1. **Nested Cloned Repository (`Main-Project/Main-Project`):**
   The folder `D:\4th year\Main-Project\Main-Project\` contains an entire nested git repository cloned inside itself, complete with a nested `.git` directory, `.dart_tool`, and duplicate files. This consumes hundreds of megabytes and risks catastrophic merge/tooling confusion.
2. **File Naming & Space Inconsistencies:**
   - Root document: `Main Project - Beginner Setup Guide.md` (spaces in filename).
   - Root README: `Readme.md` (non-standard casing; standard is `README.md`).
   - Abstract folder: `Abstract/Crowd-Sourced Pothole and Road Hazard Detection using Smartphone Sensor Fusion (2).pdf` (spaces, trailing `(2)`).
   - Reference papers: `Reference Papers/002.pdf` (folder with spaces, non-descriptive filename).
3. **Product & Package Naming Discrepancies:**
   - App title in UI: `RoadSense`
   - Description in pubspec: `RoadSense: Know the road around you.`
   - Package name in pubspec: `road_loop`
   - Android package identifier: `com.avanthika.roadsense`
   - Documentation in README: references `RoadLoop` throughout.
4. **Binary Files in Git Tracking:**
   - `assets/welcome_road.png`: 2.7 MB PNG image tracked in git.
   - `Abstract/... (2).pdf`: 224 KB PDF tracked in git.
   - `Reference Papers/002.pdf`: 602 KB PDF tracked in git.
5. **Stale Documentation:**
   - `Main Project - Beginner Setup Guide.md` contains outdated commands and marketing tracking query parameters (`utm_source=...`).

---

## 8. Risks, Blockers & Open Questions

### Technical Risks
1. **Physical Sensor Sampling on Android/iOS:** `sensors_plus` is not yet installed. On modern Android versions (Android 12+ / 14), sensor sampling at 50 Hz requires proper permissions, background execution considerations (foreground service with `location` or `health`/sensor type), and power management exemption.
2. **Phone Placement & Gravity Removal:** Without a vehicle-phone mount assumption or a robust orientation filter (Madgwick/Kalman), vibrations on pitch/roll will falsely trigger vertical pothole spikes. The current `DefaultOrientationHandler` only checks 90-degree UI rotations.
3. **Consensus Engine Location:** The app has in-memory clustering logic in `verification.dart`. Clustering multiple users' detections cannot realistically run on a client phone unless the phone downloads all raw observations from all users across the city. This belongs in a backend worker, Cloud Function, or admin tool.

### Open Questions for Approval Before Phase 1
1. **Nested Repo Directory:** Can we safely remove the untracked duplicate clone directory `Main-Project/`?
2. **Untracked Map Rerouting Code:** The working tree has untracked files for map rerouting (`lib/map/`, `lib/domain/route_*`, and matching tests). These tests currently pass and add real OSRM routing and hazard matching. Shall we keep and incorporate these into the unified architecture, or revert them to match `main`?
3. **Package Name vs Product Name:** We will unify the product name to **RoadSense**. Shall we keep the package name as `road_loop` (to avoid breaking Android package and asset manifests), or perform a complete rename of the package identifier to `road_sense`?
4. **Scope of Hazard Types:** We propose restricting active hazards in Phase 2 to **`pothole`**, **`speed_breaker`**, and **`unclassified`** (retiring `waterlogging`, `debris`, `open_manhole`, `cracks` to future backlog notes). Does this align with your project abstract?
5. **PDF Reference Storage:** Should reference PDFs (`Abstract/`, `Reference Papers/`) be moved to `docs/references/` within git, or moved outside the repository?

---

*End of Phase 0 Audit. Awaiting user approval to proceed to Phase 1.*
