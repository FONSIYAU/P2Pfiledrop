import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/app_workspace_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/platform_bridge.dart';
import '../src/rust/api.dart';
import 'theme/app_theme_tokens.dart';

/// Multi-room E2EE invite & device pairing bottom sheet.
///
/// Tab 1: Generate QR invite ticket for room members (includes room key).
/// Tab 2: Scan QR or paste `RoomInviteTicket` v2 (or Phase 1 `PairingTicket` v1).
class RoomInviteSheet extends StatefulWidget {
  final AppWorkspaceController controller;
  final RoomDto? room;
  final bool initialScanTab;
  final bool isFullScreen;

  const RoomInviteSheet({
    super.key,
    required this.controller,
    this.room,
    this.initialScanTab = false,
    this.isFullScreen = false,
  });

  @override
  State<RoomInviteSheet> createState() => _RoomInviteSheetState();
}

class _RoomInviteSheetState extends State<RoomInviteSheet>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _scannerMethodChannel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );

  late final TabController _tabs;
  final TextEditingController _ticketController = TextEditingController();
  MobileScannerController? _scannerController;

  String? _qrPayload;
  String? _error;
  bool _loadingQr = false;
  bool _joining = false;
  bool _scannerHandled = false;
  bool _forceDevicePairingQr = false;
  bool _startingScanner = false;
  bool _analyzingImage = false;

  bool get _hasGroupRoom =>
      widget.room != null && widget.room!.roomType == 'group';
  bool get _isGroupInviteMode => _hasGroupRoom && !_forceDevicePairingQr;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialScanTab ? 1 : 0,
    );
    _tabs.addListener(_handleTabChange);
    if (Platform.isAndroid) {
      _scannerController = MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
      if (widget.initialScanTab) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_startScannerSafely());
          }
        });
      }
    }
    _loadInviteQr();
  }

  void _handleTabChange() {
    if (!Platform.isAndroid || _tabs.indexIsChanging) return;
    if (_tabs.index == 1) {
      unawaited(_startScannerSafely());
    } else {
      unawaited(_stopScannerSafely());
    }
  }

  Future<void> _forceResetNativeScanner() async {
    try {
      await _scannerMethodChannel.invokeMethod<void>('stop', {'force': true});
    } catch (_) {}
    try {
      await MobileScannerPlatform.instance.stop();
    } catch (_) {}
  }

  Future<void> _startScannerSafely({bool forceReset = false}) async {
    if (!Platform.isAndroid ||
        !mounted ||
        _startingScanner ||
        _joining ||
        _analyzingImage ||
        _tabs.index != 1) {
      return;
    }
    final controller = _scannerController;
    if (controller == null) return;

    setState(() => _startingScanner = true);
    try {
      if (forceReset) {
        await _forceResetNativeScanner();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted || _tabs.index != 1) return;
      }
      await controller.start();
      if (!mounted) return;
      if (controller.value.error?.errorCode ==
          MobileScannerErrorCode.controllerAlreadyInitialized) {
        await _forceResetNativeScanner();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!mounted || _tabs.index != 1) return;
        await controller.start();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _startingScanner = false);
      }
    }
  }

  Future<void> _stopScannerSafely() async {
    if (!Platform.isAndroid) return;
    try {
      await _scannerController?.stop();
    } catch (_) {}
    try {
      await MobileScannerPlatform.instance.stop();
    } catch (_) {}
  }

  Future<void> _pickAndScanGalleryQr() async {
    if (_analyzingImage || _joining) return;
    setState(() {
      _analyzingImage = true;
      _error = null;
    });

    await _stopScannerSafely();

    try {
      final List<String> paths;
      if (Platform.isAndroid) {
        paths = await PlatformBridge.pickGalleryImages(maxItems: 1);
      } else {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        paths = res?.files.map((f) => f.path).whereType<String>().toList() ??
            const <String>[];
      }

      if (paths.isEmpty || !mounted) {
        if (mounted) {
          setState(() => _analyzingImage = false);
        }
        if (Platform.isAndroid && _tabs.index == 1) {
          unawaited(_startScannerSafely());
        }
        return;
      }

      if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        if (mounted) {
          final s = AppLocalizations.of(context);
          setState(() {
            _analyzingImage = false;
            _error = s.desktopQrImageUnsupported;
          });
        }
        return;
      }

      final capture = await MobileScannerPlatform.instance.analyzeImage(
        paths.first,
        formats: const [BarcodeFormat.qrCode],
      );
      if (!mounted) return;

      final code = capture?.barcodes
              .map((b) => b.rawValue?.trim())
              .whereType<String>()
              .firstWhere((v) => v.isNotEmpty, orElse: () => '') ??
          '';

      if (code.isNotEmpty) {
        setState(() => _analyzingImage = false);
        await _submitTicket(code);
        if (mounted && !_joining && Platform.isAndroid && _tabs.index == 1) {
          unawaited(_startScannerSafely());
        }
      } else {
        final s = AppLocalizations.of(context);
        setState(() {
          _analyzingImage = false;
          _error = s.noQrDetectedInImage;
        });
        if (Platform.isAndroid && _tabs.index == 1) {
          unawaited(_startScannerSafely());
        }
      }
    } catch (e) {
      if (!mounted) return;
      final s = AppLocalizations.of(context);
      setState(() {
        _analyzingImage = false;
        _error = s.galleryQrScanFailed(e);
      });
      if (Platform.isAndroid && _tabs.index == 1) {
        unawaited(_startScannerSafely());
      }
    }
  }

  Future<void> _loadInviteQr() async {
    setState(() {
      _loadingQr = true;
      _error = null;
    });
    try {
      final ticket = _isGroupInviteMode
          ? await widget.controller.buildRoomInviteTicket(
              roomId: widget.room!.roomId,
            )
          : await widget.controller.buildMyDevicePairingQr();
      if (!mounted) return;
      setState(() {
        _qrPayload = ticket;
        _loadingQr = false;
      });
    } catch (e) {
      if (!mounted) return;
      final s = AppLocalizations.current;
      setState(() {
        _error = s.generateQrFailed(e);
        _loadingQr = false;
      });
    }
  }

  Future<void> _submitTicket(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    final ok = await widget.controller.joinOrPairFromCode(trimmed);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final s = AppLocalizations.of(context);
      setState(() {
        _joining = false;
        _scannerHandled = false;
        _error = s.joinOrPairFailedHint;
      });
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_handleTabChange);
    _tabs.dispose();
    _ticketController.dispose();
    final controller = _scannerController;
    _scannerController = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final roomDisplayName = widget.room != null
        ? widget.controller.resolveRoomTitle(widget.room!)
        : '';
    final titleText = _isGroupInviteMode
        ? s.inviteGroupTitle(roomDisplayName)
        : s.inviteDeviceTitle;
    final tabBar = TabBar(
      controller: _tabs,
      tabs: [
        Tab(text: _isGroupInviteMode ? s.tabGroupInviteQr : s.tabDevicePairingQr),
        Tab(text: s.tabScanOrPaste),
      ],
    );

    if (widget.isFullScreen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            titleText,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          bottom: tabBar,
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _buildGenerateTab(s, roomDisplayName),
            _buildFullScreenScanTab(s),
          ],
        ),
      );
    }

    return SafeArea(
      child: SizedBox(
        height: 580,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                titleText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            tabBar,
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildGenerateTab(s, roomDisplayName),
                  _buildScanOrPasteTab(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateTab(AppStrings s, String roomDisplayName) {
    final tokens = AppThemeTokens.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.isFullScreen && _error != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
          if (_hasGroupRoom) ...[
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(s.tabGroupInviteQr),
                  selected: !_forceDevicePairingQr,
                  onSelected: (_) {
                    if (_forceDevicePairingQr) {
                      setState(() => _forceDevicePairingQr = false);
                      _loadInviteQr();
                    }
                  },
                ),
                ChoiceChip(
                  label: Text(s.tabDevicePairingQr),
                  selected: _forceDevicePairingQr,
                  onSelected: (_) {
                    if (!_forceDevicePairingQr) {
                      setState(() => _forceDevicePairingQr = true);
                      _loadInviteQr();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Text(
            _isGroupInviteMode
                ? s.groupInviteDesc(roomDisplayName)
                : s.devicePairingDesc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: tokens.mutedText),
          ),
          const SizedBox(height: 14),
          if (_loadingQr)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            )
          else if (_qrPayload != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(blurRadius: 10, color: Colors.black12),
                ],
              ),
              child: QrImageView(
                data: _qrPayload!,
                version: QrVersions.auto,
                size: 205,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _qrPayload!));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.toastCopiedQrJson)),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(s.btnCopyTextTicket),
            ),
          ] else
            FilledButton(
              onPressed: _loadInviteQr,
              child: Text(s.btnRetryGenerateQr),
            ),
        ],
      ),
    );
  }

  String _describeScannerError(AppStrings s, MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return s.scannerPermDenied;
      case MobileScannerErrorCode.unsupported:
        return s.scannerUnsupported;
      case MobileScannerErrorCode.controllerAlreadyInitialized:
        return s.scannerReinitializing;
      case MobileScannerErrorCode.controllerDisposed:
      case MobileScannerErrorCode.controllerUninitialized:
      case MobileScannerErrorCode.genericError:
        final details = error.errorDetails?.message?.trim();
        if (details != null && details.isNotEmpty) {
          return s.scannerGenericErrorWithDetails(details);
        }
        return s.scannerGenericError;
    }
  }

  Widget _buildScannerPlaceholder(AppStrings s) {
    return ColoredBox(
      color: const Color(0xFF101317),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.startingCamera,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _analyzingImage || _joining
                    ? null
                    : _pickAndScanGalleryQr,
                icon: const Icon(Icons.photo_library_outlined, size: 17),
                label: Text(s.btnPickQrFromGallery),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerErrorOverlay(AppStrings s, MobileScannerException error) {
    return ColoredBox(
      color: const Color(0xFF101317),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                _describeScannerError(s, error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: (_startingScanner || _analyzingImage || _joining)
                        ? null
                        : () => _startScannerSafely(forceReset: true),
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(s.btnRetryCamera),
                  ),
                  OutlinedButton.icon(
                    onPressed: (_analyzingImage || _joining)
                        ? null
                        : _pickAndScanGalleryQr,
                    icon: const Icon(Icons.photo_library_outlined, size: 17),
                    label: Text(s.btnPickQrFromGallery),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPasteTicketDialog(AppStrings s) async {
    await _stopScannerSafely();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.pasteTicketDialogTitle),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: _ticketController,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText: s.pasteTicketFieldHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              final raw = _ticketController.text;
              Navigator.of(ctx).pop();
              _submitTicket(raw);
            },
            child: Text(s.btnJoinOrRegister),
          ),
        ],
      ),
    );
    if (mounted &&
        !_joining &&
        !_analyzingImage &&
        Platform.isAndroid &&
        _tabs.index == 1) {
      unawaited(_startScannerSafely());
    }
  }

  Widget _buildFullScreenScanTab(AppStrings s) {
    final hasCamera = Platform.isAndroid && _scannerController != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasCamera)
          MobileScanner(
            controller: _scannerController,
            fit: BoxFit.cover,
            placeholderBuilder: (_, _) => _buildScannerPlaceholder(s),
            errorBuilder: (_, error, _) => _buildScannerErrorOverlay(s, error),
            onDetect: (capture) {
              if (_scannerHandled) return;
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null && code.isNotEmpty) {
                _scannerHandled = true;
                _submitTicket(code);
              }
            },
          )
        else
          ColoredBox(
            color: const Color(0xFF101317),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  s.cameraNotSupportedPlatform,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
        if (hasCamera)
          IgnorePointer(
            child: CustomPaint(
              painter: _QrViewfinderPainter(),
            ),
          ),
        Positioned(
          top: 16,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                )
              else if (hasCamera)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.qrViewfinderHint,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
            ],
          ),
        ),
        if (_joining || _analyzingImage)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      _analyzingImage ? s.analyzingImageQr : s.verifyingHandshake,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOverlayCircleAction(
                  icon: Icons.photo_library_outlined,
                  label: s.actionGallery,
                  onTap: (_analyzingImage || _joining)
                      ? null
                      : _pickAndScanGalleryQr,
                ),
                _buildOverlayCircleAction(
                  icon: Icons.content_paste_rounded,
                  label: s.actionPasteTicket,
                  onTap: (_analyzingImage || _joining)
                      ? null
                      : () => _showPasteTicketDialog(s),
                ),
                if (hasCamera)
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _scannerController!,
                    builder: (context, state, _) {
                      final torchOn = state.torchState == TorchState.on;
                      final available =
                          state.isRunning &&
                          state.torchState != TorchState.unavailable;
                      return _buildOverlayCircleAction(
                        icon: torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        label: torchOn ? s.actionTorchOff : s.actionTorchOn,
                        active: torchOn,
                        onTap: available
                            ? () => _scannerController?.toggleTorch()
                            : null,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayCircleAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
              child: Icon(
                icon,
                color: active ? Colors.black87 : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOrPasteTab(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (Platform.isAndroid && _scannerController != null)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _scannerController,
                  placeholderBuilder: (_, _) => _buildScannerPlaceholder(s),
                  errorBuilder: (_, error, _) =>
                      _buildScannerErrorOverlay(s, error),
                  onDetect: (capture) {
                    if (_scannerHandled) return;
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    if (code != null && code.isNotEmpty) {
                      _scannerHandled = true;
                      _submitTicket(code);
                    }
                  },
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.windowsPasteTicketHint,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_analyzingImage || _joining)
                        ? null
                        : _pickAndScanGalleryQr,
                    icon: _analyzingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(
                      _analyzingImage ? s.btnAnalyzingQr : s.btnPickQrFromGallery,
                    ),
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: (_startingScanner || _analyzingImage || _joining)
                        ? null
                        : () => _startScannerSafely(forceReset: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(s.btnRestartCamera),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _ticketController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: s.pasteTicketFieldLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _joining ? null : () => _submitTicket(_ticketController.text),
              icon: _joining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(_joining ? s.verifyingHandshake : s.btnJoinToThisDevice),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = (size.shortestSide * 0.64).clamp(180.0, 270.0);
    final center = Offset(size.width / 2, size.height * 0.44);
    final scanRect = Rect.fromCenter(center: center, width: side, height: side);
    final rrect = RRect.fromRectAndRadius(scanRect, const Radius.circular(18));

    final maskPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.52),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    const cornerLen = 24.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final l = scanRect.left;
    final t = scanRect.top;
    final r = scanRect.right;
    final b = scanRect.bottom;

    // Top-left
    canvas.drawLine(Offset(l, t + cornerLen), Offset(l, t + 6), cornerPaint);
    canvas.drawLine(Offset(l + 6, t), Offset(l + cornerLen, t), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(r - cornerLen, t), Offset(r - 6, t), cornerPaint);
    canvas.drawLine(Offset(r, t + 6), Offset(r, t + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(l, b - cornerLen), Offset(l, b - 6), cornerPaint);
    canvas.drawLine(Offset(l + 6, b), Offset(l + cornerLen, b), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(r - cornerLen, b), Offset(r - 6, b), cornerPaint);
    canvas.drawLine(Offset(r, b - 6), Offset(r, b - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
