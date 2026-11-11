import 'package:easy_scrap/ui/maps/route_interaction_gate.dart';
import 'package:easy_scrap/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final action in ['Keep request', 'Confirm', 'barrier']) {
    testWidgets('Map yields input until confirmation closes via $action', (
      tester,
    ) async {
      bool? interactive;
      bool? result;
      final mapKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  RouteInteractionGate(
                    builder: (context, enabled) {
                      interactive = enabled;
                      return SizedBox(key: mapKey, width: 300, height: 300);
                    },
                  ),
                  TextButton(
                    onPressed: () async {
                      result = await confirmAction(
                        context,
                        'Choose Mang Ben?',
                        'Confirm this buyer.',
                      );
                    },
                    child: const Text('Choose buyer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final originalMap = mapKey.currentContext;
      expect(interactive, isTrue);
      await tester.tap(find.text('Choose buyer'));
      await tester.pumpAndSettle();
      expect(interactive, isFalse);
      expect(result, isNull);
      expect(mapKey.currentContext, same(originalMap));

      if (action == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.text(action));
      }
      await tester.pumpAndSettle();
      expect(result, action == 'Confirm');
      expect(find.byType(AlertDialog), findsNothing);
      expect(interactive, isTrue);
      expect(mapKey.currentContext, same(originalMap));
      expect(tester.takeException(), isNull);
    });
  }
}

