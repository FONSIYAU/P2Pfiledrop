import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

import '../controllers/app_workspace_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/platform_bridge.dart';
import '../src/rust/api.dart';
import 'room_invite_sheet.dart';
import 'theme/app_theme_tokens.dart';
import 'widgets/chat_dialogs.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_list_pane.dart';
import 'widgets/chat_timeline_view.dart';
import 'widgets/contacts_pane.dart';
import 'widgets/desktop_nav_rail.dart';
import 'widgets/me_tab_view.dart';
import 'widgets/message_bubble.dart';
import 'widgets/room_avatar.dart';
import 'widgets/room_files_sheet.dart';
import 'widgets/send_preview_dialog.dart';

/// Root adaptive workspace shell supporting WeChat-style 3-section navigation:
/// - Wide Desktop (>= 780px): Slim left vertical rail + middle list + right workspace.
/// - Narrow Mobile (< 780px): 3-tab bottom NavigationBar landing on 「聊天」 list,
///   pushing a dedicated conversation screen when opening a chat.
class ChatPage extends StatefulWidget {
  final String myEndpointId;
  final Directory dataDir;
  final Directory autoReceiveDir;
  final AppThemeController themeController;
  final List<AndroidNicInfo> initialAndroidNics;

  const ChatPage({
    super.key,
    required this.myEndpointId,
    required this.dataDir,
    required this.autoReceiveDir,
    required this.themeController,
    this.initialAndroidNics = const [],
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  late final AppWorkspaceController _controller;
  final TextEditingController _msgController = TextEditingController();
  StreamSubscription<String>? _toastSub;
  StreamSubscription<List<SharedPayloadItem>>? _shareSub;
  final List<List<SharedPayloadItem>> _pendingShareBatches = [];

  WorkspaceTab _tab = WorkspaceTab.chats;
  String? _selectedContactId;
  bool _isDragging = false;
  bool _isPickingGallery = false;
  bool _handlingShareFlow = false;
  bool _isMobileConversationOpen = false;
  int _scrollToBottomRequestId = 0;

  String? _lastSyncedWinLocaleCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AppWorkspaceController(
      myEndpointId: widget.myEndpointId,
      dataDir: widget.dataDir.path,
      autoReceiveDir: widget.autoReceiveDir.path,
      initialAndroidNics: widget.initialAndroidNics,
    );
    _toastSub = _controller.toastMessages.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    });
    _shareSub = _controller.incomingShares.listen(_enqueueShareBatch);
    widget.themeController.addListener(_syncWindowsShellStringsIfNeeded);
    _controller.initialize();
    for (final batch in _controller.takePendingSharedBatches()) {
      _enqueueShareBatch(batch);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWindowsShellStringsIfNeeded();
    });
  }

  void _syncWindowsShellStringsIfNeeded() {
    if (!Platform.isWindows || !mounted) return;
    final s = AppLocalizations.current;
    if (_lastSyncedWinLocaleCode == s.localeCode) return;
    _lastSyncedWinLocaleCode = s.localeCode;
    unawaited(PlatformBridge.syncWindowsShellStrings(s));
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    _lastSyncedWinLocaleCode = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWindowsShellStringsIfNeeded();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.onAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.themeController.removeListener(_syncWindowsShellStringsIfNeeded);
    _toastSub?.cancel();
    _shareSub?.cancel();
    _msgController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _enqueueShareBatch(List<SharedPayloadItem> items) {
    if (items.isEmpty || !mounted) return;
    _pendingShareBatches.add(items);
    if (!_handlingShareFlow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_processShareQueue());
        }
      });
    }
  }

  Future<void> _processShareQueue() async {
    if (_handlingShareFlow || !mounted) return;
    _handlingShareFlow = true;
    try {
      while (_pendingShareBatches.isNotEmpty && mounted) {
        final batch = _pendingShareBatches.removeAt(0);
        await _handleExternalShareBatch(batch);
      }
    } finally {
      _handlingShareFlow = false;
    }
  }

  Future<void> _handleExternalShareBatch(List<SharedPayloadItem> items) async {
    if (!mounted || items.isEmpty) return;
    if (_controller.rooms.isEmpty && _controller.peers.isEmpty) {
      final s = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.noShareTargetsToast),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final selected = await showExternalShareDialog(
      context,
      _controller,
      items,
    );
    if (selected == null || !mounted) return;

    final targetRoomId = await _controller.prepareTargetRoom(
      roomId: selected.room?.roomId,
      peerId: selected.peer?.nodeId,
    );
    if (targetRoomId == null || !mounted) return;

    final isWide = MediaQuery.sizeOf(context).width >= 780;
    if (isWide) {
      if (_tab != WorkspaceTab.chats) {
        setState(() => _tab = WorkspaceTab.chats);
      }
    } else if (!_isMobileConversationOpen) {
      unawaited(_pushMobileConversationPage());
    }

    await _controller.sendSharedItemsToActiveRoom(items);
    _requestTimelineScrollToBottom();
  }

  void _requestTimelineScrollToBottom() {
    if (!mounted) return;
    setState(() => _scrollToBottomRequestId++);
  }

  Future<void> _sendTextMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    final sent = await _controller.sendText(text);
    if (sent) {
      _requestTimelineScrollToBottom();
    }
  }

  Future<void> _previewAndSendFiles(
    List<String> paths, {
    FileType pickerType = FileType.any,
  }) async {
    if (paths.isEmpty || !mounted) return;
    final confirmed = await showSendPreviewDialog(
      context: context,
      initialPaths: paths,
      pickerType: pickerType,
    );
    if (confirmed == null || confirmed.isEmpty || !mounted) return;
    await _controller.sendFiles(confirmed);
    _requestTimelineScrollToBottom();
  }

  Future<void> _pickAndSendGalleryImages() async {
    if (_isPickingGallery) return;
    _isPickingGallery = true;
    try {
      final List<String> paths;
      if (Platform.isAndroid) {
        paths = await PlatformBridge.pickGalleryImages(
          maxItems: kMaxBatchSendFiles,
        );
      } else {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        paths = res?.files.map((f) => f.path).whereType<String>().toList() ??
            const <String>[];
      }
      if (paths.isEmpty || !mounted) return;
      await _previewAndSendFiles(paths, pickerType: FileType.image);
    } finally {
      _isPickingGallery = false;
    }
  }

  Future<void> _pickAndSendFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null || res.files.isEmpty) return;
    final paths = res.files.map((f) => f.path).whereType<String>().toList();
    await _previewAndSendFiles(paths);
  }

  Future<void> _handleClipboardPaste() async {
    if (_controller.activeRoom == null) return;
    try {
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        await _previewAndSendFiles(files);
        return;
      }
      final imgBytes = await Pasteboard.image;
      if (imgBytes != null && imgBytes.isNotEmpty) {
        final tmp = await getTemporaryDirectory();
        final name = 'paste_${DateTime.now().millisecondsSinceEpoch}.png';
        final path = '${tmp.path}${Platform.pathSeparator}$name';
        await File(path).writeAsBytes(imgBytes);
        await _previewAndSendFiles([path]);
        return;
      }
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final txt = clip?.text;
      if (txt != null && txt.isNotEmpty) {
        final sel = _msgController.selection;
        final cur = _msgController.text;
        if (sel.isValid && sel.start >= 0) {
          final updated = cur.replaceRange(sel.start, sel.end, txt);
          _msgController.value = TextEditingValue(
            text: updated,
            selection: TextSelection.collapsed(offset: sel.start + txt.length),
          );
        } else {
          _msgController.text = '$cur$txt';
        }
      }
    } catch (_) {}
  }

  void _openRoomInviteSheet({
    bool initialScanTab = false,
    bool forceDevicePairing = false,
  }) {
    final targetRoom = forceDevicePairing ? null : _controller.activeRoom;
    final isWide = MediaQuery.sizeOf(context).width >= 780;
    if (!isWide) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RoomInviteSheet(
            controller: _controller,
            room: targetRoom,
            initialScanTab: initialScanTab,
            isFullScreen: true,
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RoomInviteSheet(
        controller: _controller,
        room: targetRoom,
        initialScanTab: initialScanTab,
      ),
    );
  }

  void _openEditProfileDialog(String nodeId, String displayName, {String? raw}) {
    showEditProfileDialog(
      context: context,
      controller: _controller,
      myEndpointId: widget.myEndpointId,
      nodeId: nodeId,
      initialDisplayName: displayName,
      rawDefaultName: raw,
    );
  }

  int _countActiveTransfers() {
    return _controller.messages
        .where(
          (m) => m.status == 'transferring' || m.status == 'handshaking',
        )
        .length;
  }

  PeerDto? _resolveSelectedContact() {
    final peers = _controller.peers;
    if (peers.isEmpty) return null;
    if (_selectedContactId != null) {
      for (final p in peers) {
        if (p.nodeId == _selectedContactId) return p;
      }
    }
    return peers.first;
  }

  Future<void> _openRoomOnCurrentDevice(RoomDto room, bool isWide) async {
    await _controller.selectRoom(room.roomId);
    if (!mounted) return;
    if (isWide) {
      if (_tab != WorkspaceTab.chats) {
        setState(() => _tab = WorkspaceTab.chats);
      }
      return;
    }
    await _pushMobileConversationPage();
  }

  Future<void> _startChatWithPeer(PeerDto peer, bool isWide) async {
    final room = await _controller.openDirectChatWithPeer(peer.nodeId);
    if (!mounted || room == null) return;
    if (isWide) {
      setState(() => _tab = WorkspaceTab.chats);
      return;
    }
    setState(() => _tab = WorkspaceTab.chats);
    await _pushMobileConversationPage();
  }

  Future<void> _pushMobileConversationPage() async {
    if (!mounted || _isMobileConversationOpen) return;
    _isMobileConversationOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (routeCtx) => _MobileConversationPage(
            controller: _controller,
            myEndpointId: widget.myEndpointId,
            buildHeaderTitle: (ctx, tokens, scheme) =>
                _buildRoomHeaderTitle(ctx, tokens, scheme),
            buildConversationBody: (ctx, tokens, scheme) =>
                _buildConversationPane(ctx, tokens, scheme),
            onOpenInviteSheet: () => _openRoomInviteSheet(initialScanTab: false),
          ),
        ),
      );
    } finally {
      _isMobileConversationOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 780;

    return ListenableBuilder(
      listenable: Listenable.merge([_controller, widget.themeController]),
      builder: (context, _) {
        if (isWide) {
          return Scaffold(
            backgroundColor: tokens.canvasBg,
            body: SafeArea(
              child: Row(
                children: [
                  DesktopNavRail(
                    controller: _controller,
                    activeTab: _tab,
                    activeTransfersCount: _countActiveTransfers(),
                    onSelectTab: (tab) => setState(() => _tab = tab),
                    onOpenFolder: _controller.openAutoReceiveFolder,
                    onOpenFiles: () => showRoomFilesView(
                      context: context,
                      controller: _controller,
                    ),
                    onOpenScanPair: () =>
                        _openRoomInviteSheet(initialScanTab: true),
                  ),
                  Expanded(child: _buildDesktopContent(tokens, scheme)),
                ],
              ),
            ),
          );
        }

        return _buildMobileShell(tokens, scheme);
      },
    );
  }

  Widget _buildDesktopContent(AppThemeTokens tokens, ColorScheme scheme) {
    switch (_tab) {
      case WorkspaceTab.chats:
        return Row(
          children: [
            SizedBox(
              width: 292,
              child: ChatListPane(
                controller: _controller,
                showDesktopHeaderActions: true,
                highlightActiveRoom: true,
                onSelectRoom: (r) => _openRoomOnCurrentDevice(r, true),
                onOpenInviteScan: () =>
                    _openRoomInviteSheet(initialScanTab: true),
                onOpenCreateGroup: () =>
                    showCreateRoomDialog(context, _controller),
                onSwitchToContacts: () =>
                    setState(() => _tab = WorkspaceTab.contacts),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: tokens.subtleBorder),
            Expanded(child: _buildDesktopChatPane(tokens, scheme)),
          ],
        );

      case WorkspaceTab.contacts:
        final selectedPeer = _resolveSelectedContact();
        return Row(
          children: [
            SizedBox(
              width: 292,
              child: ContactsListPane(
                controller: _controller,
                selectedPeerId: selectedPeer?.nodeId,
                highlightSelectedPeer: true,
                onSelectPeer: (peer) =>
                    setState(() => _selectedContactId = peer.nodeId),
                onOpenInviteScan: () =>
                    _openRoomInviteSheet(initialScanTab: true),
                onOpenCreateGroup: () =>
                    showCreateRoomDialog(context, _controller),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: tokens.subtleBorder),
            Expanded(
              child: ContactDetailPane(
                controller: _controller,
                peer: selectedPeer,
                onStartChat: (peer) => _startChatWithPeer(peer, true),
                onEditProfile: (peer, resolvedName) => _openEditProfileDialog(
                  peer.nodeId,
                  resolvedName,
                  raw: peer.displayName,
                ),
                onDeletePeer: (peer, resolvedName) async {
                  final ok = await confirmAndDeletePeer(
                    context: context,
                    controller: _controller,
                    peer: peer,
                    resolvedName: resolvedName,
                  );
                  if (ok && mounted && _selectedContactId == peer.nodeId) {
                    setState(() => _selectedContactId = null);
                  }
                },
                onOpenScanPair: () =>
                    _openRoomInviteSheet(initialScanTab: true),
              ),
            ),
          ],
        );

      case WorkspaceTab.me:
        return MeTabView(
          controller: _controller,
          themeController: widget.themeController,
          dataDir: widget.dataDir,
          myEndpointId: widget.myEndpointId,
          onOpenMyQr: () => _openRoomInviteSheet(
            initialScanTab: false,
            forceDevicePairing: true,
          ),
          onEditSelfProfile: () => _openEditProfileDialog(
            widget.myEndpointId,
            _controller.deviceName,
            raw: _controller.hardwareModelName,
          ),
        );
    }
  }

  Widget _buildDesktopChatPane(AppThemeTokens tokens, ColorScheme scheme) {
    final s = AppLocalizations.of(context);
    final activeRoom = _controller.activeRoom;
    return Column(
      children: [
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: tokens.headerBg,
            border: Border(bottom: BorderSide(color: tokens.subtleBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: activeRoom == null
                    ? Text(
                        s.desktopWorkspaceTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      )
                    : _buildRoomHeaderTitle(context, tokens, scheme),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_rounded, size: 17),
                label: Text(s.btnOpenFolder, style: const TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: tokens.inputFillBg,
                  side: BorderSide(color: tokens.subtleBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: _controller.openAutoReceiveFolder,
              ),
              const SizedBox(width: 6),
              if (activeRoom != null) ...[
                IconButton(
                  tooltip: s.tooltipRoomFiles,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.perm_media_outlined),
                  onPressed: () => showRoomFilesView(
                    context: context,
                    controller: _controller,
                    initialRoomId: activeRoom.roomId,
                  ),
                ),
                IconButton(
                  tooltip: s.tooltipInviteOrScan,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_2),
                  onPressed: () =>
                      _openRoomInviteSheet(initialScanTab: false),
                ),
                IconButton(
                  tooltip: s.tooltipRoomMembers,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.group_outlined),
                  onPressed: () => showRoomMembersDialog(
                    context: context,
                    controller: _controller,
                    myEndpointId: widget.myEndpointId,
                    onOpenInvite: () =>
                        _openRoomInviteSheet(initialScanTab: false),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: activeRoom == null
              ? _buildDesktopEmptyChatState(s, tokens)
              : _buildConversationPane(context, tokens, scheme),
        ),
      ],
    );
  }

  Widget _buildDesktopEmptyChatState(AppStrings s, AppThemeTokens tokens) {
    return Container(
      color: tokens.canvasBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 56,
                color: tokens.accentColor.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 14),
              Text(
                s.desktopEmptyTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                s.desktopEmptySubtitle,
                style: TextStyle(fontSize: 12.5, color: tokens.mutedText),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _openRoomInviteSheet(initialScanTab: true),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: Text(s.btnScanPairDevice),
                  ),
                  OutlinedButton.icon(
                    onPressed: _controller.openAutoReceiveFolder,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: Text(s.menuOpenReceiveFolder),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileShell(AppThemeTokens tokens, ColorScheme scheme) {
    final s = AppLocalizations.of(context);
    final activeTransfers = _countActiveTransfers();
    final tabTitle = switch (_tab) {
      WorkspaceTab.chats => s.navTransfers,
      WorkspaceTab.contacts => s.navDevices,
      WorkspaceTab.me => s.navThisDevice,
    };

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      appBar: AppBar(
        backgroundColor: tokens.canvasBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 62,
        titleSpacing: 20,
        title: Text(
          tabTitle,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: s.tooltipAllFiles,
            icon: const Icon(Icons.folder_outlined, size: 24),
            onPressed: () => showRoomFilesView(
              context: context,
              controller: _controller,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: s.moreActionsTooltip,
            icon: const Icon(Icons.add_rounded, size: 28),
            onSelected: (value) {
              if (value == 'scan') {
                _openRoomInviteSheet(initialScanTab: true);
              } else if (value == 'my_qr') {
                _openRoomInviteSheet(
                  initialScanTab: false,
                  forceDevicePairing: true,
                );
              } else if (value == 'group') {
                showCreateRoomDialog(context, _controller);
              } else if (value == 'folder') {
                _controller.openAutoReceiveFolder();
              } else if (value == 'reconnect') {
                _controller.connectActiveRoom();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'scan',
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 19),
                    const SizedBox(width: 10),
                    Text(s.menuScanPairOrJoin),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'group',
                child: Row(
                  children: [
                    const Icon(Icons.group_add_outlined, size: 19),
                    const SizedBox(width: 10),
                    Text(s.menuCreateGroup),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'my_qr',
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 19),
                    const SizedBox(width: 10),
                    Text(s.menuMyPairingQr),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'folder',
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded, size: 19),
                    const SizedBox(width: 10),
                    Text(s.menuOpenReceiveFolder),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reconnect',
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, size: 19),
                    const SizedBox(width: 10),
                    Text(s.menuProbeReconnect),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _tab.index,
        children: [
          ChatListPane(
            controller: _controller,
            showDesktopHeaderActions: false,
            highlightActiveRoom: false,
            onSelectRoom: (r) => _openRoomOnCurrentDevice(r, false),
            onOpenInviteScan: () =>
                _openRoomInviteSheet(initialScanTab: true),
            onOpenCreateGroup: () =>
                showCreateRoomDialog(context, _controller),
            onSwitchToContacts: () =>
                setState(() => _tab = WorkspaceTab.contacts),
          ),
          ContactsListPane(
            controller: _controller,
            selectedPeerId: null,
            highlightSelectedPeer: false,
            onSelectPeer: (peer) => showMobileContactSheet(
              context: context,
              controller: _controller,
              peer: peer,
              onStartChat: (p) => _startChatWithPeer(p, false),
              onEditProfile: (p, resolvedName) => _openEditProfileDialog(
                p.nodeId,
                resolvedName,
                raw: p.displayName,
              ),
            ),
            onOpenInviteScan: () =>
                _openRoomInviteSheet(initialScanTab: true),
            onOpenCreateGroup: () =>
                showCreateRoomDialog(context, _controller),
          ),
          MeTabView(
            controller: _controller,
            themeController: widget.themeController,
            dataDir: widget.dataDir,
            myEndpointId: widget.myEndpointId,
            isVisible: _tab == WorkspaceTab.me,
            onOpenMyQr: () => _openRoomInviteSheet(
              initialScanTab: false,
              forceDevicePairing: true,
            ),
            onEditSelfProfile: () => _openEditProfileDialog(
              widget.myEndpointId,
              _controller.deviceName,
              raw: _controller.hardwareModelName,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) =>
            setState(() => _tab = WorkspaceTab.values[i]),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeTransfers > 0,
              label: Text('$activeTransfers'),
              child: const Icon(Icons.swap_horiz_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeTransfers > 0,
              label: Text('$activeTransfers'),
              child: const Icon(Icons.swap_horizontal_circle_rounded),
            ),
            label: s.navTransfers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.devices_outlined),
            selectedIcon: const Icon(Icons.devices_rounded),
            label: s.navDevices,
          ),
          NavigationDestination(
            icon: const Icon(Icons.tune_outlined),
            selectedIcon: const Icon(Icons.tune_rounded),
            label: s.navThisDevice,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomHeaderTitle(
    BuildContext dialogContext,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) {
    final s = AppLocalizations.of(dialogContext);
    final activeRoom = _controller.activeRoom;
    if (activeRoom == null) {
      return Text(s.fallbackShortTitle, style: const TextStyle(fontSize: 16));
    }

    final isDm = activeRoom.roomType == 'dm';
    final roomTitle = _controller.resolveRoomTitle(activeRoom);
    final dmPeerId = _controller.resolveDmPeerId(activeRoom);
    final tColor = transportColor(_controller.roomTransport);
    final groupSummary =
        isDm ? null : _controller.getRoomOnlineSummary(activeRoom);
    final statusSubtitle = isDm
        ? transportLabel(_controller.roomTransport, s)
        : (groupSummary!.hasOnlinePeer
            ? s.groupOnlineCount(groupSummary.online, groupSummary.total)
            : s.groupOfflineCount(groupSummary.total));
    final dotColor = isDm
        ? tColor
        : (groupSummary!.hasOnlinePeer
            ? const Color(0xFF16A34A)
            : transportColor('offline'));
    final subtitleOnline =
        isDm ? _controller.isRoomOnline : groupSummary!.hasOnlinePeer;

    return InkWell(
      onTap: () => showRoomMembersDialog(
        context: dialogContext,
        controller: _controller,
        myEndpointId: widget.myEndpointId,
        onOpenInvite: () => _openRoomInviteSheet(initialScanTab: false),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            RoomAvatar(
              room: activeRoom,
              size: 34,
              peerAvatarPath: dmPeerId != null
                  ? _controller.resolveMemberAvatarPath(dmPeerId)
                  : null,
              peerFallbackText: dmPeerId != null
                  ? _controller.resolveMemberAvatar(
                      dmPeerId,
                      fallbackName: roomTitle,
                    )
                  : null,
              peerDeviceKind: dmPeerId != null
                  ? _controller.resolveMemberDeviceKind(
                      dmPeerId,
                      fallbackName: roomTitle,
                    )
                  : null,
              peerAccentColor:
                  dmPeerId != null ? senderAccentColor(dmPeerId) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    roomTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          statusSubtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtitleOnline ? dotColor : tokens.mutedText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationPane(
    BuildContext viewContext,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (Platform.isWindows || Platform.isLinux)
          const SingleActivator(LogicalKeyboardKey.keyV, control: true):
              _handleClipboardPaste,
        if (Platform.isMacOS)
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
              _handleClipboardPaste,
      },
      child: Column(
        children: [
          Expanded(child: _buildDropTimelineZone(viewContext, tokens, scheme)),
          ChatInputBar(
            controller: _msgController,
            hasRoom: _controller.activeRoom != null,
            onSend: _sendTextMessage,
            onPickFiles: _pickAndSendFiles,
            onPickGallery: Platform.isAndroid ? _pickAndSendGalleryImages : null,
            onPasteClipboard: _handleClipboardPaste,
          ),
        ],
      ),
    );
  }

  Widget _buildDropTimelineZone(
    BuildContext viewContext,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) {
    final s = AppLocalizations.of(viewContext);
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        final paths = details.files.map((x) => x.path).toList();
        await _previewAndSendFiles(paths);
      },
      child: Stack(
        children: [
          Container(
            color: tokens.canvasBg,
            child: _controller.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 46,
                            color: tokens.accentColor.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _controller.activeRoom == null
                                ? s.emptyRoomNoSession
                                : s.emptyRoomE2eeNotice,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: tokens.mutedText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            Platform.isWindows
                                ? s.emptyRoomWindowsHint
                                : s.emptyRoomMobileHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.mutedText.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildTimelineList(viewContext, tokens),
          ),
          if (_isDragging)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.file_upload_outlined,
                        size: 50,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.dropZonePrompt(
                          _controller.activeRoom != null
                              ? _controller.resolveRoomTitle(
                                  _controller.activeRoom!,
                                )
                              : '',
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineList(BuildContext viewContext, AppThemeTokens tokens) {
    final roomId = _controller.activeRoom?.roomId ?? '';
    return ChatTimelineView(
      key: ValueKey('timeline_$roomId'),
      roomId: roomId,
      messages: _controller.messages,
      scrollToBottomRequestId: _scrollToBottomRequestId,
      itemBuilder: (context, msg, showDateChip) {
        return Column(
          children: [
            if (showDateChip)
              _buildDateSeparator(context, msg.createdAtMs, tokens),
            MessageBubble(
              msg: msg,
              myEndpointId: widget.myEndpointId,
              controller: _controller,
              onEditMemberProfile: (nodeId, displayName) {
                final targetId = nodeId.isNotEmpty
                    ? nodeId
                    : (_controller.activeRoom != null
                            ? _controller.resolveDmPeerId(
                                _controller.activeRoom!,
                              )
                            : null) ??
                        '';
                if (targetId.isEmpty) return;
                _openEditProfileDialog(targetId, displayName);
              },
              onOpenImagePreview: (path, name) => showImagePreviewDialog(
                viewContext,
                path,
                name,
                onForward: () =>
                    showForwardMessageDialog(viewContext, _controller, msg),
                onDeleteRecord: () => showDeleteMessageConfirmDialog(
                  viewContext,
                  _controller,
                  msg,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(
    BuildContext context,
    int createdAtMs,
    AppThemeTokens tokens,
  ) {
    final s = AppLocalizations.of(context);
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    final label = diff == 0
        ? s.todayLabel
        : diff == 1
            ? s.yesterdayLabel
            : s.formatMonthDay(dt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.dateChipBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: tokens.dateChipText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen pushed conversation route used on narrow mobile layouts when
/// tapping a room from the 「聊天」 list.
class _MobileConversationPage extends StatefulWidget {
  final AppWorkspaceController controller;
  final String myEndpointId;
  final Widget Function(
    BuildContext context,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) buildHeaderTitle;
  final Widget Function(
    BuildContext context,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) buildConversationBody;
  final VoidCallback onOpenInviteSheet;

  const _MobileConversationPage({
    required this.controller,
    required this.myEndpointId,
    required this.buildHeaderTitle,
    required this.buildConversationBody,
    required this.onOpenInviteSheet,
  });

  @override
  State<_MobileConversationPage> createState() =>
      _MobileConversationPageState();
}

class _MobileConversationPageState extends State<_MobileConversationPage> {
  bool _popping = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final activeRoom = widget.controller.activeRoom;
        if (activeRoom == null && !_popping) {
          _popping = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        }

        final s = AppLocalizations.of(context);
        return Scaffold(
          backgroundColor: tokens.canvasBg,
          appBar: AppBar(
            backgroundColor: tokens.headerBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: tokens.subtleBorder),
            ),
            titleSpacing: 0,
            title: widget.buildHeaderTitle(context, tokens, scheme),
            actions: [
              IconButton(
                tooltip: s.tooltipRoomFiles,
                icon: const Icon(Icons.perm_media_outlined),
                onPressed: activeRoom == null
                    ? null
                    : () => showRoomFilesView(
                          context: context,
                          controller: widget.controller,
                          initialRoomId: activeRoom.roomId,
                        ),
              ),
              if (activeRoom != null)
                PopupMenuButton<String>(
                  tooltip: s.moreTooltip,
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    switch (value) {
                      case 'invite_contacts':
                        showInviteContactsToActiveGroupDialog(
                          context,
                          widget.controller,
                        );
                      case 'start_group':
                        final dmPeerId =
                            widget.controller.resolveDmPeerId(activeRoom);
                        showCreateRoomDialog(
                          context,
                          widget.controller,
                          initialSelectedIds:
                              dmPeerId != null ? {dmPeerId} : null,
                        );
                      case 'members':
                        showRoomMembersDialog(
                          context: context,
                          controller: widget.controller,
                          myEndpointId: widget.myEndpointId,
                          onOpenInvite: widget.onOpenInviteSheet,
                        );
                      case 'open_folder':
                        widget.controller.openAutoReceiveFolder();
                    }
                  },
                  itemBuilder: (menuContext) {
                    final isDm = activeRoom.roomType == 'dm';
                    return [
                      if (!isDm)
                        PopupMenuItem<String>(
                          value: 'invite_contacts',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                            title: Text(s.menuAddPairedToGroup),
                          ),
                        )
                      else
                        PopupMenuItem<String>(
                          value: 'start_group',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.group_add_outlined, size: 20),
                            title: Text(s.btnNewSharedGroup),
                          ),
                        ),
                      PopupMenuItem<String>(
                        value: 'members',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.group_outlined, size: 20),
                          title: Text(
                            isDm
                                ? s.menuDeviceDetailsAndRemark
                                : s.menuGroupMembersAndManage,
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'open_folder',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_open_rounded, size: 20),
                          title: Text(s.menuOpenReceiveFolder),
                        ),
                      ),
                    ];
                  },
                ),
            ],
          ),
          body: widget.buildConversationBody(context, tokens, scheme),
        );
      },
    );
  }
}
