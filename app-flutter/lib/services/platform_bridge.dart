import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:p2p_chat_app/l10n/app_localizations.dart';
import 'package:p2p_chat_app/src/rust/api.dart';

/// Shared item received from Android Share Sheet (`ACTION_SEND`).
class SharedPayloadItem {
  final String type; // "file" or "text"
  final String value;

  const SharedPayloadItem({required this.type, required this.value});
}

/// Native Windows shell configuration mirrored from C++ tray & registry hooks.
class WindowsShellState {
  final bool autoStart;
  final bool closeToTray;

  const WindowsShellState({
    required this.autoStart,
    required this.closeToTray,
  });
}

/// User-customized display name and avatar override stored locally per device ID.
class DeviceProfileOverride {
  final String? nickname;
  final String? avatar;

  const DeviceProfileOverride({this.nickname, this.avatar});
}

/// Manages OS-specific paths, Relay configuration, Android Share intents,
/// and Android physical-NIC `NetworkHandle` discovery.
class PlatformBridge {
  static const MethodChannel _channel = MethodChannel('dev.p2pchat/platform');

  static void Function(List<SharedPayloadItem> items)? _onShareCallback;
  static void Function(List<AndroidNicInfo> nics)? _onNetworkChangedCallback;
  static bool _handlerRegistered = false;

  static void _ensureChannelHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedItems' && call.arguments is List) {
        final items = _parseShareList(call.arguments as List);
        if (items.isNotEmpty) {
          _onShareCallback?.call(items);
        }
      } else if (call.method == 'onNetworkChanged' && call.arguments is List) {
        final nics = _parseNicList(call.arguments as List);
        _onNetworkChangedCallback?.call(nics);
      }
    });
  }

  static void listenToShares(
    void Function(List<SharedPayloadItem> items) onItems,
  ) {
    _onShareCallback = onItems;
    _ensureChannelHandler();
  }

  static void listenToNetworkChanges(
    void Function(List<AndroidNicInfo> nics) onChanged,
  ) {
    _onNetworkChangedCallback = onChanged;
    _ensureChannelHandler();
  }

  static Future<List<SharedPayloadItem>> consumeInitialShares() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'consumeInitialShares',
      );
      if (raw == null) return const [];
      return _parseShareList(raw);
    } catch (_) {
      return const [];
    }
  }

  static List<SharedPayloadItem> _parseShareList(List<dynamic> raw) {
    final result = <SharedPayloadItem>[];
    for (final entry in raw) {
      if (entry is Map) {
        final type = entry['type']?.toString();
        final value = entry['value']?.toString();
        if (type != null && value != null && value.isNotEmpty) {
          result.add(SharedPayloadItem(type: type, value: value));
        }
      }
    }
    return result;
  }

  /// Queries Android `ConnectivityManager` for active non-VPN Wi-Fi/Ethernet interfaces.
  static Future<List<AndroidNicInfo>> getAndroidPhysicalNics() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getPhysicalLanInterfaces',
      );
      if (raw == null) return const [];
      return _parseNicList(raw);
    } catch (_) {
      return const [];
    }
  }

  static List<AndroidNicInfo> _parseNicList(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map(
          (m) => AndroidNicInfo(
            osIndex: (m['osIndex'] as num?)?.toInt() ?? 0,
            name: m['name']?.toString() ?? 'wlan0',
            localIp: m['localIp']?.toString() ?? '',
            networkHandle: (m['networkHandle'] as num?)?.toInt() ?? 0,
          ),
        )
        .where((n) => n.localIp.isNotEmpty)
        .toList();
  }

  static Future<Directory> getDataDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final target = Directory('${dir.path}${Platform.pathSeparator}p2p_chat');
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }
    return target;
  }

  static Future<Directory> getDefaultAutoReceiveDirectory() async {
    Directory? downloads;
    if (Platform.isWindows) {
      downloads = await getDownloadsDirectory();
    } else if (Platform.isAndroid) {
      downloads = await getExternalStorageDirectory();
    }
    downloads ??= await getApplicationDocumentsDirectory();
    final target = Directory(
      '${downloads.path}${Platform.pathSeparator}P2PChat',
    );
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }
    return target;
  }

  static Future<Directory> getAutoReceiveDirectory({Directory? dataDir}) async {
    if (!Platform.isAndroid && dataDir != null) {
      final customPath = await loadCustomSaveDir(dataDir);
      if (customPath != null) {
        try {
          final customDir = Directory(customPath);
          if (!customDir.existsSync()) {
            customDir.createSync(recursive: true);
          }
          return customDir;
        } catch (_) {
          // Fallback to default directory if custom path is temporarily unavailable.
        }
      }
    }
    return getDefaultAutoReceiveDirectory();
  }

  static Future<void> _settingsQueue = Future<void>.value();

  static Future<T> _withSettingsLock<T>(Future<T> Function() action) {
    final prev = _settingsQueue.catchError((_) {});
    final completer = Completer<T>();
    _settingsQueue = prev.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<Map<String, dynamic>> _readSettings(Directory dataDir) async {
    final file = File('${dataDir.path}${Platform.pathSeparator}settings.json');
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  static Future<void> _writeSettings(
    Directory dataDir,
    Map<String, dynamic> settings,
  ) async {
    if (!dataDir.existsSync()) {
      await dataDir.create(recursive: true);
    }
    final file = File('${dataDir.path}${Platform.pathSeparator}settings.json');
    final tmpFile = File('${file.path}.tmp');
    final encoded = jsonEncode(settings);
    await tmpFile.writeAsString(encoded, flush: true);
    try {
      await tmpFile.rename(file.path);
    } catch (_) {
      try {
        if (file.existsSync()) {
          await file.delete();
        }
        await tmpFile.rename(file.path);
      } finally {
        if (tmpFile.existsSync()) {
          try {
            await tmpFile.delete();
          } catch (_) {}
        }
      }
    }
  }

  static String? _cleanOptional(Object? raw) {
    final s = raw?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static String prefixPlatformEmoji(String rawName, {String? fallbackId}) {
    final trimmed = rawName.trim();
    final emoji = Platform.isWindows
        ? '💻'
        : Platform.isAndroid
        ? '📱'
        : (Platform.isIOS || Platform.isMacOS)
        ? '🍎'
        : '🖥️';
    if (trimmed.isEmpty) {
      final tag = Platform.isAndroid
          ? 'Android'
          : Platform.isWindows
          ? 'Windows'
          : (Platform.isIOS || Platform.isMacOS)
          ? 'Apple'
          : 'Device';
      final cleanId = fallbackId?.trim() ?? '';
      if (cleanId.isEmpty) {
        return '$emoji ${AppLocalizations.current.deviceWithTag(tag)}';
      }
      final suffix = (cleanId.length >= 4 ? cleanId.substring(0, 4) : cleanId)
          .toUpperCase();
      return '$emoji $tag · $suffix';
    }
    if (_startsWithPictograph(trimmed)) return trimmed;
    return '$emoji $trimmed';
  }

  static bool _startsWithPictograph(String text) {
    final first = text.runes.firstOrNull;
    if (first == null) return false;
    return (first >= 0x1F300 && first <= 0x1FAFF) ||
        (first >= 0x2600 && first <= 0x27BF);
  }

  /// Resolves the physical device model name (Android Settings/Build, Windows hostname)
  /// prefixed with a platform emoji, falling back cleanly when unavailable.
  static Future<String> getHardwareDeviceModel({String? fallbackEndpointId}) async {
    if (Platform.isAndroid) {
      try {
        final name = _cleanOptional(
          await _channel.invokeMethod<String>('getDeviceModelName'),
        );
        if (name != null) {
          return prefixPlatformEmoji(name, fallbackId: fallbackEndpointId);
        }
      } catch (_) {}
    } else if (Platform.isWindows) {
      final host = _cleanOptional(Platform.localHostname);
      if (host != null) {
        return prefixPlatformEmoji(host, fallbackId: fallbackEndpointId);
      }
    }
    return prefixPlatformEmoji('', fallbackId: fallbackEndpointId);
  }

  static Future<DeviceProfileOverride> loadSelfProfile(Directory dataDir) async {
    final map = await _readSettings(dataDir);
    return DeviceProfileOverride(
      nickname: _cleanOptional(map['self_nickname']),
      avatar: _cleanOptional(map['self_avatar']),
    );
  }

  static Future<void> saveSelfProfile(
    Directory dataDir, {
    String? nickname,
    String? avatar,
  }) =>
      _withSettingsLock(() async {
        final map = await _readSettings(dataDir);
        map['self_nickname'] = _cleanOptional(nickname);
        map['self_avatar'] = _cleanOptional(avatar);
        await _writeSettings(dataDir, map);
      });

  static Future<Map<String, DeviceProfileOverride>> loadPeerProfiles(
    Directory dataDir,
  ) async {
    final map = await _readSettings(dataDir);
    final rawPeers = map['peer_profiles'];
    if (rawPeers is! Map) return {};
    final result = <String, DeviceProfileOverride>{};
    for (final entry in rawPeers.entries) {
      final key = entry.key.toString().trim();
      final val = entry.value;
      if (key.isEmpty || val is! Map) continue;
      final nick = _cleanOptional(val['nickname']);
      final av = _cleanOptional(val['avatar']);
      if (nick != null || av != null) {
        result[key] = DeviceProfileOverride(nickname: nick, avatar: av);
      }
    }
    return result;
  }

  static Future<void> savePeerProfile(
    Directory dataDir,
    String nodeId, {
    String? nickname,
    String? avatar,
  }) async {
    final id = nodeId.trim();
    if (id.isEmpty) return;
    await _withSettingsLock(() async {
      final map = await _readSettings(dataDir);
      final rawPeers = map['peer_profiles'];
      final peers = rawPeers is Map
          ? Map<String, dynamic>.from(rawPeers)
          : <String, dynamic>{};
      final nick = _cleanOptional(nickname);
      final av = _cleanOptional(avatar);
      if (nick == null && av == null) {
        peers.remove(id);
      } else {
        peers[id] = <String, dynamic>{'nickname': nick, 'avatar': av};
      }
      map['peer_profiles'] = peers;
      await _writeSettings(dataDir, map);
    });
  }

  static Future<Map<String, String>> loadRoomNicknames(
    Directory dataDir,
  ) async {
    final map = await _readSettings(dataDir);
    final raw = map['room_nicknames'];
    if (raw is! Map) return {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      final val = _cleanOptional(entry.value?.toString());
      if (key.isNotEmpty && val != null) {
        result[key] = val;
      }
    }
    return result;
  }

  static Future<void> saveRoomNickname(
    Directory dataDir,
    String roomId,
    String? nickname,
  ) async {
    final id = roomId.trim();
    if (id.isEmpty) return;
    await _withSettingsLock(() async {
      final map = await _readSettings(dataDir);
      final raw = map['room_nicknames'];
      final rooms = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final nick = _cleanOptional(nickname);
      if (nick == null) {
        rooms.remove(id);
      } else {
        rooms[id] = nick;
      }
      map['room_nicknames'] = rooms;
      await _writeSettings(dataDir, map);
    });
  }

  static Future<String?> loadCustomSaveDir(Directory dataDir) async {
    final map = await _readSettings(dataDir);
    final path = map['custom_save_dir']?.toString().trim();
    return (path == null || path.isEmpty) ? null : path;
  }

  static Future<void> saveCustomSaveDir(
    Directory dataDir,
    String? dirPath,
  ) =>
      _withSettingsLock(() async {
        final map = await _readSettings(dataDir);
        final trimmed = dirPath?.trim() ?? '';
        map['custom_save_dir'] = trimmed.isEmpty ? null : trimmed;
        await _writeSettings(dataDir, map);
      });

  static Future<String?> loadCustomRelayUrl(Directory dataDir) async {
    final map = await _readSettings(dataDir);
    final url = map['custom_relay_url']?.toString().trim();
    return (url == null || url.isEmpty) ? null : url;
  }

  static Future<void> saveCustomRelayUrl(
    Directory dataDir,
    String? relayUrl,
  ) =>
      _withSettingsLock(() async {
        final map = await _readSettings(dataDir);
        final trimmed = relayUrl?.trim() ?? '';
        map['custom_relay_url'] = trimmed.isEmpty ? null : trimmed;
        await _writeSettings(dataDir, map);
      });

  /// Persists the Android Scoped Storage target: `'downloads'` (default, MediaStore),
  /// `'documents'` (MediaStore), `'custom'`, or `'app_private'`.
  static Future<String> loadAndroidStorageMode(Directory dataDir) async {
    final map = await _readSettings(dataDir);
    final mode = map['android_storage_mode']?.toString().trim();
    if (mode == 'documents' ||
        mode == 'custom' ||
        mode == 'app_private' ||
        mode == 'downloads') {
      return mode!;
    }
    return 'downloads';
  }

  static Future<void> saveAndroidStorageMode(
    Directory dataDir,
    String mode,
  ) =>
      _withSettingsLock(() async {
        final map = await _readSettings(dataDir);
        map['android_storage_mode'] = mode;
        await _writeSettings(dataDir, map);
      });

  static Future<bool> hasLegacyStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasLegacyStoragePermission') ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestLegacyStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'requestLegacyStoragePermission',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getPublicDownloadsSubdir() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getPublicDownloadsSubdir');
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getPublicDocumentsSubdir() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getPublicDocumentsSubdir');
    } catch (_) {
      return null;
    }
  }

  /// Exports a completed incoming file from app-private staging into Android
  /// `MediaStore.Downloads` or `Documents` with zero `MANAGE_EXTERNAL_STORAGE`
  /// permission, returning the final readable path when available.
  static Future<String?> exportToPublicMediaStore({
    required String sourcePath,
    required String mode,
    required String fileName,
    required String yearMonth,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'exportToPublicMediaStore',
        <String, dynamic>{
          'sourcePath': sourcePath,
          'mode': mode,
          'fileName': fileName,
          'yearMonth': yearMonth,
        },
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasAllFilesPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestAllFilesPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestAllFilesPermission') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> exportToCustomDirectory({
    required String sourcePath,
    required String targetDir,
    required String fileName,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'exportToCustomDirectory',
        <String, dynamic>{
          'sourcePath': sourcePath,
          'targetDir': targetDir,
          'fileName': fileName,
        },
      );
    } catch (_) {
      return null;
    }
  }

  static Future<WindowsShellState> getWindowsShellState() async {
    if (!Platform.isWindows) {
      return const WindowsShellState(autoStart: false, closeToTray: true);
    }
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getWindowsShellState',
      );
      return WindowsShellState(
        autoStart: raw?['autoStart'] == true,
        closeToTray: raw?['closeToTray'] != false,
      );
    } catch (_) {
      return const WindowsShellState(autoStart: false, closeToTray: true);
    }
  }

  static Future<bool> setWindowsAutoStart(bool enabled) async {
    if (!Platform.isWindows) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'setWindowsAutoStart',
            <String, dynamic>{'enabled': enabled},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setWindowsCloseToTray(bool enabled) async {
    if (!Platform.isWindows) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'setWindowsCloseToTray',
            <String, dynamic>{'enabled': enabled},
          ) ??
          enabled;
    } catch (_) {
      return enabled;
    }
  }

  static Future<void> showDesktopNotification({
    required String title,
    required String body,
  }) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>(
        'showTrayNotification',
        <String, dynamic>{'title': title, 'body': body},
      );
    } catch (_) {}
  }

  static Future<bool> revealFileInFolder(String filePath) async {
    final clean = filePath.trim();
    if (clean.isEmpty) return false;
    if (Platform.isAndroid) {
      return openFolder(File(clean).parent.path);
    }
    if (!Platform.isWindows) return false;
    try {
      final handled = await _channel.invokeMethod<bool>(
        'revealInExplorer',
        <String, dynamic>{'path': clean},
      );
      if (handled == true) return true;
    } catch (_) {}
    try {
      await Process.run('explorer.exe', ['/select,$clean']);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearNativeMediaCaches() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearNativeMediaCaches');
    } catch (_) {}
  }

  /// Opens [dirPath] in the OS file manager (Windows Explorer / Android Files).
  /// Creates the directory if needed and returns `true` when an external viewer opens.
  static Future<bool> openFolder(String dirPath) async {
    final clean = dirPath.trim();
    if (clean.isEmpty) return false;
    try {
      await Directory(clean).create(recursive: true);
    } catch (_) {}

    if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', [clean]);
        return true;
      } catch (_) {
        return false;
      }
    }

    if (Platform.isAndroid) {
      try {
        final opened = await _channel.invokeMethod<bool>(
          'openDirectory',
          <String, dynamic>{'path': clean},
        );
        return opened == true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Future<void> hideToSystemTray() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('hideToTray');
    } catch (_) {}
  }

  /// Opens Android's native multi-select Photo Picker (`ACTION_PICK_IMAGES`,
  /// falling back to `ACTION_GET_CONTENT` on older Android) without extra
  /// storage permissions, returning local cache file paths.
  static Future<List<String>> pickGalleryImages({int maxItems = 50}) async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'pickGalleryImages',
        <String, dynamic>{'maxItems': maxItems},
      );
      if (raw == null) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> syncWindowsShellStrings(AppStrings s) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>(
        'setWindowsShellStrings',
        <String, dynamic>{
          'appTitle': s.appTitle,
          'trayTooltip': s.winTrayTooltip,
          'openWindow': s.winTrayOpenWindow,
          'autoStart': s.winTrayAutoStart,
          'closeToTray': s.winTrayCloseToTray,
          'exitApp': s.winTrayExitApp,
        },
      );
    } catch (_) {}
  }

  static Future<void> quitDesktopApp() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod<void>('quitApp');
    } catch (_) {}
  }
}
