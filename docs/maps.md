# Google Maps

All address and buyer route maps use google_maps_flutter. Leaflet assets, iframe/WebView renderers, bridge test and the WebView dependency have been removed.

## Android

The supplied key is installed locally in **android/secrets.properties**, excluded from Git. For a fresh checkout copy android/secrets.properties.example to that filename and replace the placeholder. The file contains:

    MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY

android/app/build.gradle.kts reads this properties file into the MAPS_API_KEY manifest placeholder. android/app/src/main/AndroidManifest.xml passes it to the Maps SDK. No Secrets Gradle Plugin is required in this project. The SDK key is embedded in the APK as required; application/API restrictions control its use.

In Google Cloud project **speedy-victory-511800-v4**:

1. Enable Maps SDK for Android and complete required billing setup.
2. Restrict the key to Android apps.
3. Package: ph.easyscrap.easy_scrap.
4. Current local signing SHA-1: A3:65:C6:1F:5A:4B:86:1A:D5:06:06:F1:A3:36:5F:86:14:58:DC:FC.
5. API restriction: Maps SDK for Android only.

Check signing with ./gradlew.bat signingReport from the android directory. Current release builds also use debug signing. Configure an actual release keystore before store distribution and add its SHA-1 (and Google Play app-signing SHA-1 if applicable).

Build from app-side:

    flutter pub get
    flutter build apk --debug --dart-define=API_URL=https://easy-api.project-domain.site/api/v1

Output: build/app/outputs/flutter-apk/app-debug.apk. Install as an update. API_URL remains the backend URL, independent of the Maps key.

## Chrome

Create a **separate browser key**, enable Maps JavaScript API, restrict to Websites and allow http://localhost:5174/* and your actual Flutter website. The Android key cannot authorize websites.

    flutter run -d chrome --web-hostname=localhost --web-port=5174 --dart-define=API_URL=http://127.0.0.1:4000/api/v1 --dart-define=GOOGLE_MAPS_WEB_API_KEY=YOUR_BROWSER_MAPS_KEY

lib/ui/maps/google_maps_runtime_web.dart loads the Google script once before creating maps. Without this setting the map displays setup instructions. Rebuild after changing the key. Website keys are visible in browser code; referrer/API restrictions control their use.

## iOS later

The shared map widget supports iOS, but no iOS key was supplied and it was not tested on Windows. Enable Maps SDK for iOS, obtain a bundle-restricted key, add import GoogleMaps and GMSServices.provideAPIKey(...) to ios/Runner/AppDelegate.swift following Google's guide and meet the resolved plugin's deployment target. Only after that build with --dart-define=GOOGLE_MAPS_IOS_CONFIGURED=true on macOS/Xcode. Until configured the map displays instructions instead of invoking an unconfigured SDK.

## Preserved behavior

- Address maps start collapsed; buyer My Route starts expanded. Hidden controls stay inside the collapsed body.
- Set pin enables taps/dragging. The reverse address and municipality/barangay must be reviewed before saving. Municipality selection alone does not move the pin; selecting the barangay starts the lookup.
- Google street and satellite-with-labels views. Satellite is not a Street View panorama.
- Blue vehicle pin marks the route start. Use my location requests device GPS on demand, not continuously.
- Numbered, color-coded pointed pickup pins. Nearby pins are separated visually with connector lines to original coordinates; saved coordinates and road geometry do not change.
- Maps temporarily yield their platform surface while Flutter dialogs are open so confirmation buttons remain clickable.
- Address lookups retain request-driven loading overlays. Failed providers leave manual selection available.

## Provider separation

Google renders the map using the supplied Android SDK key. **Photon** still provides address/reverse estimates and **OSRM** supplies road geometry, distance and duration. These services are independent of Leaflet; there is no Leaflet fallback. OSRM/OpenStreetMap route attribution remains visible.

The Photon-compatible MAP_GEOCODER_URL / MAP_REVERSE_GEOCODER_URL and OSRM-compatible MAP_ROUTER_URL remain in lib/core/map_config.dart. Do not substitute Google URLs: their request/response formats differ.

To migrate address lookup and routes to Google too, enable Geocoding API and Routes API, create a separate server key and implement authenticated, bounded backend endpoints. Keep that key in backend environment variables, never the APK. No server key or Google routing/geocoding endpoints were added in this display migration.

Routes follow pickup schedule order, without optimization, live traffic or turn-by-turn navigation. Public Photon/OSRM services have limited capacity. Approximate barangay coordinates cannot establish an exact purok/house; users must review the pin. The bundled Philippine JSON location codes remain unchanged.

## Verification

    flutter analyze
    flutter test
    flutter build web

Desktop widget tests show a platform placeholder and do not prove Google Cloud authorization or actual tiles. On a real phone verify open/collapse, satellite switch, drag/save pin and address, close pickup markers, routes, GPS permission and Confirm/Keep request dialogs.

If Android maps are blank, inspect adb logcat for authorization errors and check billing, enabled API, package/SHA-1 restrictions and internet access. Rebuild after key changes. A successful build does not validate Cloud authorization.

References: [Flutter setup](https://developers.google.com/maps/flutter-package/config), [Android keys](https://developers.google.com/maps/documentation/android-sdk/get-api-key), [key security](https://developers.google.com/maps/api-security-best-practices), [pricing](https://developers.google.com/maps/billing-and-pricing/overview).

## Pin editing and barangay lookup fixes

Set pin and Use my location are above the map. Use my location requests the device GPS; a profile/address marker is not the device's current location. Allow precise location when Android asks. Set pin supports tap, long-press and hold/drag, with eager gesture handling only during editing so the surrounding ListView cannot steal map gestures. Pending reverse lookups do not block subsequent taps; stale responses are ignored.

Selecting a barangay uses explicit matching municipality evidence or a matching municipal postal code when Photon omits that field. Live Photon data identifies Guinobatan, Trinidad near 10.073630 / 124.356214, while another Guinobatan has a different postal code. These are barangay estimates, not house coordinates or administrative boundary proof. An unresolved barangay cannot silently be saved as the municipality centre.

A tapped/GPS pin triggers reverse lookup, then populates barangay/municipality codes when uniquely matched to bundled data. The draft address and exact coordinates appear before saving. Correcting the address fields after a manual/GPS pin preserves its coordinates. Review uncertain results manually; provider data cannot guarantee every barangay boundary. Save pin & address persists both through the existing backend contract. Google map taps supply coordinates, while Photon is still the reverse address provider; this does not activate Google Geocoding API.
