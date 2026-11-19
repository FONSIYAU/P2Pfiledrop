import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_version.dart';
import '../../controllers/app_workspace_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/platform_bridge.dart';
import '../../src/rust/api.dart';
import '../theme/app_theme_tokens.dart';
import 'room_avatar.dart';

/// Unified 「我的」 profile, storage shortcut, desktop residency, theme, and
/// network diagnostics page (replaces nested settings dialogs).
class MeTabView extends StatefulWidget {
  final AppWorkspaceController controller;
  final AppThemeController themeController;
  final Directory dataDir;
  final String myEndpointId;
  final bool isVisible;
  final VoidCallback onOpenMyQr;
  final VoidCallback onEditSelfProfile;

  const MeTabView({
    super.key,
    required this.controller,
    required this.themeController,
    required this.dataDir,
    required this.myEndpointId,
    this.isVisible = true,
    required this.onOpenMyQr,
    required this.onEditSelfProfile,
  });

  @override
  State<MeTabView> createState() => _MeTabViewState();
}

class _MeTabViewState extends State<MeTabView> {
  final TextEditingController _relayCtrl = TextEditingController();
  List<String> _nics = const [];
  Directory? _defaultDir;
  bool _legacyStorageGranted = true;
  bool _loadingDiag = true;
  bool _storageExpanded = false;
  bool _networkDiagExpanded = false;
  String? _saveDirError;
  int? _receiveFolderBytes;
  int _receiveFolderCount = 0;
  int _thumbCacheBytes = 0;
  bool _loadingStorageStats = false;
  String? _lastScannedSaveDir;
  int _lastScannedFileVersion = -1;
  bool _wasControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    _wasControllerInitialized = widget.controller.initialized;
    widget.controller.addListener(_onControllerChanged);
    _loadInfo();
  }

  @override
  void didUpdateWidget(covariant MeTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastScannedSaveDir = null;
      _lastScannedFileVersion = -1;
      _wasControllerInitialized = widget.controller.initialized;
      unawaited(_refreshStorageStats());
    } else if (!oldWidget.isVisible && widget.isVisible) {
      unawaited(_refreshStorageStats());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _relayCtrl.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final ctrl = widget.controller;
    final initializedNow = ctrl.initialized;
    final saveDir = ctrl.effectiveDisplaySaveDir;
    final fileVer = ctrl.filePresenceVersion;

    final changed = initializedNow != _wasControllerInitialized ||
        saveDir != _lastScannedSaveDir ||
        fileVer != _lastScannedFileVersion;
    if (!changed) return;

    _wasControllerInitialized = initializedNow;
    if (widget.isVisible || (initializedNow && saveDir != _lastScannedSaveDir)) {
      unawaited(_refreshStorageStats());
    }
  }

  Future<void> _loadInfo() async {
    if (mounted) setState(() => _loadingDiag = true);
    final results = await Future.wait([
      listPhysicalLanInterfaces(),
      PlatformBridge.loadCustomRelayUrl(widget.dataDir),
      PlatformBridge.getDefaultAutoReceiveDirectory(),
      PlatformBridge.hasLegacyStoragePermission(),
    ]);
    await widget.controller.refreshUsbAndRouteStatus();
    if (!mounted) return;
    setState(() {
      _nics = results[0] as List<String>;
      _relayCtrl.text = (results[1] as String?) ?? '';
      _defaultDir = results[2] as Directory;
      _legacyStorageGranted = results[3] as bool;
      _loadingDiag = false;
    });
    unawaited(_refreshStorageStats());
  }

  Future<({int bytes, int count})> _scanDirStats(Directory dir) async {
    if (!dir.existsSync()) return (bytes: 0, count: 0);
    var bytes = 0;
    var count = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            bytes += await entity.length();
            count++;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return (bytes: bytes, count: count);
  }

  Future<void> _refreshStorageStats() async {
    if (_loadingStorageStats || !mounted) return;
    setState(() => _loadingStorageStats = true);
    try {
      final recvPath = widget.controller.effectiveDisplaySaveDir;
      _wasControllerInitialized = widget.controller.initialized;
      _lastScannedSaveDir = recvPath;
      _lastScannedFileVersion = widget.controller.filePresenceVersion;
      final thumbsDir =
          Directory('${widget.dataDir.path}${Platform.pathSeparator}thumbs');
      final results = await Future.wait([
        _scanDirStats(Directory(recvPath)),
        _scanDirStats(thumbsDir),
      ]);
      if (!mounted) return;
      setState(() {
        _receiveFolderBytes = results[0].bytes;
        _receiveFolderCount = results[0].count;
        _thumbCacheBytes = results[1].bytes;
      });
    } finally {
      if (mounted) setState(() => _loadingStorageStats = false);
    }
  }

  Future<void> _clearThumbnailCache() async {
    await widget.controller.clearThumbnailCache();
    await _refreshStorageStats();
    if (mounted) {
      final s = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.toastThumbCacheCleared)),
      );
    }
  }

  Future<void> _applySaveDir(String? targetDir) async {
    final s = AppLocalizations.of(context);
    setState(() => _saveDirError = null);
    try {
      await widget.controller.updateCustomSaveDir(targetDir);
      unawaited(_refreshStorageStats());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.toastSaveDirUpdated(widget.controller.effectiveDisplaySaveDir),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saveDirError = s.saveDirNotWritable(e);
      });
    }
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String title,
    AppThemeTokens tokens,
  ) {
    if (tokens.isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSettingIcon(
    BuildContext context,
    AppThemeTokens tokens,
    IconData icon, {
    required Color lightBg,
    required Color lightFg,
    required Color darkBg,
    required Color darkFg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (tokens.isDesktop) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? darkBg : lightBg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: isDark ? darkFg : lightFg,
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? darkBg : lightBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 19,
        color: isDark ? darkFg : lightFg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final hasNick = controller.deviceName != controller.hardwareModelName;

    return Container(
      color: tokens.canvasBg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: ListView(
            padding: tokens.isDesktop
                ? const EdgeInsets.fromLTRB(16, 14, 16, 28)
                : const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _buildProfileCard(s, tokens, scheme, controller, hasNick),
              _buildSectionLabel(context, s.sectionGeneral, tokens),
              _buildGeneralCard(s, tokens),
              _buildSectionLabel(context, s.sectionReceiveStorage, tokens),
              if (tokens.isDesktop) ...[
                _buildStorageCard(s, tokens, scheme, controller),
                const SizedBox(height: 8),
                _buildCacheCard(s, tokens, scheme, controller),
              ] else
                _buildMobileStorageGroupCard(s, tokens, scheme, controller),
              _buildSectionLabel(context, s.sectionResidencyNetwork, tokens),
              if (Platform.isWindows) ...[
                _buildWindowsResidencyCard(s, tokens, controller),
                const SizedBox(height: 8),
              ],
              _buildNetworkDiagnosticsCard(s, tokens, controller),
              _buildSectionLabel(context, s.sectionAbout, tokens),
              _buildAboutCard(s, tokens),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyFullDeviceId(AppStrings s) async {
    await Clipboard.setData(ClipboardData(text: widget.myEndpointId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.toastCopiedFullDeviceId)),
    );
  }

  String _formatCompactDeviceId(String id) {
    if (id.length <= 14) return id;
    return '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
  }

  Widget _buildProfileCard(
    AppStrings s,
    AppThemeTokens tokens,
    ColorScheme scheme,
    AppWorkspaceController controller,
    bool hasNick,
  ) {
    final compactId = _formatCompactDeviceId(widget.myEndpointId);

    final cardContent = Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        tokens.isDesktop ? 10 : 12,
        14,
      ),
      child: Row(
        children: [
          if (tokens.isDesktop)
            InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: widget.onEditSelfProfile,
              child: DeviceAvatar(
                radius: 26,
                fallbackText: controller.effectiveSelfAvatar,
                deviceKind: controller.selfDeviceKind,
                imagePath: controller.myAvatarPath,
                accentColor: tokens.accentColor,
              ),
            )
          else
            DeviceAvatar(
              radius: 26,
              fallbackText: controller.effectiveSelfAvatar,
              deviceKind: controller.selfDeviceKind,
              imagePath: controller.myAvatarPath,
              accentColor: tokens.accentColor,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                if (hasNick)
                  Text(
                    s.deviceModelLabel(controller.hardwareModelName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.mutedText,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'ID · $compactId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: tokens.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (tokens.isDesktop) ...[
            IconButton(
              tooltip: s.menuMyPairingQr,
              onPressed: widget.onOpenMyQr,
              icon: Icon(Icons.qr_code_2_rounded, color: tokens.accentColor),
            ),
            IconButton(
              tooltip: s.tooltipEditNameAvatar,
              onPressed: widget.onEditSelfProfile,
              icon: Icon(Icons.edit_outlined, color: tokens.mutedText),
            ),
          ] else ...[
            _ProfileActionCircle(
              tooltip: s.menuMyPairingQr,
              icon: Icons.qr_code_2_rounded,
              color: tokens.accentColor,
              onTap: widget.onOpenMyQr,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.mutedText.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: tokens.isDesktop
          ? cardContent
          : InkWell(
              onTap: widget.onEditSelfProfile,
              onLongPress: () => _copyFullDeviceId(s),
              child: cardContent,
            ),
    );
  }

  String _formatCompactAndroidPath(String raw) {
    const prefix = '/storage/emulated/0/';
    final normalized = raw.trim().replaceAll('\\', '/');
    if (normalized.startsWith(prefix)) {
      return normalized.substring(prefix.length);
    }
    return normalized;
  }

  Future<void> _pickAndroidCustomFolder(
    AppWorkspaceController controller,
  ) async {
    final s = AppLocalizations.of(context);
    final granted = await PlatformBridge.hasAllFilesPermission();
    if (!granted) {
      if (!mounted) return;
      final goGrant = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.needAllFilesPermTitle),
          content: Text(s.needAllFilesPermBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.btnGoGrant),
            ),
          ],
        ),
      );
      if (goGrant == true) {
        await PlatformBridge.requestAllFilesPermission();
      }
      return;
    }

    final initial = controller.customSaveDir;
    final picked = await FilePicker.platform.getDirectoryPath(
      dialogTitle: s.pickReceiveFolderDialogTitle,
      initialDirectory:
          (initial != null && Directory(initial).existsSync()) ? initial : null,
    );
    if (picked == null || picked.trim().isEmpty || !mounted) return;
    await controller.setAndroidStorageMode('custom', customPath: picked.trim());
  }

  Widget _buildStorageOptionTile({
    required AppThemeTokens tokens,
    required ColorScheme scheme,
    required bool selected,
    required String title,
    required String subtitle,
    String? badge,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final titleColor =
        selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final subColor = selected
        ? scheme.onSecondaryContainer.withValues(alpha: 0.78)
        : scheme.onSurfaceVariant;

    return Material(
      color: selected
          ? scheme.secondaryContainer.withValues(alpha: 0.72)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? scheme.primary.withValues(alpha: 0.14)
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: subColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageCard(
    AppStrings s,
    AppThemeTokens tokens,
    ColorScheme scheme,
    AppWorkspaceController controller,
  ) {
    final saveDir = controller.effectiveDisplaySaveDir;
    final mode = controller.androidStorageMode;
    final customDir = controller.customSaveDir?.trim();
    final hasCustomDir = customDir != null &&
        customDir.isNotEmpty &&
        !customDir.contains('/Android/data/');

    final sizeSuffix = _receiveFolderBytes != null
        ? s.storageSizeSuffix(
            formatBytes(_receiveFolderBytes!),
            _receiveFolderCount,
          )
        : '';
    final String storageSummary;
    if (Platform.isAndroid) {
      final modeBase = switch (mode) {
        'documents' => s.storageModeDocuments,
        'custom' when hasCustomDir =>
          s.storageModeCustom(_formatCompactAndroidPath(customDir)),
        'app_private' => s.storageModeAppPrivate,
        _ => s.storageModeDownloads,
      };
      storageSummary = '$modeBase$sizeSuffix';
    } else {
      storageSummary = '$saveDir$sizeSuffix';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _storageExpanded = !_storageExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  _buildSettingIcon(
                    context,
                    tokens,
                    Icons.folder_outlined,
                    lightBg: const Color(0xFFDCFCE7),
                    lightFg: const Color(0xFF0D9488),
                    darkBg: const Color(0xFF143F38),
                    darkFg: const Color(0xFF5EEAD4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.receiveLocationTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          storageSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: controller.openAutoReceiveFolder,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    child: Text(s.open, style: const TextStyle(fontSize: 12.5)),
                  ),
                  Icon(
                    _storageExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: tokens.mutedText,
                  ),
                ],
              ),
            ),
          ),
          if (_storageExpanded) ...[
            Divider(height: 1, color: tokens.subtleBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Platform.isAndroid)
                    ..._buildAndroidStorageOptionsList(
                      s,
                      tokens,
                      scheme,
                      controller,
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.sidebarBg,
                        borderRadius:
                            BorderRadius.circular(tokens.cardRadius * 0.8),
                        border: Border.all(color: tokens.subtleBorder),
                      ),
                      child: SelectableText(
                        saveDir,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontFamily: 'monospace',
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (_saveDirError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _saveDirError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.drive_file_move_outlined,
                              size: 17),
                          label: Text(s.btnChangeFolder),
                          onPressed: () async {
                            final picked =
                                await FilePicker.platform.getDirectoryPath(
                              dialogTitle: s.pickReceiveDirDialogTitle,
                              initialDirectory: Directory(saveDir).existsSync()
                                  ? saveDir
                                  : null,
                            );
                            if (picked != null && picked.isNotEmpty) {
                              await _applySaveDir(picked);
                            }
                          },
                        ),
                        if (_defaultDir != null)
                          TextButton.icon(
                            icon: const Icon(Icons.restore, size: 17),
                            label: Text(s.resetDefault),
                            onPressed: () => _applySaveDir(null),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAndroidStorageOptionsList(
    AppStrings s,
    AppThemeTokens tokens,
    ColorScheme scheme,
    AppWorkspaceController controller,
  ) {
    final mode = controller.androidStorageMode;
    final customDir = controller.customSaveDir?.trim();
    final hasCustomDir = customDir != null &&
        customDir.isNotEmpty &&
        !customDir.contains('/Android/data/');

    return [
      _buildStorageOptionTile(
        tokens: tokens,
        scheme: scheme,
        selected: mode == 'downloads',
        title: s.storageModeDownloads,
        badge: s.recommendedBadge,
        subtitle: s.storageDownloadsDesc,
        onTap: () {
          controller.setAndroidStorageMode('downloads');
          unawaited(_refreshStorageStats());
        },
      ),
      const SizedBox(height: 4),
      _buildStorageOptionTile(
        tokens: tokens,
        scheme: scheme,
        selected: mode == 'documents',
        title: s.storageModeDocuments,
        subtitle: s.storageDocumentsDesc,
        onTap: () {
          controller.setAndroidStorageMode('documents');
          unawaited(_refreshStorageStats());
        },
      ),
      const SizedBox(height: 4),
      _buildStorageOptionTile(
        tokens: tokens,
        scheme: scheme,
        selected: mode == 'custom',
        title: s.storageModeCustomTitle,
        subtitle: hasCustomDir
            ? s.storageCustomSelectedDesc(
                _formatCompactAndroidPath(customDir),
              )
            : s.storageCustomUnselectedDesc,
        onTap: () {
          if (mode == 'custom' || !hasCustomDir) {
            unawaited(_pickAndroidCustomFolder(controller)
                .then((_) => _refreshStorageStats()));
          } else {
            unawaited(controller
                .setAndroidStorageMode('custom')
                .then((_) => _refreshStorageStats()));
          }
        },
        trailing: hasCustomDir
            ? TextButton(
                onPressed: () => _pickAndroidCustomFolder(controller)
                    .then((_) => _refreshStorageStats()),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  s.btnChange,
                  style: const TextStyle(fontSize: 12),
                ),
              )
            : null,
      ),
      const SizedBox(height: 4),
      _buildStorageOptionTile(
        tokens: tokens,
        scheme: scheme,
        selected: mode == 'app_private',
        title: s.storageAppPrivateTitle,
        subtitle: s.storageAppPrivateDesc,
        onTap: () {
          controller.setAndroidStorageMode('app_private');
          unawaited(_refreshStorageStats());
        },
      ),
      if (!_legacyStorageGranted &&
          (mode == 'downloads' || mode == 'documents')) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.folder_special_outlined,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.legacyStoragePermNotice,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final granted =
                      await PlatformBridge.requestLegacyStoragePermission();
                  if (mounted) {
                    setState(() => _legacyStorageGranted = granted);
                  }
                },
                child: Text(s.btnAuthorize),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildWindowsResidencyCard(
    AppStrings s,
    AppThemeTokens tokens,
    AppWorkspaceController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSettingIcon(
                  context,
                  tokens,
                  Icons.computer_rounded,
                  lightBg: const Color(0xFFE0ECFF),
                  lightFg: const Color(0xFF0067C0),
                  darkBg: const Color(0xFF1E3658),
                  darkFg: const Color(0xFF4CC2FF),
                ),
                const SizedBox(width: 12),
                Text(
                  s.windowsResidencyTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.windowsCloseToTrayTitle),
              subtitle: Text(
                s.windowsCloseToTraySubtitle,
                style: const TextStyle(fontSize: 12),
              ),
              value: controller.windowsCloseToTray,
              onChanged: controller.toggleWindowsCloseToTray,
            ),
            Divider(height: 1, color: tokens.subtleBorder),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.windowsAutoStartTitle),
              subtitle: Text(
                s.windowsAutoStartSubtitle,
                style: const TextStyle(fontSize: 12),
              ),
              value: controller.windowsAutoStart,
              onChanged: controller.toggleWindowsAutoStart,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.vertical_align_bottom, size: 17),
                  label: Text(s.btnHideToTrayNow),
                  onPressed: controller.hideToTray,
                ),
                TextButton.icon(
                  icon: const Icon(
                    Icons.power_settings_new,
                    size: 17,
                    color: Colors.redAccent,
                  ),
                  label: Text(
                    s.btnQuitBackgroundService,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  onPressed: controller.quitApp,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showThemePickerDialog() async {
    final s = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppThemeTokens.of(context);
    final current = widget.themeController.themeMode;
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.themeDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStorageOptionTile(
              tokens: tokens,
              scheme: scheme,
              selected: current == ThemeMode.system,
              title: s.themeSystemTitle,
              subtitle: s.themeSystemSubtitle,
              onTap: () => Navigator.of(ctx).pop(ThemeMode.system),
            ),
            const SizedBox(height: 4),
            _buildStorageOptionTile(
              tokens: tokens,
              scheme: scheme,
              selected: current == ThemeMode.light,
              title: s.themeLightTitle,
              subtitle: s.themeLightSubtitle,
              onTap: () => Navigator.of(ctx).pop(ThemeMode.light),
            ),
            const SizedBox(height: 4),
            _buildStorageOptionTile(
              tokens: tokens,
              scheme: scheme,
              selected: current == ThemeMode.dark,
              title: s.themeDarkTitle,
              subtitle: s.themeDarkSubtitle,
              onTap: () => Navigator.of(ctx).pop(ThemeMode.dark),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (picked != null) {
      await widget.themeController.setThemeMode(picked);
    }
  }

  Future<void> _showLocalePickerDialog() async {
    final s = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tokens = AppThemeTokens.of(context);
    final current = widget.themeController.localeCode;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.languageDialogTitle),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStorageOptionTile(
                  tokens: tokens,
                  scheme: scheme,
                  selected: current == 'system',
                  title: s.languageSystemTitle,
                  subtitle: s.languageSystemSubtitle,
                  onTap: () => Navigator.of(ctx).pop('system'),
                ),
                for (final opt in AppLocalizations.supportedLocaleOptions) ...[
                  const SizedBox(height: 4),
                  _buildStorageOptionTile(
                    tokens: tokens,
                    scheme: scheme,
                    selected: current == opt.code,
                    title: opt.nativeName,
                    subtitle: opt.englishName,
                    onTap: () => Navigator.of(ctx).pop(opt.code),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
        ],
      ),
    );
    if (picked != null) {
      await widget.themeController.setLocaleCode(picked);
      if (mounted) {
        final nextStrings = AppLocalizations.current;
        final label = picked == 'system'
            ? nextStrings.languageSystemTitle
            : (AppLocalizations.optionForCode(picked)?.nativeName ?? picked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nextStrings.toastLanguageUpdated(label))),
        );
      }
    }
  }

  Widget _buildSettingNavRow({
    required AppThemeTokens tokens,
    required Widget leadingIcon,
    required String title,
    String? subtitle,
    required String trailingText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: tokens.isDesktop ? 14 : 13,
        ),
        child: Row(
          children: [
            leadingIcon,
            SizedBox(width: tokens.isDesktop ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.mutedText),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailingText,
              style: TextStyle(fontSize: 13, color: tokens.mutedText),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralCard(AppStrings s, AppThemeTokens tokens) {
    final modeLabel = switch (widget.themeController.themeMode) {
      ThemeMode.system => s.themeSystemShort,
      ThemeMode.light => s.themeLightShort,
      ThemeMode.dark => s.themeDarkShort,
    };
    final localeOpt =
        AppLocalizations.optionForCode(widget.themeController.localeCode);
    final localeLabel = localeOpt?.nativeName ?? s.languageSystemTitle;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildSettingNavRow(
            tokens: tokens,
            leadingIcon: _buildSettingIcon(
              context,
              tokens,
              Icons.palette_outlined,
              lightBg: const Color(0xFFEDE9FE),
              lightFg: const Color(0xFF6D28D9),
              darkBg: const Color(0xFF2E2352),
              darkFg: const Color(0xFFC4B5FD),
            ),
            title: s.themeDialogTitle,
            trailingText: modeLabel,
            onTap: _showThemePickerDialog,
          ),
          Divider(
            height: 1,
            indent: tokens.isDesktop ? 62 : 66,
            color: tokens.subtleBorder,
          ),
          _buildSettingNavRow(
            tokens: tokens,
            leadingIcon: _buildSettingIcon(
              context,
              tokens,
              Icons.language_rounded,
              lightBg: const Color(0xFFE0ECFF),
              lightFg: const Color(0xFF2563EB),
              darkBg: const Color(0xFF1E3658),
              darkFg: const Color(0xFF93C5FD),
            ),
            title: s.languageSettingTitle,
            trailingText: localeLabel,
            onTap: _showLocalePickerDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _showStorageManagerDialog(
    AppWorkspaceController controller,
  ) async {
    await _refreshStorageStats();
    if (!mounted) return;
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    if (!tokens.isDesktop) {
      await _showMobileStorageManagerSheet(s, controller, tokens);
      return;
    }
    final recvText = _receiveFolderBytes != null
        ? s.storageRecvStats(formatBytes(_receiveFolderBytes!), _receiveFolderCount)
        : s.countingStats;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.storageManagerTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.folder_outlined, color: tokens.accentColor),
              title: Text(s.storageRecvUsedTitle),
              subtitle: Text(recvText),
              trailing: TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  controller.openAutoReceiveFolder();
                },
                child: Text(s.open),
              ),
            ),
            Divider(height: 1, color: tokens.subtleBorder),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cleaning_services_outlined,
                  color: tokens.accentColor),
              title: Text(s.thumbCacheTitle),
              subtitle: Text(
                s.thumbCacheDesc(formatBytes(_thumbCacheBytes)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.close),
          ),
          FilledButton.tonal(
            onPressed: _thumbCacheBytes == 0
                ? null
                : () async {
                    Navigator.of(ctx).pop();
                    await _clearThumbnailCache();
                  },
            child: Text(s.btnClearThumbCache),
          ),
        ],
      ),
    );
  }

  Future<void> _showMobileStorageManagerSheet(
    AppStrings s,
    AppWorkspaceController controller,
    AppThemeTokens tokens,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recvColor =
        isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
    final cacheColor =
        isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final pillBg = isDark ? const Color(0xFF233042) : const Color(0xFFDCE6F2);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.canvasBg,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final recvBytes = _receiveFolderBytes ?? 0;
          final cacheBytes = _thumbCacheBytes;
          final totalBytes = recvBytes + cacheBytes;
          final recvRatio = totalBytes > 0 ? recvBytes / totalBytes : 0.0;
          final cacheRatio = totalBytes > 0 ? cacheBytes / totalBytes : 0.0;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          s.mobileStorageTitle,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        formatBytes(totalBytes),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 10,
                      width: double.infinity,
                      color: isDark
                          ? const Color(0xFF252A32)
                          : const Color(0xFFE2E8F0),
                      child: totalBytes == 0
                          ? null
                          : Row(
                              children: [
                                if (recvBytes > 0)
                                  Flexible(
                                    flex: (recvRatio * 1000)
                                        .round()
                                        .clamp(1, 1000),
                                    child: Container(color: recvColor),
                                  ),
                                if (recvBytes > 0 && cacheBytes > 0)
                                  Container(
                                    width: 2,
                                    color: tokens.canvasBg,
                                  ),
                                if (cacheBytes > 0)
                                  Flexible(
                                    flex: (cacheRatio * 1000)
                                        .round()
                                        .clamp(1, 1000),
                                    child: Container(color: cacheColor),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _LegendDot(
                        color: recvColor,
                        label: s.legendReceivedFiles(formatBytes(recvBytes)),
                        textColor: tokens.mutedText,
                      ),
                      _LegendDot(
                        color: cacheColor,
                        label: s.legendThumbCache(formatBytes(cacheBytes)),
                        textColor: tokens.mutedText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          _buildSettingIcon(
                            ctx,
                            tokens,
                            Icons.folder_outlined,
                            lightBg: const Color(0xFFDCFCE7),
                            lightFg: const Color(0xFF0D9488),
                            darkBg: const Color(0xFF143F38),
                            darkFg: const Color(0xFF5EEAD4),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.receivedFilesCountTitle(_receiveFolderCount),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatBytes(recvBytes),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                controller.openAutoReceiveFolder();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  s.open,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          _buildSettingIcon(
                            ctx,
                            tokens,
                            Icons.cleaning_services_outlined,
                            lightBg: const Color(0xFFE0F2FE),
                            lightFg: const Color(0xFF0284C7),
                            darkBg: const Color(0xFF13364D),
                            darkFg: const Color(0xFF7DD3FC),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.thumbCacheTitleWithSize(
                                    formatBytes(cacheBytes),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  s.thumbCacheNoTouchNotice,
                                  maxLines: 3,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: tokens.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: cacheBytes == 0
                          ? null
                          : () async {
                              await _clearThumbnailCache();
                              if (ctx.mounted) {
                                setSheetState(() {});
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: pillBg,
                        foregroundColor: scheme.onSurface,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        cacheBytes == 0
                            ? s.noCacheToClear
                            : s.btnClearThumbCacheWithSize(
                                formatBytes(cacheBytes),
                              ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCacheCard(
    AppStrings s,
    AppThemeTokens tokens,
    ColorScheme scheme,
    AppWorkspaceController controller,
  ) {
    final cacheText = formatBytes(_thumbCacheBytes);
    final recvSummary = _receiveFolderBytes != null
        ? s.cacheCardSummary(formatBytes(_receiveFolderBytes!), cacheText)
        : s.cacheCardSummaryOnly(cacheText);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: _buildSettingNavRow(
        tokens: tokens,
        leadingIcon: _buildSettingIcon(
          context,
          tokens,
          Icons.cleaning_services_outlined,
          lightBg: const Color(0xFFE0F2FE),
          lightFg: const Color(0xFF0284C7),
          darkBg: const Color(0xFF13364D),
          darkFg: const Color(0xFF7DD3FC),
        ),
        title: s.storageAndCacheTitle,
        subtitle: recvSummary,
        trailingText: cacheText,
        onTap: () => _showStorageManagerDialog(controller),
      ),
    );
  }

  Widget _buildMobileStorageGroupCard(
    AppStrings s,
    AppThemeTokens tokens,
    ColorScheme scheme,
    AppWorkspaceController controller,
  ) {
    final mode = controller.androidStorageMode;
    final customDir = controller.customSaveDir?.trim();
    final hasCustomDir = customDir != null &&
        customDir.isNotEmpty &&
        !customDir.contains('/Android/data/');
    final modeBase = switch (mode) {
      'documents' => s.storageModeDocuments,
      'custom' when hasCustomDir =>
        s.storageModeCustom(_formatCompactAndroidPath(customDir)),
      'app_private' => s.storageModeAppPrivate,
      _ => s.storageModeDownloads,
    };
    final cacheText = formatBytes(_thumbCacheBytes);
    final totalBytes = (_receiveFolderBytes ?? 0) + _thumbCacheBytes;
    final cacheSummary = _receiveFolderBytes != null
        ? s.mobileCacheSummary(formatBytes(totalBytes), cacheText)
        : s.cacheCardSummaryOnly(cacheText);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _storageExpanded = !_storageExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
              child: Row(
                children: [
                  _buildSettingIcon(
                    context,
                    tokens,
                    Icons.folder_outlined,
                    lightBg: const Color(0xFFDCFCE7),
                    lightFg: const Color(0xFF0D9488),
                    darkBg: const Color(0xFF143F38),
                    darkFg: const Color(0xFF5EEAD4),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.receiveLocationTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          modeBase,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: controller.openAutoReceiveFolder,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    child: Text(s.open, style: const TextStyle(fontSize: 13)),
                  ),
                  Icon(
                    _storageExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: tokens.mutedText,
                  ),
                ],
              ),
            ),
          ),
          if (_storageExpanded) ...[
            Divider(height: 1, color: tokens.subtleBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildAndroidStorageOptionsList(
                  s,
                  tokens,
                  scheme,
                  controller,
                ),
              ),
            ),
          ],
          Divider(height: 1, indent: 66, color: tokens.subtleBorder),
          _buildSettingNavRow(
            tokens: tokens,
            leadingIcon: _buildSettingIcon(
              context,
              tokens,
              Icons.cleaning_services_outlined,
              lightBg: const Color(0xFFE0F2FE),
              lightFg: const Color(0xFF0284C7),
              darkBg: const Color(0xFF13364D),
              darkFg: const Color(0xFF7DD3FC),
            ),
            title: s.storageAndCacheTitle,
            subtitle: cacheSummary,
            trailingText: cacheText,
            onTap: () => _showStorageManagerDialog(controller),
          ),
        ],
      ),
    );
  }

  Future<void> _showAboutDialog() async {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.aboutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.aboutVersion(kAppVersionTag),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              s.aboutBody,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: tokens.mutedText,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(AppStrings s, AppThemeTokens tokens) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: _buildSettingNavRow(
        tokens: tokens,
        leadingIcon: _buildSettingIcon(
          context,
          tokens,
          Icons.info_outline_rounded,
          lightBg: const Color(0xFFE2E8F0),
          lightFg: const Color(0xFF475569),
          darkBg: const Color(0xFF27303F),
          darkFg: const Color(0xFFCBD5E1),
        ),
        title: s.aboutTitle,
        subtitle: s.aboutSubtitle,
        trailingText: kAppVersionTag,
        onTap: _showAboutDialog,
      ),
    );
  }

  Widget _buildNetworkDiagnosticsCard(
    AppStrings s,
    AppThemeTokens tokens,
    AppWorkspaceController controller,
  ) {
    final route = controller.usbRouteStatus;
    final summaryText = _loadingDiag
        ? s.networkDiagLoading
        : tokens.isDesktop
            ? (_nics.isNotEmpty
                ? s.networkDiagDesktopReady(_nics.length)
                : s.networkDiagDesktopWanOnly)
            : (_nics.isNotEmpty
                ? s.networkDiagMobileReady(_nics.length)
                : s.networkDiagMobileWanOnly);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                setState(() => _networkDiagExpanded = !_networkDiagExpanded),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: tokens.isDesktop ? 16 : 14,
              ),
              child: Row(
                children: [
                  _buildSettingIcon(
                    context,
                    tokens,
                    Icons.lan_outlined,
                    lightBg: const Color(0xFFFEF3C7),
                    lightFg: const Color(0xFFD97706),
                    darkBg: const Color(0xFF422C12),
                    darkFg: const Color(0xFFFCD34D),
                  ),
                  SizedBox(width: tokens.isDesktop ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.networkDiagTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: tokens.isDesktop
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summaryText,
                          maxLines: tokens.isDesktop ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: tokens.isDesktop ? 11.5 : 12,
                            color: tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _networkDiagExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: tokens.mutedText,
                  ),
                ],
              ),
            ),
          ),
          if (_networkDiagExpanded) ...[
            Divider(height: 1, color: tokens.subtleBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 连接刷新与局域网网卡检测
                  Text(
                    s.nicDetectionTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.nicDetectionDesc,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: tokens.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.sidebarBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.subtleBorder),
                    ),
                    child: _nics.isEmpty
                        ? Text(
                            _loadingDiag ? s.nicReading : s.nicNoneConnected,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.mutedText,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _nics
                                .map(
                                  (n) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      '• ${n.replaceFirst('[USB专线]', '[${s.usbTetherTag}]')}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            controller.busy ? null : controller.connectActiveRoom,
                        icon: const Icon(Icons.sync_rounded, size: 17),
                        label: Text(s.menuProbeReconnect),
                      ),
                      TextButton.icon(
                        onPressed: _loadingDiag ? null : _loadInfo,
                        icon: _loadingDiag
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 17),
                        label: Text(s.btnRefreshNics),
                      ),
                    ],
                  ),
                  if (Platform.isWindows && route != null) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, color: tokens.subtleBorder),
                    const SizedBox(height: 14),
                    // 2. USB 数据线高速直连保护 (Windows)
                    Text(
                      s.usbProtectionTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.usbProtectionDesc,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: tokens.mutedText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: route.metricProtected || !route.usbTetherDetected
                            ? const Color(0x2216A34A)
                            : const Color(0x22EA580C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            route.metricProtected || !route.usbTetherDetected
                                ? Icons.verified_user_outlined
                                : Icons.shield_outlined,
                            size: 18,
                            color: route.metricProtected ||
                                    !route.usbTetherDetected
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              route.usbTetherDetected
                                  ? (route.metricProtected
                                      ? s.usbProtectionReady
                                      : s.usbProtectionNeedsFix(
                                          s.formatUsbRouteMessage(
                                            usbTetherDetected:
                                                route.usbTetherDetected,
                                            metricProtected:
                                                route.metricProtected,
                                            needsElevation: route.needsElevation,
                                            usbIfName: route.usbIfName,
                                          ),
                                        ))
                                  : s.usbProtectionNotPlugged,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (route.usbTetherDetected && !route.metricProtected)
                            TextButton(
                              onPressed: controller.busy
                                  ? null
                                  : controller.repairWindowsUsbMetric,
                              child: Text(s.btnFixMetric),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(height: 1, color: tokens.subtleBorder),
                  const SizedBox(height: 14),
                  // 3. 自定义异地中继服务器
                  Text(
                    s.customRelayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.customRelayDesc,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: tokens.mutedText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _relayCtrl,
                    decoration: InputDecoration(
                      labelText: s.customRelayLabel,
                      hintText: 'https://relay.example.com',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await PlatformBridge.saveCustomRelayUrl(
                        widget.dataDir,
                        _relayCtrl.text,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.toastRelaySaved)),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: Text(s.btnSaveRelay),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: tokens.subtleBorder),
                  const SizedBox(height: 14),
                  Text(
                    s.deviceIdLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.sidebarBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.subtleBorder),
                    ),
                    child: SelectableText(
                      widget.myEndpointId,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: tokens.mutedText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _copyFullDeviceId(s),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(s.btnCopyDeviceId),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: textColor),
        ),
      ],
    );
  }
}

class _ProfileActionCircle extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ProfileActionCircle({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF233042) : const Color(0xFFE8EEF5);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
