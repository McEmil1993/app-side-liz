import 'package:flutter/material.dart';
import '../data/push_service.dart';
import 'widgets.dart';

class PushSettings extends StatelessWidget {
  const PushSettings({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PushService.instance,
    builder: (context, _) {
      final push = PushService.instance;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (push.supported)
            OutlinedButton.icon(
              onPressed: push.busy
                  ? null
                  : () => perform(
                      context,
                      push.enable,
                      success:
                          'Real-time connection requested. Check the status below.',
                    ),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                push.busy
                    ? 'Connecting...'
                    : push.enabled
                    ? 'Reconnect real-time updates'
                    : 'Connect real-time updates',
              ),
            )
          else
            const Text(
              'Real-time updates are available on Android and web.',
              style: TextStyle(fontSize: 12),
            ),
          if (push.supported && push.enabled)
            TextButton(
              onPressed: () => perform(
                context,
                push.testNotification,
                success: 'Test notification queued for your account.',
              ),
              child: const Text('Send me a test notification'),
            ),
          Text(
            push.enabled
                ? 'Real-time updates connected'
                : 'Real-time updates disconnected',
          ),
          const Text(
            'Live updates require an active connection. Reopen the app to fetch missed notifications.',
            style: TextStyle(fontSize: 12),
          ),
          if (push.alertError != null)
            Text(
              push.alertError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          if (push.error != null)
            Text(
              push.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          const SizedBox(height: 12),
        ],
      );
    },
  );
}
