import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:p2p_chat_app/controllers/app_workspace_controller.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/src/rust/api.dart';
import 'package:p2p_chat_app/ui/theme/app_theme_tokens.dart';
import 'package:p2p_chat_app/ui/widgets/chat_dialogs.dart';
import 'package:p2p_chat_app/ui/widgets/message_bubble.dart';
import 'package:p2p_chat_app/ui/widgets/room_avatar.dart';

const _tinyPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

AppWorkspaceController _makeController(Directory tmp) {
  return AppWorkspaceController(
    myEndpointId: 'me-node',
    dataDir: tmp.path,
    autoReceiveDir: tmp.path,
    deviceName: 'TestPC',
  );
}

Widget _wrapBubble({
  required AppUiStyle style,
  required MessageDto msg,
  required AppWorkspaceController controller,
  void Function(MessageDto msg)? onForwardMessage,
}) {
  return MaterialApp(
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildAppTheme(brightness: Brightness.light, styleOverride: style),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: MessageBubble(
          msg: msg,
          myEndpointId: 'me-node',
          controller: controller,
          onEditMemberProfile: (_, _) {},
          onOpenImagePreview: (_, _) {},
          onForwardMessage: onForwardMessage,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    AppLocalizations.setOverrideLocale(const Locale('zh', 'CN'));
  });

  tearDown(() {
    AppLocalizations.setOverrideLocale(null);
  });
  testWidgets(
    'Delivered image bubble shows only thumbnail without redundant file card or buttons',
    (WidgetTester tester) async {
      final tmp = Directory.systemTemp.createTempSync('p2p_img_bubble_');
      try {
        final imgFile = File('${tmp.path}${Platform.pathSeparator}shot_01.png')
          ..writeAsBytesSync(_tinyPngBytes);
        final ctrl = _makeController(tmp);
        addTearDown(ctrl.dispose);

        final msg = MessageDto(
          msgId: 'm-img',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'peer-1',
          isOutgoing: false,
          isFile: true,
          fileName: 'shot_01.png',
          fileSize: BigInt.from(_tinyPngBytes.length),
          localPath: imgFile.path,
          totalChunks: 1,
          completedChunks: 1,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['me-node'],
          createdAtMs: 1700000000000,
        );

        await tester.pumpWidget(
          _wrapBubble(
            style: AppUiStyle.androidExpressive,
            msg: msg,
            controller: ctrl,
          ),
        );
        await tester.pump();

        expect(find.byType(Image), findsOneWidget);
        expect(find.text('shot_01.png'), findsNothing);
        expect(find.text('查看大图'), findsNothing);
        expect(find.text('打开文件'), findsNothing);
        expect(find.text('在文件夹中显示'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        PaintingBinding.instance.imageCache.clear();
        try {
          if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        } catch (_) {}
      }
    },
  );

  testWidgets(
    'Delivered normal file bubble hides inline action buttons',
    (WidgetTester tester) async {
      final tmp = Directory.systemTemp.createTempSync('p2p_file_bubble_');
      try {
        final docFile = File('${tmp.path}${Platform.pathSeparator}report.pdf')
          ..writeAsStringSync('dummy pdf');
        final ctrl = _makeController(tmp);
        addTearDown(ctrl.dispose);

        final msg = MessageDto(
          msgId: 'm-pdf',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'peer-1',
          isOutgoing: false,
          isFile: true,
          fileName: 'report.pdf',
          fileSize: BigInt.from(9),
          localPath: docFile.path,
          totalChunks: 1,
          completedChunks: 1,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['me-node'],
          createdAtMs: 1700000000000,
        );

        await tester.pumpWidget(
          _wrapBubble(
            style: AppUiStyle.windowsFluent,
            msg: msg,
            controller: ctrl,
          ),
        );
        await tester.pump();

        expect(find.text('report.pdf'), findsOneWidget);
        expect(find.text('打开文件'), findsNothing);
        expect(find.text('在文件夹中显示'), findsNothing);
        expect(find.byIcon(Icons.copy), findsNothing);
      } finally {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'Mobile long-press on image and text opens sheet with Forward action',
    (WidgetTester tester) async {
      final tmp = Directory.systemTemp.createTempSync('p2p_fwd_mobile_');
      try {
        final imgFile = File('${tmp.path}${Platform.pathSeparator}pic.png')
          ..writeAsBytesSync(_tinyPngBytes);
        final ctrl = _makeController(tmp);
        addTearDown(ctrl.dispose);

        MessageDto? forwarded;
        final imgMsg = MessageDto(
          msgId: 'm-img-2',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'me-node',
          isOutgoing: true,
          isFile: true,
          fileName: 'pic.png',
          fileSize: BigInt.from(_tinyPngBytes.length),
          localPath: imgFile.path,
          totalChunks: 1,
          completedChunks: 1,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['peer-1'],
          createdAtMs: 1700000000000,
        );

        await tester.pumpWidget(
          _wrapBubble(
            style: AppUiStyle.androidExpressive,
            msg: imgMsg,
            controller: ctrl,
            onForwardMessage: (m) => forwarded = m,
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
        await tester.longPress(find.text('已送达'));
        await tester.pumpAndSettle();

        expect(find.text('转发'), findsOneWidget);
        expect(find.text('打开文件'), findsOneWidget);
        expect(find.text('复制文件路径'), findsOneWidget);

        await tester.tap(find.text('转发'));
        await tester.pumpAndSettle();
        expect(forwarded?.msgId, 'm-img-2');

        // Verify long-press on text bubble also triggers Forward & Copy.
        forwarded = null;
        final txtMsg = MessageDto(
          msgId: 'm-txt-1',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'peer-1',
          isOutgoing: false,
          isFile: false,
          bodyText: 'Hello P2P',
          completedChunks: 0,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['me-node'],
          createdAtMs: 1700000001000,
        );
        await tester.pumpWidget(
          _wrapBubble(
            style: AppUiStyle.androidExpressive,
            msg: txtMsg,
            controller: ctrl,
            onForwardMessage: (m) => forwarded = m,
          ),
        );
        await tester.pump();

        await tester.longPress(find.text('Hello P2P'));
        await tester.pumpAndSettle();
        expect(find.text('复制文字内容'), findsOneWidget);
        expect(find.text('转发'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        PaintingBinding.instance.imageCache.clear();
        try {
          if (tmp.existsSync()) tmp.deleteSync(recursive: true);
        } catch (_) {}
      }
    },
  );

  testWidgets(
    'Desktop right-click on file bubble includes Forward and file actions',
    (WidgetTester tester) async {
      final tmp = Directory.systemTemp.createTempSync('p2p_fwd_desktop_');
      try {
        final docFile = File('${tmp.path}${Platform.pathSeparator}archive.zip')
          ..writeAsStringSync('zipdata');
        final ctrl = _makeController(tmp);
        addTearDown(ctrl.dispose);

        MessageDto? forwarded;
        final msg = MessageDto(
          msgId: 'm-zip',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'me-node',
          isOutgoing: true,
          isFile: true,
          fileName: 'archive.zip',
          fileSize: BigInt.from(7),
          localPath: docFile.path,
          totalChunks: 1,
          completedChunks: 1,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['peer-1'],
          createdAtMs: 1700000000000,
        );

        await tester.pumpWidget(
          _wrapBubble(
            style: AppUiStyle.windowsFluent,
            msg: msg,
            controller: ctrl,
            onForwardMessage: (m) => forwarded = m,
          ),
        );
        await tester.pump();

        final center = tester.getCenter(find.text('archive.zip'));
        await tester.tapAt(center, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('转发'), findsOneWidget);
        expect(find.text('打开文件'), findsOneWidget);
        expect(find.text('复制文件路径'), findsOneWidget);

        await tester.tap(find.text('转发'));
        await tester.pumpAndSettle();
        expect(forwarded?.msgId, 'm-zip');
      } finally {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'Missing incoming image shows surface deleted indicator, non-black preview dialog, and mobile 删除 menu',
    (WidgetTester tester) async {
      final tmp = Directory.systemTemp.createTempSync('p2p_missing_img_');
      try {
        final missingPath = '${tmp.path}${Platform.pathSeparator}gone.png';
        final ctrl = _makeController(tmp);
        addTearDown(ctrl.dispose);

        final msg = MessageDto(
          msgId: 'm-gone',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'peer-1',
          isOutgoing: false,
          isFile: true,
          fileName: 'gone.png',
          fileSize: BigInt.from(2048),
          localPath: missingPath,
          totalChunks: 1,
          completedChunks: 1,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['me-node'],
          createdAtMs: 1700000000000,
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(
              brightness: Brightness.light,
              styleOverride: AppUiStyle.androidExpressive,
            ),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: MessageBubble(
                    msg: msg,
                    myEndpointId: 'me-node',
                    controller: ctrl,
                    onEditMemberProfile: (_, _) {},
                    onOpenImagePreview: (path, name) => showImagePreviewDialog(
                      ctx,
                      path,
                      name,
                      onDeleteRecord: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(Image), findsNothing);
        expect(find.text('本地文件已删除'), findsOneWidget);
        expect(find.textContaining('图片已从本地删除'), findsOneWidget);

        await tester.tap(find.text('gone.png'));
        await tester.pumpAndSettle();
        expect(find.text('该图片已从本地删除'), findsOneWidget);
        expect(find.text('删除这条消息记录'), findsOneWidget);

        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('gone.png'));
        await tester.pumpAndSettle();
        expect(find.text('删除'), findsOneWidget);
        expect(find.text('打开文件'), findsNothing);
      } finally {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'Right-click on missing file bubble still opens menu with 删除 option',
    (WidgetTester tester) async {
      final tmp = Directory.systemTemp.createTempSync('p2p_missing_doc_');
      try {
        final ctrl = _makeController(tmp);
        addTearDown(ctrl.dispose);

        MessageDto? deletedTarget;
        final msg = MessageDto(
          msgId: 'm-missing-doc',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'peer-1',
          isOutgoing: false,
          isFile: true,
          fileName: 'deleted_notes.pdf',
          fileSize: BigInt.from(1024),
          localPath: '${tmp.path}${Platform.pathSeparator}deleted_notes.pdf',
          totalChunks: 1,
          completedChunks: 1,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['me-node'],
          createdAtMs: 1700000000000,
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(
              brightness: Brightness.light,
              styleOverride: AppUiStyle.windowsFluent,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: MessageBubble(
                  msg: msg,
                  myEndpointId: 'me-node',
                  controller: ctrl,
                  onEditMemberProfile: (_, _) {},
                  onOpenImagePreview: (_, _) {},
                  onDeleteMessage: (m) => deletedTarget = m,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('本地文件已删除'), findsOneWidget);
        final center = tester.getCenter(find.text('deleted_notes.pdf'));
        await tester.tapAt(center, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();

        expect(find.text('删除'), findsOneWidget);
        expect(find.text('转发'), findsNothing);
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        expect(deletedTarget?.msgId, 'm-missing-doc');
      } finally {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'Revoked messages render WhatsApp tombstones for sender and receiver',
    (WidgetTester tester) async {
      final tmp = Directory.systemTemp.createTempSync('p2p_revoked_');
      try {
        final ctrl = _makeController(tmp);
        addTearDown(ctrl.dispose);

        final mine = MessageDto(
          msgId: 'm-rev-out',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'me-node',
          isOutgoing: true,
          isFile: false,
          bodyText: null,
          totalChunks: null,
          completedChunks: 0,
          status: 'revoked',
          deliveryScope: 'direct',
          ackedPeers: const [],
          createdAtMs: 1700000000000,
        );
        final theirs = MessageDto(
          msgId: 'm-rev-in',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'peer-1',
          isOutgoing: false,
          isFile: true,
          fileName: 'secret.png',
          totalChunks: null,
          completedChunks: 0,
          status: 'revoked',
          deliveryScope: 'direct',
          ackedPeers: const [],
          createdAtMs: 1700000001000,
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(
              brightness: Brightness.light,
              styleOverride: AppUiStyle.windowsFluent,
            ),
            home: Scaffold(
              body: Column(
                children: [
                  MessageBubble(
                    msg: mine,
                    myEndpointId: 'me-node',
                    controller: ctrl,
                    onEditMemberProfile: (_, _) {},
                    onOpenImagePreview: (_, _) {},
                  ),
                  MessageBubble(
                    msg: theirs,
                    myEndpointId: 'me-node',
                    controller: ctrl,
                    onEditMemberProfile: (_, _) {},
                    onOpenImagePreview: (_, _) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('你撤回了此消息'), findsOneWidget);
        expect(find.text('对方撤回了此消息'), findsOneWidget);
        expect(find.text('secret.png'), findsNothing);

        final center = tester.getCenter(find.text('对方撤回了此消息'));
        await tester.tapAt(center, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        expect(find.text('删除'), findsOneWidget);
        expect(find.text('转发'), findsNothing);
      } finally {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      }
    },
  );

  testWidgets(
    'Delete dialog enforces touch-zero on outgoing source files and defaults checkbox on incoming file',
    (WidgetTester tester) async {
      final tmp = Directory.systemTemp.createTempSync('p2p_del_dialog_');
      try {
        final srcFile = File('${tmp.path}${Platform.pathSeparator}source.png')
          ..writeAsBytesSync(_tinyPngBytes);
        final rxFile = File('${tmp.path}${Platform.pathSeparator}received.png')
          ..writeAsBytesSync(_tinyPngBytes);
        final ctrl = _makeController(tmp);
        addTearDown(ctrl.dispose);

        final outgoingMsg = MessageDto(
          msgId: 'm-out',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'me-node',
          isOutgoing: true,
          isFile: true,
          fileName: 'source.png',
          fileSize: BigInt.from(_tinyPngBytes.length),
          localPath: srcFile.path,
          totalChunks: 1,
          completedChunks: 1,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['peer-1'],
          createdAtMs: 1700000000000,
        );
        final incomingMsg = MessageDto(
          msgId: 'm-in',
          roomId: 'room-1',
          peerId: 'peer-1',
          senderId: 'peer-1',
          isOutgoing: false,
          isFile: true,
          fileName: 'received.png',
          fileSize: BigInt.from(_tinyPngBytes.length),
          localPath: rxFile.path,
          totalChunks: 1,
          completedChunks: 1,
          status: 'delivered',
          deliveryScope: 'direct',
          ackedPeers: const ['me-node'],
          createdAtMs: 1700000001000,
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(
              brightness: Brightness.light,
              styleOverride: AppUiStyle.windowsFluent,
            ),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => showDeleteMessageConfirmDialog(
                        ctx,
                        ctrl,
                        outgoingMsg,
                      ),
                      child: const Text('open_out'),
                    ),
                    ElevatedButton(
                      onPressed: () => showDeleteMessageConfirmDialog(
                        ctx,
                        ctrl,
                        incomingMsg,
                      ),
                      child: const Text('open_in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Outgoing delete dialog: must NOT offer local file deletion, must offer revoke.
        await tester.tap(find.text('open_out'));
        await tester.pumpAndSettle();
        expect(find.text('同时从对方设备撤回删除'), findsOneWidget);
        expect(find.text('仅从本机移除'), findsOneWidget);
        expect(find.text('同时删除本地保存的文件'), findsNothing);
        expect(find.textContaining('原始源文件不会被删除或改动'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(srcFile.existsSync(), isTrue);

        // Incoming delete dialog: checkbox defaults to checked, no revoke option.
        await tester.tap(find.text('open_in'));
        await tester.pumpAndSettle();
        expect(find.text('同时删除本地保存的文件'), findsOneWidget);
        final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkbox.value, isTrue);
        expect(find.text('同时从对方设备撤回删除'), findsNothing);
      } finally {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      }
    },
  );

  test('transportLabel and transportColor distinguish direct WAN P2P from relay fallback', () {
    expect(transportLabel('usb_tether'), 'USB 专线');
    expect(transportLabel('lan_direct'), '局域网直连');
    expect(transportLabel('wan_p2p'), '外网 P2P');
    expect(transportLabel('wan_relay'), '中继转发');
    expect(transportLabel('wan_p2p_relay'), '外网 P2P');
    expect(transportLabel('offline'), '离线待命');
    expect(transportColor('wan_relay'), isNot(transportColor('wan_p2p')));
  });
}
