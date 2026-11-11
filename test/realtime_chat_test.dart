import 'dart:async';
import 'package:easy_scrap/application/app_controller.dart';
import 'package:easy_scrap/data/demo_recycling_repository.dart';
import 'package:easy_scrap/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

class DelayedMessages extends DemoRecyclingRepository {
  final gate = Completer<void>();
  @override
  Future<ChatMessage> sendMessage(
    AppUser actor,
    String pickupId,
    String text,
  ) async {
    await gate.future;
    return super.sendMessage(actor, pickupId, text);
  }
}

void main() {
  test(
    'pending bubble is immediate and live messages survive stale refresh without duplicates',
    () async {
      final repo = DelayedMessages();
      final app = AppController(repo);
      await app.refresh();
      await app.signIn('household', 'EasyScrap123!');
      final sending = app.sendMessage('P102', 'I am here');
      expect(app.messages.where((m) => m.pending).single.text, 'I am here');
      final incoming = ChatMessage(
        id: 'server-77',
        pickupId: 'P102',
        senderId: 'b1',
        text: 'On my way',
        sentAt: DateTime.now(),
      );
      app.receiveChatMessage(incoming);
      app.receiveChatMessage(incoming);
      await app.refresh();
      expect(app.messages.where((m) => m.id == 'server-77'), hasLength(1));
      expect(app.messages.where((m) => m.pending), hasLength(1));
      repo.gate.complete();
      await sending;
      await app.refresh();
      expect(app.messages.where((m) => m.text == 'I am here'), hasLength(1));
      expect(app.messages.any((m) => m.pending), isFalse);
      app.receiveChatMessage(
        ChatMessage(
          id: 'foreign',
          pickupId: 'unknown',
          senderId: 'x',
          text: 'Hidden',
          sentAt: DateTime.now(),
        ),
      );
      expect(app.messages.any((m) => m.id == 'foreign'), isFalse);
      app.dispose();
    },
  );

  test('failed sends remove the pending bubble and report failure', () async {
    final repo = DelayedMessages();
    final app = AppController(repo);
    await app.refresh();
    await app.signIn('household', 'EasyScrap123!');
    final sending = app.sendMessage('P102', 'Not delivered');
    final failure = expectLater(sending, throwsStateError);
    repo.gate.completeError(StateError('Network unavailable'));
    await failure;
    expect(app.messages.any((m) => m.text == 'Not delivered'), isFalse);
    expect(app.busy, isFalse);
    app.dispose();
  });
}
