# RoadSense — Cloud Firestore Schema & Data Contracts (Module 03)

**Author:** Person 2 — Backend, Firebase & Data Integration  
**Status:** Provisional (Draft for Team Review)  
**Schema Version:** 1  

---

## 1. Overview & Classification Legend

This document defines the Cloud Firestore data model schema for the RoadSense crowd-sourced hazard detection and navigation platform.

### Field & Decision Status Legend
- **[Existing]:** Verified as currently implemented and functioning in the repository codebase.
- **[Proposed]:** Designed backend foundation ready for team integration.
- **[Pending]:** Awaiting formal decision, confirmation, or technical input from the responsible teammate.
- **[Agreed]:** Formally discussed and agreed upon across all affected team members (none marked agreed without explicit confirmation).

---

## 2. Provisional Firestore Collections

```
Cloud Firestore
├── users/{uid}                                    [User Profile & Account Metadata]
├── trips/{tripId}                                 [Trip Metadata & Ownership]
│   └── sensorWindows/{windowId}                   [Bounded Sensor Windows / Features]
├── hazardObservations/{observationId}             [Sensor & Manual Hazard Observations]
├── reports/{reportId}                             [User-Submitted Road Hazard Reports]
├── hazards/{hazardId}                             [Confirmed Map Hazards for Active Routing]
├── verificationDecisions/{decisionId}             [Authoritative Review Decisions]
├── modelPredictions/{predictionId}                [Candidate ML Inferences (Isolated)]
└── roadSegments/{segmentId}                       [Topological Road Segments (Optional)]
```

---

## 3. Collection Specifications

### 3.1 `users/{uid}`
- **Purpose:** User profile, display details, and account metadata.
- **Ownership:** Document key matches the authenticated Firebase Authentication UID.
- **Security Constraint:** Passwords and credentials are never stored. Role fields cannot grant administrative privileges client-side.

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `uid` | String | **[Existing]** | Stable Firebase Authentication UID (never email). |
| `displayName` | String | **[Existing]** | Public or self-assigned driver display name. |
| `email` | String | **[Existing]** | Account contact email from Firebase Auth. |
| `role` | String (`user`, `administrator`, `researcher`) | **[Existing]** | Authorization role (default: `user`). Client-side changes cannot escalate privileges. |
| `isEmailVerified` | Boolean | **[Existing]** | Synced verification status from Firebase Auth. |
| `createdAt` | Timestamp / ISO 8601 | **[Proposed]** | UTC timestamp of account creation. |
| `updatedAt` | Timestamp / ISO 8601 (nullable) | **[Proposed]** | Last profile update timestamp. |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

### 3.2 `trips/{tripId}`
- **Purpose:** Stable trip metadata, summary telemetry, and user ownership.
- **Ownership:** `ownerUid` must match the authenticated contributor UID.
- **Architecture Note:** High-frequency raw sensor telemetry (100Hz+) is intentionally **excluded** from this document to prevent document size bloat and excessive Firestore write costs.

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `tripId` | String | **[Existing]** | Unique trip identifier. |
| `ownerUid` | String | **[Proposed]** | Firebase Auth UID of the driver/contributor. |
| `startedAt` | Timestamp / ISO 8601 | **[Existing]** | Trip start timestamp (UTC). |
| `endedAt` | Timestamp / ISO 8601 (nullable) | **[Existing]** | Trip completion timestamp (UTC; null if in-progress). |
| `durationSeconds` | Integer (nullable) | **[Existing]** | Total trip duration in seconds. |
| `distanceKm` | Double (nullable) | **[Existing]** | Total travel distance in kilometers (>= 0.0). |
| `startLabel` | String (nullable) | **[Existing]** | Human-readable start place description. |
| `endLabel` | String (nullable) | **[Existing]** | Human-readable destination place description. |
| `roadQuality` | String (nullable) | **[Existing]** | Qualitative trip assessment label (e.g., 'Mostly clear'). |
| `status` | String (`inProgress`, `completed`, `cancelled`) | **[Proposed]** | Lifecycle state of the trip. |
| `observationCount`| Integer | **[Proposed]** | Number of hazard observations generated on this trip. |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

### 3.3 `trips/{tripId}/sensorWindows/{windowId}` (Subcollection)
- **Purpose:** Bounded statistical sensor feature windows (e.g., 2–5s windows) associated with a trip.
- **Ownership:** Inherits trip ownership (`ownerUid`).

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `windowId` | String | **[Existing]** | Unique identifier for the sensor time window. |
| `tripId` | String | **[Existing]** | Parent trip identifier reference. |
| `ownerUid` | String | **[Proposed]** | Contributor UID. |
| `startTime` | Timestamp / ISO 8601 | **[Existing]** | Window commencement UTC timestamp. |
| `endTime` | Timestamp / ISO 8601 | **[Existing]** | Window conclusion UTC timestamp. |
| `sampleCount` | Integer | **[Proposed]** | Count of raw sensor points summarized in this window. |
| `latitude` | Double (nullable) | **[Proposed]** | Representative GPS latitude (-90.0 to 90.0). |
| `longitude` | Double (nullable) | **[Proposed]** | Representative GPS longitude (-180.0 to 180.0). |
| `averageSpeedMps` | Double (nullable) | **[Existing]** | Mean vehicle speed during window (m/s). |
| `peakAccelerationMagnitude` | Double (nullable) | **[Proposed]** | Maximum instantaneous acceleration magnitude ($m/s^2$). |
| `averageAccelerationMagnitude` | Double (nullable) | **[Existing]** | Mean acceleration magnitude ($m/s^2$). |
| `averageGyroscopeMagnitude` | Double (nullable) | **[Existing]** | Mean rotational velocity ($rad/s$). |
| `retainedSamples` | Array of Maps (nullable) | **[Pending]** | Raw sample buffer if Person 3 requires offline retraining retention. |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

### 3.4 `hazardObservations/{observationId}`
- **Purpose:** Granular hazard detections or user observations contributing toward hazard clustering and verification.
- **Separation:** Observations are inputs to clustering; they are **never** treated as confirmed map hazards without corroboration.

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `observationId` | String | **[Existing]** | Unique observation identifier. |
| `reporterUid` | String | **[Proposed]** | Firebase Auth UID of the contributing driver (never email). |
| `tripId` | String (nullable) | **[Existing]** | Originating trip identifier. |
| `latitude` | Double | **[Existing]** | Geographic latitude (-90.0 to 90.0). |
| `longitude` | Double | **[Existing]** | Geographic longitude (-180.0 to 180.0). |
| `type` | String (`pothole`, `roughSurface`, `debris`, `unknown`) | **[Existing]** | Detected or observed hazard category. |
| `severity` | String (`possible`, `moderate`, `high`) | **[Existing]** | Estimated severity level. |
| `timestamp` | Timestamp / ISO 8601 | **[Existing]** | Observation occurrence UTC timestamp. |
| `source` | String (`sensorDetection`, `manualReport`, `crowdCluster`, `verifiedReview`) | **[Proposed]** | Origin channel of the observation. |
| `sensorWindowId`| String (nullable) | **[Proposed]** | Sensor window that triggered the observation. |
| `segmentId` | String | **[Existing]** | Road segment ID ('unmatched' if topological match pending). |
| `confidence` | Double (nullable) | **[Proposed]** | Detection confidence estimate ($0.0 \dots 1.0$). |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

### 3.5 `reports/{reportId}`
- **Purpose:** User-submitted road hazard reports submitted via the in-app manual report flow.
- **Privacy Boundary:** Reporter UID is retained for attribution and integrity, but personal details are excluded from public map documents.

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `reportId` | String | **[Existing]** | Unique report identifier. |
| `reporterUid` | String | **[Proposed]** | Submitting user's Firebase Auth UID. |
| `tripId` | String (nullable) | **[Existing]** | Active trip identifier if reported while driving. |
| `category` | String (`pothole`, `speedBreaker`, `roughRoad`, `roadCrack`, `openManhole`, `waterlogging`, `debris`, `other`) | **[Existing]** | User-selected report category. |
| `latitude` | Double | **[Existing]** | Validated latitude (-90.0 to 90.0). Missing coordinates rejected. |
| `longitude` | Double | **[Existing]** | Validated longitude (-180.0 to 180.0). Missing coordinates rejected. |
| `severity` | String (`possible`, `moderate`, `high`) | **[Existing]** | User-selected severity estimate. |
| `submittedAt` | Timestamp / ISO 8601 | **[Existing]** | Submission timestamp (UTC). |
| `description` | String (nullable) | **[Existing]** | Optional user text commentary. |
| `photoUrl` | String (nullable) | **[Proposed]** | Public Cloud Storage download URL. Local device file paths (`file://`, `/data/`) are strictly filtered and rejected. |
| `status` | String (`submitted`, `underReview`, `accepted`, `rejected`) | **[Proposed]** | Editorial review status. |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

### 3.6 `hazards/{hazardId}`
- **Purpose:** Shared hazard representation queried by Person 1 for active map display and routing warnings.
- **Strict Boundary:** An unverified sensor observation or ML prediction **must not** directly create or modify a confirmed hazard document without verification logic (Person 4).

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `hazardId` | String | **[Existing]** | Shared unique hazard identifier. |
| `latitude` | Double | **[Existing]** | Geographic latitude (-90.0 to 90.0). |
| `longitude` | Double | **[Existing]** | Geographic longitude (-180.0 to 180.0). |
| `geohash` | String (nullable) | **[Proposed]** | Spatial geohash for range bounding queries. |
| `type` | String (`pothole`, `roughSurface`, `debris`, `unknown`) | **[Existing]** | Verified hazard type. |
| `severity` | String (`possible`, `moderate`, `high`) | **[Existing]** | Overall assessed hazard severity. |
| `status` | String (`possible`, `underVerification`, `verified`, `rejected`, `resolved`) | **[Existing]** | Current lifecycle verification status. |
| `confidence` | Double | **[Existing]** | Aggregated confidence score ($0.0 \dots 1.0$). |
| `observationCount` | Integer | **[Existing]** | Total corroborating observations. |
| `uniqueUserCount` | Integer | **[Existing]** | Count of distinct contributing users. |
| `segmentId` | String | **[Existing]** | Associated road segment ID. |
| `firstObserved` | Timestamp / ISO 8601 | **[Existing]** | First time this hazard was detected (UTC). |
| `lastObserved` | Timestamp / ISO 8601 | **[Existing]** | Most recent detection timestamp (UTC). |
| `lastConfirmedAt` | Timestamp / ISO 8601 (nullable) | **[Proposed]** | When verification criteria was met. |
| `resolvedAt` | Timestamp / ISO 8601 (nullable) | **[Proposed]** | When hazard was verified repaired or removed. |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

### 3.7 `verificationDecisions/{decisionId}`
- **Purpose:** Authoritative record of hazard verification transitions (verified, rejected, expired, repaired).
- **Security Rule:** Self-authorization by standard clients is rejected. Only authorized reviewers or backend administrative triggers may generate records.

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `decisionId` | String | **[Proposed]** | Unique audit record identifier. |
| `hazardId` | String | **[Existing]** | Referenced hazard or crowd cluster ID. |
| `reviewerUid` | String | **[Existing]** | Firebase Auth UID of the reviewer or backend service. |
| `status` | String (`verified`, `rejected`, `resolved`) | **[Existing]** | Concluded lifecycle status. |
| `reasons` | Array of Strings | **[Existing]** | List of heuristic or manual decision justification notes. |
| `independentObservationCount` | Integer | **[Existing]** | Count of independent corroborations confirmed. |
| `confidence` | Double | **[Existing]** | Verified confidence level ($0.0 \dots 1.0$). |
| `timestamp` | Timestamp / ISO 8601 | **[Existing]** | Review execution UTC timestamp. |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

### 3.8 `modelPredictions/{predictionId}`
- **Purpose:** Raw candidate inference records output by mobile TFLite or server-side ML models.
- **Strict Boundary:** Completely isolated from map display queries.

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `predictionId` | String | **[Proposed]** | Unique inference result identifier. |
| `sensorWindowId`| String | **[Existing]** | Referenced sensor feature window ID. |
| `tripId` | String (nullable) | **[Proposed]** | Trip identifier. |
| `classification`| String (`pothole`, `speedBreaker`, `roughRoad`, `roadCrack`, `waterlogging`, `debris`, `other`) | **[Existing]** | Predicted classification. |
| `confidence` | Double | **[Existing]** | Model inference confidence ($0.0 \dots 1.0$). |
| `severityEstimate` | String (`possible`, `moderate`, `high`) | **[Existing]** | Model-estimated severity. |
| `latitude` | Double | **[Existing]** | GPS latitude (-90.0 to 90.0). |
| `longitude` | Double | **[Existing]** | GPS longitude (-180.0 to 180.0). |
| `speedMps` | Double | **[Existing]** | Vehicle travel speed during detection. |
| `modelVersion` | String | **[Existing]** | Model artifact identifier (e.g., `'mock-demo-1.0'`). |
| `source` | String (`mockDemo`, `tensorFlowLite`) | **[Existing]** | Inference engine source. |
| `timestamp` | Timestamp / ISO 8601 | **[Existing]** | Timestamp of inference execution (UTC). |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

### 3.9 `roadSegments/{segmentId}`
- **Purpose:** Optional topological road segments for corridor clustering and OSRM route matching.

| Field | Type | Status | Description |
| --- | --- | --- | --- |
| `segmentId` | String | **[Existing]** | Unique road segment identifier. |
| `name` | String (nullable) | **[Proposed]** | Road name or highway code. |
| `points` | Array of Maps (`latitude`, `longitude`) | **[Existing]** | List of coordinate vertices defining the segment. |
| `hazardCount` | Integer | **[Proposed]** | Number of active hazards along this segment. |
| `updatedAt` | Timestamp / ISO 8601 (nullable) | **[Proposed]** | Last topology update timestamp. |
| `schemaVersion` | Integer | **[Proposed]** | Schema version number (default: 1). |

---

## 4. Cross-Team Integration Dependencies

### Person 1 — Maps & Routing
- **Active Hazard Contract:** Query `hazards` collection where `status == 'verified'`. Map pins require `hazardId`, `latitude`, `longitude`, `type`, `severity`, and `confidence`.
- **Public Field Safety:** `hazards` records contain zero personal data or individual UIDs. Safe for public map display.
- **Routing Alerts:** Rerouting checks should filter by road segment `segmentId` and active bounding box.

### Person 3 — Sensors & ML
- **Sensor Retention Decision [Pending]:** Confirm whether raw high-frequency accelerometer/gyroscope arrays are uploaded for model retraining or if only bounded feature windows (`sensorWindows`) are retained.
- **Model Inferences:** ML model outputs must be committed to `modelPredictions`, referencing `sensorWindowId`. They do **not** write to `hazards`.
- **Consent/Bandwidth:** Ensure user sensor preference toggle in Settings dictates whether raw window samples are synced.

### Person 4 — Hazard Intelligence & Clustering
- **Deduplication Heuristic [Pending]:** Confirm spatial radius ($r = 35m$) and temporal window ($\Delta t = 30m$) for clustering `hazardObservations`.
- **Promotion to Confirmed Hazard [Pending]:** Agree on threshold of independent users ($N \ge 5$) required before a cluster triggers creation/update of a `hazards` document with `status = 'verified'`.
- **Lifecycle Expiry [Pending]:** Agree on hazard decay/re-verification rules (e.g., hazard auto-transitions to `underVerification` if not corroborated for 14 days).

### Person 2 — Backend Foundations
- **Persistence Boundary:** Domain models use standard Dart `DateTime` and `double` coordinates. Persisted payloads map cleanly to ISO 8601 strings, millisecond timestamps, and Firestore `Timestamp` objects.
- **Versioning:** All document models include `schemaVersion = 1` for seamless backward compatibility in future migrations.
- **No Client Privilege Escalation:** Firestore rules in Module 04 will enforce that `role` in `users` and `status` in `verificationDecisions` cannot be authored by standard authenticated clients.

---

## 5. Open Questions for Team Alignment

1. **Sensor Storage Budget:** Does RoadSense have the Cloud Storage/Firestore budget to store raw accelerometer arrays in `retainedSamples`, or should we store only statistical features and drop raw waveforms after on-device inference? *(Assignee: Person 3)*
2. **Hazard Corroboration Threshold:** Is $N = 5$ independent users with confidence $\ge 0.7$ sufficient to promote an unverified observation to a verified map hazard? *(Assignee: Person 4)*
3. **Hazard Expiry Time:** How many days without observations should elapse before a verified hazard is flagged for re-verification or considered repaired? *(Assignee: Person 4 & Person 1)*
4. **Geohashing Precision:** Will Person 1 query hazards using geohash prefixes (length 6 ~ 1.2km × 0.6km) or bounding-box latitude/longitude queries? *(Assignee: Person 1)*
