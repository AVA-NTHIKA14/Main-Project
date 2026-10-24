# RoadSense — Cloud Firestore Security Rules & Trusted Operations (Module 05)

## 1. Overview & Objective

This document defines the Firestore security model, collection-level access policies, data validation invariants, and trusted backend operation boundaries for RoadSense (`roadsense-cc1f5`).

The security model adheres strictly to the **principle of least privilege**:
- Mobile clients are untrusted devices.
- User data and private telemetry are strictly guarded by authenticated UID ownership (`request.auth.uid`).
- **No mobile client may independently mark a hazard as confirmed, alter verification decisions, or falsely mark a hazard as resolved.**
- Authoritative lifecycle state transitions, crowd aggregation, and closure criteria require trusted server-side execution (Firebase Cloud Functions or authorized reviewer roles).

---

## 2. Collection Access Matrix

| Collection Path | Read Access | Create Access | Update Access | Delete Access | Ownership Field |
|---|---|---|---|---|---|
| `users/{uid}` | Owner only (`request.auth.uid == uid`) or Admin | Owner only (`uid == request.auth.uid`) | Owner only (allowed fields only; immutable `role` & `uid`) | Denied (`false`) | Document ID (`uid`) |
| `trips/{tripId}` | Owner only (`ownerUid == request.auth.uid`) | Owner only (`ownerUid == request.auth.uid`) | Owner only (immutable `ownerUid`) | Denied (`false`) | `ownerUid` |
| `trips/{tripId}/sensorWindows/{windowId}` | Trip owner only | Trip owner only | Denied (`false`) | Denied (`false`) | Inherited from `trips/{tripId}.ownerUid` |
| `reports/{reportId}` | Reporter only (`reporterUid == request.auth.uid`) or Reviewer | Authenticated (`reporterUid == request.auth.uid`); status must be `'submitted'` | Reviewers only | Denied (`false`) | `reporterUid` |
| `hazardObservations/{observationId}` | Reporter only (`reporterUid == request.auth.uid`) or Reviewer | Authenticated (`reporterUid == request.auth.uid`) with valid coordinates | Denied (`false`) (Immutable evidence) | Denied (`false`) | `reporterUid` |
| `hazards/{hazardId}` | All authenticated users (Map display) | **Denied for clients (`false`)** (Trusted server / Reviewer only) | **Denied for clients (`false`)** (Trusted server / Reviewer only) | **Denied for clients (`false`)** | Managed by server |
| `verificationDecisions/{decisionId}` | All authenticated users (Audit trail) | Reviewers only (`request.auth.token.role == 'reviewer'`) | Denied (`false`) (Immutable audit log) | Denied (`false`) | `reviewerUid` |
| `modelPredictions/{predictionId}` | All authenticated users | Authenticated users with valid coordinates | Denied (`false`) (Immutable candidate signal) | Denied (`false`) | N/A |
| `roadSegments/{segmentId}` | All authenticated users | Admin / GIS pipeline only | Admin / GIS pipeline only | Admin only | System-owned |

---

## 3. Data Validation & Boundary Invariants

Firestore Security Rules in `firestore.rules` enforce the following syntactic and semantic constraints:

### A. Authentication and Identity
- `request.auth != null`: Unauthenticated requests are rejected across all private collections.
- User profiles must have `request.resource.data.uid == uid` where `uid == request.auth.uid`.
- Users cannot forge email as UID; UIDs are guaranteed stable identifiers from Firebase Auth.

### B. Client Privilege Escalation Prevention
- On `users/{uid}` creation, `role` cannot be set to `administrator` or `researcher` (defaults to `'user'`).
- On `users/{uid}` update, `request.resource.data.role == resource.data.role`. A user editing their `displayName` cannot escalate their own permissions.
- `createdAt` is immutable after document creation.

### C. Geographic Coordinates Validation
- Latitude must be between $-90.0$ and $+90.0$.
- Longitude must be between $-180.0$ and $+180.0$.
- Both fields must be numeric. Submissions with missing coordinates, `NaN`, or out-of-range coordinates are rejected.

### D. Private Data Sanitization
- Reports strictly sanitize photo URLs: device-local URIs (`file://`, `/data/user/0/...`, `C:\...`) are rejected by rules (`isNotLocalPath`).
- Private reporter details (`reporterUid`, user notes) remain strictly in `reports/{reportId}` and are never readable by third-party mobile clients.

### E. Query Compatibility
- Rules rely on equality checks (`resource.data.ownerUid == request.auth.uid`) matching repository query bounds (`filters: {'ownerUid': currentUser.id}`).
- Client queries are designed with explicit `limit` clauses preventing unbounded scans.

---

## 4. Trusted Backend Operations (Cloud Functions / Server Execution)

The following high-stakes operations **MUST NOT** be performed directly by ordinary mobile client SDKs and are explicitly blocked in `firestore.rules`:

### 1. Hazard Aggregation and Deduplication
- **Why trusted:** Ordinary clients cannot be trusted to correlate multi-user reports or verify spatial clustering across distinct devices.
- **Implementation:** Triggered on new `hazardObservations` or `reports` via background Cloud Function (`onDocumentCreated`). Computes spatial proximity (DBSCAN or geohash cluster) across unique user IDs.

### 2. Hazard Confirmation (`VerificationStatus.verified`)
- **Why trusted:** A malicious or compromised client could falsely flag clear roads as hazardous or inflate road disruption.
- **Rule:** `hazards/{hazardId}` write rules deny ordinary client updates. Only an authorized Cloud Function or authenticated reviewer with custom claim `role: 'reviewer'` can confirm a hazard.
- **Agreement Status:** Person 4 owns confirmation thresholds (e.g. minimum 3 independent user observations from distinct trips within a 2-hour window).

### 3. Authoritative Verification Decisions
- **Why trusted:** Ordinary users cannot approve or dismiss crowd clusters.
- **Rule:** `verificationDecisions/{decisionId}` allows writes only when `request.auth.token.role == 'reviewer'`.

### 4. Hazard Decay and Resolution (`VerificationStatus.resolved`)
- **Why trusted:** A client cannot arbitrarily clear road hazards from the navigation map.
- **Implementation:** Scheduled Cloud Function (cron) or consecutive negative observations verifying road repair.

> [!CAUTION]
> Service account credentials and admin SDK private keys must NEVER be bundled in the Flutter application binary. All trusted operations must execute in a protected cloud environment.

---

## 5. Local Emulator Suite Setup & Validation

To validate the security rules locally using the Firebase Local Emulator Suite:

### Prerequisites:
- Node.js 18+ and npm installed
- Java Runtime Environment (JRE 11+) installed

### Emulator Configuration (`firebase.json`):
- Firestore Emulator: port `8080`
- Auth Emulator: port `9099`
- Emulator UI: port `4000`

### Commands:
```bash
# 1. Install dependencies
npm install -g firebase-tools

# 2. Start the local emulator with security rules
firebase emulators:start --only firestore,auth

# 3. Run unit tests against the emulator
npm test
```

---

## 6. Known Limitations & Teammate Dependencies

1. **Person 1 (Map UI):**
   - Public read access for `hazards` is granted to all authenticated users.
   - Exact geohash-based spatial queries and bounding box filters will be optimized when map tile requirements are finalized.

2. **Person 3 (Sensors & ML):**
   - High-frequency sensor samples are grouped into `trips/{tripId}/sensorWindows/{windowId}` or stored locally.
   - `modelPredictions/{predictionId}` stores candidate inference signals without altering map hazards.

3. **Person 4 (Hazard Intelligence):**
   - Concrete confirmation algorithms, time decay intervals, and resolution rules will be deployed as Cloud Functions in subsequent milestones.
