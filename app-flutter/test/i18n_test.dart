import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/main.dart';
import 'package:p2p_chat_app/src/rust/api.dart';
import 'package:p2p_chat_app/ui/room_invite_sheet.dart';
import 'package:p2p_chat_app/controllers/app_workspace_controller.dart';
import 'package:p2p_chat_app/ui/theme/app_theme_tokens.dart';

void main() {
  tearDown(() {
    AppLocalizations.setOverrideLocale(null);
  });

  test('AppLocalizations.resolveAppLocale implements 4-tier fallback chain', () {
    // Tier 1 & 2: Chinese region / script collapse
    expect(
      AppLocalizations.resolveAppLocale([const Locale('zh', 'CN')]),
      const Locale('zh', 'CN'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('zh', 'SG')]),
      const Locale('zh', 'CN'),
    );
    expect(
      AppLocalizations.resolveAppLocale([
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ]),
      const Locale('zh', 'CN'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('zh', 'TW')]),
      const Locale('zh', 'TW'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('zh', 'HK')]),
      const Locale('zh', 'TW'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('zh', 'MO')]),
      const Locale('zh', 'TW'),
    );
    expect(
      AppLocalizations.resolveAppLocale([
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]),
      const Locale('zh', 'TW'),
    );

    // Tier 2: English regional variants collapse to 'en'
    expect(
      AppLocalizations.resolveAppLocale([const Locale('en', 'GB')]),
      const Locale('en'),
    );

    // Tier 2 & 3: Regional variants across all 11 supported languages
    expect(
      AppLocalizations.resolveAppLocale([const Locale('ja', 'JP')]),
      const Locale('ja'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('ko', 'KR')]),
      const Locale('ko'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('es', 'MX')]),
      const Locale('es'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('pt', 'BR')]),
      const Locale('pt'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('fr', 'CA')]),
      const Locale('fr'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('de', 'AT')]),
      const Locale('de'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('ru', 'RU')]),
      const Locale('ru'),
    );
    expect(
      AppLocalizations.resolveAppLocale([const Locale('uk', 'UA')]),
      const Locale('uk'),
    );

    // Tier 1 priority walking across multiple OS preference locales
    expect(
      AppLocalizations.resolveAppLocale([
        const Locale('ar', 'SA'),
        const Locale('zh', 'HK'),
        const Locale('en', 'US'),
      ]),
      const Locale('zh', 'TW'),
    );
    expect(
      AppLocalizations.resolveAppLocale([
        const Locale('th', 'TH'),
        const Locale('uk', 'UA'),
        const Locale('ru', 'RU'),
      ]),
      const Locale('uk'),
    );
    expect(
      AppLocalizations.resolveAppLocale([
        const Locale('ar', 'SA'),
        const Locale('en', 'AU'),
        const Locale('zh', 'CN'),
      ]),
      const Locale('en'),
    );

    // Tier 4: Global fallback when no OS preference matches supported locales
    expect(
      AppLocalizations.resolveAppLocale([
        const Locale('ar', 'SA'),
        const Locale('th', 'TH'),
      ]),
      const Locale('en'),
    );
  });

  test('AppLocalizations.normalizeLocaleCode normalizes legacy and invalid values', () {
    expect(AppLocalizations.normalizeLocaleCode(null), 'system');
    expect(AppLocalizations.normalizeLocaleCode(''), 'system');
    expect(AppLocalizations.normalizeLocaleCode('system'), 'system');
    expect(AppLocalizations.normalizeLocaleCode('zh'), 'zh_CN');
    expect(AppLocalizations.normalizeLocaleCode('zh_cn'), 'zh_CN');
    expect(AppLocalizations.normalizeLocaleCode('zh_tw'), 'zh_TW');
    expect(AppLocalizations.normalizeLocaleCode('EN'), 'en');
    expect(AppLocalizations.normalizeLocaleCode('JA'), 'ja');
    expect(AppLocalizations.normalizeLocaleCode('KO'), 'ko');
    expect(AppLocalizations.normalizeLocaleCode('ES'), 'es');
    expect(AppLocalizations.normalizeLocaleCode('PT'), 'pt');
    expect(AppLocalizations.normalizeLocaleCode('FR'), 'fr');
    expect(AppLocalizations.normalizeLocaleCode('DE'), 'de');
    expect(AppLocalizations.normalizeLocaleCode('RU'), 'ru');
    expect(AppLocalizations.normalizeLocaleCode('UK'), 'uk');
    expect(AppLocalizations.normalizeLocaleCode('ar_SA'), 'system');
  });

  test('AppThemeController persists app_locale.txt and migrates legacy zh', () async {
    final tmp = await Directory.systemTemp.createTemp('p2p_locale_pref_');
    try {
      final ctrl = AppThemeController();
      addTearDown(ctrl.dispose);

      // Legacy 'zh' migrates to 'zh_CN' on load.
      await File('${tmp.path}${Platform.pathSeparator}app_locale.txt')
          .writeAsString('zh');
      await ctrl.load(tmp);
      expect(ctrl.localeCode, 'zh_CN');
      expect(ctrl.effectiveLocale, const Locale('zh', 'CN'));
      expect(AppLocalizations.current.localeCode, 'zh_CN');

      await ctrl.setLocaleCode('zh_TW');
      expect(ctrl.localeCode, 'zh_TW');
      expect(ctrl.effectiveLocale, const Locale('zh', 'TW'));
      expect(AppLocalizations.current.localeCode, 'zh_TW');
      expect(
        await File('${tmp.path}${Platform.pathSeparator}app_locale.txt')
            .readAsString(),
        'zh_TW',
      );

      await ctrl.setLocaleCode('en');
      expect(ctrl.localeCode, 'en');
      expect(ctrl.effectiveLocale, const Locale('en'));
      expect(AppLocalizations.current.localeCode, 'en');

      await ctrl.setLocaleCode('ja');
      expect(ctrl.localeCode, 'ja');
      expect(ctrl.effectiveLocale, const Locale('ja'));
      expect(AppLocalizations.current.localeCode, 'ja');

      await ctrl.setLocaleCode('ko');
      expect(ctrl.localeCode, 'ko');
      expect(ctrl.effectiveLocale, const Locale('ko'));
      expect(AppLocalizations.current.localeCode, 'ko');

      await ctrl.setLocaleCode('system');
      expect(ctrl.localeCode, 'system');
      expect(ctrl.effectiveLocale, isNull);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('P2pChatApp renders startup UI across all 11 supported languages', (
    WidgetTester tester,
  ) async {
    final themeCtrl = AppThemeController();
    addTearDown(themeCtrl.dispose);

    final cases = <String, String>{
      'zh_CN': '正在启动 P2P 加密传输引擎...',
      'zh_TW': '正在啟動 P2P 加密傳輸引擎...',
      'en': 'Starting P2P encrypted transfer engine...',
      'ja': 'P2P 暗号化転送エンジンを起動しています...',
      'ko': 'P2P 암호화 전송 엔진을 시작하는 중...',
      'es': 'Iniciando motor de transferencia cifrada P2P...',
      'pt': 'Iniciando motor criptografado P2P...',
      'fr': 'Démarrage du moteur chiffré P2P...',
      'de': 'Verschlüsselte P2P-Engine wird gestartet...',
      'ru': 'Запуск зашифрованного P2P-движка...',
      'uk': 'Запуск шифрованого P2P-рушія...',
    };

    for (final entry in cases.entries) {
      await themeCtrl.setLocaleCode(entry.key);
      await tester.pumpWidget(P2pChatApp(themeController: themeCtrl));
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
    }

    // Error view localized
    await themeCtrl.setLocaleCode('uk');
    await tester.pumpWidget(
      P2pChatApp(
        key: const ValueKey('error-view'),
        themeController: themeCtrl,
        initialError: 'boom',
      ),
    );
    await tester.pump();
    expect(find.textContaining('Помилка запуску рушія'), findsOneWidget);
    expect(find.text('Повторити'), findsOneWidget);

    await themeCtrl.setLocaleCode('de');
    await tester.pump();
    expect(find.textContaining('Start der Engine fehlgeschlagen'), findsOneWidget);
    expect(find.text('Wiederholen'), findsOneWidget);
  });

  testWidgets('RoomInviteSheet My QR tab handles initState error without assertion', (
    WidgetTester tester,
  ) async {
    AppLocalizations.setOverrideLocale(const Locale('en'));
    final tmp = Directory.systemTemp.createTempSync('p2p_qr_err_');
    final ctrl = AppWorkspaceController(
      myEndpointId: 'me_node_1',
      dataDir: tmp.path,
      autoReceiveDir: tmp.path,
    );
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildAppTheme(brightness: Brightness.light),
          home: Scaffold(
            body: RoomInviteSheet(
              controller: ctrl,
              initialScanTab: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should cleanly render localized error + retry button instead of crashing on
      // dependOnInheritedWidgetOfExactType inside initState.
      expect(find.textContaining('Failed to generate QR code'), findsOneWidget);
      expect(find.text('Retry QR'), findsOneWidget);
    } finally {
      ctrl.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  test('Unnamed group rooms resolve dynamically by current locale and members', () {
    final tmp = Directory.systemTemp.createTempSync('p2p_group_name_');
    final ctrl = AppWorkspaceController(
      myEndpointId: 'me-1',
      dataDir: tmp.path,
      autoReceiveDir: tmp.path,
    );
    try {
      final unnamedGroup = RoomDto(
        roomId: 'room-g1',
        name: '新建加密群聊',
        roomType: 'group',
        isPinned: false,
        retentionDays: 7,
        memberCount: 3,
        createdAtMs: 1700000000000,
      );
      final explicitGroup = RoomDto(
        roomId: 'room-g2',
        name: 'Family Photos',
        roomType: 'group',
        isPinned: false,
        retentionDays: 7,
        memberCount: 2,
        createdAtMs: 1700000000000,
      );

      // 0 other regular members (only self + home_node) -> localized empty group title
      ctrl.setRoomsAndPeersForTest(
        rooms: [unnamedGroup, explicitGroup],
        roomMembersByRoom: {
          'room-g1': [
            RoomMemberDto(
              roomId: 'room-g1',
              nodeId: 'me-1',
              displayName: 'MyPC',
              role: 'owner',
              joinedAtMs: 1700000000000,
            ),
            RoomMemberDto(
              roomId: 'room-g1',
              nodeId: 'hn-1',
              displayName: '16th',
              role: 'home_node',
              joinedAtMs: 1700000000000,
            ),
          ],
        },
      );
      AppLocalizations.setOverrideLocale(const Locale('zh', 'CN'));
      expect(ctrl.resolveRoomTitle(unnamedGroup), '新建加密群聊');
      AppLocalizations.setOverrideLocale(const Locale('en'));
      expect(ctrl.resolveRoomTitle(unnamedGroup), 'Encrypted Group');
      AppLocalizations.setOverrideLocale(const Locale('ja'));
      expect(ctrl.resolveRoomTitle(unnamedGroup), '新規暗号化グループ');
      expect(ctrl.resolveRoomTitle(explicitGroup), 'Family Photos');

      // With peer members -> localized dynamic concatenation excluding self and home_node
      ctrl.setRoomsAndPeersForTest(
        roomMembersByRoom: {
          'room-g1': [
            RoomMemberDto(
              roomId: 'room-g1',
              nodeId: 'me-1',
              displayName: 'MyPC',
              role: 'owner',
              joinedAtMs: 1700000000000,
            ),
            RoomMemberDto(
              roomId: 'room-g1',
              nodeId: 'p-1',
              displayName: 'OnePlus 12',
              role: 'member',
              joinedAtMs: 1700000000000,
            ),
            RoomMemberDto(
              roomId: 'room-g1',
              nodeId: 'p-2',
              displayName: 'Pixel 9',
              role: 'member',
              joinedAtMs: 1700000000000,
            ),
            RoomMemberDto(
              roomId: 'room-g1',
              nodeId: 'hn-1',
              displayName: '16th',
              role: 'home_node',
              joinedAtMs: 1700000000000,
            ),
          ],
        },
      );
      AppLocalizations.setOverrideLocale(const Locale('zh', 'CN'));
      expect(ctrl.resolveRoomTitle(unnamedGroup), 'OnePlus 12、Pixel 9 共享组');
      AppLocalizations.setOverrideLocale(const Locale('en'));
      expect(ctrl.resolveRoomTitle(unnamedGroup), 'OnePlus 12, Pixel 9 Group');
      AppLocalizations.setOverrideLocale(const Locale('ja'));
      expect(ctrl.resolveRoomTitle(unnamedGroup), 'OnePlus 12・Pixel 9 グループ');
      AppLocalizations.setOverrideLocale(const Locale('es'));
      expect(ctrl.resolveRoomTitle(unnamedGroup), 'Grupo OnePlus 12, Pixel 9');

      // Local custom group nickname still overrides dynamic default
      ctrl.setRoomsAndPeersForTest(
        roomNicknames: const {'room-g1': 'Work Backup'},
      );
      expect(ctrl.resolveRoomTitle(unnamedGroup), 'Work Backup');
    } finally {
      ctrl.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });
}
