import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/src/rust/api.dart';
import 'package:p2p_chat_app/ui/widgets/chat_timeline_view.dart';

MessageDto _makeMsg({
  required String roomId,
  required int index,
  bool isOutgoing = false,
  int? createdAtMs,
}) {
  return MessageDto(
    msgId: '$roomId-msg-$index',
    roomId: roomId,
    peerId: 'peer-1',
    senderId: isOutgoing ? 'me' : 'peer-1',
    isOutgoing: isOutgoing,
    isFile: false,
    bodyText: '$roomId message #$index',
    completedChunks: 0,
    status: 'delivered',
    deliveryScope: 'direct',
    ackedPeers: const [],
    createdAtMs: createdAtMs ?? (1700000000000 + index * 1000),
  );
}

Widget _wrapTimeline({
  required String roomId,
  required List<MessageDto> messages,
  int scrollToBottomRequestId = 0,
}) {
  return MaterialApp(
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 420,
        height: 480,
        child: ChatTimelineView(
          key: ValueKey('timeline_$roomId'),
          roomId: roomId,
          messages: messages,
          scrollToBottomRequestId: scrollToBottomRequestId,
          itemBuilder: (context, msg, showDateChip) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDateChip)
                  Container(
                    key: ValueKey('date_${msg.msgId}'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: const Center(child: Text('DATE_CHIP')),
                  ),
                Container(
                  height: 64,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(msg.bodyText ?? ''),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('ChatTimelineView opens directly on the newest message', (
    WidgetTester tester,
  ) async {
    final msgs = List.generate(
      40,
      (i) => _makeMsg(roomId: 'room-a', index: i),
    );

    await tester.pumpWidget(_wrapTimeline(roomId: 'room-a', messages: msgs));
    await tester.pumpAndSettle();

    expect(find.text('room-a message #39'), findsOneWidget);
    expect(find.text('room-a message #0'), findsNothing);
  });

  testWidgets(
    'Date separator renders above the earliest message of a day',
    (WidgetTester tester) async {
      final day1 = DateTime(2026, 11, 14, 10, 0).millisecondsSinceEpoch;
      final day2a = DateTime(2026, 11, 15, 9, 0).millisecondsSinceEpoch;
      final day2b = DateTime(2026, 11, 15, 11, 0).millisecondsSinceEpoch;

      final msgs = [
        _makeMsg(roomId: 'room-d', index: 0, createdAtMs: day1),
        _makeMsg(roomId: 'room-d', index: 1, createdAtMs: day2a),
        _makeMsg(roomId: 'room-d', index: 2, createdAtMs: day2b),
      ];

      await tester.pumpWidget(_wrapTimeline(roomId: 'room-d', messages: msgs));
      await tester.pumpAndSettle();

      // Date chips only for msg 0 (day1) and msg 1 (day2a), not msg 2 (day2b).
      expect(find.byKey(const ValueKey('date_room-d-msg-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('date_room-d-msg-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('date_room-d-msg-2')), findsNothing);

      final chipY =
          tester.getTopLeft(find.byKey(const ValueKey('date_room-d-msg-1'))).dy;
      final msg1Y = tester.getTopLeft(find.text('room-d message #1')).dy;
      final msg2Y = tester.getTopLeft(find.text('room-d message #2')).dy;

      expect(chipY, lessThan(msg1Y));
      expect(msg1Y, lessThan(msg2Y));
    },
  );

  testWidgets(
    'Switching rooms after scrolling up resets immediately to newest message',
    (WidgetTester tester) async {
      final roomAMsgs = List.generate(
        40,
        (i) => _makeMsg(roomId: 'room-a', index: i),
      );
      final roomBMsgs = List.generate(
        40,
        (i) => _makeMsg(roomId: 'room-b', index: i),
      );

      await tester.pumpWidget(
        _wrapTimeline(roomId: 'room-a', messages: roomAMsgs),
      );
      await tester.pumpAndSettle();

      // Scroll up into history in room A (drag downward to pull older items down).
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('room-a message #39'), findsNothing);

      // Switch to room B (same count): must land directly on newest message #39.
      await tester.pumpWidget(
        _wrapTimeline(roomId: 'room-b', messages: roomBMsgs),
      );
      await tester.pumpAndSettle();

      expect(find.text('room-b message #39'), findsOneWidget);
      expect(find.text('room-b message #0'), findsNothing);
    },
  );

  testWidgets(
    'Scrolling up pauses auto-scroll on incoming messages and shows jump button',
    (WidgetTester tester) async {
      final msgs = List.generate(
        40,
        (i) => _makeMsg(roomId: 'room-a', index: i),
      );

      await tester.pumpWidget(_wrapTimeline(roomId: 'room-a', messages: msgs));
      await tester.pumpAndSettle();

      // Scroll up far enough (>240px) to show the jump-to-bottom button.
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.text('room-a message #39'), findsNothing);

      // Incoming message arrives while user is reading older history.
      final withIncoming = [
        ...msgs,
        _makeMsg(roomId: 'room-a', index: 40, isOutgoing: false),
      ];
      await tester.pumpWidget(
        _wrapTimeline(roomId: 'room-a', messages: withIncoming),
      );
      await tester.pumpAndSettle();

      // Should NOT yank user to bottom; instead show unread indicator on button.
      expect(find.text('room-a message #40'), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('条新消息'), findsOneWidget);

      // Tap the floating button -> returns to the newest message.
      await tester.tap(find.text('条新消息'));
      await tester.pumpAndSettle();

      expect(find.text('room-a message #40'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    },
  );

  testWidgets(
    'Sending an outgoing message while scrolled up returns to newest message',
    (WidgetTester tester) async {
      final msgs = List.generate(
        40,
        (i) => _makeMsg(roomId: 'room-a', index: i),
      );

      await tester.pumpWidget(_wrapTimeline(roomId: 'room-a', messages: msgs));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('room-a message #39'), findsNothing);

      final withOutgoing = [
        ...msgs,
        _makeMsg(roomId: 'room-a', index: 40, isOutgoing: true),
      ];
      await tester.pumpWidget(
        _wrapTimeline(
          roomId: 'room-a',
          messages: withOutgoing,
          scrollToBottomRequestId: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('room-a message #40'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    },
  );
}
