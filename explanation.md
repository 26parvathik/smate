# SteerMate — Complete Project Explanation

## 1. Project Overview

SteerMate is a Flutter-based Advanced Driver Assistance System (ADAS) mobile app. It monitors driving behavior in real-time, detects traffic signs via an on-device YOLOv8n TFLite model, tracks harsh braking and overspeeding events, computes a per-trip safety score, and provides analytics with personalized insights.

**Firebase Project**: `steermate-736dd` — configured for Android, iOS, and Web.

### Firebase Services Used
- **Firebase Auth**: Email/password authentication for login and signup.
- **Cloud Firestore**: Two collections:
  - `users` — stores profile data (keyed by `user.uid`). Fields: `name`, `email`, `phone`, `vehicle`.
  - `trips` — stores trip logs. Fields: `userId`, `harshBraking` (int), `overspeed` (int), `score` (double), `speedLimit` (double), `timestamp` (server timestamp).
- **Firebase Storage**: Dependency declared (`firebase_storage: ^11.6.5`) but not actively used in the current codebase.

### Tech Stack & Dependencies (from `pubspec.yaml`)
| Category | Package | Version |
|---|---|---|
| GPS | `geolocator` | ^10.1.0 |
| Accelerometer | `sensors_plus` | ^4.0.2 |
| Text-to-Speech | `flutter_tts` | ^3.8.3 |
| Firebase Core | `firebase_core` | ^2.19.0 |
| Firebase Auth | `firebase_auth` | ^4.6.0 |
| Firestore | `cloud_firestore` | ^4.9.0 |
| Firebase Storage | `firebase_storage` | ^11.6.5 |
| ML Inference | `tflite_flutter` | ^0.11.0 |
| Camera | `camera` | ^0.11.0+2 |
| Image Processing | `image` | ^4.1.4 |

SDK constraint: `>=3.0.0 <4.0.0`. Theme: `ThemeData.dark()`.

---

## 2. Application Flow & Screen-by-Screen Breakdown

### 2.1 Entry Point (`main.dart`)
- Calls `WidgetsFlutterBinding.ensureInitialized()`.
- Initializes Firebase with platform-specific options from `firebase_options.dart`.
- Launches `SteerMateApp` → `MaterialApp` with dark theme, starting at `SplashScreen`.

### 2.2 Splash Screen (`splash_screen.dart`)
- Displays the app name "SteerMate" in bold italic (fontSize 42, letterSpacing 3) with three glow shadows (white, blueAccent, lightBlueAccent) on a `CheckeredBackground`.
- After a **2-second** `Timer`, navigates to `LoginScreen` via `pushReplacement`.

### 2.3 Login Screen (`login_screen.dart`)
- Two fields: Email and Password.
- Uses `FirebaseAuth.instance.signInWithEmailAndPassword()`.
- On success → `pushReplacement` to `HomeScreen`.
- Error handling for `FirebaseAuthException`: `user-not-found`, `wrong-password`, `invalid-email`.

### 2.4 Signup Screen (`signup_screen.dart`)
- Five fields: Name, Email, Phone, Vehicle, Password.
- Creates a Firebase Auth account, then writes a profile document to `Firestore → users/{uid}` with `name`, `email`, `phone`, `vehicle`.
- On success → `Navigator.pop()` back to Login.
- Handles `email-already-in-use` error.

### 2.5 Register Screen (`register_screen.dart`)
- **Legacy/unused screen**. Only takes Email and Password (no Firestore profile write). Not referenced from any navigation flow — the app uses `SignupScreen` instead.

### 2.6 Home Screen (`home_screen.dart`)
- `StatefulWidget` with a `BottomNavigationBar` (4 tabs), wrapped in `CheckeredBackground`.
- Tabs (index order): Drive → Trips → Analytics → Profile.
- Nav bar: `BottomNavigationBarType.fixed`, background `#0B1220`, selected white, unselected white70.

### 2.7 Checkered Background (`checkered_background.dart`)
- A reusable `StatelessWidget` used across Splash, Login, Signup, Home, and Driving screens.
- Renders a grid of alternating dark (`#0B1220`) and light (`#0F172A`) tiles.
- Grid: **12 columns**, rows computed dynamically from screen height. Pattern: `(row + col) % 2 == 0` → dark tile.
- Content is overlaid via a `Stack` with `SafeArea`.

---

## 3. Machine Learning: Traffic Sign Detection

### 3.1 Model File
- Path: `assets/models/best_float32.tflite` (~12.3 MB).
- Architecture: **YOLOv8n** (Nano variant), exported to float32 TFLite.
- Loaded via `Interpreter.fromAsset()` from the `tflite_flutter` package.
- The model is loaded in `DrivingScreen.initState()` (before any trip starts) so it's ready immediately.

### 3.2 Input Specifications
- **Input Tensor Shape**: `[1, 640, 640, 3]` (batch, height, width, channels).
- **Color Space**: RGB.
- **Normalization**: Each pixel channel divided by `255.0` → range `[0.0, 1.0]`.
- **Letterbox Padding**: Image is resized to fit within 640×640 while preserving aspect ratio. The remaining space is filled with gray `rgb(114, 114, 114)` (standard YOLOv8 pad color). The resized image is centered on the padded canvas.

**Letterbox scale & offset formulas:**
```
scale = min(640 / origWidth, 640 / origHeight)
newW  = round(origWidth * scale)
newH  = round(origHeight * scale)
offsetX = (640 - newW) ~/ 2    (integer division)
offsetY = (640 - newH) ~/ 2
```

### 3.3 Output Specifications
- **Output Tensor Shape**: `[1, 20, 8400]`.
  - 20 = 4 bounding-box values + 16 class scores.
  - 8400 = number of candidate anchor predictions.
- **Bounding box format** (rows 0–3): `cx, cy, w, h` — center-x, center-y, width, height — all in 640-pixel letterboxed space.
- **Class scores** (rows 4–19): Raw confidence scores for each of the 16 classes.

### 3.4 Detected Signs — 16 Classes

| Index | Label | Category | Overlay Color |
|---|---|---|---|
| 0 | Speed Limit 20 | Speed Limit | lightBlueAccent |
| 1 | Speed Limit 30 | Speed Limit | lightBlueAccent |
| 2 | Speed Limit 50 | Speed Limit | lightBlueAccent |
| 3 | Speed Limit 60 | Speed Limit | lightBlueAccent |
| 4 | Speed Limit 70 | Speed Limit | lightBlueAccent |
| 5 | Speed Limit 80 | Speed Limit | lightBlueAccent |
| 6 | Speed Limit 100 | Speed Limit | lightBlueAccent |
| 7 | Speed Limit 120 | Speed Limit | lightBlueAccent |
| 8 | Left Curve | Warning | amberAccent |
| 9 | Right Curve | Warning | amberAccent |
| 10 | Pedestrian Crossing | Warning | yellowAccent |
| 11 | No Vehicles | Prohibition | redAccent |
| 12 | School Ahead | Warning | orangeAccent |
| 13 | Keep Right | Mandatory | cyanAccent |
| 14 | Keep Left | Mandatory | cyanAccent |
| 15 | Give Way | Priority | red |

**Speed Limit Auto-Update Map** — When a speed-limit sign (classes 0–7) is the top detection, the app's `speedLimit` variable is automatically set:
- Class 0 → 20 km/h, Class 1 → 30, Class 2 → 50, Class 3 → 60, Class 4 → 70, Class 5 → 80, Class 6 → 100, Class 7 → 120.

### 3.5 Detection Thresholds & Constants
| Parameter | Value | Purpose |
|---|---|---|
| `inputSize` | 640 | Model input resolution (px) |
| `confThreshold` | **0.25** (25%) | Minimum class score to keep a detection |
| `iouThreshold` | **0.45** | IoU cutoff for NMS overlap removal |
| `numClasses` | 16 | Total sign classes |

### 3.6 Post-Processing Pipeline

**Step 1 — Find best class per anchor:**
For each of the 8400 anchors, iterate over the 16 class scores (rows 4–19). The class with the highest score is selected. If that score < `0.25`, the anchor is discarded.

**Step 2 — Convert bounding box to corner format (still in 640-space):**
```
x1 = cx - w/2
y1 = cy - h/2
x2 = cx + w/2
y2 = cy + h/2
```

**Step 3 — Reverse letterbox transform (map back to original image coordinates):**
```
finalX1 = (x1 - offsetX) / scale
finalY1 = (y1 - offsetY) / scale
finalX2 = (x2 - offsetX) / scale
finalY2 = (y2 - offsetY) / scale
```

**Step 4 — Non-Maximum Suppression (NMS):**
1. Sort all remaining detections by confidence **descending**.
2. Take the highest-confidence detection, add it to the result list.
3. Remove all remaining detections whose IoU with the selected detection exceeds `0.45`.
4. Repeat until the list is empty.

**IoU Formula:**
```
interArea = max(0, min(a.x2, b.x2) - max(a.x1, b.x1)) * max(0, min(a.y2, b.y2) - max(a.y1, b.y1))
unionArea = areaA + areaB - interArea
IoU = interArea / unionArea   (0 if unionArea == 0)
```

### 3.7 Camera Pipeline (in `DrivingScreen`)

- **Camera Selection**: Prefers back-facing camera (`CameraLensDirection.back`), falls back to first available.
- **Resolution**: `ResolutionPreset.medium`.
- **Format**: `ImageFormatGroup.yuv420`.
- **Frame Throttling**: Detection runs at most once every **500ms** (max ~2 fps). Enforced by comparing `DateTime.now()` against `_lastDetectionTime`.
- **Concurrency Guard**: A boolean `_isProcessing` flag prevents overlapping inference runs.

**YUV420 → RGB Conversion Formulas:**
```
R = clamp(Y + 1.370705 * (V - 128), 0, 255)
G = clamp(Y - 0.337633 * (U - 128) - 0.698001 * (V - 128), 0, 255)
B = clamp(Y + 1.732446 * (U - 128), 0, 255)
```
UV planes are subsampled at half resolution — `uvIndex = (y ÷ 2) * bytesPerRow + (x ÷ 2) * pixelStride`.

**Sensor Rotation**: After conversion, the image is rotated by the camera's `sensorOrientation` degrees (using `img.copyRotate`) so traffic signs appear upright for the model.

### 3.8 Detection Overlay Widget (`detection_overlay.dart`)
- A `CustomPainter` that draws rounded bounding boxes (strokeWidth 2.5, corner radius 4) and label badges over the camera preview.
- Label format: `"ClassName  XX%"` (confidence as integer percentage).
- Coordinates are scaled from original image space to widget space: `scaleX = widgetWidth / imageWidth`, `scaleY = widgetHeight / imageHeight`.
- **Note**: This overlay widget exists in the codebase but the current `DrivingScreen` UI does **not** render the full camera preview or overlay. Instead, it shows a simplified text-based detection banner ("Detected: SignName") or a "Scanning for signs..." indicator.

---

## 4. Driving Telemetry & Event Detection

### 4.1 GPS & Speed Tracking
- **Package**: `geolocator`.
- **Location Settings**: `LocationAccuracy.bestForNavigation`, `distanceFilter: 0` (emit on every position update).
- **Permission Flow**: Checks if location services are enabled → checks permission → requests if denied → shows SnackBar errors for each failure case including `deniedForever`.
- **Speed Conversion**: `position.speed` (m/s) × `3.6` = km/h.

### 4.2 Overspeeding Detection
- **Default Speed Limit**: `40 km/h` (can be changed by the UI slider or auto-updated by sign detection).
- **UI Slider Range**: 10–120 km/h, 22 divisions (increments of 5 km/h).
- **Logic**: `if (speed > speedLimit)` → overspeed event.
- **Lock Mechanism**: `overspeedLock` boolean.
  - First time speed exceeds limit → `overspeedCount++`, lock engaged, TTS speaks: *"Slow down. Overspeeding detected"*.
  - While speed remains above limit → lock stays engaged (no duplicate count).
  - When speed drops to or below limit → lock resets, `overSpeeding` UI flag set to `false`.
- **Speedometer UI**: A 220×220 circle with a 6px border. Border is **green** normally, turns **red** when overspeeding.

### 4.3 Harsh Braking Detection
- **Package**: `sensors_plus` — uses `userAccelerometerEventStream()` (gravity-removed accelerometer).
- **Magnitude**: `sqrt(x² + y² + z²)` — represents pure device acceleration.
- **All four conditions must be met simultaneously:**

| # | Constraint | Threshold | Purpose |
|---|---|---|---|
| 1 | Moving | speed ≥ **8.0 km/h** | Ignore stationary phone movements |
| 2 | Cooldown | ≥ **2 seconds** since last alert | Prevent alert spam |
| 3 | Trigger | magnitude > **4.0 m/s²** | Minimum deceleration force |
| 4 | Duration | sustained for ≥ **500 ms** | Filter out brief jolts |

**Behavior flow:**
1. If speed < 8 → reset `_harshEventStartTime`, set `harshBraking = false`, return.
2. If within 2s cooldown → reset `_harshEventStartTime`, return.
3. If magnitude > 4.0 → set `_harshEventStartTime ??= now` (start timing if not already).
   - If duration ≥ 500ms → `harshBrakeCount++`, update `_lastAlertTime`, reset timer, TTS: *"Harsh braking detected"*, set UI flag `harshBraking = true`.
   - After **2 seconds**, UI flag auto-clears via `Future.delayed`.
4. If magnitude ≤ 4.0 → reset `_harshEventStartTime` (duration resets).

**Note**: `harshLock` variable is declared but never used in the current code — it's dead code.

---

## 5. Trip Score Calculation

### 5.1 Formula
```
tripScore = 100 - (harshBrakeCount × 2) - (overspeedCount × 2)
```
- **Base Score**: 100
- **Harsh Braking Penalty**: −2 per event
- **Overspeeding Penalty**: −2 per event
- **Floor**: Clamped to minimum of **0** (`if (tripScore < 0) tripScore = 0`)

### 5.2 Trip End Flow
When the user presses "Stop Trip":
1. Cancel GPS stream and accelerometer stream.
2. Stop and dispose camera.
3. Calculate `tripScore` using the formula above.
4. If user is authenticated → save to Firestore `trips` collection:
   ```json
   {
     "userId": "<uid>",
     "harshBraking": <int>,
     "overspeed": <int>,
     "score": <double>,
     "speedLimit": <double>,
     "timestamp": FieldValue.serverTimestamp()
   }
   ```
5. Navigate to `TripSummaryScreen` (via `push`, not `pushReplacement`).

### 5.3 Trip Summary Screen (`trip_summary_screen.dart`)
Displays: "Trip Completed" heading, the driving score (large green number), and three `Card`s showing Harsh Braking Events, Overspeed Events, and Speed Limit Used. A "Back to Dashboard" button pops back.

---

## 6. Trip History (`trip_history_screen.dart`)

- Fetches all trips for the current user via a Firestore `StreamBuilder` (real-time).
- **Sorting**: Done client-side by `timestamp` descending (to avoid requiring a composite Firestore index).
- Null-safe field access: checks if field exists in data via `.toString().contains("fieldName")` before reading.
- **Default values**: score=100, harshBraking=0, overspeed=0, speedLimit=40 if fields are missing.
- Each trip is displayed as a `Card` (color `#1B1F34`, borderRadius 16) showing score, harsh braking count, overspeed count, and speed limit.

---

## 7. Analytics & Insights (`analytics_screen.dart`)

### 7.1 Data Grouping
- All user trips are fetched from Firestore, sorted by timestamp descending.
- **Recent trips**: first 7 (most recent).
- **Older trips**: next 7 (trips 8–14).
- If fewer than 7 older trips exist, older metrics default to the same value as recent metrics (no change detected).

### 7.2 Metrics Calculated

**Average Weekly Score:**
```
averageScore = sum(recentTrips.score) / recentTrips.length
```

**Hard Braking Trend** — uses `_trendLabel()`:
```
delta = recentHarshRate - olderHarshRate
if |delta| < 0.4 → "Stable this week"
if delta < 0 (fewer events) → "Improving"
if delta > 0 (more events) → "Needs attention"
```
(Lower is better for harsh braking, so `positiveWhenLower = true`.)

**Overspeed Risk:**
```
totalOverspeedEvents across recent 7 trips:
  0 events       → "Under control"
  1–2 events     → "N mild alerts"
  3+ events      → "N high-risk alerts"
```

**Road Sign Compliance:**
```
totalEvents = sum(harshBraking + overspeed) across recent trips
overspeedEvents = sum(overspeed) across recent trips
compliancePercent = ((totalEvents - overspeedEvents) / totalEvents) × 100
```
If `totalEvents == 0` → 100%. Result is clamped to `[0, 100]`.
This effectively measures the proportion of driving events that were harsh braking (not overspeeding), treating braking-only events as "compliant" behavior.

**Driving Behavior Comparison:**
```
comparisonDelta = averageScore - olderScore
  >= +4  → "Better than last week"
  <= -4  → "Lower than last week"
  else   → "Holding steady"
```

### 7.3 Insights Generation (up to 4 insights)

**Insight 1 — Braking:**
- `recentHarshRate >= 2` → *"Brake earlier to reduce repeated hard-braking events."*
- `recentHarshRate > 0` → *"Your braking is improving. Keep leaving extra stopping distance."*
- `recentHarshRate == 0` → *"Smooth braking this week. Keep that steady control."*

**Insight 2 — Overspeeding:**
- `recentOverspeedRate >= 2` → *"Overspeed events are recurring. Ease off sooner near changing speed zones."*
- `recentOverspeedRate > 0` → *"A few speed alerts appeared. Watch for posted limits after each sign detection."*
- `recentOverspeedRate == 0` → *"Great pace control. You stayed within limits across recent trips."*

**Insight 3 — Compliance:**
- `compliancePercent < 75` → *"Road-sign compliance is low. Slow down quicker after speed-limit and stop signs."*
- `compliancePercent < 90` → *"Compliance is decent, with room to improve near posted speed changes."*
- `compliancePercent >= 90` → *"Strong sign compliance. Keep scanning ahead and reacting early."*

**Insight 4 — Trend:**
- `comparisonDelta >= 4` → *"Your overall driving score is trending upward compared with earlier trips."*
- `comparisonDelta <= -4` → *"Your score dipped versus earlier trips. Focus on one habit at a time this week."*
- `averageScore >= 90` → *"You are maintaining a strong safety score. Consistency is your advantage."*
- else → *"Your driving pattern is steady. Small reductions in alerts should lift the score quickly."*

### 7.4 Analytics UI
- **Dashboard** shows 5 `_MetricCard` widgets (color `#2E6286`, borderRadius 18).
- **Insights** shown as `_InsightCard` widgets (color `#345E84`, borderRadius 16).
- Empty state shows an `insights` icon with "Analytics will appear after your first trip."

---

## 8. Profile Screen (`profile_screen.dart`)

- Fetches user document from `Firestore → users/{uid}`.
- Displays: Name, Email, Phone, Vehicle in `_ProfileRow` widgets.
- **Fallback values** on error or missing data: name="Driver", email=Firebase auth email, phone/vehicle="Not provided".
- **Logout**: Calls `FirebaseAuth.instance.signOut()`, then `pushAndRemoveUntil` to `LoginScreen` (clears entire navigation stack).
- Profile card styled with color `#10243A`, borderRadius 24, avatar circle colored `#2E6286`.

---

## 9. File Structure Summary

```
lib/
├── main.dart                    # Entry point, Firebase init
├── firebase_options.dart        # FlutterFire CLI generated config
├── splash_screen.dart           # 2-second splash with glow text
├── login_screen.dart            # Email/password login
├── signup_screen.dart           # Registration with profile fields
├── register_screen.dart         # Legacy (unused) registration
├── home_screen.dart             # Bottom nav with 4 tabs
├── driving_screen.dart          # Core ADAS: camera, GPS, accelerometer
├── trip_summary_screen.dart     # Post-trip score display
├── trip_history_screen.dart     # List of past trips from Firestore
├── analytics_screen.dart        # Aggregated metrics & insights
├── profile_screen.dart          # User profile & logout
├── checkered_background.dart    # Reusable dark checkered background
├── services/
│   └── tflite_service.dart      # YOLOv8 TFLite inference engine
└── widgets/
    └── detection_overlay.dart   # Bounding box painter (exists but unused in current UI)

assets/
└── models/
    └── best_float32.tflite      # YOLOv8n float32 model (~12.3 MB)
```
