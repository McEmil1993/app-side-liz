import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';
import 'app_permissions.dart';
import 'package:permission_handler/permission_handler.dart';

class PushService extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = PushService._();
  PushService._();
  final local = FlutterLocalNotificationsPlugin();
  ApiClient? client;
  io.Socket? _socket;
  Timer? _timer;
  int _generation = 0, _attempts = 0;
  bool _localReady = false, _refreshing = false, _refreshAgain = false;
  final Set<String> _seen = {};
  bool ready = false, enabled = false, busy = false, activeSession = false;
  String? error, alertError;
  Map<String, dynamic>? pendingTap;
  void Function(Map<String, dynamic>)? onTap;
  Future<void> Function()? onUpdate;
  void Function(Map<String, dynamic>)? onNotification;
  bool get supported =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize(ApiClient api) async {
    client = api;
    if (!supported) return;
    WidgetsBinding.instance.addObserver(this);
    if (_android) {
      try {
        await local.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification'),
          ),
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            if (payload != null) {
              tap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
            }
          },
        );
        await local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                'easyscrap_updates',
                'EasyScrap updates',
                description: 'Messages, pickups and account updates',
                importance: Importance.high,
              ),
            );
        _localReady = true;
        final launch = await local.getNotificationAppLaunchDetails();
        final payload = launch?.notificationResponse?.payload;
        if (payload != null) {
          pendingTap = Map<String, dynamic>.from(jsonDecode(payload) as Map);
        }
      } catch (e) {
        alertError =
            'Android alerts could not initialize. Reconnect notifications to retry.';
        debugPrint(
          'SOCKET_LOCAL_INIT_FAILED: ${e is PlatformException ? e.code : e.runtimeType}',
        );
      }
    }
    ready = true;
    notifyListeners();
  }

  void _close() {
    _timer?.cancel();
    _timer = null;
    final previous = _socket;
    _socket = null;
    previous?.dispose();
    enabled = false;
  }

  void _schedule(Duration delay) {
    _close();
    if (activeSession && client?.token != null) {
      _timer = Timer(delay, () => unawaited(_connect()));
    }
    notifyListeners();
  }

  void _retry() {
    if (!activeSession) return;
    error = 'Real-time connection interrupted. Reconnecting...';
    final seconds = (1 << _attempts.clamp(0, 5)).clamp(1, 30);
    _attempts++;
    _schedule(Duration(seconds: seconds));
  }

  Future<void> _connect() async {
    if (!ready || !activeSession || client?.token == null) return;
    final generation = ++_generation;
    _close();
    busy = true;
    notifyListeners();
    try {
      final result = await client!.request(
        'notifications/socket-ticket',
        mobile: false,
        method: 'POST',
        body: <String, String>{},
      );
      if (generation != _generation || !activeSession) return;
      final data = Map<String, dynamic>.from(result as Map);
      final socket = io.io(data['url'] as String, <String, dynamic>{
        'transports': ['websocket'],
        'auth': {'ticket': data['ticket']},
        'autoConnect': false,
        'reconnection': false,
        'forceNew': true,
        'timeout': 20000,
      });
      _socket = socket;
      bool current() =>
          generation == _generation &&
          activeSession &&
          identical(socket, _socket);
      socket.on('session:ready', (_) {
        if (!current()) return;
        enabled = true;
        error = null;
        _attempts = 0;
        notifyListeners();
        final renewal =
            DateTime.parse(
              data['expires_at'] as String,
            ).difference(DateTime.now()).inMilliseconds -
            30000;
        _timer = Timer(
          Duration(milliseconds: renewal.clamp(1000, 300000)),
          () => unawaited(_connect()),
        );
        unawaited(_refresh());
      });
      socket.on('notification:new', (value) {
        if (current() && value is Map) {
          unawaited(_receive(Map<String, dynamic>.from(value)));
        }
      });
      socket.on('session:expired', (_) {
        if (current()) _schedule(Duration.zero);
      });
      socket.onDisconnect((_) {
        if (current()) _retry();
      });
      socket.onConnectError((_) {
        if (current()) _retry();
      });
      socket.connect();
    } catch (e) {
      if (generation != _generation || !activeSession) return;
      error = e is ApiException
          ? e.message.toString()
          : 'Could not connect to real-time notifications.';
      debugPrint('SOCKET_CONNECT_FAILED: ${e.runtimeType}');
      if (e is! ApiException || (e.status != 401 && e.status != 403)) {
        final message = error;
        _retry();
        error = message;
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        if (activeSession) await onUpdate?.call();
      } while (_refreshAgain && activeSession);
    } catch (e) {
      debugPrint('SOCKET_HISTORY_REFRESH_FAILED: ${e.runtimeType}');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _receive(Map<String, dynamic> notification) async {
    final id = '${notification['id']}';
    if (!_seen.add(id)) return;
    if (_seen.length > 500) _seen.remove(_seen.first);
    onNotification?.call(notification);
    if (_localReady && activeSession) {
      try {
        await local.show(
          id: int.tryParse(id) ?? id.hashCode.abs(),
          title: notification['title']?.toString(),
          body: notification['body']?.toString(),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'easyscrap_updates',
              'EasyScrap updates',
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_notification',
            ),
          ),
          payload: jsonEncode(notification['data'] ?? {}),
        );
      } catch (e) {
        alertError =
            'Android alert failed. Check notification permission and rebuild the latest APK.';
        debugPrint(
          'SOCKET_LOCAL_ALERT_FAILED: ${e is PlatformException ? e.code : e.runtimeType}',
        );
        notifyListeners();
      }
    }
    await _refresh();
  }

  Future<void> signedIn() async {
    activeSession = true;
    // Authentication must not wait for the socket service to wake up.
    unawaited(_connect());
  }

  Future<void> signedOut() async {
    activeSession = false;
    _generation++;
    busy = false;
    _close();
    _seen.clear();
    pendingTap = null;
    error = null;
    if (_localReady) await local.cancelAll();
    notifyListeners();
  }

  Future<void> requestInitialPermission() async {
    if (!_android) return;
    try {
      final status = await AppPermissions.request(Permission.notification);
      alertError = status.isGranted
          ? null
          : 'Notifications are not allowed. Open Profile > App permissions to enable them.';
      notifyListeners();
    } catch (e) {
      debugPrint('SOCKET_ALERT_PERMISSION_FAILED: ${e.runtimeType}');
    }
  }

  Future<void> _syncPermission() async {
    if (!_android) return;
    try {
      final status = await Permission.notification.status;
      if (_localReady) {
        alertError = status.isGranted
            ? null
            : 'Notifications are not allowed. Open Profile > App permissions to enable them.';
        notifyListeners();
      }
    } catch (_) {
      /* Profile retains the manual retry action. */
    }
  }

  Future<void> enable() async {
    if (!ready) {
      throw StateError('Real-time updates are unavailable on this platform.');
    }
    if (client?.token == null) throw StateError('Please log in first.');
    await requestInitialPermission();
    activeSession = true;
    await _connect();
  }

  Future<void> testNotification() async {
    if (client?.token == null) throw StateError('Please log in first.');
    await client!.request(
      'notifications/test',
      mobile: false,
      method: 'POST',
      body: <String, String>{},
    );
  }

  void tap(Map<String, dynamic> data) {
    if (client?.token == null || onTap == null) {
      pendingTap = data;
      return;
    }
    onTap!(data);
  }

  void consumeTap() {
    final data = pendingTap;
    pendingTap = null;
    if (data != null) tap(data);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncPermission());
      if (activeSession) _schedule(Duration.zero);
    }
  }
}
