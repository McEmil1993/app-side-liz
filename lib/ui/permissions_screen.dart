import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/app_permissions.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  PermissionStatus? notification, location;
  bool busy = false, locationEnabled = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (!AppPermissions.supported) return;
    try {
      final notices = await Permission.notification.status;
      final gps = await Permission.locationWhenInUse.status;
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          notification = notices;
          location = gps;
          locationEnabled = enabled;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not read permissions. Tap Refresh to retry.',
        );
      }
    }
  }

  Future<void> request(Permission permission) async {
    setState(() => busy = true);
    try {
      await AppPermissions.request(permission);
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Permission request failed. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String label(PermissionStatus? status) {
    if (status == null) return 'Checking...';
    if (status.isGranted || status.isLimited) return 'Allowed';
    if (status.isPermanentlyDenied || status.isRestricted) {
      return 'Blocked by Android';
    }
    return 'Not allowed';
  }

  Widget permissionCard(
    String title,
    String purpose,
    Permission permission,
    PermissionStatus? status,
    IconData icon,
  ) {
    final allowed = status?.isGranted == true || status?.isLimited == true;
    final blocked =
        status?.isPermanentlyDenied == true || status?.isRestricted == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(label(status)),
            ),
            Text(purpose),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy || status == null
                  ? null
                  : allowed
                  ? () async {
                      await openAppSettings();
                      await refresh();
                    }
                  : () => request(permission),
              child: Text(
                allowed
                    ? 'Manage $title'
                    : blocked
                    ? 'Open Android settings'
                    : 'Allow $title',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('App permissions'),
      actions: [
        IconButton(
          onPressed: busy ? null : refresh,
          tooltip: 'Refresh permissions',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: !AppPermissions.supported
        ? const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'On the web, permissions are managed by your browser when you use a feature.',
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Allow notifications and location here. Android handles the permission prompts. Permanently blocked permissions open the app settings directly.',
              ),
              const SizedBox(height: 12),
              permissionCard(
                'Notifications',
                'Show message and pickup alerts while the app is connected.',
                Permission.notification,
                notification,
                Icons.notifications_outlined,
              ),
              permissionCard(
                'Location',
                'Use your current position when choosing a map pin. Background location is not requested.',
                Permission.locationWhenInUse,
                location,
                Icons.location_on_outlined,
              ),
              if (!locationEnabled)
                Card(
                  child: ListTile(
                    title: const Text('Device location is turned off'),
                    trailing: TextButton(
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                        await refresh();
                      },
                      child: const Text('Turn on'),
                    ),
                  ),
                ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Photos and files: choose only the items you want through the Android system picker. No full-gallery or storage permission is needed.\n\nInternet access does not have a permission popup.',
                  ),
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
  );
}
