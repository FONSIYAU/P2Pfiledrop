import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:p2p_chat_app/app_version.dart';
import 'package:p2p_chat_app/controllers/app_workspace_controller.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/services/platform_bridge.dart';
import 'package:p2p_chat_app/services/thumbnail_cache_service.dart';
import 'package:p2p_chat_app/ui/room_invite_sheet.dart';
import 'package:p2p_chat_app/ui/theme/app_theme_tokens.dart';
import 'package:p2p_chat_app/ui/widgets/desktop_nav_rail.dart';

Future<void> _writeSolidPng(File target, int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF0078D4),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    await target.writeAsBytes(byteData!.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  tearDown(() {
    AppLocalizations.setOverrideLocale(null);
  });

  test('PlatformBridge concurrent settings saves preserve all keys without tmp debris', () async {
    final tmp = await Directory.systemTemp.createTemp('p2p_settings_lock_');
    try {
      await Future.wait([
        PlatformBridge.saveSelfProfile(tmp, nickname: 'MyWorkstation'),
        PlatformBridge.saveAndroidStorageMode(tmp, 'documents'),
        PlatformBridge.saveCustomSaveDir(tmp, '/storage/emulated/0/Work'),
        PlatformBridge.savePeerProfile(tmp, 'peer-1', nickname: 'PhoneA'),
      ]);

      final settingsFile =
          File('${tmp.path}${Platform.pathSeparator}settings.json');
      final tmpFile =
          File('${tmp.path}${Platform.pathSeparator}settings.json.tmp');
      expect(settingsFile.existsSync(), isTrue);
      expect(tmpFile.existsSync(), isFalse);

      final parsed = jsonDecode(await settingsFile.readAsString())
          as Map<String, dynamic>;
      expect(parsed['self_nickname'], 'MyWorkstation');
      expect(parsed['android_storage_mode'], 'documents');
      expect(parsed['custom_save_dir'], '/storage/emulated/0/Work');
      expect((parsed['peer_profiles'] as Map)['peer-1']['nickname'], 'PhoneA');
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  test('ThumbnailCacheService ensureIndexed and clear manage disk and memory cleanly', () async {
    final tmp = await Directory.systemTemp.createTemp('p2p_thumb_idx_');
    final emptyCache = ThumbnailCacheService(tmp.path);
    try {
      // No thumbs dir yet -> returns null without throwing.
      expect(emptyCache.lookupSync('missing-1'), isNull);
      await emptyCache.ensureIndexed();
      expect(emptyCache.lookupSync('missing-1'), isNull);
    } finally {
      emptyCache.dispose();
    }

    // Now pre-populate a cached thumbnail before constructing a fresh service.
    final thumbsDir = Directory('${tmp.path}${Platform.pathSeparator}thumbs')
      ..createSync(recursive: true);
    final preCached = File(
      '${thumbsDir.path}${Platform.pathSeparator}msg_100_120x240.png',
    )..writeAsBytesSync(const [0x89, 0x50, 0x4E, 0x47]);

    final cache = ThumbnailCacheService(tmp.path);
    try {
      await cache.ensureIndexed();
      final hit = cache.lookupSync('msg_100');
      expect(hit, isNotNull);
      expect(hit!.width, 120);
      expect(hit.height, 240);
      expect(hit.path, preCached.path);

      await cache.clear();
      expect(cache.lookupSync('msg_100'), isNull);
      expect(preCached.existsSync(), isFalse);
    } finally {
      cache.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('ThumbnailCacheService avoids upscaling small images and caps tall images', (
    WidgetTester tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('p2p_thumb_scale_');
    final cache = ThumbnailCacheService(tmp.path);
    try {
      await tester.runAsync(() async {
        final smallFile = File('${tmp.path}${Platform.pathSeparator}small.png');
        final tallFile = File('${tmp.path}${Platform.pathSeparator}tall.png');
        await _writeSolidPng(smallFile, 20, 10);
        await _writeSolidPng(tallFile, 100, 2000);

        final readySmall = cache.onThumbReady.firstWhere((id) => id == 'm-small');
        final readyTall = cache.onThumbReady.firstWhere((id) => id == 'm-tall');
        cache.warmUp('m-small', smallFile.path);
        cache.warmUp('m-tall', tallFile.path);

        await Future.wait([readySmall, readyTall]).timeout(
          const Duration(seconds: 10),
        );

        final smallInfo = cache.lookupSync('m-small');
        expect(smallInfo, isNotNull);
        expect(smallInfo!.width, 20);
        expect(smallInfo.height, 10);

        final tallInfo = cache.lookupSync('m-tall');
        expect(tallInfo, isNotNull);
        expect(tallInfo!.height, lessThanOrEqualTo(ThumbnailCacheService.maxThumbHeight));
        expect(tallInfo.width, lessThanOrEqualTo(ThumbnailCacheService.maxThumbWidth));
      });
    } finally {
      cache.dispose();
      PaintingBinding.instance.imageCache.clear();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('DesktopNavRail renders with zero overflow across long European and CJK locales', (
    WidgetTester tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('p2p_rail_i18n_');
    final ctrl = AppWorkspaceController(
      myEndpointId: 'me-rail-1',
      dataDir: tmp.path,
      autoReceiveDir: tmp.path,
      deviceName: 'TestDesktop',
    );
    try {
      const localesToCheck = [
        Locale('pt'),
        Locale('ru'),
        Locale('fr'),
        Locale('de'),
        Locale('en'),
        Locale('zh', 'CN'),
      ];
      for (final loc in localesToCheck) {
        AppLocalizations.setOverrideLocale(loc);
        await tester.pumpWidget(
          MaterialApp(
            locale: loc,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(
              brightness: Brightness.light,
              styleOverride: AppUiStyle.windowsFluent,
            ),
            home: Scaffold(
              body: SizedBox(
                height: 720,
                child: Row(
                  children: [
                    DesktopNavRail(
                      controller: ctrl,
                      activeTab: WorkspaceTab.chats,
                      activeTransfersCount: 3,
                      onSelectTab: (_) {},
                      onOpenFolder: () {},
                      onOpenFiles: () {},
                      onOpenScanPair: () {},
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Overflow in locale $loc');
      }
    } finally {
      ctrl.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  testWidgets('RoomInviteSheet fullScreen shows QR error on Tab 1 and uses theme muted color in dark mode', (
    WidgetTester tester,
  ) async {
    AppLocalizations.setOverrideLocale(const Locale('en'));
    final tmp = Directory.systemTemp.createTempSync('p2p_qr_fs_err_');
    final ctrl = AppWorkspaceController(
      myEndpointId: 'me_node_fs',
      dataDir: tmp.path,
      autoReceiveDir: tmp.path,
    );
    try {
      final darkTheme = buildAppTheme(
        brightness: Brightness.dark,
        styleOverride: AppUiStyle.androidExpressive,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkTheme,
          home: RoomInviteSheet(
            controller: ctrl,
            initialScanTab: false,
            isFullScreen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to generate QR code'), findsOneWidget);
      final enStrings = AppLocalizations.stringsForLocale(const Locale('en'));
      final descFinder = find.text(enStrings.devicePairingDesc);
      expect(descFinder, findsOneWidget);
      final descText = tester.widget<Text>(descFinder);
      expect(descText.style?.color, isNot(Colors.black54));
    } finally {
      ctrl.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });

  test('All 11 locales provide storageModeCustomTitle and parameterized aboutVersion', () {
    for (final opt in AppLocalizations.supportedLocaleOptions) {
      final s = AppLocalizations.stringsForLocale(opt.locale);
      expect(
        s.storageModeCustomTitle.trim(),
        isNotEmpty,
        reason: 'Missing storageModeCustomTitle in ${opt.code}',
      );
      expect(
        s.storageModeCustomTitle.contains('()'),
        isFalse,
        reason: 'Broken () placeholder in ${opt.code}',
      );
      final ver = s.aboutVersion(kAppVersionTag);
      expect(
        ver.contains(kAppVersionTag),
        isTrue,
        reason: 'aboutVersion missing version tag in ${opt.code}: $ver',
      );
      expect(
        ver.contains('Phase 3'),
        isFalse,
        reason: 'Stale Phase 3 string in ${opt.code}: $ver',
      );
    }
  });

  test('resolveLatestMonthFolder picks newest YYYY-MM subfolder and falls back cleanly', () {
    final tmp = Directory.systemTemp.createTempSync('p2p_month_dir_');
    try {
      // No month folders yet -> falls back to root directory.
      expect(PlatformBridge.resolveLatestMonthFolder(tmp.path), tmp.path);

      // Non-month folders and files are ignored.
      Directory('${tmp.path}${Platform.pathSeparator}misc').createSync();
      Directory('${tmp.path}${Platform.pathSeparator}2026-11-extra').createSync();
      File('${tmp.path}${Platform.pathSeparator}2026-12').writeAsStringSync('not a dir');
      expect(PlatformBridge.resolveLatestMonthFolder(tmp.path), tmp.path);

      // Picks the latest YYYY-MM directory.
      Directory('${tmp.path}${Platform.pathSeparator}2025-12').createSync();
      Directory('${tmp.path}${Platform.pathSeparator}2026-09').createSync();
      final newest = Directory('${tmp.path}${Platform.pathSeparator}2026-11')
        ..createSync();
      expect(PlatformBridge.resolveLatestMonthFolder(tmp.path), newest.path);

      // Missing root directory falls back to original path.
      final missing = '${tmp.path}${Platform.pathSeparator}does_not_exist';
      expect(PlatformBridge.resolveLatestMonthFolder(missing), missing);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  });
}
