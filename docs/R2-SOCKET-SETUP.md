# Flutter: API, private R2 uploads and Socket.IO

Uploads remain authenticated through backend-api and stored in private R2. Notification transport now uses Socket.IO and backend-issued tickets; no transport signing/publishing secret belongs in the APK.

```powershell
flutter pub get
flutter run --dart-define=API_URL=https://YOUR-BACKEND-DOMAIN/api/v1
flutter build apk --release --dart-define=API_URL=https://YOUR-BACKEND-DOMAIN/api/v1
```

For a local API on a physical phone use your PC LAN IP; localhost refers to the phone. Android system alerts need notification permission and an active process/socket. Flutter web gets real-time state updates; add its exact browser origin to the backend and socket allowlists. Closed/terminated apps cannot be woken by this transport. Reconnection/resume refreshes persistent API history.

Open bell ? Notifications to see connection status, reconnect or send a self-test. Test assigned-buyer/household chat, offers, pickup changes, document review and announcements with separate real accounts.

For Render/Vercel variables, renewal, retries, security limits and deployment order see [Socket.IO integration](../../socket-server/docs/APP-INTEGRATION.md). Maps API configuration remains separate in [maps.md](maps.md).
