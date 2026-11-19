import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import '../services/platform_bridge.dart';
import '../services/thumbnail_cache_service.dart';
import '../src/rust/api.dart';

/// Semantic hardware form-factor category used to pick default device avatar icons
/// while keeping the controller decoupled from Material Widgets.
enum DeviceIconKind {
  desktop,
  laptop,
  phone,
  tablet,
  homeNode,
  unknown,
}

/// Real-time throughput & remaining-time estimate for an active file transfer.
class TransferSpeedInfo {
  final double bytesPerSecond;
  final int? etaSeconds;

  const TransferSpeedInfo({
    required this.bytesPerSecond,
    this.etaSeconds,
  });
}

/// Pure business-state controller for Phase 2/3 multi-room E2EE transfer,
/// zero-knowledge Home Node blind locker, Windows tray integration, and USB auto-discovery.
///
/// Strictly decoupled from Flutter Widgets / BuildContext so UI layers stay hot-swappable.
class AppWorkspaceController extends ChangeNotifier {
  final String myEndpointId;
  final String dataDir;
  String autoReceiveDir;
  String? customSaveDir;
  String? customRelayUrl;
  String _hardwareModelName;
  String? _selfNickname;
  String? _myAvatarPath;
  Map<String, DeviceProfileOverride> _peerProfiles = {};
  Map<String, String> _roomNicknames = {};
  String _lastAndroidNicSignature = '';
  late final ThumbnailCacheService _thumbCache = ThumbnailCacheService(dataDir);

  AppWorkspaceController({
    required this.myEndpointId,
    required this.dataDir,
    required this.autoReceiveDir,
    this.customSaveDir,
    this.customRelayUrl,
    String? deviceName,
    List<AndroidNicInfo> initialAndroidNics = const [],
  })  : _hardwareModelName = deviceName?.trim() ?? '',
        _lastAndroidNicSignature = _computeNicSignature(initialAndroidNics);

  static AppStrings get _s => AppLocalizations.current;

  static String _defaultDeviceName() => PlatformBridge.prefixPlatformEmoji('');

  /// Strips redundant leading OS device emojis (`💻`, `📱`, `🍎`, `🖥️`) when
  /// rendering device names alongside the new hardware vector avatars.
  static String stripLeadingDeviceEmoji(String raw) {
    final cleaned = raw.trim().replaceFirst(
          RegExp(r'^(?:💻|📱|🍎|🖥️?)\uFE0F?\s*'),
          '',
        );
    return cleaned.isNotEmpty ? cleaned : raw.trim();
  }

  String get hardwareModelName {
    final raw =
        _hardwareModelName.isNotEmpty ? _hardwareModelName : _defaultDeviceName();
    return stripLeadingDeviceEmoji(raw);
  }

  String get deviceName {
    final nick = _selfNickname?.trim() ?? '';
    return nick.isNotEmpty ? stripLeadingDeviceEmoji(nick) : hardwareModelName;
  }

  String? get selfNickname => _selfNickname;
  String? get myAvatarPath {
    final p = _myAvatarPath?.trim() ?? '';
    if (p.isEmpty || !File(p).existsSync()) return null;
    return p;
  }

  String get effectiveSelfAvatar => firstGrapheme(deviceName);

  static bool _isMeaningfulGlyphRune(int r) {
    final isAsciiAlnum = (r >= 0x30 && r <= 0x39) ||
        (r >= 0x41 && r <= 0x5A) ||
        (r >= 0x61 && r <= 0x7A);
    if (isAsciiAlnum) return true;
    final isLatinExt = r >= 0x00C0 && r <= 0x024F;
    final isCjk = (r >= 0x4E00 && r <= 0x9FFF) ||
        (r >= 0x3400 && r <= 0x4DBF) ||
        (r >= 0x3040 && r <= 0x30FF) ||
        (r >= 0xAC00 && r <= 0xD7AF);
    return isLatinExt || isCjk;
  }

  /// Extracts the fallback WhatsApp avatar initial, skipping leading emojis,
  /// symbols, and whitespace to pick the first letter, digit, or CJK character.
  static String firstGrapheme(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return _s.defaultAvatarFallback;
    for (final rune in trimmed.runes) {
      if (_isMeaningfulGlyphRune(rune)) {
        return String.fromCharCode(rune).toUpperCase();
      }
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  static bool _isMeaningfulMemberName(String name) {
    final t = name.trim();
    return t.isNotEmpty && t != '本机设备' && t != '对端设备';
  }

  static String _computeNicSignature(List<AndroidNicInfo> nics) =>
      nics.map((n) => '${n.name}:${n.localIp}:${n.networkHandle}').join('|');

  final StreamController<String> _toastController =
      StreamController<String>.broadcast();
  Stream<String> get toastMessages => _toastController.stream;

  final StreamController<List<SharedPayloadItem>> _incomingSharesController =
      StreamController<List<SharedPayloadItem>>.broadcast();
  Stream<List<SharedPayloadItem>> get incomingShares =>
      _incomingSharesController.stream;
  final List<List<SharedPayloadItem>> _pendingShareBatches = [];

  List<List<SharedPayloadItem>> takePendingSharedBatches() {
    if (_pendingShareBatches.isEmpty) return const [];
    final batches = List<List<SharedPayloadItem>>.from(_pendingShareBatches);
    _pendingShareBatches.clear();
    return batches;
  }

  StreamSubscription<UiEventDto>? _eventSub;

  bool _disposed = false;
  bool _initialized = false;
  bool _busy = false;

  List<RoomDto> _rooms = const [];
  List<PeerDto> _peers = const [];
  String? _activeRoomId;
  List<RoomMemberDto> _activeMembers = const [];
  final Map<String, List<RoomMemberDto>> _roomMembersByRoom =
      <String, List<RoomMemberDto>>{};
  List<MessageDto> _messages = const [];
  String _roomTransport = 'offline';
  final Map<String, MessageDto> _lastMessageByRoom = <String, MessageDto>{};
  final Map<String, String> _peerTransports = <String, String>{};
  final Map<String, int> _unreadCountsByRoom = <String, int>{};
  final Map<String, ({int chunks, int tsMs, double bps})> _speedSamples = {};
  final Map<String, TransferSpeedInfo> _transferSpeeds = {};
  final Set<String> _notifiedMessageIds = <String>{};
  final Set<String> _notifiedBatchIds = <String>{};
  final Set<String> _exportingMsgIds = <String>{};
  final Set<String> _failedExportMsgIds = <String>{};
  final Map<String, Map<String, String?>> _activeIncomingFilesByRoom =
      <String, Map<String, String?>>{};
  final Map<String, int> _lastFileNotifyMsByRoom = <String, int>{};
  int _sendBatchSeq = 0;
  int _filePresenceVersion = 0;
  bool _seededInitialNotifications = false;
  bool _windowsAutoStart = false;
  bool _windowsCloseToTray = true;
  String _androidStorageMode = 'downloads';
  String? _androidPublicDownloadsDir;
  String? _androidPublicDocumentsDir;

  UsbRouteStatusDto? _usbRouteStatus;

  bool get initialized => _initialized;
  bool get busy => _busy;
  int getUnreadCount(String roomId) => _unreadCountsByRoom[roomId] ?? 0;
  void markRoomRead(String roomId) {
    if (_unreadCountsByRoom.remove(roomId) != null) {
      _safeNotify();
    }
  }
  bool get windowsAutoStart => _windowsAutoStart;
  bool get windowsCloseToTray => _windowsCloseToTray;
  int get filePresenceVersion => _filePresenceVersion;
  String get androidStorageMode => _androidStorageMode;
  String get effectiveDisplaySaveDir {
    if (Platform.isAndroid) {
      if (_androidStorageMode == 'custom' &&
          (customSaveDir?.trim().isNotEmpty ?? false)) {
        return customSaveDir!.trim();
      }
      if (_androidStorageMode == 'downloads' &&
          (_androidPublicDownloadsDir?.isNotEmpty ?? false)) {
        return _androidPublicDownloadsDir!;
      }
      if (_androidStorageMode == 'documents' &&
          (_androidPublicDocumentsDir?.isNotEmpty ?? false)) {
        return _androidPublicDocumentsDir!;
      }
    }
    return autoReceiveDir;
  }

  CachedThumbInfo? lookupCachedThumbnail(String msgId, String? sourcePath) {
    final hit = _thumbCache.lookupSync(msgId);
    if (hit == null && sourcePath != null && sourcePath.isNotEmpty) {
      _thumbCache.warmUp(msgId, sourcePath);
    }
    return hit;
  }

  void _warmUpRoomImages(List<MessageDto> msgs, {int maxCount = 6}) {
    var warmed = 0;
    for (var i = msgs.length - 1; i >= 0 && warmed < maxCount; i--) {
      final m = msgs[i];
      if (!m.isFile || m.status == 'revoked') continue;
      final p = m.localPath;
      final name = (m.fileName ?? '').toLowerCase();
      final isImg = name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.png') ||
          name.endsWith('.webp') ||
          name.endsWith('.gif');
      if (isImg && p != null && p.isNotEmpty && File(p).existsSync()) {
        _thumbCache.warmUp(m.msgId, p);
        warmed++;
      }
    }
  }

  void refreshLocalFilePresence() {
    if (_disposed) return;
    _filePresenceVersion++;
    _safeNotify();
  }

  List<RoomDto> get rooms => List.unmodifiable(_rooms);
  List<PeerDto> get peers => List.unmodifiable(_peers);
  String? get activeRoomId => _activeRoomId;
  RoomDto? get activeRoom {
    if (_rooms.isEmpty) return null;
    for (final r in _rooms) {
      if (r.roomId == _activeRoomId) return r;
    }
    return _rooms.first;
  }

  List<RoomMemberDto> get activeMembers => List.unmodifiable(_activeMembers);
  List<RoomMemberDto> get activeRegularMembers =>
      _activeMembers.where((m) => m.role != 'home_node').toList();

  List<RoomMemberDto> _cachedMembersForRoom(String roomId) {
    if (roomId == _activeRoomId && _activeMembers.isNotEmpty) {
      return _activeMembers;
    }
    return _roomMembersByRoom[roomId] ?? const <RoomMemberDto>[];
  }

  /// Returns live online vs. total regular member counts (including self) for
  /// a room, backed by cached member lists and live [_peerTransports].
  ({int online, int total, bool hasOnlinePeer}) getRoomOnlineSummary(
    RoomDto room,
  ) {
    final cached = _cachedMembersForRoom(room.roomId);
    final regularMembers = cached.where((m) => m.role != 'home_node').toList();
    if (regularMembers.isEmpty) {
      final fallbackTotal = room.memberCount > 0 ? room.memberCount : 1;
      return (online: 1, total: fallbackTotal, hasOnlinePeer: false);
    }
    var online = 0;
    var hasOnlinePeer = false;
    for (final m in regularMembers) {
      if (m.nodeId == myEndpointId) {
        online++;
      } else {
        final t = _peerTransports[m.nodeId] ?? 'offline';
        if (t != 'offline') {
          online++;
          hasOnlinePeer = true;
        }
      }
    }
    return (
      online: online,
      total: regularMembers.length,
      hasOnlinePeer: hasOnlinePeer,
    );
  }

  List<MessageDto> get messages => List.unmodifiable(_messages);
  MessageDto? getLastMessageForRoom(String roomId) => _lastMessageByRoom[roomId];
  String get roomTransport => _roomTransport;
  bool get isRoomOnline => _roomTransport != 'offline';
  String? getPeerTransport(String nodeId) => _peerTransports[nodeId];
  TransferSpeedInfo? getTransferSpeed(String msgId) => _transferSpeeds[msgId];

  String? formatTransferSpeed(String msgId) {
    final info = _transferSpeeds[msgId];
    if (info == null || info.bytesPerSecond <= 0) return null;
    final bps = info.bytesPerSecond;
    final rate = bps >= 1024 * 1024
        ? '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s'
        : '${(bps / 1024).toStringAsFixed(0)} KB/s';
    if (info.etaSeconds == null) return rate;
    final eta = info.etaSeconds!;
    if (eta < 60) return '$rate · ${_s.formatRemainingSeconds(eta)}';
    return '$rate · ${_s.formatRemainingMinutesSeconds(eta ~/ 60, eta % 60)}';
  }

  UsbRouteStatusDto? get usbRouteStatus => _usbRouteStatus;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;

    _eventSub = subscribeEvents().listen(
      _handleUiEvent,
      onError: (Object err) => _emitToast(_s.toastEventStreamError(err)),
    );

    if (Platform.isAndroid) {
      PlatformBridge.listenToNetworkChanges((nics) {
        unawaited(_onPlatformNetworkChanged(nics));
      });
      PlatformBridge.listenToShares((items) {
        _enqueueIncomingShares(items);
      });
    }

    final dir = Directory(dataDir);
    final modelFuture = _hardwareModelName.isEmpty
        ? PlatformBridge.getHardwareDeviceModel(
            fallbackEndpointId: myEndpointId,
          )
        : Future.value(_hardwareModelName);
    final selfProfFuture = PlatformBridge.loadSelfProfile(dir);
    final avatarFuture = getMyAvatarPath();
    final peerProfilesFuture = PlatformBridge.loadPeerProfiles(dir);
    final roomNicknamesFuture = PlatformBridge.loadRoomNicknames(dir);
    final windowsShellFuture = Platform.isWindows
        ? PlatformBridge.getWindowsShellState()
        : Future<WindowsShellState?>.value(null);
    final sharesFuture = Platform.isAndroid
        ? PlatformBridge.consumeInitialShares()
        : Future<List<SharedPayloadItem>>.value(const []);
    final androidModeFuture = Platform.isAndroid
        ? PlatformBridge.loadAndroidStorageMode(dir)
        : Future<String>.value('downloads');
    final androidDownloadsFuture = Platform.isAndroid
        ? PlatformBridge.getPublicDownloadsSubdir()
        : Future<String?>.value(null);
    final androidDocumentsFuture = Platform.isAndroid
        ? PlatformBridge.getPublicDocumentsSubdir()
        : Future<String?>.value(null);
    final androidCustomDirFuture = Platform.isAndroid
        ? PlatformBridge.loadCustomSaveDir(dir)
        : Future<String?>.value(null);

    // Stage 1: Load persisted storage/profile preferences and thumb index
    // before refreshing rooms so Android auto-export sees the true target mode.
    final results = await Future.wait<dynamic>([
      modelFuture,
      selfProfFuture,
      avatarFuture,
      peerProfilesFuture,
      windowsShellFuture,
      sharesFuture,
      androidModeFuture,
      androidDownloadsFuture,
      androidDocumentsFuture,
      roomNicknamesFuture,
      androidCustomDirFuture,
      _thumbCache.ensureIndexed(),
    ]);
    if (_disposed) return;

    _hardwareModelName = results[0] as String;
    final selfProf = results[1] as DeviceProfileOverride;
    _selfNickname = selfProf.nickname;
    _myAvatarPath = results[2] as String?;
    _peerProfiles = results[3] as Map<String, DeviceProfileOverride>;
    _roomNicknames = results[9] as Map<String, String>;

    final shell = results[4] as WindowsShellState?;
    if (shell != null) {
      _windowsAutoStart = shell.autoStart;
      _windowsCloseToTray = shell.closeToTray;
    }

    _androidStorageMode = results[6] as String;
    _androidPublicDownloadsDir = results[7] as String?;
    _androidPublicDocumentsDir = results[8] as String?;
    final loadedCustomDir = results[10] as String?;
    if (loadedCustomDir != null && loadedCustomDir.trim().isNotEmpty) {
      customSaveDir = loadedCustomDir.trim();
    }

    // Stage 2: Load rooms/messages after storage preferences are ready.
    await refreshRooms(autoSelect: _activeRoomId == null);
    if (_disposed) return;

    unawaited(
      updateMyProfile(
        displayName: deviceName,
        clearAvatar: false,
      ),
    );

    if (Platform.isWindows) {
      unawaited(refreshUsbAndRouteStatus());
    }

    final initialShares = results[5] as List<SharedPayloadItem>;

    _initialized = true;
    _safeNotify();
    unawaited(syncActivePeerTransports());
    unawaited(connectAllPairedPeersInBackground());
    if (initialShares.isNotEmpty) {
      _enqueueIncomingShares(initialShares);
    }
  }

  Future<void> syncActivePeerTransports() async {
    if (_disposed) return;
    try {
      final active = await listActivePeerTransports();
      if (_disposed) return;
      final nextMap = <String, String>{
        for (final entry in active) entry.peerId: entry.transport,
      };
      var changed = false;
      for (final entry in nextMap.entries) {
        if (_peerTransports[entry.key] != entry.value) {
          _peerTransports[entry.key] = entry.value;
          changed = true;
        }
      }
      for (final existingKey in _peerTransports.keys.toList()) {
        if (!nextMap.containsKey(existingKey) &&
            _peerTransports[existingKey] != 'offline') {
          _peerTransports[existingKey] = 'offline';
          changed = true;
        }
      }
      _recomputeRoomTransport();
      if (changed) _safeNotify();
    } catch (_) {}
  }

  Future<void> connectAllPairedPeersInBackground() async {
    if (_disposed) return;
    try {
      await connectAllPairedPeers();
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !_initialized) return;
    refreshLocalFilePresence();
    await Future.wait([
      syncActivePeerTransports(),
      refreshRooms(autoSelect: _activeRoomId == null),
    ]);
    unawaited(connectAllPairedPeersInBackground());
  }

  Future<void> refreshAll() async {
    await refreshRooms(autoSelect: _activeRoomId == null);
    unawaited(syncActivePeerTransports());
    if (Platform.isWindows) {
      unawaited(refreshUsbAndRouteStatus());
    }
    _safeNotify();
  }

  Future<void> refreshPeers() async {
    final loaded = await listPeers();
    _peers = loaded.where((p) => p.nodeId != myEndpointId).toList();
    _safeNotify();
  }

  Future<void> refreshRooms({bool autoSelect = false}) async {
    final results = await Future.wait([
      listRooms(),
      listPeers(),
    ]);
    final list = results[0] as List<RoomDto>;
    final loadedPeers = results[1] as List<PeerDto>;
    _peers = loadedPeers.where((p) => p.nodeId != myEndpointId).toList();
    _rooms = list;
    if (list.isNotEmpty &&
        (autoSelect ||
            _activeRoomId == null ||
            !list.any((r) => r.roomId == _activeRoomId))) {
      _activeRoomId = list.first.roomId;
    } else if (list.isEmpty) {
      _activeRoomId = null;
    }
    if (_activeRoomId != null) {
      await _loadActiveRoomDetails();
      unawaited(connectActiveRoom());
    } else {
      _activeMembers = const [];
      _messages = const [];
      _roomTransport = 'offline';
    }
    unawaited(_refreshRoomPreviews(list));
    _safeNotify();
  }

  Future<void> _refreshRoomPreviews(List<RoomDto> rooms) async {
    final targets = rooms.where((r) => r.roomId != _activeRoomId).toList();
    if (targets.isEmpty) return;
    try {
      final previews = await Future.wait(
        targets.map((r) => listRoomTimeline(roomId: r.roomId, limit: 1)),
      );
      final groupTargets = targets.where((r) => r.roomType != 'dm').toList();
      final groupMembers = groupTargets.isEmpty
          ? const <List<RoomMemberDto>>[]
          : await Future.wait(
              groupTargets.map((r) => listRoomMembers(roomId: r.roomId)),
            );
      var changed = false;
      for (var i = 0; i < targets.length; i++) {
        final roomId = targets[i].roomId;
        final msgs = previews[i];
        if (msgs.isNotEmpty) {
          final latest = msgs.last;
          if (_lastMessageByRoom[roomId]?.msgId != latest.msgId ||
              _lastMessageByRoom[roomId]?.status != latest.status) {
            _lastMessageByRoom[roomId] = latest;
            changed = true;
          }
          _warmUpRoomImages(msgs, maxCount: 1);
        } else if (_lastMessageByRoom.remove(roomId) != null) {
          changed = true;
        }
      }
      for (var i = 0; i < groupTargets.length; i++) {
        final roomId = groupTargets[i].roomId;
        final members = groupMembers[i];
        final prev = _roomMembersByRoom[roomId];
        if (prev == null || _membersListChanged(prev, members)) {
          changed = true;
        }
        _roomMembersByRoom[roomId] = members;
      }
      if (changed) _safeNotify();
    } catch (_) {}
  }

  bool _membersListChanged(
    List<RoomMemberDto> prev,
    List<RoomMemberDto> next,
  ) {
    if (prev.length != next.length) return true;
    for (var i = 0; i < prev.length; i++) {
      if (prev[i].nodeId != next[i].nodeId ||
          prev[i].displayName != next[i].displayName ||
          prev[i].role != next[i].role) {
        return true;
      }
    }
    return false;
  }

  Future<void> selectRoom(String roomId, {bool waitForConnect = false}) async {
    final hadUnread = _unreadCountsByRoom.remove(roomId) != null;
    if (_activeRoomId == roomId) {
      if (hadUnread) _safeNotify();
      if (waitForConnect) {
        await connectActiveRoom();
      } else {
        unawaited(connectActiveRoom());
      }
      return;
    }
    _activeRoomId = roomId;
    _activeMembers = const [];
    _messages = const [];
    await _loadActiveRoomDetails();
    if (waitForConnect) {
      await connectActiveRoom();
    } else {
      unawaited(connectActiveRoom());
    }
  }

  Future<void> _loadActiveRoomDetails() async {
    final roomId = _activeRoomId;
    if (roomId == null) return;
    final results = await Future.wait([
      listRoomMembers(roomId: roomId),
      listRoomTimeline(roomId: roomId, limit: 250),
    ]);
    _activeMembers = results[0] as List<RoomMemberDto>;
    _roomMembersByRoom[roomId] = _activeMembers;
    _messages = results[1] as List<MessageDto>;
    if (_messages.isNotEmpty) {
      _lastMessageByRoom[roomId] = _messages.last;
    } else {
      _lastMessageByRoom.remove(roomId);
    }
    if (!_seededInitialNotifications) {
      for (final m in _messages) {
        if (!m.isOutgoing && (!m.isFile || m.status == 'delivered')) {
          _notifiedMessageIds.add(m.msgId);
        }
      }
      _seededInitialNotifications = true;
    } else {
      for (final m in _messages) {
        _maybeNotifyIncoming(m, trackActive: false);
      }
    }
    for (final m in _messages) {
      _maybeExportAndroidIncomingFile(m);
    }
    _warmUpRoomImages(_messages, maxCount: 6);
    _recomputeRoomTransport();
    _safeNotify();
  }

  Future<void> connectActiveRoom() async {
    final roomId = _activeRoomId;
    if (roomId == null) return;
    try {
      final mode = await connectRoomPeers(roomId: roomId);
      _roomTransport = mode;
      await syncActivePeerTransports();
      _safeNotify();
    } catch (_) {}
  }

  Future<RoomDto?> createEncryptedRoom(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return null;
    try {
      final created = await createRoom(name: name, myDeviceName: deviceName);
      _activeRoomId = created.roomId;
      await refreshRooms();
      _emitToast(_s.toastCreatedRoom(resolveRoomTitle(created)));
      return created;
    } catch (e) {
      _emitToast(_s.toastCreateRoomFailed(e));
      return null;
    }
  }

  Future<RoomDto?> openDirectChatWithPeer(String peerId) async {
    try {
      final dmRoom = await createRoom(
        name: '__dm__:$peerId',
        myDeviceName: deviceName,
      );
      if (_activeRoomId != dmRoom.roomId) {
        _activeRoomId = dmRoom.roomId;
        _activeMembers = const [];
        _messages = const [];
      }
      await refreshRooms();
      return dmRoom;
    } catch (e) {
      _emitToast(_s.toastOpenChatFailed(e));
      return null;
    }
  }

  Future<RoomDto?> createGroupWithPeers(
    String rawName,
    List<String> memberIds,
  ) async {
    try {
      final payload = jsonEncode({
        'name': rawName.trim(),
        'member_ids': memberIds,
      });
      final created = await createRoom(
        name: '__group__:$payload',
        myDeviceName: deviceName,
      );
      _activeRoomId = created.roomId;
      await refreshRooms();
      _emitToast(_s.toastCreatedGroup(resolveRoomTitle(created)));
      return created;
    } catch (e) {
      _emitToast(_s.toastCreateGroupFailed(e));
      return null;
    }
  }

  Future<String> buildMyDevicePairingQr() =>
      createPairingQr(deviceName: deviceName);

  Future<String> buildRoomInviteTicket({
    required String roomId,
  }) {
    return createRoomInviteQr(
      roomId: roomId,
      deviceName: deviceName,
      inviteAsHomeNode: false,
    );
  }

  Future<bool> joinOrPairFromCode(String rawJson) async {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) return false;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> &&
          decoded['kind'] == 'room_invite_v2') {
        final joined = await joinRoomWithQr(
          qrJson: trimmed,
          myDeviceName: deviceName,
        );
        _activeRoomId = joined.roomId;
        await refreshRooms();
        _emitToast(_s.toastJoinedRoom(resolveRoomTitle(joined)));
        _safeNotify();
        return true;
      }

      // PairingTicket v1: add to Contacts and immediately open 1v1 DM chat.
      final peer = await pairWithQr(qrJson: trimmed);
      final dmRoom = await createRoom(
        name: '__dm__:${peer.nodeId}',
        myDeviceName: deviceName,
      );
      _activeRoomId = dmRoom.roomId;
      await refreshRooms();
      final resolved = resolveMemberDisplayName(
        peer.nodeId,
        fallbackName: peer.displayName,
      );
      _emitToast(_s.toastAddedDevice(resolved));
      return true;
    } catch (e) {
      _emitToast(_s.toastPairFailed(e));
      return false;
    }
  }

  Future<bool> sendText(String rawText) async {
    final text = rawText.trim();
    final roomId = _activeRoomId;
    if (text.isEmpty || roomId == null) {
      return false;
    }
    try {
      final sent = await sendRoomText(roomId: roomId, text: text);
      _upsertMessage(sent);
      return true;
    } catch (e) {
      _emitToast(_s.toastSendTextFailed(e));
      return false;
    }
  }

  Future<void> sendFiles(List<String> paths) async {
    final roomId = _activeRoomId;
    if (roomId == null) {
      _emitToast(_s.toastSelectRoomFirst);
      return;
    }
    final cleanPaths = paths.where((p) => p.trim().isNotEmpty).toList();
    if (cleanPaths.isEmpty) return;

    final idPrefix = myEndpointId.length > 8
        ? myEndpointId.substring(0, 8)
        : myEndpointId;
    final batchId =
        '$idPrefix-${DateTime.now().microsecondsSinceEpoch}-${_sendBatchSeq++}';

    for (final p in cleanPaths) {
      try {
        final sent = await sendRoomFileInBatch(
          roomId: roomId,
          filePath: p,
          batchId: batchId,
        );
        _upsertMessage(sent);
      } catch (e) {
        _emitToast(_s.toastSendFileFailed(p, e));
      }
    }
  }

  Future<bool> forwardMessageToRoom({
    required MessageDto message,
    required String targetRoomId,
  }) async {
    try {
      if (message.isFile) {
        final path = message.localPath?.trim() ?? '';
        if (path.isEmpty || !File(path).existsSync()) {
          _emitToast(_s.toastForwardFileMissing);
          return false;
        }
        final sent = await sendRoomFile(roomId: targetRoomId, filePath: path);
        if (targetRoomId == _activeRoomId) {
          _upsertMessage(sent);
        }
      } else {
        final text = (message.bodyText ?? '').trim();
        if (text.isEmpty) {
          _emitToast(_s.toastForwardEmptyText);
          return false;
        }
        final sent = await sendRoomText(roomId: targetRoomId, text: text);
        if (targetRoomId == _activeRoomId) {
          _upsertMessage(sent);
        }
      }
      if (targetRoomId != _activeRoomId) {
        unawaited(connectRoomPeers(roomId: targetRoomId));
      }
      await refreshRooms();
      RoomDto? targetRoom;
      for (final r in _rooms) {
        if (r.roomId == targetRoomId) {
          targetRoom = r;
          break;
        }
      }
      final targetName =
          targetRoom != null ? resolveRoomTitle(targetRoom) : _s.fallbackTargetRoom;
      _emitToast(_s.toastForwardedTo(targetName));
      return true;
    } catch (e) {
      _emitToast(_s.toastForwardFailed(e));
      return false;
    }
  }

  Future<bool> forwardMessageToPeer({
    required MessageDto message,
    required String peerId,
  }) async {
    try {
      final dmRoom = await createRoom(
        name: '__dm__:$peerId',
        myDeviceName: deviceName,
      );
      return await forwardMessageToRoom(
        message: message,
        targetRoomId: dmRoom.roomId,
      );
    } catch (e) {
      _emitToast(_s.toastForwardFailed(e));
      return false;
    }
  }

  Future<void> confirmPendingFileTransfer(MessageDto msg) async {
    try {
      final updated = await sendRoomFile(
        roomId: msg.roomId,
        filePath: '__confirm_msg__:${msg.msgId}',
      );
      _upsertMessage(updated);
      unawaited(connectActiveRoom());
      _emitToast(_s.toastConfirmedSend(msg.fileName ?? _s.fallbackBigFile));
    } catch (e) {
      _emitToast(_s.toastConfirmSendFailed(e));
    }
  }

  Future<void> requestDownloadGroupFile(MessageDto msg) async {
    try {
      final updated = await sendRoomFile(
        roomId: msg.roomId,
        filePath: '__pull_file__:${msg.msgId}',
      );
      _upsertMessage(updated);
      _emitToast(_s.toastPullingFile(msg.fileName ?? _s.fallbackFile));
    } catch (e) {
      _emitToast(_s.toastPullFileFailed(e));
    }
  }

  Future<void> deletePairedPeer(String peerId) async {
    try {
      final dmRoom = activeRoom;
      await sendRoomFile(
        roomId: _activeRoomId ?? 'dm',
        filePath: '__delete_peer__:$peerId',
      );
      if (dmRoom != null && resolveDmPeerId(dmRoom) == peerId) {
        _activeRoomId = null;
      }
      _peerTransports.remove(peerId);
      await refreshRooms(autoSelect: _activeRoomId == null);
      _emitToast(_s.toastPeerDeleted);
    } catch (e) {
      _emitToast(_s.toastDeletePeerFailed(e));
    }
  }

  Future<void> deleteChatRoom(String roomId) async {
    try {
      await sendRoomFile(
        roomId: roomId,
        filePath: '__delete_room__:$roomId',
      );
      if (_activeRoomId == roomId) {
        _activeRoomId = null;
      }
      await refreshRooms(autoSelect: _activeRoomId == null);
      _emitToast(_s.toastRoomDeleted);
    } catch (e) {
      _emitToast(_s.toastDeleteRoomFailed(e));
    }
  }

  /// Delete a single message/file from this device only.
  /// Strictly never touches source files on outgoing messages.
  Future<bool> deleteMessageForMe(
    MessageDto msg, {
    bool deleteReceivedFile = false,
  }) async {
    final allowDeleteFile = !msg.isOutgoing && deleteReceivedFile;
    try {
      final deleted = await deleteMessageLocal(
        msgId: msg.msgId,
        deleteLocalFile: allowDeleteFile,
      );
      if (deleted) {
        _messages = _messages.where((m) => m.msgId != msg.msgId).toList();
        _transferSpeeds.remove(msg.msgId);
        _speedSamples.remove(msg.msgId);
        _activeIncomingFilesByRoom[msg.roomId]?.remove(msg.msgId);
        _safeNotify();
        unawaited(refreshRooms(autoSelect: false));
        _emitToast(
          allowDeleteFile
              ? _s.toastDeletedRecordAndFile
              : _s.toastRemovedLocalRecord,
        );
      }
      return deleted;
    } catch (e) {
      _emitToast(_s.toastDeleteMsgFailed(e));
      return false;
    }
  }

  /// WhatsApp-style revoke: remove from peer devices & Home Node blind locker,
  /// and turn the message into a tombstone without touching sender's source file.
  Future<MessageDto?> revokeMessageForAll(MessageDto msg) async {
    if (!msg.isOutgoing) {
      _emitToast(_s.toastOnlyRevokeOwn);
      return null;
    }
    try {
      final updated = await revokeMessageForEveryone(msgId: msg.msgId);
      _transferSpeeds.remove(msg.msgId);
      _speedSamples.remove(msg.msgId);
      _upsertMessage(updated);
      _safeNotify();
      unawaited(refreshRooms(autoSelect: false));
      _emitToast(_s.toastRevokedForAll);
      return updated;
    } catch (e) {
      _emitToast(_s.toastRevokeFailed(e));
      return null;
    }
  }

  Future<void> addMembersToActiveGroup(List<String> memberIds) async {
    final roomId = _activeRoomId;
    if (roomId == null || memberIds.isEmpty) return;
    try {
      await sendRoomFile(
        roomId: roomId,
        filePath: '__add_members__:${memberIds.join(",")}',
      );
      await _loadActiveRoomDetails();
      await refreshRooms();
      _emitToast(_s.toastInvitedMembers(memberIds.length));
    } catch (e) {
      _emitToast(_s.toastAddMembersFailed(e));
    }
  }

  Future<void> removeMemberFromActiveGroup(String peerId) async {
    final roomId = _activeRoomId;
    if (roomId == null) return;
    try {
      await sendRoomFile(
        roomId: roomId,
        filePath: '__remove_member__:$peerId',
      );
      await _loadActiveRoomDetails();
      await refreshRooms();
      _emitToast(_s.toastRemovedMember);
    } catch (e) {
      _emitToast(_s.toastRemoveMemberFailed(e));
    }
  }

  Future<void> refreshUsbAndRouteStatus() async {
    try {
      if (Platform.isWindows) {
        _usbRouteStatus = await getUsbRouteProtectionStatus();
      }
      _safeNotify();
    } catch (_) {}
  }

  Future<void> repairWindowsUsbMetric() async {
    final idx = _usbRouteStatus?.usbIfIndex;
    if (!Platform.isWindows || idx == null) return;
    _busy = true;
    _safeNotify();
    try {
      final status = await fixWindowsUsbMetric(osIndex: idx);
      _usbRouteStatus = status;
      _emitToast(
        _s.formatUsbRouteMessage(
          usbTetherDetected: status.usbTetherDetected,
          metricProtected: status.metricProtected,
          needsElevation: status.needsElevation,
          usbIfName: status.usbIfName,
        ),
      );
    } catch (e) {
      _emitToast(_s.toastFixUsbMetricFailed(e));
    } finally {
      _busy = false;
      _safeNotify();
    }
  }

  Future<void> openAutoReceiveFolder() async {
    final targetDir = effectiveDisplaySaveDir;
    final opened = await PlatformBridge.openFolder(targetDir);
    if (!opened) {
      _emitToast(_s.toastReceiveDirFallback(targetDir));
    }
  }

  Future<void> setAndroidStorageMode(
    String mode, {
    String? customPath,
  }) async {
    final normalized = (mode == 'documents' ||
            mode == 'custom' ||
            mode == 'app_private')
        ? mode
        : 'downloads';
    final dir = Directory(dataDir);
    if (normalized == 'custom' &&
        customPath != null &&
        customPath.trim().isNotEmpty) {
      final cleanPath = customPath.trim();
      customSaveDir = cleanPath;
      await PlatformBridge.saveCustomSaveDir(dir, cleanPath);
    }
    _androidStorageMode = normalized;
    _failedExportMsgIds.clear();
    await PlatformBridge.saveAndroidStorageMode(dir, normalized);
    if (normalized != 'app_private') {
      for (final m in _messages) {
        _maybeExportAndroidIncomingFile(m);
      }
    }
    _filePresenceVersion++;
    _safeNotify();
  }

  Future<void> clearThumbnailCache() async {
    await _thumbCache.clear();
    await PlatformBridge.clearNativeMediaCaches();
    if (_disposed) return;
    _filePresenceVersion++;
    _safeNotify();
  }

  Future<void> updateCustomSaveDir(String? dir) async {
    final data = Directory(dataDir);
    if (dir != null && dir.trim().isNotEmpty) {
      final validated = await setAutoReceiveDir(dirPath: dir.trim());
      autoReceiveDir = validated;
      customSaveDir = validated;
      await PlatformBridge.saveCustomSaveDir(data, validated);
    } else {
      final defaultDir = await PlatformBridge.getDefaultAutoReceiveDirectory();
      final validated = await setAutoReceiveDir(dirPath: defaultDir.path);
      autoReceiveDir = validated;
      customSaveDir = null;
      await PlatformBridge.saveCustomSaveDir(data, null);
    }
    _filePresenceVersion++;
    _safeNotify();
  }

  String resolveEffectiveSenderNodeId(String senderId) {
    final trimmed = senderId.trim();
    if (trimmed.isNotEmpty) return trimmed;
    for (final m in activeRegularMembers) {
      if (m.nodeId != myEndpointId) return m.nodeId;
    }
    return '';
  }

  String resolveMemberDisplayName(String nodeId, {String? fallbackName}) {
    final effectiveId = resolveEffectiveSenderNodeId(nodeId);
    if (effectiveId == myEndpointId) return deviceName;

    final customNick = _peerProfiles[effectiveId]?.nickname?.trim() ?? '';
    if (customNick.isNotEmpty) return stripLeadingDeviceEmoji(customNick);

    String normalizeRaw(String raw) {
      final stripped = stripLeadingDeviceEmoji(raw);
      return stripped == '家庭常驻盲盒节点' ? _s.homeNodeDefaultName : stripped;
    }

    for (final m in _activeMembers) {
      if (m.nodeId == effectiveId && _isMeaningfulMemberName(m.displayName)) {
        return normalizeRaw(m.displayName);
      }
    }
    for (final p in _peers) {
      if (p.nodeId == effectiveId && _isMeaningfulMemberName(p.displayName)) {
        return normalizeRaw(p.displayName);
      }
    }
    if (fallbackName != null && _isMeaningfulMemberName(fallbackName)) {
      return normalizeRaw(fallbackName);
    }
    if (effectiveId.isNotEmpty) {
      final shortId = (effectiveId.length >= 4
              ? effectiveId.substring(0, 4)
              : effectiveId)
          .toUpperCase();
      return _s.deviceShortIdLabel(shortId);
    }
    return _s.peerDeviceFallback;
  }

  String? resolveDmPeerId(RoomDto room) {
    if (room.roomType != 'dm') return null;
    if (_activeRoomId == room.roomId) {
      for (final m in _activeMembers) {
        if (m.nodeId != myEndpointId && m.role != 'home_node') return m.nodeId;
      }
    }
    for (final p in _peers) {
      if (room.roomId == 'dm-$myEndpointId-${p.nodeId}' ||
          room.roomId == 'dm-${p.nodeId}-$myEndpointId') {
        return p.nodeId;
      }
    }
    return null;
  }

  String resolveRoomTitle(RoomDto room) {
    final dmPeerId = resolveDmPeerId(room);
    if (dmPeerId != null) {
      return resolveMemberDisplayName(dmPeerId, fallbackName: room.name);
    }
    final custom = _roomNicknames[room.roomId]?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return resolveDefaultRoomName(room);
  }

  /// Resolves the localized default room title before any local custom alias.
  ///
  /// Unnamed groups (`''` or `'新建加密群聊'`) dynamically derive their title from
  /// the current UI locale and cached non-home-node peer members (WeChat style),
  /// falling back to the localized empty-group title when no peers exist yet.
  String resolveDefaultRoomName(RoomDto room) {
    final trimmed = room.name.trim();
    if (room.roomType == 'group' &&
        (trimmed.isEmpty || trimmed == '新建加密群聊')) {
      final others = _cachedMembersForRoom(room.roomId)
          .where((m) => m.nodeId != myEndpointId && m.role != 'home_node')
          .toList();
      if (others.isNotEmpty) {
        final names = others
            .map(
              (m) => resolveMemberDisplayName(
                m.nodeId,
                fallbackName: m.displayName,
              ),
            )
            .take(3)
            .toList();
        return _s.defaultGroupNameFromPeers(names.join(_s.nameSeparator));
      }
      return _s.defaultEncryptedGroupName;
    }
    return localizeDefaultRoomName(room.name);
  }

  /// Translates known Rust-generated default room names while preserving user-defined names.
  String localizeDefaultRoomName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed == '个人设备群 (Personal)') {
      return _s.defaultPersonalRoomName;
    }
    if (trimmed == '新建加密群聊') {
      return _s.defaultEncryptedGroupName;
    }
    if (trimmed == '新建私密加密房间') {
      return _s.defaultPrivateRoomName;
    }
    if (trimmed.startsWith('加密房间 ')) {
      return _s.encryptedRoomWithId(trimmed.substring('加密房间 '.length));
    }
    return rawName;
  }

  String? resolveMemberAvatarPath(String nodeId) {
    final effectiveId = resolveEffectiveSenderNodeId(nodeId);
    if (effectiveId == myEndpointId) return myAvatarPath;
    for (final p in _peers) {
      if (p.nodeId == effectiveId) {
        final path = p.avatarPath?.trim() ?? '';
        if (path.isNotEmpty && File(path).existsSync()) {
          return path;
        }
        return null;
      }
    }
    return null;
  }

  String resolveMemberAvatar(String nodeId, {String? fallbackName}) {
    final effectiveId = resolveEffectiveSenderNodeId(nodeId);
    if (effectiveId == myEndpointId) return effectiveSelfAvatar;
    return firstGrapheme(
      resolveMemberDisplayName(effectiveId, fallbackName: fallbackName),
    );
  }

  /// Resolves the local device's hardware form-factor icon category.
  DeviceIconKind get selfDeviceKind {
    if (Platform.isMacOS) return DeviceIconKind.laptop;
    if (Platform.isWindows || Platform.isLinux) return DeviceIconKind.desktop;
    if (Platform.isAndroid || Platform.isIOS) return DeviceIconKind.phone;
    return inferDeviceKind(hardwareModelName);
  }

  /// Infers a peer's hardware form-factor from its synced device model name,
  /// custom fallback name, or room role.
  DeviceIconKind resolveMemberDeviceKind(
    String nodeId, {
    String? fallbackName,
    String? role,
  }) {
    final effectiveId = resolveEffectiveSenderNodeId(nodeId);
    if (effectiveId == myEndpointId) return selfDeviceKind;

    final candidates = <String>[];
    for (final p in _peers) {
      if (p.nodeId == effectiveId && p.displayName.trim().isNotEmpty) {
        candidates.add(p.displayName);
      }
    }
    for (final m in _activeMembers) {
      if (m.nodeId == effectiveId && m.displayName.trim().isNotEmpty) {
        candidates.add(m.displayName);
      }
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty) {
      candidates.add(fallbackName);
    }
    final resolved = resolveMemberDisplayName(
      effectiveId,
      fallbackName: fallbackName,
    );
    if (resolved.trim().isNotEmpty) {
      candidates.add(resolved);
    }

    for (final c in candidates) {
      final kind = inferDeviceKind(c);
      if (kind != DeviceIconKind.unknown) return kind;
    }
    if (role == 'home_node') return DeviceIconKind.homeNode;
    return DeviceIconKind.unknown;
  }

  /// Classifies a device name/model string into a clean hardware icon kind.
  static DeviceIconKind inferDeviceKind(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return DeviceIconKind.unknown;
    if (trimmed.contains('💻') || trimmed.contains('🖥️')) {
      return DeviceIconKind.desktop;
    }
    if (trimmed.contains('📱')) {
      return DeviceIconKind.phone;
    }

    final lower = trimmed.toLowerCase();
    if (lower.contains('ipad') ||
        lower.contains('tablet') ||
        lower.contains('平板')) {
      return DeviceIconKind.tablet;
    }
    if (lower.contains('macbook') ||
        lower.contains('laptop') ||
        lower.contains('thinkpad') ||
        lower.contains('notebook') ||
        lower.contains('笔记本')) {
      return DeviceIconKind.laptop;
    }
    if (lower.startsWith('desktop-') ||
        lower.contains('desktop') ||
        lower.contains('windows') ||
        lower.contains('imac') ||
        lower.contains('workstation') ||
        lower.contains('台式') ||
        lower.contains('电脑') ||
        RegExp(r'(^|[^a-z])pc([^a-z]|$)').hasMatch(lower)) {
      return DeviceIconKind.desktop;
    }
    if (lower.contains('android') ||
        lower.contains('oneplus') ||
        lower.contains('pje') ||
        lower.contains('meizu') ||
        lower == '16th' ||
        lower.contains('iphone') ||
        lower.contains('xiaomi') ||
        lower.contains('redmi') ||
        lower.contains('huawei') ||
        lower.contains('honor') ||
        lower.contains('oppo') ||
        lower.contains('vivo') ||
        lower.contains('samsung') ||
        lower.contains('pixel') ||
        lower.contains('galaxy') ||
        lower.contains('realme') ||
        lower.contains('iqoo') ||
        lower.contains('手机')) {
      return DeviceIconKind.phone;
    }
    if (lower.contains('盲盒') || lower.contains('home node')) {
      return DeviceIconKind.homeNode;
    }
    return DeviceIconKind.unknown;
  }

  DeviceProfileOverride getProfileOverride(String nodeId) {
    final effectiveId = resolveEffectiveSenderNodeId(nodeId);
    if (effectiveId == myEndpointId) {
      return DeviceProfileOverride(nickname: _selfNickname);
    }
    return _peerProfiles[effectiveId] ?? const DeviceProfileOverride();
  }

  Future<void> updateDeviceProfile({
    required String nodeId,
    String? nickname,
    Uint8List? avatarPngBytes,
    bool clearAvatar = false,
  }) async {
    final cleanId = nodeId.trim();
    if (cleanId.isEmpty) return;
    final dir = Directory(dataDir);
    if (cleanId == myEndpointId) {
      await PlatformBridge.saveSelfProfile(
        dir,
        nickname: nickname,
      );
      final loaded = await PlatformBridge.loadSelfProfile(dir);
      _selfNickname = loaded.nickname;
      try {
        _myAvatarPath = await updateMyProfile(
          displayName: deviceName,
          avatarPng: avatarPngBytes,
          clearAvatar: clearAvatar,
        );
      } catch (e) {
        _emitToast(_s.toastSyncAvatarFailed(e));
      }
    } else {
      await PlatformBridge.savePeerProfile(
        dir,
        cleanId,
        nickname: nickname,
      );
      _peerProfiles = await PlatformBridge.loadPeerProfiles(dir);
    }
    _emitToast(
      cleanId == myEndpointId
          ? _s.toastSelfProfileUpdated
          : _s.toastPeerRemarkUpdated,
    );
    _safeNotify();
  }

  Future<void> updateRoomNickname(String roomId, String? nickname) async {
    final cleanId = roomId.trim();
    if (cleanId.isEmpty) return;
    final dir = Directory(dataDir);
    final trimmed = nickname?.trim();
    await PlatformBridge.saveRoomNickname(dir, cleanId, trimmed);
    _roomNicknames = await PlatformBridge.loadRoomNicknames(dir);
    _emitToast(
      (trimmed == null || trimmed.isEmpty)
          ? _s.toastRestoredGroupName
          : _s.toastUpdatedGroupName,
    );
    _safeNotify();
  }

  Future<void> toggleWindowsAutoStart(bool enabled) async {
    if (!Platform.isWindows) return;
    _windowsAutoStart = await PlatformBridge.setWindowsAutoStart(enabled);
    _emitToast(
      _windowsAutoStart ? _s.toastAutoStartEnabled : _s.toastAutoStartDisabled,
    );
    _safeNotify();
  }

  Future<void> toggleWindowsCloseToTray(bool enabled) async {
    if (!Platform.isWindows) return;
    _windowsCloseToTray = await PlatformBridge.setWindowsCloseToTray(enabled);
    _emitToast(
      _windowsCloseToTray
          ? _s.toastCloseToTrayEnabled
          : _s.toastCloseToTrayDisabled,
    );
    _safeNotify();
  }

  Future<void> hideToTray() => PlatformBridge.hideToSystemTray();

  Future<void> quitApp() => PlatformBridge.quitDesktopApp();

  Future<void> _onPlatformNetworkChanged(List<AndroidNicInfo> nics) async {
    final sig = _computeNicSignature(nics);
    // MainActivity deduplicates full connectivity snapshots (Wi-Fi + Cellular);
    // never drop transitions when physical LAN NICs are empty (cellular / WAN handover).
    if (nics.isNotEmpty && sig == _lastAndroidNicSignature) return;
    _lastAndroidNicSignature = sig;
    await refreshNetworkInterfaces(androidNics: nics);
    await connectActiveRoom();
    unawaited(connectAllPairedPeersInBackground());
    if (!_disposed &&
        _roomTransport == 'offline' &&
        activeRegularMembers.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (_disposed) return;
      await refreshNetworkInterfaces(androidNics: nics);
      await connectActiveRoom();
      unawaited(connectAllPairedPeersInBackground());
    }
    await syncActivePeerTransports();
    await refreshUsbAndRouteStatus();
  }

  void _enqueueIncomingShares(List<SharedPayloadItem> items) {
    if (_disposed || items.isEmpty) return;
    if (_incomingSharesController.hasListener &&
        !_incomingSharesController.isClosed) {
      _incomingSharesController.add(items);
    } else {
      _pendingShareBatches.add(items);
    }
  }

  Future<String?> prepareTargetRoom({
    String? roomId,
    String? peerId,
  }) async {
    if (_disposed) return null;
    if (roomId != null && roomId.isNotEmpty) {
      await selectRoom(roomId, waitForConnect: false);
      return roomId;
    }
    if (peerId != null && peerId.isNotEmpty) {
      final dm = await openDirectChatWithPeer(peerId);
      return dm?.roomId;
    }
    return null;
  }

  Future<void> sendSharedItemsToActiveRoom(List<SharedPayloadItem> items) async {
    if (_disposed || items.isEmpty) return;
    final filePaths = <String>[];
    for (final item in items) {
      if (item.type == 'file') {
        filePaths.add(item.value);
      } else if (item.type == 'text' && item.value.trim().isNotEmpty) {
        await sendText(item.value);
      }
    }
    if (filePaths.isNotEmpty) {
      await sendFiles(filePaths);
    }
  }

  void _handleUiEvent(UiEventDto ev) {
    if (_disposed) return;
    switch (ev.kind) {
      case 'peer_connected':
        if (ev.peerId != null && ev.transport != null) {
          _peerTransports[ev.peerId!] = ev.transport!;
          _recomputeRoomTransport();
        }
        break;
      case 'peer_disconnected':
        if (ev.peerId != null) {
          _peerTransports[ev.peerId!] = 'offline';
          _recomputeRoomTransport();
        }
        break;
      case 'message_added':
      case 'message_updated':
        final m = ev.message;
        if (m != null) {
          if (m.status == 'revoked') {
            _transferSpeeds.remove(m.msgId);
            _speedSamples.remove(m.msgId);
            _activeIncomingFilesByRoom[m.roomId]?.remove(m.msgId);
            _filePresenceVersion++;
          }
          if (m.roomId == _activeRoomId) {
            _upsertMessage(m);
          } else {
            final prevLast = _lastMessageByRoom[m.roomId];
            if (prevLast == null || m.createdAtMs >= prevLast.createdAtMs) {
              _lastMessageByRoom[m.roomId] = m;
            }
            if (ev.kind == 'message_added') {
              if (!m.isOutgoing &&
                  (!m.isFile ||
                      m.status == 'delivered' ||
                      m.status == 'awaiting_download')) {
                _unreadCountsByRoom[m.roomId] =
                    (_unreadCountsByRoom[m.roomId] ?? 0) + 1;
                if (Platform.isAndroid && m.isFile && m.status == 'delivered') {
                  final sender = _displaySenderName(m.senderId);
                  final fname = m.fileName?.trim() ?? _s.fallbackFile;
                  _emitToast(_s.toastAndroidIncomingFile(sender, fname));
                }
              }
              _maybeNotifyIncoming(m);
            }
            if (!m.isOutgoing && m.isFile && m.status == 'delivered') {
              _filePresenceVersion++;
            }
            _maybeExportAndroidIncomingFile(m);
          }
        }
        break;
      case 'message_deleted':
        final targetMsgId = ev.msgId;
        if (targetMsgId != null &&
            (ev.roomId == null || ev.roomId == _activeRoomId)) {
          _messages = _messages.where((m) => m.msgId != targetMsgId).toList();
          _transferSpeeds.remove(targetMsgId);
          _speedSamples.remove(targetMsgId);
        }
        if (targetMsgId != null) {
          for (final roomMap in _activeIncomingFilesByRoom.values) {
            roomMap.remove(targetMsgId);
          }
        }
        break;
      case 'transfer_progress':
        _applyProgressEvent(ev);
        break;
      case 'room_updated':
        unawaited(refreshRooms());
        unawaited(syncActivePeerTransports());
        break;
      case 'peer_profile_updated':
        unawaited(refreshPeers());
        unawaited(refreshRooms());
        break;
    }
    _safeNotify();
  }

  void _recomputeRoomTransport() {
    var best = 'offline';
    int rank(String t) => switch (t) {
          'usb_tether' => 4,
          'lan_direct' => 3,
          'wan_p2p' || 'wan_p2p_relay' => 2,
          'wan_relay' => 1,
          _ => 0,
        };
    for (final m in _activeMembers) {
      if (m.nodeId == myEndpointId) continue;
      final t = _peerTransports[m.nodeId] ?? 'offline';
      if (rank(t) > rank(best)) best = t;
    }
    if (best == 'offline' &&
        _peerTransports.isEmpty &&
        _roomTransport != 'offline') {
      return;
    }
    _roomTransport = best;
  }

  static int _statusPrecedence(String status) => switch (status) {
        'revoked' => 6,
        'delivered' => 5,
        'failed_source_missing' => 4,
        'transferring' || 'paused_reconnecting' => 3,
        'handshaking' => 2,
        'awaiting_download' => 1,
        _ => 0,
      };

  void _upsertMessage(MessageDto msg) {
    final idx = _messages.indexWhere((m) => m.msgId == msg.msgId);
    final updated = List<MessageDto>.from(_messages);
    if (idx >= 0) {
      final prev = updated[idx];
      // Prevent a delayed FFI return (typically initial `queued_offline`) from
      // clobbering a newer delivery/progress state pushed over the event stream.
      if (_statusPrecedence(prev.status) > _statusPrecedence(msg.status)) {
        return;
      }
      updated[idx] = msg;
    } else {
      updated.add(msg);
      updated.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    }
    _messages = updated;
    if (_messages.isNotEmpty) {
      _lastMessageByRoom[msg.roomId] = _messages.last;
    }
    if (msg.status == 'delivered') {
      _speedSamples.remove(msg.msgId);
      _transferSpeeds.remove(msg.msgId);
      if (msg.isFile && !msg.isOutgoing) {
        _filePresenceVersion++;
      }
    }
    _maybeExportAndroidIncomingFile(msg);
    _maybeNotifyIncoming(msg);
    _safeNotify();
  }

  void _applyProgressEvent(UiEventDto ev) {
    final msgId = ev.msgId;
    if (msgId == null) return;
    final idx = _messages.indexWhere((m) => m.msgId == msgId);
    if (idx < 0) {
      unawaited(_loadActiveRoomDetails());
      return;
    }
    final prev = _messages[idx];
    final nextAcked = List<String>.from(prev.ackedPeers);
    if (ev.status == 'delivered' &&
        ev.peerId != null &&
        !nextAcked.contains(ev.peerId)) {
      nextAcked.add(ev.peerId!);
    }
    final nextCompleted = ev.completedChunks ?? prev.completedChunks;
    final nextTotal = ev.totalChunks ?? prev.totalChunks;
    final nextStatus = ev.status ?? prev.status;

    _updateTransferSpeed(
      msgId: msgId,
      completedChunks: nextCompleted,
      totalChunks: nextTotal,
      fileSizeBytes: prev.fileSize?.toInt(),
      status: nextStatus,
    );

    final updated = List<MessageDto>.from(_messages);
    final nextMsg = MessageDto(
      msgId: prev.msgId,
      roomId: prev.roomId,
      peerId: prev.peerId,
      senderId: prev.senderId,
      isOutgoing: prev.isOutgoing,
      isFile: prev.isFile,
      bodyText: prev.bodyText,
      fileName: prev.fileName,
      fileSize: prev.fileSize,
      localPath: ev.localPath ?? prev.localPath,
      totalChunks: nextTotal,
      completedChunks: nextCompleted,
      status: nextStatus,
      deliveryScope: prev.deliveryScope,
      ackedPeers: nextAcked,
      batchId: prev.batchId,
      createdAtMs: prev.createdAtMs,
    );
    updated[idx] = nextMsg;
    _messages = updated;
    if (_messages.isNotEmpty) {
      _lastMessageByRoom[nextMsg.roomId] = _messages.last;
    }
    if (nextMsg.status == 'delivered' && nextMsg.isFile && !nextMsg.isOutgoing) {
      _filePresenceVersion++;
    }
    _maybeExportAndroidIncomingFile(nextMsg);
    _maybeNotifyIncoming(nextMsg);
  }

  void _updateTransferSpeed({
    required String msgId,
    required int completedChunks,
    required int? totalChunks,
    required int? fileSizeBytes,
    required String status,
  }) {
    if (status == 'delivered') {
      _speedSamples.remove(msgId);
      _transferSpeeds.remove(msgId);
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final prevSample = _speedSamples[msgId];
    if (prevSample == null) {
      _speedSamples[msgId] = (chunks: completedChunks, tsMs: nowMs, bps: 0);
      return;
    }
    final deltaChunks = completedChunks - prevSample.chunks;
    final deltaMs = nowMs - prevSample.tsMs;
    if (deltaChunks <= 0 || deltaMs < 150) return;

    final chunkBytes =
        (fileSizeBytes != null && totalChunks != null && totalChunks > 0)
            ? fileSizeBytes / totalChunks
            : 64.0 * 1024.0;
    final instantBps = (deltaChunks * chunkBytes) / (deltaMs / 1000.0);
    final smoothed = prevSample.bps > 0
        ? (prevSample.bps * 0.55 + instantBps * 0.45)
        : instantBps;

    _speedSamples[msgId] = (chunks: completedChunks, tsMs: nowMs, bps: smoothed);

    int? etaSeconds;
    if (totalChunks != null && totalChunks > completedChunks && smoothed > 0) {
      final remainingBytes = (totalChunks - completedChunks) * chunkBytes;
      etaSeconds = (remainingBytes / smoothed).ceil();
    }
    _transferSpeeds[msgId] = TransferSpeedInfo(
      bytesPerSecond: smoothed,
      etaSeconds: etaSeconds,
    );
  }

  static bool _isActivelyReceivingStatus(String status) =>
      status == 'handshaking' || status == 'transferring';

  /// Evaluates an incoming message for desktop tray notification and returns
  /// `(title, body)` when a notification should be displayed, or `null` otherwise.
  @visibleForTesting
  ({String title, String body})? evaluateIncomingNotification(
    MessageDto msg, {
    bool trackActive = true,
    bool forcePlatformCheck = true,
  }) {
    if ((forcePlatformCheck && !Platform.isWindows) ||
        msg.isOutgoing ||
        msg.status == 'revoked') {
      return null;
    }

    if (msg.isFile && trackActive) {
      final active = _activeIncomingFilesByRoom.putIfAbsent(
        msg.roomId,
        () => <String, String?>{},
      );
      if (_isActivelyReceivingStatus(msg.status)) {
        final normalizedBatch = msg.batchId?.trim();
        active[msg.msgId] =
            (normalizedBatch != null && normalizedBatch.isNotEmpty)
                ? normalizedBatch
                : null;
      } else {
        active.remove(msg.msgId);
      }
    }

    if (!_seededInitialNotifications) return null;

    final ready = !msg.isFile || msg.status == 'delivered';
    if (!ready || !_notifiedMessageIds.add(msg.msgId)) return null;

    final sender = _displaySenderName(msg.senderId);
    if (msg.isFile) {
      final batchId = msg.batchId?.trim() ?? '';
      if (batchId.isNotEmpty) {
        if (!_notifiedBatchIds.add(batchId)) {
          return null;
        }
      } else {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final lastMs = _lastFileNotifyMsByRoom[msg.roomId] ?? 0;
        const batchCooldownMs = 8000;
        _lastFileNotifyMsByRoom[msg.roomId] = nowMs;
        if (nowMs - lastMs <= batchCooldownMs) {
          return null;
        }
      }
      final roomActive = _activeIncomingFilesByRoom[msg.roomId];
      final remainingCount = roomActive == null
          ? 0
          : batchId.isNotEmpty
              ? roomActive.values.where((b) => b == batchId).length
              : roomActive.length;
      final fileLabel = msg.fileName ?? _s.notifyFileFallbackBody;
      final body = remainingCount > 0
          ? _s.notifyBatchFilesReceiving(fileLabel, remainingCount + 1)
          : fileLabel;
      return (title: _s.notifyNewFileTitle(sender), body: body);
    }

    final text = (msg.bodyText ?? '').trim();
    final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;
    return (
      title: _s.notifyNewTextTitle(sender),
      body: preview.isEmpty ? _s.notifyNewEncryptedText : preview,
    );
  }

  @visibleForTesting
  void seedNotificationsForTest() {
    _seededInitialNotifications = true;
  }

  @visibleForTesting
  void setRoomsAndPeersForTest({
    List<RoomDto>? rooms,
    List<PeerDto>? peers,
    Map<String, List<RoomMemberDto>>? roomMembersByRoom,
    Map<String, String>? roomNicknames,
  }) {
    if (rooms != null) _rooms = rooms;
    if (peers != null) _peers = peers;
    if (roomMembersByRoom != null) {
      _roomMembersByRoom
        ..clear()
        ..addAll(roomMembersByRoom);
      final targetId =
          _activeRoomId ?? (_rooms.isNotEmpty ? _rooms.first.roomId : null);
      if (targetId != null && roomMembersByRoom.containsKey(targetId)) {
        _activeMembers = roomMembersByRoom[targetId]!;
      }
    }
    if (roomNicknames != null) {
      _roomNicknames
        ..clear()
        ..addAll(roomNicknames);
    }
  }

  void _maybeExportAndroidIncomingFile(MessageDto msg) {
    if (!Platform.isAndroid) return;
    if (_androidStorageMode == 'app_private') return;
    if (msg.isOutgoing || !msg.isFile || msg.status != 'delivered') return;
    if (_failedExportMsgIds.contains(msg.msgId)) return;
    final src = msg.localPath?.trim() ?? '';
    if (src.isEmpty) return;
    final normSrc = src.replaceAll('\\', '/');
    final normStaging = autoReceiveDir.trim().replaceAll('\\', '/');
    if (!normSrc.startsWith(normStaging)) return;
    if (!_exportingMsgIds.add(msg.msgId)) return;
    unawaited(_exportAndroidFileAsync(msg, src));
  }

  Future<void> _exportAndroidFileAsync(MessageDto msg, String sourcePath) async {
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(msg.createdAtMs.toInt());
      final yearMonth =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';
      final fileName = (msg.fileName?.trim().isNotEmpty == true)
          ? msg.fileName!.trim()
          : sourcePath.split(RegExp(r'[/\\]')).last;
      final String? exported;
      if (_androidStorageMode == 'custom' &&
          (customSaveDir?.trim().isNotEmpty ?? false)) {
        exported = await PlatformBridge.exportToCustomDirectory(
          sourcePath: sourcePath,
          targetDir: customSaveDir!.trim(),
          fileName: fileName,
        );
      } else {
        exported = await PlatformBridge.exportToPublicMediaStore(
          sourcePath: sourcePath,
          mode: _androidStorageMode,
          fileName: fileName,
          yearMonth: yearMonth,
        );
      }
      if (_disposed) return;
      if (exported == null || exported.trim().isEmpty) {
        _failedExportMsgIds.add(msg.msgId);
        return;
      }
      final cleanExported = exported.trim();
      await updateMessageLocalPath(msgId: msg.msgId, localPath: cleanExported);
      _replaceLocalPathInMemory(msg.msgId, msg.roomId, cleanExported);
      _filePresenceVersion++;
      _safeNotify();
    } catch (_) {
      // Keep staging path intact when export fails or lacks legacy permission.
      _failedExportMsgIds.add(msg.msgId);
    } finally {
      _exportingMsgIds.remove(msg.msgId);
    }
  }

  void _replaceLocalPathInMemory(
    String msgId,
    String roomId,
    String newLocalPath,
  ) {
    MessageDto cloneWithPath(MessageDto prev) => MessageDto(
          msgId: prev.msgId,
          roomId: prev.roomId,
          peerId: prev.peerId,
          senderId: prev.senderId,
          isOutgoing: prev.isOutgoing,
          isFile: prev.isFile,
          bodyText: prev.bodyText,
          fileName: prev.fileName,
          fileSize: prev.fileSize,
          localPath: newLocalPath,
          totalChunks: prev.totalChunks,
          completedChunks: prev.completedChunks,
          status: prev.status,
          deliveryScope: prev.deliveryScope,
          ackedPeers: prev.ackedPeers,
          batchId: prev.batchId,
          createdAtMs: prev.createdAtMs,
        );

    final idx = _messages.indexWhere((m) => m.msgId == msgId);
    if (idx >= 0) {
      final updated = List<MessageDto>.from(_messages);
      updated[idx] = cloneWithPath(updated[idx]);
      _messages = updated;
    }
    final last = _lastMessageByRoom[roomId];
    if (last != null && last.msgId == msgId) {
      _lastMessageByRoom[roomId] = cloneWithPath(last);
    }
  }

  void _maybeNotifyIncoming(MessageDto msg, {bool trackActive = true}) {
    final payload = evaluateIncomingNotification(msg, trackActive: trackActive);
    if (payload == null) return;
    unawaited(
      PlatformBridge.showDesktopNotification(
        title: payload.title,
        body: payload.body,
      ),
    );
  }

  String _displaySenderName(String senderId) =>
      resolveMemberDisplayName(senderId);

  void _emitToast(String message) {
    if (!_disposed && !_toastController.isClosed) {
      _toastController.add(message);
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _thumbCache.dispose();
    _eventSub?.cancel();
    _toastController.close();
    _incomingSharesController.close();
    super.dispose();
  }
}
