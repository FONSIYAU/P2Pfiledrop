// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:p2p_chat_app/controllers/app_workspace_controller.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/main.dart';
import 'package:p2p_chat_app/services/platform_bridge.dart';
import 'package:p2p_chat_app/src/rust/api.dart';
import 'package:p2p_chat_app/ui/room_invite_sheet.dart';
import 'package:p2p_chat_app/ui/theme/app_theme_tokens.dart';
import 'package:p2p_chat_app/ui/widgets/chat_dialogs.dart';
import 'package:p2p_chat_app/ui/widgets/chat_timeline_view.dart';
import 'package:p2p_chat_app/ui/widgets/room_avatar.dart';

void main() {
  setUp(() {
    AppLocalizations.setOverrideLocale(const Locale('zh', 'CN'));
  });

  tearDown(() {
    AppLocalizations.setOverrideLocale(null);
  });

  testWidgets('App renders startup loading screen', (WidgetTester tester) async {
    final themeCtrl = AppThemeController();
    addTearDown(themeCtrl.dispose);
    await themeCtrl.setLocaleCode('zh_CN');
    await tester.pumpWidget(P2pChatApp(themeController: themeCtrl));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在启动 P2P 加密传输引擎...'), findsOneWidget);
  });

  testWidgets('App renders error retry screen when preload fails', (
    WidgetTester tester,
  ) async {
    final themeCtrl = AppThemeController();
    addTearDown(themeCtrl.dispose);
    await themeCtrl.setLocaleCode('zh_CN');
    await tester.pumpWidget(
      P2pChatApp(
        themeController: themeCtrl,
        initialError: 'mock init failure',
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('引擎初始化失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  test('PlatformBridge persists save dir and relay URL independently', () async {
    final tmp = await Directory.systemTemp.createTemp('p2p_settings_test_');
    try {
      await PlatformBridge.saveCustomRelayUrl(tmp, 'https://relay.example.com');
      await PlatformBridge.saveCustomSaveDir(tmp, 'D:\\P2PReceived');

      expect(
        await PlatformBridge.loadCustomRelayUrl(tmp),
        'https://relay.example.com',
      );
      expect(
        await PlatformBridge.loadCustomSaveDir(tmp),
        'D:\\P2PReceived',
      );

      await PlatformBridge.saveCustomSaveDir(tmp, null);
      expect(await PlatformBridge.loadCustomSaveDir(tmp), isNull);
      expect(
        await PlatformBridge.loadCustomRelayUrl(tmp),
        'https://relay.example.com',
      );
    } finally {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    }
  });

  test('PlatformBridge persists self and peer nickname/avatar overrides cleanly', () async {
    final tmp = await Directory.systemTemp.createTemp('p2p_profile_test_');
    try {
      await PlatformBridge.saveSelfProfile(
        tmp,
        nickname: '主力电脑',
        avatar: '💻',
      );
      await PlatformBridge.savePeerProfile(
        tmp,
        'peer_oneplus_01',
        nickname: '一加手机',
        avatar: '一加',
      );
      await PlatformBridge.savePeerProfile(
        tmp,
        'peer_meizu_02',
        nickname: '魅族快递柜',
      );

      final selfLoaded = await PlatformBridge.loadSelfProfile(tmp);
      expect(selfLoaded.nickname, '主力电脑');
      expect(selfLoaded.avatar, '💻');

      final peersLoaded = await PlatformBridge.loadPeerProfiles(tmp);
      expect(peersLoaded['peer_oneplus_01']?.nickname, '一加手机');
      expect(peersLoaded['peer_oneplus_01']?.avatar, '一加');
      expect(peersLoaded['peer_meizu_02']?.nickname, '魅族快递柜');
      expect(peersLoaded['peer_meizu_02']?.avatar, isNull);

      await PlatformBridge.saveSelfProfile(tmp, nickname: null, avatar: null);
      await PlatformBridge.savePeerProfile(
        tmp,
        'peer_oneplus_01',
        nickname: null,
        avatar: null,
      );

      final clearedSelf = await PlatformBridge.loadSelfProfile(tmp);
      expect(clearedSelf.nickname, isNull);
      expect(clearedSelf.avatar, isNull);

      final updatedPeers = await PlatformBridge.loadPeerProfiles(tmp);
      expect(updatedPeers.containsKey('peer_oneplus_01'), isFalse);
      expect(updatedPeers['peer_meizu_02']?.nickname, '魅族快递柜');
    } finally {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    }
  });

  test('buildAppTheme provides distinct platform tokens for Android & Windows', () {
    final androidLight = buildAppTheme(
      brightness: Brightness.light,
      styleOverride: AppUiStyle.androidExpressive,
    );
    final windowsDark = buildAppTheme(
      brightness: Brightness.dark,
      styleOverride: AppUiStyle.windowsFluent,
    );

    final androidTokens = androidLight.extension<AppThemeTokens>()!;
    final windowsTokens = windowsDark.extension<AppThemeTokens>()!;

    expect(androidTokens.style, AppUiStyle.androidExpressive);
    expect(androidTokens.bubbleRadius, greaterThan(windowsTokens.bubbleRadius));
    expect(androidTokens.cardBorderWidth, 0.0);

    expect(windowsTokens.style, AppUiStyle.windowsFluent);
    expect(windowsTokens.isDesktop, isTrue);
    expect(windowsTokens.cardBorderWidth, greaterThan(0.0));
  });

  test('AppThemeController persists theme mode cleanly', () async {
    final tmp = await Directory.systemTemp.createTemp('p2p_theme_test_');
    try {
      final ctrl = AppThemeController();
      await ctrl.load(tmp);
      expect(ctrl.themeMode, ThemeMode.system);

      await ctrl.setThemeMode(ThemeMode.dark);
      expect(ctrl.themeMode, ThemeMode.dark);

      final reloaded = AppThemeController();
      await reloaded.load(tmp);
      expect(reloaded.themeMode, ThemeMode.dark);
    } finally {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    }
  });

  test('WhatsApp initial extraction skips leading emojis and whitespace', () {
    expect(AppWorkspaceController.firstGrapheme('💻 DESKTOP-PTLB7S4'), 'D');
    expect(AppWorkspaceController.firstGrapheme('📱 一加12'), '一');
    expect(AppWorkspaceController.firstGrapheme('🍎 macbook'), 'M');
    expect(AppWorkspaceController.firstGrapheme('   🚀'), '🚀');
    expect(AppWorkspaceController.firstGrapheme(''), '设');

    final prefixed = PlatformBridge.prefixPlatformEmoji('MyDevice');
    expect(prefixed, isNot('MyDevice'));
    expect(PlatformBridge.prefixPlatformEmoji(prefixed), prefixed);
  });

  MessageDto makeImageMsg({
    required String id,
    required int createdAtMs,
    String? batchId,
  }) =>
      MessageDto(
        msgId: id,
        roomId: 'r1',
        peerId: 'p1',
        senderId: 's1',
        isOutgoing: false,
        isFile: true,
        bodyText: null,
        fileName: '$id.jpg',
        fileSize: BigInt.from(1024),
        localPath: null,
        totalChunks: 1,
        completedChunks: 1,
        status: 'delivered',
        deliveryScope: 'direct',
        ackedPeers: const [],
        batchId: batchId,
        createdAtMs: createdAtMs,
      );

  testWidgets('ChatTimelineView separates distinct batchIds even within 1 second',
      (WidgetTester tester) async {
    final baseMs = DateTime(2026, 11, 16, 12, 0, 0).millisecondsSinceEpoch;
    final messages = <MessageDto>[
      for (var k = 0; k < 6; k++)
        makeImageMsg(id: 'img_a_$k', createdAtMs: baseMs + k * 100, batchId: 'b1'),
      // New single image sent immediately after on the same day with a different batchId.
      makeImageMsg(id: 'img_b_0', createdAtMs: baseMs + 700, batchId: 'b2'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: ChatTimelineView(
            roomId: 'r1',
            messages: messages,
            itemBuilder: (_, msg, _) => Text('ITEM:${msg.msgId}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('共 6 张图片'), findsOneWidget);
    expect(find.text('共 7 张图片'), findsNothing);
    expect(find.text('ITEM:img_b_0'), findsOneWidget);
  });

  testWidgets('ChatTimelineView keeps matching batchId grouped and splits legacy gaps',
      (WidgetTester tester) async {
    final baseMs = DateTime(2026, 11, 16, 9, 0, 0).millisecondsSinceEpoch;
    final messages = <MessageDto>[
      // Legacy messages (batchId == null) spaced 1s apart -> collapsed (5).
      for (var k = 0; k < 5; k++)
        makeImageMsg(id: 'legacy_$k', createdAtMs: baseMs + k * 1000),
      // Legacy message 2 minutes later -> stays standalone.
      makeImageMsg(id: 'legacy_late', createdAtMs: baseMs + 125 * 1000),
      // Batch with slow hashing (>30s between items) -> still stays in 1 group (5).
      for (var k = 0; k < 5; k++)
        makeImageMsg(
          id: 'slow_$k',
          createdAtMs: baseMs + 300 * 1000 + k * 40000,
          batchId: 'b-slow',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: ChatTimelineView(
            roomId: 'r1',
            messages: messages,
            itemBuilder: (_, msg, _) => Text('ITEM:${msg.msgId}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('共 5 张图片'), findsNWidgets(2));
    expect(find.text('ITEM:legacy_late'), findsOneWidget);
  });

  test('Incoming notification ignores paused/awaiting files and scopes counts by batchId', () {
    final controller = AppWorkspaceController(
      myEndpointId: 'me_1',
      dataDir: Directory.systemTemp.path,
      autoReceiveDir: Directory.systemTemp.path,
    )..seedNotificationsForTest();

    MessageDto makeIncomingFile({
      required String id,
      required String name,
      required String status,
      String? batchId,
    }) =>
        MessageDto(
          msgId: id,
          roomId: 'r1',
          peerId: 'peer_1',
          senderId: 'peer_1',
          isOutgoing: false,
          isFile: true,
          fileName: name,
          fileSize: BigInt.from(1024),
          completedChunks: status == 'delivered' ? 1 : 0,
          totalChunks: 1,
          status: status,
          deliveryScope: 'direct',
          ackedPeers: const [],
          batchId: batchId,
          createdAtMs: 1000,
        );

    // Historical interrupted & awaiting_download files must NOT inflate notifications.
    expect(
      controller.evaluateIncomingNotification(
        makeIncomingFile(
          id: 'old_paused',
          name: 'old_paused.jpg',
          status: 'paused_reconnecting',
        ),
        forcePlatformCheck: false,
      ),
      isNull,
    );
    expect(
      controller.evaluateIncomingNotification(
        makeIncomingFile(
          id: 'old_await',
          name: 'big_offer.zip',
          status: 'awaiting_download',
        ),
        forcePlatformCheck: false,
      ),
      isNull,
    );

    // Single new image delivered -> should show ONLY its own filename, not "共 2 个文件".
    final singleRes = controller.evaluateIncomingNotification(
      makeIncomingFile(
        id: 'single_1',
        name: 'single.jpg',
        status: 'delivered',
        batchId: 'batch-single',
      ),
      forcePlatformCheck: false,
    );
    expect(singleRes?.body, 'single.jpg');

    // Two active files in same batchId (plus another active file in different batchId).
    controller.evaluateIncomingNotification(
      makeIncomingFile(
        id: 'other_batch_file',
        name: 'other.jpg',
        status: 'transferring',
        batchId: 'batch-other',
      ),
      forcePlatformCheck: false,
    );
    controller.evaluateIncomingNotification(
      makeIncomingFile(
        id: 'b2_1',
        name: 'first.jpg',
        status: 'transferring',
        batchId: 'batch-2',
      ),
      forcePlatformCheck: false,
    );
    controller.evaluateIncomingNotification(
      makeIncomingFile(
        id: 'b2_2',
        name: 'second.jpg',
        status: 'handshaking',
        batchId: 'batch-2',
      ),
      forcePlatformCheck: false,
    );
    final batchRes = controller.evaluateIncomingNotification(
      makeIncomingFile(
        id: 'b2_1',
        name: 'first.jpg',
        status: 'delivered',
        batchId: 'batch-2',
      ),
      forcePlatformCheck: false,
    );
    expect(batchRes?.body, 'first.jpg 等共 2 个文件正在接收');
  });

  testWidgets('DeviceAvatar renders default hardware icons when no photo is set', (
    WidgetTester tester,
  ) async {
    expect(
      AppWorkspaceController.inferDeviceKind('DESKTOP-PTLB7S4'),
      DeviceIconKind.desktop,
    );
    expect(
      AppWorkspaceController.inferDeviceKind('OnePlus PJE110'),
      DeviceIconKind.phone,
    );
    expect(
      AppWorkspaceController.inferDeviceKind('16th'),
      DeviceIconKind.phone,
    );
    expect(AppWorkspaceController.stripLeadingDeviceEmoji('📱 16th'), '16th');
    expect(
      AppWorkspaceController.stripLeadingDeviceEmoji('💻 DESKTOP-PTLB7S4'),
      'DESKTOP-PTLB7S4',
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.light),
        home: const Scaffold(
          body: Row(
            children: [
              DeviceAvatar(
                fallbackText: 'D',
                deviceKind: DeviceIconKind.desktop,
                accentColor: Colors.teal,
              ),
              DeviceAvatar(
                fallbackText: 'O',
                deviceKind: DeviceIconKind.phone,
                accentColor: Colors.teal,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);
    expect(find.byIcon(Icons.smartphone_outlined), findsOneWidget);
    expect(find.text('D'), findsNothing);
    expect(find.text('O'), findsNothing);
  });

  test('PlatformBridge Android storage mode persists valid modes with downloads default', () async {
    final tmp = await Directory.systemTemp.createTemp('p2p_chat_storage_mode_');
    try {
      expect(await PlatformBridge.loadAndroidStorageMode(tmp), 'downloads');

      await PlatformBridge.saveAndroidStorageMode(tmp, 'documents');
      expect(await PlatformBridge.loadAndroidStorageMode(tmp), 'documents');

      await PlatformBridge.saveAndroidStorageMode(tmp, 'app_private');
      expect(await PlatformBridge.loadAndroidStorageMode(tmp), 'app_private');

      await PlatformBridge.saveAndroidStorageMode(tmp, 'invalid_mode');
      expect(await PlatformBridge.loadAndroidStorageMode(tmp), 'downloads');
    } finally {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('External share dialog follows Step 1 -> Step 2 confirm card -> reselect -> send', (
    WidgetTester tester,
  ) async {
    final controller = AppWorkspaceController(
      myEndpointId: 'me_node_1',
      dataDir: Directory.systemTemp.path,
      autoReceiveDir: Directory.systemTemp.path,
    );
    controller.setRoomsAndPeersForTest(
      peers: const [
        PeerDto(
          nodeId: 'peer_pc',
          displayName: 'DESKTOP-PTLB7S4',
          createdAtMs: 1000,
        ),
        PeerDto(
          nodeId: 'peer_16th',
          displayName: '16th',
          createdAtMs: 2000,
        ),
      ],
      rooms: const [
        RoomDto(
          roomId: 'dm-me_node_1-peer_pc',
          name: 'DESKTOP-PTLB7S4',
          roomType: 'dm',
          isPinned: false,
          retentionDays: 7,
          createdAtMs: 1000,
          memberCount: 2,
        ),
        RoomDto(
          roomId: 'dm-me_node_1-peer_16th',
          name: '16th',
          roomType: 'dm',
          isPinned: false,
          retentionDays: 7,
          createdAtMs: 2000,
          memberCount: 2,
        ),
      ],
    );

    RoomOrPeerSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showExternalShareDialog(
                    ctx,
                    controller,
                    const [
                      SharedPayloadItem(
                        type: 'text',
                        value: 'Hello from gallery share',
                      ),
                    ],
                  );
                },
                child: const Text('TriggerShare'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('TriggerShare'));
    await tester.pumpAndSettle();

    // Step 1: Pick target
    expect(find.text('分享到...'), findsOneWidget);
    expect(find.text('DESKTOP-PTLB7S4'), findsOneWidget);
    expect(find.text('16th'), findsOneWidget);

    await tester.tap(find.text('16th'));
    await tester.pumpAndSettle();

    // Step 2: WeChat-style confirm card
    expect(find.text('发送给'), findsOneWidget);
    expect(find.text('16th'), findsOneWidget);
    expect(find.text('Hello from gallery share'), findsOneWidget);
    expect(find.text('重选'), findsOneWidget);
    expect(find.text('发送'), findsOneWidget);

    // Reselect goes back to Step 1
    await tester.tap(find.text('重选'));
    await tester.pumpAndSettle();
    expect(find.text('分享到...'), findsOneWidget);

    // Pick DESKTOP-PTLB7S4 and confirm send
    await tester.tap(find.text('DESKTOP-PTLB7S4'));
    await tester.pumpAndSettle();
    expect(find.text('发送给'), findsOneWidget);
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();

    expect(result?.room?.roomId, 'dm-me_node_1-peer_pc');
    controller.dispose();
  });

  testWidgets('RoomInviteSheet renders gallery QR picker button and paste input on scan tab', (
    WidgetTester tester,
  ) async {
    final controller = AppWorkspaceController(
      myEndpointId: 'me_node_1',
      dataDir: Directory.systemTemp.path,
      autoReceiveDir: Directory.systemTemp.path,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.light),
        home: Scaffold(
          body: RoomInviteSheet(
            controller: controller,
            initialScanTab: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加设备 / 扫码配对'), findsOneWidget);
    expect(
      find.text('从相册选二维码'),
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
          ? findsOneWidget
          : findsNothing,
    );
    expect(find.text('粘贴房间邀请凭证或设备配对 JSON'), findsOneWidget);
    expect(find.text('加入 / 注册到本机'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('RoomInviteSheet full-screen mode renders WhatsApp-style controls', (
    WidgetTester tester,
  ) async {
    final controller = AppWorkspaceController(
      myEndpointId: 'me_node_1',
      dataDir: Directory.systemTemp.path,
      autoReceiveDir: Directory.systemTemp.path,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(brightness: Brightness.light),
        home: RoomInviteSheet(
          controller: controller,
          initialScanTab: true,
          isFullScreen: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加设备 / 扫码配对'), findsOneWidget);
    expect(find.text('相册'), findsOneWidget);
    expect(find.text('粘贴凭证'), findsOneWidget);

    await tester.tap(find.text('粘贴凭证'));
    await tester.pumpAndSettle();
    expect(find.text('粘贴凭证加入'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('showEditProfileDialog displays full Device ID with copy action', (
    WidgetTester tester,
  ) async {
    const fullId =
        '636f66086fbae8ef0123456789abcdef0123456789abcdef0123456789abcdef';
    final tmp = Directory.systemTemp.createTempSync('p2p_edit_profile_id_');
    final controller = AppWorkspaceController(
      myEndpointId: fullId,
      dataDir: tmp.path,
      autoReceiveDir: tmp.path,
      deviceName: 'OnePlus PJE110',
    );
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        copiedText = args?['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(brightness: Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: FilledButton(
                  onPressed: () => showEditProfileDialog(
                    context: ctx,
                    controller: controller,
                    myEndpointId: fullId,
                    nodeId: fullId,
                    initialDisplayName: 'OnePlus PJE110',
                  ),
                  child: const Text('OpenProfile'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OpenProfile'));
      await tester.pumpAndSettle();

      expect(find.text('设备 ID'), findsOneWidget);
      expect(find.text(fullId), findsOneWidget);
      expect(find.text('复制设备 ID'), findsOneWidget);

      await tester.ensureVisible(find.text('复制设备 ID'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制设备 ID'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(copiedText, fullId);
      expect(find.text('已复制'), findsOneWidget);

      // Drain delayed reset timer cleanly before test teardown.
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    } finally {
      controller.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('showRoomMembersDialog allows wrapping group title and keeps member names readable', (
    WidgetTester tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('p2p_members_sheet_');
    final controller = AppWorkspaceController(
      myEndpointId: 'me_node_1',
      dataDir: tmp.path,
      autoReceiveDir: tmp.path,
      deviceName: 'OnePlus PJE110',
    );
    const groupRoom = RoomDto(
      roomId: 'room-group-1',
      name: '新建加密群聊',
      roomType: 'group',
      isPinned: false,
      retentionDays: 7,
      memberCount: 3,
      createdAtMs: 1700000000000,
    );
    controller.setRoomsAndPeersForTest(
      rooms: const [groupRoom],
      roomMembersByRoom: const {
        'room-group-1': [
          RoomMemberDto(
            roomId: 'room-group-1',
            nodeId: 'me_node_1',
            displayName: 'OnePlus PJE110',
            role: 'owner',
            joinedAtMs: 1700000000000,
          ),
          RoomMemberDto(
            roomId: 'room-group-1',
            nodeId: '969b2128a6480000',
            displayName: 'DESKTOP-PTLB7S4',
            role: 'member',
            joinedAtMs: 1700000000000,
          ),
          RoomMemberDto(
            roomId: 'room-group-1',
            nodeId: 'd71408a46df80000',
            displayName: '16th',
            role: 'member',
            joinedAtMs: 1700000000000,
          ),
        ],
      },
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(brightness: Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: FilledButton(
                  onPressed: () => showRoomMembersDialog(
                    context: ctx,
                    controller: controller,
                    myEndpointId: 'me_node_1',
                    onOpenInvite: () {},
                  ),
                  child: const Text('OpenMembers'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OpenMembers'));
      await tester.pumpAndSettle();

      final titleWidget = tester.widget<Text>(
        find.text('DESKTOP-PTLB7S4、16th 共享组'),
      );
      expect(titleWidget.maxLines, greaterThanOrEqualTo(3));

      final memberWidget = tester.widget<Text>(
        find.text('DESKTOP-PTLB7S4'),
      );
      expect(memberWidget.maxLines, greaterThanOrEqualTo(2));

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
    } finally {
      controller.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });
}
