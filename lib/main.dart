import 'data/app_permissions.dart';
import 'domain/models.dart';
import 'package:flutter/material.dart';
import 'application/app_controller.dart';
import 'data/demo_recycling_repository.dart';
import 'data/demo_auth_repository.dart';
import 'ui/app.dart';
import 'core/app_config.dart';
import 'data/push_service.dart';
import 'ui/shared_screens.dart';
import 'ui/connected_profile_screen.dart';
import 'ui/pickup_detail_screen.dart';
import 'data/api_client.dart';
import 'data/api_auth_repository.dart';
import 'data/api_recycling_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = ApiClient();
  final controller = AppConfig.demoMode
      ? AppController(
          DemoRecyclingRepository(),
          authRepository: DemoAuthRepository(),
        )
      : AppController(
          ApiRecyclingRepository(client),
          authRepository: ApiAuthRepository(client),
        );
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  client.onSessionExpired = () {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    controller.expireSession();
  };
  final push = PushService.instance;
  if (!AppConfig.demoMode) {
    await push.initialize(client);
    client.onAuthenticated = push.signedIn;
    client.onSessionCleared = push.signedOut;
    push.onNotification = (notification) {
      if (controller.currentUser == null) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            '${notification['title'] ?? 'EasyScrap update'}\n${notification['body'] ?? ''}',
          ),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              push.tap(
                Map<String, dynamic>.from(notification['data'] as Map? ?? {}),
              );
            },
          ),
        ),
      );
      final data = notification['data'];
      if (data is Map && data['chat_message_id'] != null) {
        try {
          controller.receiveChatMessage(
            ChatMessage.fromJson({
              'id': data['chat_message_id'],
              'pickup_id': data['pickup_id'],
              'sender_id': data['chat_sender_id'],
              'text': data['chat_text'],
              'sent_at': data['chat_sent_at'],
            }),
          );
        } catch (_) {
          debugPrint('SOCKET_CHAT_PAYLOAD_INVALID');
        }
      }
    };
    push.onUpdate = () async {
      while (controller.currentUser != null && controller.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (controller.currentUser != null) await controller.refresh();
    };
    push.onTap = (data) async {
      if (controller.currentUser == null) return;
      try {
        await controller.refresh();
      } catch (_) {}
      final navigator = navigatorKey.currentState;
      if (navigator == null || controller.currentUser == null) return;
      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              data['pickup_id'] != null &&
                  controller.pickups.any((p) => p.id == '${data['pickup_id']}')
              ? PickupDetailScreen(pickupId: '${data['pickup_id']}')
              : data['screen'] == 'verification'
              ? const BuyerDocumentsScreen()
              : const NotificationsScreen(),
        ),
      );
    };
  }
  controller.starting = true;
  controller.addListener(() {
    if (controller.currentUser != null &&
        !controller.starting &&
        push.pendingTap != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => push.consumeTap());
    }
  });
  runApp(
    EasyScrapApp(
      controller: controller,
      navigatorKey: navigatorKey,
      messengerKey: messengerKey,
    ),
  );
  if (!AppConfig.demoMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AppPermissions.requestOnFirstLaunch();
      } catch (_) {
        debugPrint('FIRST_LAUNCH_PERMISSION_REQUEST_FAILED');
      }
    });
  }
  await controller.initialize();
  WidgetsBinding.instance.addPostFrameCallback((_) => push.consumeTap());
}
