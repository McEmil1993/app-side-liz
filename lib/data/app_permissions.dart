import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android runtime permissions, independent of API login and socket startup.
class AppPermissions {
  static const firstLaunchKey = 'easyscrap_permissions_onboarding_v1';
  static const storage = FlutterSecureStorage();
  static bool _requesting = false;
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> requestOnFirstLaunch() async {
    if (!supported || _requesting) return;
    _requesting = true;
    try {
      if (await storage.read(key: firstLaunchKey) == 'done') return;
      // Sequential native dialogs; never request two permissions concurrently.
      for (final permission in [
        Permission.notification,
        Permission.locationWhenInUse,
      ]) {
        if ((await permission.status).isDenied) await permission.request();
      }
      // A denial is still a completed choice. Retry is available in Profile.
      await storage.write(key: firstLaunchKey, value: 'done');
    } finally {
      _requesting = false;
    }
  }

  static Future<PermissionStatus> request(Permission permission) async {
    if (_requesting || !supported) return permission.status;
    _requesting = true;
    try {
      var status = await permission.status;
      if (status.isDenied) status = await permission.request();
      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
      }
      return status;
    } finally {
      _requesting = false;
    }
  }
}
