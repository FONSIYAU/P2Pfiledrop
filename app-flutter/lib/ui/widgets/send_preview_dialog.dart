import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../services/platform_bridge.dart';
import '../theme/app_theme_tokens.dart';
import 'room_avatar.dart';

/// Maximum number of files/images allowed in a single batch send.
const int kMaxBatchSendFiles = 50;

/// Shows a WhatsApp-style pre-send preview & confirmation UI before sending
/// selected/dropped/pasted files or images. Returns the confirmed paths, or
/// `null` if cancelled.
Future<List<String>?> showSendPreviewDialog({
  required BuildContext context,
  required List<String> initialPaths,
  FileType pickerType = FileType.any,
}) {
  final seen = <String>{};
  final deduped = <String>[];
  for (final p in initialPaths) {
    final trimmed = p.trim();
    if (trimmed.isNotEmpty && seen.add(trimmed)) {
      deduped.add(trimmed);
    }
  }
  if (deduped.isEmpty) return Future.value(null);

  final truncated = deduped.length > kMaxBatchSendFiles;
  final capped = truncated ? deduped.sublist(0, kMaxBatchSendFiles) : deduped;

  final isWide = MediaQuery.sizeOf(context).width >= 780;
  if (isWide) {
    return showDialog<List<String>>(
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
            width: (size.width * 0.56).clamp(480.0, 680.0),
            height: (size.height * 0.78).clamp(420.0, 680.0),
            child: _SendPreviewBody(
              initialPaths: capped,
              wasTruncated: truncated,
              isDialog: true,
              pickerType: pickerType,
            ),
          ),
        );
      },
    );
  }

  return Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      builder: (_) => _SendPreviewBody(
        initialPaths: capped,
        wasTruncated: truncated,
        isDialog: false,
        pickerType: pickerType,
      ),
    ),
  );
}

class _QueuedSendItem {
  final String path;
  final String name;
  final int sizeBytes;
  final bool isImage;

  const _QueuedSendItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.isImage,
  });

  factory _QueuedSendItem.fromPath(String path) {
    final file = File(path);
    final name = path.split(RegExp(r'[/\\]')).last;
    var size = 0;
    try {
      if (file.existsSync()) {
        size = file.lengthSync();
      }
    } catch (_) {}
    return _QueuedSendItem(
      path: path,
      name: name.isEmpty ? path : name,
      sizeBytes: size,
      isImage: isImageFileName(name),
    );
  }
}

class _SendPreviewBody extends StatefulWidget {
  final List<String> initialPaths;
  final bool wasTruncated;
  final bool isDialog;
  final FileType pickerType;

  const _SendPreviewBody({
    required this.initialPaths,
    required this.wasTruncated,
    required this.isDialog,
    required this.pickerType,
  });

  @override
  State<_SendPreviewBody> createState() => _SendPreviewBodyState();
}

class _SendPreviewBodyState extends State<_SendPreviewBody> {
  late List<_QueuedSendItem> _items;
  late final PageController _pageController;
  int _selectedIndex = 0;
  bool _truncatedNotice = false;
  bool _isPickingMore = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialPaths.map(_QueuedSendItem.fromPath).toList();
    _pageController = PageController(initialPage: 0);
    _truncatedNotice = widget.wasTruncated;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _allImages => _items.isNotEmpty && _items.every((e) => e.isImage);

  int get _totalBytes => _items.fold<int>(0, (sum, e) => sum + e.sizeBytes);

  void _selectPage(int index) {
    if (index < 0 || index >= _items.length) return;
    setState(() => _selectedIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _removeAt(int index) {
    setState(() {
      _items.removeAt(index);
      if (_selectedIndex >= _items.length) {
        _selectedIndex = _items.isEmpty ? 0 : _items.length - 1;
      }
    });
    if (_items.isEmpty) {
      Navigator.of(context).pop(null);
      return;
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_selectedIndex);
    }
  }

  Future<void> _addMoreFiles() async {
    if (_isPickingMore) return;
    final remaining = kMaxBatchSendFiles - _items.length;
    if (remaining <= 0) return;

    _isPickingMore = true;
    try {
      final List<String> pickedPaths;
      if (Platform.isAndroid && widget.pickerType == FileType.image) {
        pickedPaths = await PlatformBridge.pickGalleryImages(
          maxItems: remaining,
        );
      } else {
        final res = await FilePicker.platform.pickFiles(
          type: widget.pickerType,
          allowMultiple: true,
        );
        pickedPaths =
            res?.files.map((f) => f.path).whereType<String>().toList() ??
                const <String>[];
      }
      if (pickedPaths.isEmpty || !mounted) return;

      final existing = _items.map((e) => e.path).toSet();
      final added = <_QueuedSendItem>[];
      var hitCap = false;
      for (final rawPath in pickedPaths) {
        final path = rawPath.trim();
        if (path.isEmpty || !existing.add(path)) continue;
        if (_items.length + added.length >= kMaxBatchSendFiles) {
          hitCap = true;
          break;
        }
        added.add(_QueuedSendItem.fromPath(path));
      }

      if (added.isNotEmpty || hitCap) {
        setState(() {
          _items.addAll(added);
          if (hitCap) _truncatedNotice = true;
        });
      }
    } finally {
      _isPickingMore = false;
    }
  }

  void _confirmSend() {
    if (_items.isEmpty) return;
    Navigator.of(context).pop(_items.map((e) => e.path).toList());
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final current = _items.isNotEmpty ? _items[_selectedIndex] : null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _confirmSend,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(null),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (_allImages && _selectedIndex > 0) {
            _selectPage(_selectedIndex - 1);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (_allImages && _selectedIndex < _items.length - 1) {
            _selectPage(_selectedIndex + 1);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: _allImages ? const Color(0xFF101317) : tokens.canvasBg,
          appBar: AppBar(
            backgroundColor:
                _allImages ? const Color(0xFF171B21) : tokens.headerBg,
            foregroundColor: _allImages ? Colors.white : scheme.onSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: s.cancel,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            title: Text(
              _allImages
                  ? s.sendPreviewImageTitle(_selectedIndex + 1, _items.length)
                  : s.sendPreviewFileTitle(_items.length),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (_items.length < kMaxBatchSendFiles)
                TextButton.icon(
                  onPressed: _addMoreFiles,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(s.btnAddMore),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        _allImages ? Colors.white70 : tokens.accentColor,
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              if (_truncatedNotice)
                Container(
                  width: double.infinity,
                  color: Colors.amber.withValues(alpha: 0.16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    s.batchLimitNotice(kMaxBatchSendFiles),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _allImages
                          ? Colors.amber.shade200
                          : Colors.amber.shade900,
                    ),
                  ),
                ),
              Expanded(
                child: _allImages && current != null
                    ? _buildImageStage(s, current)
                    : _buildFileList(s, tokens, scheme),
              ),
              if (_allImages && _items.length > 1) _buildThumbnailStrip(tokens),
              _buildBottomBar(s, tokens, scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageStage(AppStrings s, _QueuedSendItem item) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _items.length,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          itemBuilder: (context, index) {
            final pageItem = _items[index];
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.file(
                  File(pageItem.path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.isDialog && _items.length > 1 && _selectedIndex > 0)
          Positioned(
            left: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: s.tooltipPrevImage,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _selectPage(_selectedIndex - 1),
              ),
            ),
          ),
        if (widget.isDialog &&
            _items.length > 1 &&
            _selectedIndex < _items.length - 1)
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: s.tooltipNextImage,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _selectPage(_selectedIndex + 1),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 10,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${item.name} · ${_formatBytes(item.sizeBytes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailStrip(AppThemeTokens tokens) {
    return Container(
      height: 76,
      color: const Color(0xFF171B21),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          final selected = index == _selectedIndex;
          return GestureDetector(
            onTap: () => _selectPage(index),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? tokens.accentColor : Colors.white24,
                      width: selected ? 2.2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(
                    File(item.path),
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 22,
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: GestureDetector(
                    onTap: () => _removeAt(index),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileList(AppStrings s, AppThemeTokens tokens, ColorScheme scheme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 68, color: tokens.subtleBorder),
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          leading: item.isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(item.path),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    cacheWidth: 140,
                    errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
                  ),
                )
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tokens.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.insert_drive_file_rounded,
                    color: tokens.accentColor,
                    size: 22,
                  ),
                ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            _formatBytes(item.sizeBytes),
            style: TextStyle(fontSize: 12, color: tokens.mutedText),
          ),
          trailing: IconButton(
            tooltip: s.remove,
            icon: Icon(Icons.close_rounded, size: 19, color: tokens.mutedText),
            onPressed: () => _removeAt(index),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(AppStrings s, AppThemeTokens tokens, ColorScheme scheme) {
    final bg = _allImages ? const Color(0xFF171B21) : tokens.headerBg;
    final textColor = _allImages ? Colors.white70 : tokens.mutedText;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(
              color: _allImages ? Colors.white12 : tokens.subtleBorder,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                s.sendPreviewFooter(
                  _items.length,
                  _formatBytes(_totalBytes),
                  widget.isDialog,
                ),
                style: TextStyle(fontSize: 12.5, color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _confirmSend,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: Text(s.btnSendCount(_items.length)),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accentColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      ),
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
}
