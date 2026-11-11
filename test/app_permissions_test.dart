import 'package:easy_scrap/data/app_permissions.dart';
import 'package:easy_scrap/ui/permissions_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionLocationPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final originalLocation = GeolocatorPlatform.instance;
  late Map<int, int> statuses;
  late List<int> requests;
  late int openedSettings;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    GeolocatorPlatform.instance = PermissionLocationPlatform();
    FlutterSecureStorage.setMockInitialValues({});
    statuses = {};
    requests = [];
    openedSettings = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'checkPermissionStatus') {
            return statuses[call.arguments] ?? 0;
          }
          if (call.method == 'requestPermissions') {
            final permissions = List<int>.from(call.arguments as List);
            requests.addAll(permissions);
            for (final permission in permissions) {
              statuses[permission] = 1;
            }
            return {
              for (final permission in permissions)
                permission: statuses[permission]!,
            };
          }
          if (call.method == 'openAppSettings') {
            openedSettings++;
            return true;
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    GeolocatorPlatform.instance = originalLocation;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'first launch requests notifications then location once, without concurrent dialogs',
    () async {
      await Future.wait([
        AppPermissions.requestOnFirstLaunch(),
        AppPermissions.requestOnFirstLaunch(),
      ]);
      expect(requests, [
        Permission.notification.value,
        Permission.locationWhenInUse.value,
      ]);
      await AppPermissions.requestOnFirstLaunch();
      expect(requests, hasLength(2));
      expect(
        await AppPermissions.storage.read(key: AppPermissions.firstLaunchKey),
        'done',
      );
    },
  );

  test(
    'granted permissions are skipped and permanently blocked permission deep-links to settings',
    () async {
      statuses[Permission.notification.value] = 1;
      statuses[Permission.locationWhenInUse.value] = 4;
      await AppPermissions.requestOnFirstLaunch();
      expect(requests, isEmpty);
      expect(openedSettings, 0);
      await AppPermissions.request(Permission.locationWhenInUse);
      expect(openedSettings, 1);
      expect(requests, isEmpty);
    },
  );

  testWidgets(
    'Profile permissions UI requests access and refreshes status after returning',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PermissionsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Allowed'), findsOneWidget);
      expect(requests, [Permission.notification.value]);
      statuses[Permission.locationWhenInUse.value] = 1;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Allowed'), findsNWidgets(2));
      expect(find.textContaining('No full-gallery'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
