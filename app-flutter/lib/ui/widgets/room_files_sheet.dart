import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';

import '../../controllers/app_workspace_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/platform_bridge.dart';
import '../../src/rust/api.dart';
import '../theme/app_theme_tokens.dart';
import 'chat_dialogs.dart';
import 'room_avatar.dart';

/// Opens the shared file/media browser as a side sheet on wide screens
/// or a full-screen page on mobile.
Future<void> showRoomFilesView({
  required BuildContext context,
  required AppWorkspaceController controller,
  String? initialRoomId,
}) {
  final isWide = MediaQuery.sizeOf(context).width >= 820;
  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: (size.width * 0.62).clamp(520.0, 760.0),
            height: (size.height * 0.84).clamp(460.0, 780.0),
            child: RoomFilesView(
              controller: controller,
              initialRoomId: initialRoomId,
              isDialog: true,
            ),
          ),
        );
      },
    );
  }

  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RoomFilesView(
        controller: controller,
        initialRoomId: initialRoomId,
        isDialog: false,
      ),
    ),
  );
}

/// Unified WhatsApp/WeChat-style media & file browser backed by local SQLite.
class RoomFilesView extends StatefulWidget {
  final AppWorkspaceController controller;
  final String? initialRoomId;
  final bool isDialog;

  const RoomFilesView({
    super.key,
    required this.controller,
    this.initialRoomId,
    this.isDialog = false,
  });

  @override
  State<RoomFilesView> createState() => _RoomFilesViewState();
}

class _RoomFilesViewState extends State<RoomFilesView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String? _selectedRoomId;
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  List<MessageDto> _allFiles = const [];
  final Map<String, bool> _existsCache = {};

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.initialRoomId;
    _tabController = TabController(length: 2, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await listRoomFiles(roomId: _selectedRoomId, limit: 600);
      final exists = <String, bool>{};
      for (final msg in rows) {
        final path = msg.localPath?.trim();
        if (path != null && path.isNotEmpty) {
          exists[path] = File(path).existsSync();
        }
      }
      if (!mounted) return;
      setState(() {
        _allFiles = rows;
        _existsCache
          ..clear()
          ..addAll(exists);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  bool _fileExists(MessageDto msg) {
    final path = msg.localPath?.trim();
    if (path == null || path.isEmpty) return false;
    return _existsCache[path] ?? false;
  }

  List<MessageDto> _filteredMessages({required bool imagesOnly}) {
    final query = _searchQuery.trim().toLowerCase();
    return _allFiles.where((msg) {
      final name = (msg.fileName ?? '').trim();
      final isImg = isImageFileName(name);
      if (imagesOnly != isImg) return false;
      if (query.isEmpty) return true;
      return name.toLowerCase().contains(query);
    }).toList();
  }

  List<_MonthGroup> _groupByMonth(List<MessageDto> items) {
    final groups = <String, List<MessageDto>>{};
    for (final item in items) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        item.createdAtMs.toInt(),
      ).toLocal();
      final key = DateFormat('yyyy-MM').format(dt);
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups.entries
        .map((e) => _MonthGroup(monthKey: e.key, items: e.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final rooms = widget.controller.rooms;
    final images = _filteredMessages(imagesOnly: true);
    final docs = _filteredMessages(imagesOnly: false);

    final activeRoomTitle = _selectedRoomId == null
        ? s.allFilesTitle
        : rooms
                .where((r) => r.roomId == _selectedRoomId)
                .map(widget.controller.resolveRoomTitle)
                .firstOrNull ??
            s.roomFilesTitle;

    return Scaffold(
      backgroundColor: tokens.canvasBg,
      appBar: AppBar(
        backgroundColor: tokens.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.isDialog,
        title: Text(
          activeRoomTitle,
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: s.tooltipOpenMainReceiveFolder,
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: widget.controller.openAutoReceiveFolder,
          ),
          IconButton(
            tooltip: s.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadFiles,
          ),
          if (widget.isDialog)
            IconButton(
              tooltip: s.close,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: const TextStyle(fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: s.searchFileNameHint,
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: tokens.mutedText,
                            ),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedRoomId != null &&
                                  rooms.any((r) => r.roomId == _selectedRoomId)
                              ? _selectedRoomId
                              : null,
                          isDense: true,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurface,
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(s.allRoomsOption),
                            ),
                            ...rooms.map(
                              (r) => DropdownMenuItem<String?>(
                                value: r.roomId,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 135),
                                  child: Text(
                                    widget.controller.resolveRoomTitle(r),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (nextRoomId) {
                            setState(() => _selectedRoomId = nextRoomId);
                            _loadFiles();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: tokens.accentColor,
                unselectedLabelColor: tokens.mutedText,
                indicatorColor: tokens.accentColor,
                tabs: [
                  Tab(text: s.tabImagesCount(images.length)),
                  Tab(text: s.tabFilesCount(docs.length)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.loadFilesFailed(_error!),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildImageTab(s, images, tokens, scheme),
                    _buildDocTab(s, docs, tokens, scheme),
                  ],
                ),
    );
  }

  Widget _buildImageTab(
    AppStrings s,
    List<MessageDto> images,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) {
    if (images.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        label: _searchQuery.isEmpty ? s.emptyImagesNone : s.emptyImagesSearch,
        tokens: tokens,
      );
    }

    final groups = _groupByMonth(images);
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final crossAxisCount = isWide ? 4 : 3;

    return CustomScrollView(
      slivers: [
        for (final group in groups) ...[
          SliverToBoxAdapter(
            child: _MonthHeader(
              monthKey: group.monthKey,
              count: group.items.length,
              tokens: tokens,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildImageTile(s, group.items[index], tokens, scheme),
                childCount: group.items.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _buildImageTile(
    AppStrings s,
    MessageDto msg,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) {
    final path = msg.localPath?.trim();
    final name = msg.fileName ?? 'image';
    final exists = _fileExists(msg);

    return GestureDetector(
      onTap: () => showImagePreviewDialog(
        context,
        path ?? '',
        name,
        onForward: exists
            ? () => showForwardMessageDialog(
                  context,
                  widget.controller,
                  msg,
                )
            : null,
        onDeleteRecord: () async {
          await showDeleteMessageConfirmDialog(
            context,
            widget.controller,
            msg,
          );
          if (mounted) await _loadFiles();
        },
      ),
      onLongPress: () => _showMessageActions(msg),
      onSecondaryTapDown: (details) =>
          _showContextMenuAt(details.globalPosition, msg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (exists && path != null)
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  errorBuilder: (_, _, _) => _missingThumb(tokens),
                )
              else
                _missingThumb(tokens),
              if (!exists)
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.badgeLocallyRemoved,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missingThumb(AppThemeTokens tokens) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 26,
        color: tokens.mutedText,
      ),
    );
  }

  Widget _buildDocTab(
    AppStrings s,
    List<MessageDto> docs,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) {
    if (docs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.insert_drive_file_outlined,
        label: _searchQuery.isEmpty ? s.emptyFilesNone : s.emptyFilesSearch,
        tokens: tokens,
      );
    }

    final groups = _groupByMonth(docs);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: groups.fold<int>(0, (sum, g) => sum + 1 + g.items.length),
      itemBuilder: (context, index) {
        var cursor = index;
        for (final group in groups) {
          if (cursor == 0) {
            return _MonthHeader(
              monthKey: group.monthKey,
              count: group.items.length,
              tokens: tokens,
            );
          }
          cursor -= 1;
          if (cursor < group.items.length) {
            return _buildDocRow(s, group.items[cursor], tokens, scheme);
          }
          cursor -= group.items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDocRow(
    AppStrings s,
    MessageDto msg,
    AppThemeTokens tokens,
    ColorScheme scheme,
  ) {
    final name = msg.fileName ?? s.unnamedFile;
    final path = msg.localPath?.trim();
    final exists = _fileExists(msg);
    final sizeText = _formatBytes(msg.fileSize?.toInt() ?? 0);
    final dt = DateTime.fromMillisecondsSinceEpoch(
      msg.createdAtMs.toInt(),
    ).toLocal();
    final dateText = DateFormat('MM-dd HH:mm').format(dt);
    final senderLabel = msg.isOutgoing
        ? widget.controller.deviceName
        : widget.controller.resolveMemberDisplayName(
            msg.senderId.isNotEmpty ? msg.senderId : msg.peerId,
          );
    final roomLabel = _selectedRoomId == null
        ? widget.controller.rooms
            .where((r) => r.roomId == msg.roomId)
            .map(widget.controller.resolveRoomTitle)
            .firstOrNull
        : null;

    final badgeColor = _extensionColor(name);
    final ext = _extensionLabel(name);

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenuAt(details.globalPosition, msg),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: exists ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            ext,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: exists ? badgeColor : tokens.mutedText,
            ),
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: exists ? scheme.onSurface : tokens.mutedText,
          ),
        ),
        subtitle: Text(
          [
            sizeText,
            senderLabel,
            if (roomLabel != null && roomLabel.isNotEmpty) roomLabel,
            dateText,
            if (!exists) s.badgeLocallyRemoved,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: tokens.mutedText),
        ),
        onTap: exists && path != null
            ? () => OpenFilex.open(path)
            : () => _showSnack(s.toastLocalFileMissing),
        trailing: IconButton(
          icon: Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: tokens.mutedText,
          ),
          onPressed: () => _showMessageActions(msg),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String label,
    required AppThemeTokens tokens,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: tokens.mutedText.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: tokens.mutedText),
          ),
        ],
      ),
    );
  }

  Future<void> _showContextMenuAt(Offset globalPos, MessageDto msg) async {
    final s = AppLocalizations.of(context);
    final path = msg.localPath?.trim();
    final exists = _fileExists(msg);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPos & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        if (exists && path != null)
          PopupMenuItem(value: 'open', child: Text(s.actionOpenShort)),
        if (exists && path != null)
          PopupMenuItem(value: 'reveal', child: Text(s.actionRevealInFolder)),
        if (exists && path != null)
          PopupMenuItem(value: 'forward', child: Text(s.actionForward)),
        if (path != null && path.isNotEmpty)
          PopupMenuItem(value: 'copy_path', child: Text(s.actionCopyFilePath)),
        PopupMenuItem(
          value: 'delete',
          child: Text(s.delete, style: const TextStyle(color: Color(0xFFD93025))),
        ),
      ],
    );
    if (!mounted || selected == null) return;
    await _handleAction(selected, msg);
  }

  Future<void> _showMessageActions(MessageDto msg) async {
    final s = AppLocalizations.of(context);
    final path = msg.localPath?.trim();
    final exists = _fileExists(msg);
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exists && path != null)
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text(s.actionOpenShort),
                onTap: () => Navigator.pop(sheetContext, 'open'),
              ),
            if (exists && path != null)
              ListTile(
                leading: const Icon(Icons.folder_open_rounded),
                title: Text(s.actionRevealInFolder),
                onTap: () => Navigator.pop(sheetContext, 'reveal'),
              ),
            if (exists && path != null)
              ListTile(
                leading: const Icon(Icons.forward_rounded),
                title: Text(s.actionForward),
                onTap: () => Navigator.pop(sheetContext, 'forward'),
              ),
            if (path != null && path.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(s.actionCopyFilePath),
                onTap: () => Navigator.pop(sheetContext, 'copy_path'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFD93025),
              ),
              title: Text(
                s.delete,
                style: const TextStyle(color: Color(0xFFD93025)),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await _handleAction(selected, msg);
  }

  Future<void> _handleAction(String action, MessageDto msg) async {
    final s = AppLocalizations.of(context);
    final path = msg.localPath?.trim();
    switch (action) {
      case 'open':
        if (path != null) await OpenFilex.open(path);
      case 'reveal':
        if (path != null) {
          final ok = await PlatformBridge.revealFileInFolder(path);
          if (!ok && mounted) {
            _showSnack(s.toastReceiveDirFallback(File(path).parent.path));
          }
        }
      case 'forward':
        await showForwardMessageDialog(context, widget.controller, msg);
      case 'copy_path':
        if (path != null) {
          await Clipboard.setData(ClipboardData(text: path));
          _showSnack(s.toastCopiedPath(path));
        }
      case 'delete':
        await showDeleteMessageConfirmDialog(context, widget.controller, msg);
        if (mounted) await _loadFiles();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIdx = 0;
    while (value >= 1024 && unitIdx < units.length - 1) {
      value /= 1024;
      unitIdx++;
    }
    return unitIdx == 0
        ? '${value.toInt()} B'
        : '${value.toStringAsFixed(1)} ${units[unitIdx]}';
  }

  String _extensionLabel(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'FILE';
    final ext = name.substring(dot + 1).toUpperCase();
    return ext.length > 4 ? ext.substring(0, 4) : ext;
  }

  Color _extensionColor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return const Color(0xFFDC2626);
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z')) {
      return const Color(0xFFD97706);
    }
    if (lower.endsWith('.apk') || lower.endsWith('.exe')) {
      return const Color(0xFF059669);
    }
    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.md')) {
      return const Color(0xFF2563EB);
    }
    return const Color(0xFF64748B);
  }
}

class _MonthGroup {
  final String monthKey;
  final List<MessageDto> items;

  const _MonthGroup({required this.monthKey, required this.items});
}

class _MonthHeader extends StatelessWidget {
  final String monthKey;
  final int count;
  final AppThemeTokens tokens;

  const _MonthHeader({
    required this.monthKey,
    required this.count,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Row(
        children: [
          Text(
            monthKey,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.mutedText,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: tokens.mutedText.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
