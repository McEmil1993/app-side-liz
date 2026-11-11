# EasyScrap Flutter app

Household and Scrap Buyer app connected to the Express/MySQL backend. The prototype colors and navigation are retained; maps now use Google Maps. See [map setup](docs/maps.md) for Android keys, Chrome configuration and routing providers. Android package: **`ph.easyscrap.easy_scrap`**.

## Current Docker / Cloudflare APK build

The default API in `lib/core/app_config.dart` points to `https://easy-api.project-domain.site/api/v1`. The socket URL comes from the backend ticket endpoint through Docker backend `SOCKET_PUBLIC_URL`; no socket secret or separate socket URL is needed in Flutter.

Run these yourself from the workspace root:

```bash
cd app-side
flutter pub get
flutter build apk --debug
```

For release, use `flutter build apk --release`. Outputs are `build/app/outputs/flutter-apk/app-debug.apk` and `app-release.apk`. Remove any old `--dart-define=API_URL=...`, because it overrides this default. Rebuild the APK after changing the backend URL. Update Docker backend `SOCKET_PUBLIC_URL` and recreate that backend when the socket URL changes.

## Local Chrome development (Git Bash)

Terminal 1, from the project root:

```bash
cd backend-api
npm install
npm run db:migrate
npm run db:seed
npm run dev
```

Terminal 2:

```bash
cd app-side
export PATH="/c/src/flutter/bin:$PATH"
flutter pub get
flutter run -d chrome --web-hostname=localhost --web-port=5174 \
  --dart-define=API_URL=http://127.0.0.1:4000/api/v1 \
  --dart-define=GOOGLE_MAPS_WEB_API_KEY=YOUR_BROWSER_MAPS_KEY
```

The local backend `.env` now allows `http://localhost:5174` and `http://127.0.0.1:5174` in `CLIENT_ORIGINS`. Restart the backend after environment changes. Keep the same web port for saved sessions. The admin continues at `http://localhost:5173`.

Register a **Household** and a **Scrap Buyer** in the Flutter app. Existing active household/buyer DB accounts can also sign in. Admin accounts use admin-side, not the mobile login. The old `household`/`buyer` demo credentials are available only in explicit demo mode below.

## Change the API URL in one place

Edit **`lib/core/app_config.dart`**:

```dart
static const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://easy-api.project-domain.site/api/v1',
);
```

Notifications use Socket.IO with authenticated backend tickets and persistent SQL history. See [deployment and integration steps](../socket-server/docs/APP-INTEGRATION.md).

| Run target | API URL |
|---|---|
| Chrome on the same PC | `http://127.0.0.1:4000/api/v1` |
| Android Studio emulator | `http://10.0.2.2:4000/api/v1` |
| Physical Android phone | `http://YOUR_PC_LAN_IP:4000/api/v1` on the same Wi-Fi |
| Vercel backend | Your deployed HTTPS URL ending in `/api/v1` |

For a physical phone, `127.0.0.1` refers to the phone. Configure the backend `HOST=0.0.0.0`, restart it, use your PC's LAN IP and allow the local development port through Windows Firewall. Restore loopback binding when LAN access is no longer needed.

Before switching to Vercel, deploy the updated backend and apply migrations to its cloud database. Only the **local** database was migrated during this implementation. Cloud deployment/DB changes were not performed.

## Android Studio / debug APK

Open `app-side` as a Flutter project. SDK on this PC: `C:\src\flutter`. Flutter 3.44.8 / Dart 3.12.2 was used. Android API 24+ is required. Select an emulator or connect a phone with USB debugging.

```bash
# Android emulator
flutter run --dart-define=API_URL=http://10.0.2.2:4000/api/v1

# APK for an Android emulator / emulator-accessible local backend
flutter build apk --debug \
  --dart-define=API_URL=http://10.0.2.2:4000/api/v1

# APK for a physical phone: replace this sample IP with your PC IP
flutter build apk --debug \
  --dart-define=API_URL=http://192.168.1.10:4000/api/v1
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. Local HTTP is allowed only in the debug Android manifest. Use an HTTPS backend for release builds. Configure `JAVA_HOME` to a valid installed JDK when building; on this machine a working JDK is under `C:/Program Files/Apache NetBeans/jdk`. Do not commit a machine-specific JDK path.

The iOS project and portable UI/repositories are included. iOS compilation/signing requires macOS/Xcode and has not been run on this Windows machine. Existing camera/photo/location permission descriptions remain in `ios/Runner/Info.plist`.

## Connected features

- Login, registration, restored sessions and logout using separate mobile Bearer JWTs. Admin session cookies remain separate. Android/iOS session storage uses the secure-storage plugin; web storage requires localhost or HTTPS ([package documentation](https://pub.dev/packages/flutter_secure_storage)).
- Profile name/contact/username/email/address editing, nullable middle name/suffix, profile photo selection, square crop, zoom/rotate, compression and upload. Changes persist in MySQL.
- Municipality/barangay dropdowns use the four bundled Philippine JSON datasets. DB stores their original 9-digit codes. Region VII and Bohol remain fixed.
- Map pin and reverse-resolved address saving; address changes invalidate the previous profile pin. Exact pickup pins stay private until the household selects a buyer.
- Buyer verification: upload business permit, valid ID and shop photo, inspect/save submitted documents, see pending/approved/rejected status and rejection reason, and resubmit after rejection. Admin-side uses the same review records. Pending buyers can sign in and submit documents; LGU approval unlocks marketplace/offers.
- Household scrap posting with photo, active categories from the database, scheduled window, notes and address/pin.
- Buyer offers, household selection, assigned pickups/My Route, on-the-way/arrived updates, recorded actual kg/cash, household confirmation/dispute and cancellation before travel.
Notifications use Socket.IO with authenticated backend tickets and persistent SQL history. See [deployment and integration steps](../socket-server/docs/APP-INTEGRATION.md).
- Confirmed collections appear in admin reports using actual kilograms and recorded cash value. Estimated or unconfirmed/disputed records are excluded.

Verification files: JPEG/PNG/PDF, **512 KB per stored file**, three required types. Images selected up to 5 MB are resized/compressed before upload; PDFs must already fit 512 KB. Profile photos are cropped/compressed to JPEG. New photo/document contents are stored privately in Cloudflare R2; MySQL stores metadata and relationships. Existing authenticated response formats are preserved. Legacy blobs remain readable until the explicit, verified R2 migration completes. Configure the R2 bucket before using new uploads.

The current app posts one category per pickup, matching its existing form. A snapshot loads up to 200 recent accessible pickups, 1,000 recent accessible messages, 100 notifications and 20 active announcements. This is a bounded capstone implementation; there is no background live-location tracking or silent cloud deployment. Push retries use the backend database outbox and configured scheduler.

## Suggested defense walkthrough

1. Register household and buyer accounts. Use separate Chrome profiles/Incognito or separate devices if both sessions need to remain open.
2. Buyer → Profile → Documents: upload all three files.
3. Admin → Buyer Verification: Review, view documents, complete both checks and approve.
4. Buyer taps Refresh. Household posts scrap with a photo and future time window.
5. Buyer sends an offer. Household refreshes and selects the buyer.
6. Buyer opens My Route/Pickup Details, marks On the way, then Arrived, and records weight/payment.
7. Household refreshes, reviews the collection and confirms. Admin Reports shows the actual kg.

## Source layout

```text
lib/core/app_config.dart            API URL and explicit demo flag
lib/data/api_client.dart            HTTP, timeouts, bearer token and session store
lib/data/api_auth_repository.dart   Account/profile/verification API mapping
lib/data/api_recycling_repository.dart  Pickup/offer/chat/collection API mapping
lib/data/upload_image.dart          Image normalization/crop/compression
lib/application/app_controller.dart Shared application state and actions
lib/ui/connected_profile_screen.dart Profile editor, avatar editor and documents
assets/data/                       Bundled geographic JSON (included in APK)
```

## Verify

```bash
flutter analyze
flutter test
flutter build web
```

Optional live-client test, with local backend running:

```bash
flutter test test/api_live_test.dart --dart-define=LIVE_API_TEST=true
cd ../backend-api
node scripts/cleanup-flutter-smoke.js
```

The live test creates isolated `flutter_api_test_*` accounts. The cleanup validates the recorded prefix and deletes only those fixture accounts/records from a local DB. Backend API integration tests: `cd backend-api && npm test`.

To preview the previous in-memory app without a backend:

```bash
flutter run -d chrome --dart-define=DEMO_MODE=true
```

Demo mode is explicit; a failed API request never silently switches to fake data.

### Instant chat and Android alerts

Chat messages appear immediately with `Sending...` while the API confirms them. Confirmed recipient messages are inserted directly from socket events; API history still reconciles after reconnect. Deploy the updated backend before installing the new APK. Release builds preserve the Android alert icon through `android/app/src/main/res/raw/keep.xml`. See [deployment notes](../socket-server/docs/APP-INTEGRATION.md).

### Permissions on Android

On first open, the app requests notifications and foreground location in sequence, independently of login/API availability. Choices are remembered per installation. Open **Profile > App settings > App permissions** to view status and request access again. Permanently blocked permissions use a direct Android app-settings link, and status refreshes when you return. Photos/files use the system picker; internet has no runtime permission prompt. This does not enable alerts when the app is terminated.

Notification prompts are supported on Android 13+. Existing granted permissions do not show another prompt after an APK update. `permission_handler` is pinned to 12.0.1 for the project's current Android SDK 36 toolchain; upgrading it requires checking its native SDK requirements.
