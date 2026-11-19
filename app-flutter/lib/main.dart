import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/services/platform_bridge.dart';
import 'package:p2p_chat_app/src/rust/api.dart';
import 'package:p2p_chat_app/src/rust/frb_generated.dart';
import 'package:p2p_chat_app/ui/chat_page.dart';
import 'package:p2p_chat_app/ui/theme/app_theme_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final lib = Platform.isWindows
      ? ExternalLibrary.open('p2p_chat_core.dll')
      : Platform.isAndroid
          ? ExternalLibrary.open('libp2p_chat_core.so')
          : null;
  await RustLib.init(externalLibrary: lib);

  final themeController = AppThemeController();
  EngineInitResult? preloaded;
  Object? preloadError;
  try {
    preloaded = await bootstrapLocalEngine(themeController: themeController);
  } catch (e) {
    preloadError = e;
  }

  runApp(
    P2pChatApp(
      themeController: themeController,
      initialResult: preloaded,
      initialError: preloadError,
    ),
  );
}

/// Performs fast local-only bootstrap (directories, theme, SQLite store, and
/// background network stack spawn) before mounting the root workspace shell.
Future<EngineInitResult> bootstrapLocalEngine({
  required AppThemeController themeController,
}) async {
  final dataDir = await PlatformBridge.getDataDirectory();
  final results = await Future.wait<dynamic>([
    themeController.load(dataDir),
    PlatformBridge.getAutoReceiveDirectory(dataDir: dataDir),
    PlatformBridge.loadCustomRelayUrl(dataDir),
    PlatformBridge.getAndroidPhysicalNics(),
  ]);
  final recvDir = results[1] as Directory;
  final customRelay = results[2] as String?;
  final androidNics = results[3] as List<AndroidNicInfo>;

  final endpointId = await initEngine(
    dataDir: dataDir.path,
    autoReceiveDir: recvDir.path,
    customRelayUrl: customRelay,
    androidNics: androidNics,
  );

  return EngineInitResult(
    endpointId: endpointId,
    dataDir: dataDir,
    autoReceiveDir: recvDir,
    initialAndroidNics: androidNics,
  );
}

class P2pChatApp extends StatefulWidget {
  final AppThemeController? themeController;
  final EngineInitResult? initialResult;
  final Object? initialError;

  const P2pChatApp({
    super.key,
    this.themeController,
    this.initialResult,
    this.initialError,
  });

  @override
  State<P2pChatApp> createState() => _P2pChatAppState();
}

class _P2pChatAppState extends State<P2pChatApp> {
  late final AppThemeController _themeController;
  late final bool _ownsThemeController;
  Future<EngineInitResult>? _initFuture;
  EngineInitResult? _readyResult;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _ownsThemeController = widget.themeController == null;
    _themeController = widget.themeController ?? AppThemeController();
    _readyResult = widget.initialResult;
    _initError = widget.initialError;
    if (_readyResult == null && _initError == null) {
      _initFuture = bootstrapLocalEngine(themeController: _themeController);
    }
  }

  @override
  void dispose() {
    if (_ownsThemeController) {
      _themeController.dispose();
    }
    super.dispose();
  }

  Widget _buildErrorView(Object error) {
    return Builder(
      builder: (ctx) {
        final s = AppLocalizations.of(ctx);
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    s.engineInitFailed(error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _initError = null;
                        _initFuture = bootstrapLocalEngine(
                          themeController: _themeController,
                        );
                      });
                    },
                    child: Text(s.retry),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHome() {
    final preloaded = _readyResult;
    if (preloaded != null) {
      return ChatPage(
        myEndpointId: preloaded.endpointId,
        dataDir: preloaded.dataDir,
        autoReceiveDir: preloaded.autoReceiveDir,
        themeController: _themeController,
        initialAndroidNics: preloaded.initialAndroidNics,
      );
    }
    if (_initError != null) {
      return _buildErrorView(_initError!);
    }

    return FutureBuilder<EngineInitResult>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error!);
        }
        if (!snapshot.hasData) {
          final s = AppLocalizations.of(context);
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(s.startingEngine),
                ],
              ),
            ),
          );
        }

        final info = snapshot.data!;
        return ChatPage(
          myEndpointId: info.endpointId,
          dataDir: info.dataDir,
          autoReceiveDir: info.autoReceiveDir,
          themeController: _themeController,
          initialAndroidNics: info.initialAndroidNics,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: _themeController.themeMode,
        locale: _themeController.effectiveLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        localeListResolutionCallback:
            AppLocalizations.localeListResolutionCallback,
        home: _buildHome(),
      ),
    );
  }
}

class EngineInitResult {
  final String endpointId;
  final Directory dataDir;
  final Directory autoReceiveDir;
  final List<AndroidNicInfo> initialAndroidNics;

  const EngineInitResult({
    required this.endpointId,
    required this.dataDir,
    required this.autoReceiveDir,
    this.initialAndroidNics = const [],
  });
}
