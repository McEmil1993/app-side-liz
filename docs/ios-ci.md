# iOS builds from Windows

The Git repository root is `app-side`, not its parent `maam-liz` folder.
The remote default branch was verified as `main`. The workflow at
`.github/workflows/flutter-ios.yml` runs on pushes to `main`, pull requests into
`main`, and manual dispatch. Pushes to feature branches do not start another
build alongside their pull request. New runs cancel older runs for the same PR
or branch. If the default branch is renamed, update both branch filters.

## Build environment and behavior

- GitHub-hosted `macos-26`, stable Xcode **26.6**, Flutter **3.44.8** and Dart
  **3.12.2** (matching the installed project SDK).
- Read-only repository permission; no Apple credentials or paid external CI service.
- Flutter SDK and pub cache enabled. No native build cache is restored across
  Xcode versions. Private repositories consume their GitHub Actions allowance;
  check the account's usage/budget settings before enabling recurring builds.
- `flutter doctor -v`, locked pub resolution, source/plugin minimum checks,
  static analysis, native dependency preparation, effective Release settings
  checks, then `flutter build ios --release --no-codesign`.
- Swift Package Manager integration is preserved. A CocoaPods Podfile and
  optional xcconfig includes supply fallback support for Google Maps. Flutter's
  `--config-only` preparation installs pods as needed; an explicit `pod install`
  confirms resolution. CocoaPods must be present on the runner.
- Podfile platform, project Debug/Release/Profile settings (inherited by app and
  test targets), and Flutter framework metadata all specify **16.0**.
  Pods with an older target are normalized to 16.0; pods requiring newer iOS
  cause an error instead of having their minimum silently lowered.
- ARM64 is retained through Xcode's device architecture defaults; no ARM64
  exclusion is introduced. CI checks effective settings and compiled binaries.
- After compilation, `tool/verify_ios.py` checks the app's `MinimumOSVersion`,
  physical-device platform, iPhone family, ARM64 executable, and minimum OS load
  commands in every embedded Mach-O (including Flutter and vendor frameworks).
  Embedded frameworks may have an older minimum, but none may require newer
  than 16.0. The main executable must specify exactly 16.0.
- `ditto -c -k --sequesterRsrc --keepParent` preserves `Runner.app` inside
  `build/flutter-ios-unsigned-build.zip`. Upload retention is seven days.
- Behavioral tests run on macOS **after upload** with
  `flutter test --exclude-tags golden`. A separate `windows-2025` job runs all
  eight pixel comparisons with `flutter test --tags golden`, using the same
  Flutter 3.44.8 SDK as the Windows reference images. Every test remains covered
  across these jobs; failures still mark the run failed while a successfully
  built app remains downloadable. The live API integration test stays skipped
  unless explicitly enabled with its backend. Screenshot differences are
  uploaded as `golden-test-differences` when the Windows job fails.

An unsigned `.app` ZIP is **not an installable IPA** and cannot be used directly
on an ordinary iPhone. Nothing in this workflow uploads to TestFlight or the App
Store. No signing secrets are needed for unsigned CI.

## Dependency compatibility review

`pubspec.yaml` requires Dart `^3.12.2`; the committed lockfile requires Flutter
`>=3.44.0`. All existing dependencies and the lockfile are preserved.
The resolved native plugin declarations were inspected in the local pub cache:

| Plugin | Version | Declared iOS minimum |
| --- | --- | --- |
| file_picker_darwin | 2.3.2 | 14.0 |
| flutter_local_notifications | 22.3.2 | 13.0 |
| flutter_secure_storage_darwin | 0.4.3 | 13.0 |
| geolocator_apple | 2.3.15 | 11.0 |
| google_maps_flutter_ios | 2.18.7 | 14.0 |
| image_picker_ios | 0.8.13+10 | 13.0 |
| package_info_plus | 10.2.2 | 12.0 CocoaPods / 13.0 SwiftPM |
| permission_handler_apple | 9.6.2 | 12.0 |
| path_provider_foundation | 2.6.0 | Dart/native-assets implementation; checked during compilation |

The other app dependencies are Dart-only or platform interfaces. No inspected
plugin declares an iOS 17 minimum. The Google Maps plugin constrains its native
GoogleMaps dependency to `>=8.4, <11.0`, excluding the newer 11.3 SDK that requires
iOS 17. Keep that compatible range when upgrading. Native transitive resolution
still needs the macOS build; source declarations alone cannot prove runtime
compatibility. Commit `ios/Podfile.lock` after the first successful macOS
resolution to make subsequent native SDK selection reproducible; never invent
that lockfile on Windows.

Existing app limitations remain: iOS Google Maps requires its separate SDK key
and AppDelegate setup described in `docs/maps.md`; notifications and permission
onboarding currently target Android/web in the Dart code. This CI work does not
enable those iOS features or add newer hardware requirements.

## Validation and remaining checks

Windows checks performed with the existing Flutter SDK:

- Locked `flutter pub get --enforce-lockfile`: passed.
- `flutter analyze`: passed, including the new layout test.
- `python tool/verify_ios.py`: source and plugin checks passed.
- Workflow YAML and expressions validated with actionlint 1.7.12.
- After the test fixes, the CI-equivalent commands passed locally on Windows:
  **51 behavioral tests passed, 1 live API test skipped**, and **all 8 golden
  tests passed**. The macOS job and hosted Windows job still require a new
  Actions run to confirm their results on those runners.
- The registration test now expects the current `Hello, Ana!` greeting while
  retaining checks for password confirmation, the registered user's identity,
  household role, empty pickup history, and successful UI rendering.
- The household-home reference image was visually reviewed and updated only
  for the intended greeting change from `Magandang araw, Juan!` to
  `Hello, Juan!`. The other seven reference images remain unchanged.
- `test/iphone8_layout_test.dart` exercises login and all five household/buyer
  tabs at 375 x 667 logical points, with the iPhone 8 status bar inset. This is
  a Flutter layout smoke test, not a native device test. Both tests passed.
- Plists parse successfully, embedded Bash passes syntax checking, and verifier
  fixtures accept iOS 16 ARM64 while rejecting iOS 17, simulator, and missing
  ARM64 binaries. `git diff --check` passed.

Only macOS can validate CocoaPods/SwiftPM resolution, Xcode settings, native
compilation, final bundle load commands, and `ditto` packaging. No iOS build or
downloadable artifact has been produced locally on Windows. The first GitHub
Actions run must establish those results. A signed build must then be tested on
a **physical iPhone 8 running iOS 16.x**: launch, login, all tabs, scrolling,
keyboard behavior, maps, location/photos, secure storage, networking, and any
enabled notification behavior. Test landscape and accessibility text sizes too.
Compilation and the viewport smoke test do not prove full device compatibility.

## Screenshot test maintenance

The eight screenshot tests have the `golden` tag in `dart_test.yaml` and their
test declarations. Run the complete suite on Windows with `flutter test`.
For the same split as CI, run `flutter test --exclude-tags golden` for behavioral
checks and `flutter test --tags golden` for screenshots. Exact pixel comparisons
use Windows baselines because [Flutter documents platform-dependent font
rendering](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html).
There is no relaxed comparison tolerance or automatic baseline regeneration.

When an intended UI change affects a screenshot, inspect its failure images,
then update only the affected baseline on Windows using the pinned SDK, e.g.:

```powershell
flutter test test/screens_test.dart --plain-name "household-home phone layout" --update-goldens
flutter test --tags golden
```

Review the image diff before committing. Updating baselines is a developer
action; CI must compare against the committed images.

## Commit and push when ready

Run in PowerShell from `app-side`. These commands stage only the CI work;
existing edits in README, maps documentation, and application code are excluded.
Review those existing edits separately before deciding what else to commit.

```powershell
git diff --check
git add .github/workflows/flutter-ios.yml docs/ios-ci.md tool/verify_ios.py test/iphone8_layout_test.dart ios/Podfile ios/Flutter/AppFrameworkInfo.plist ios/Flutter/Debug.xcconfig ios/Flutter/Release.xcconfig ios/Runner.xcodeproj/project.pbxproj
git diff --cached
git commit -m "Add unsigned iOS 16 build on macOS 26"
git push origin main
```

No commit or push was performed as part of setup.

## Monitor and download

1. Open the repository on GitHub, then **Actions → Flutter iOS unsigned build**.
2. A push to `main` starts a run automatically. For a manual run, use **Run
   workflow**, choose `main`, and submit (the workflow must first exist there).
3. Open the run and expand its steps to inspect toolchain, dependency, build,
   verification, and test logs. A test failure can make the overall run red even
   when build/upload succeeded; inspect the individual step results.
4. Under **Artifacts**, download `flutter-ios-unsigned-build`. GitHub wraps the
   uploaded archive in its download ZIP; extract it to find
   `flutter-ios-unsigned-build.zip`, containing the complete `Runner.app`.
5. Download within seven days, or rerun the workflow to produce another build.

## Future signed IPA pipeline (optional, separate workflow)

Keep this unsigned workflow independent. A future manually dispatched signing
workflow can reuse its SDK setup, target verification, analysis, and tests.
Use a protected GitHub environment for release credentials and distribution.

You will need an Apple Developer Program membership for normal distribution, an
App ID registered to your team, signing certificates with their private keys,
and a matching provisioning profile. The current bundle identifier is
`ph.easyscrap.easyScrap`; confirm ownership/availability before registering it.
All identifiers, team IDs, entitlements, certificates, and profiles must agree.

Suggested GitHub secrets for that future workflow: `IOS_CERTIFICATE_P12_BASE64`,
`IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, and
`IOS_KEYCHAIN_PASSWORD`. An App Store Connect API key additionally needs its
private `.p8` key, key ID, and issuer ID for automated uploads. These names are
documentation only; the unsigned workflow never reads these secrets.

On the signing runner, create a temporary keychain, import the certificate,
install the provisioning profile, and configure the team and export options.
Use `flutter build ipa --release --export-options-plist=...` with an appropriate
export method. Always delete temporary keychains and profiles in cleanup steps.
Distribute only the properly signed/exported IPA; renaming this unsigned ZIP
does not sign or export it.

For registered-device development or Ad Hoc distribution, register the iPhone
8 UDID and include it in the relevant profile, then install the exported build
through a suitable device installation channel. For TestFlight, create the App
Store Connect record, upload with App Store distribution signing, and invite
testers after processing/review. TestFlight does not require registering tester
UDIDs; confirm the currently available TestFlight client supports the device's
iOS version. App Store release additionally requires metadata, privacy details,
screenshots, review, and compliance with Apple's submission requirements at the
time of upload. Recheck Apple requirements when implementing signing.

## Toolchain references

- [GitHub macOS 26 runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
  lists stable Xcode 26.6. If GitHub removes it in a future image, select another
  explicitly verified stable Xcode 26 version; do not silently select Xcode 27.
- [Apple Xcode requirements](https://developer.apple.com/xcode/system-requirements)
  lists iOS 15 and later deployment support for Xcode 26.6, covering iOS 16.
- [Flutter Swift Package Manager support](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
  describes the default integration since Flutter 3.44 and CocoaPods fallback.
- [Google Maps iOS release notes](https://developers.google.com/maps/documentation/ios-sdk/release-notes)
  documents the iOS 17 minimum introduced in native SDK 11.3.
