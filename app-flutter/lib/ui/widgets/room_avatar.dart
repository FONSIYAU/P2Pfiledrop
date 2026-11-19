import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../controllers/app_workspace_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api.dart';

/// Maps a semantic [DeviceIconKind] to a clean outlined Material hardware icon.
IconData deviceKindToIcon(DeviceIconKind kind) => switch (kind) {
      DeviceIconKind.desktop => Icons.desktop_windows_outlined,
      DeviceIconKind.laptop => Icons.laptop_mac_outlined,
      DeviceIconKind.phone => Icons.smartphone_outlined,
      DeviceIconKind.tablet => Icons.tablet_mac_outlined,
      DeviceIconKind.homeNode => Icons.dns_outlined,
      DeviceIconKind.unknown => Icons.devices_outlined,
    };

/// Clean, low-saturation Morandi/pastel background & foreground pair for each
/// device category (and multi-device groups), supporting both Light and Dark.
({Color bg, Color fg}) deviceKindPastelPalette(
  DeviceIconKind? kind, {
  required bool isDark,
  bool isGroup = false,
}) {
  if (isGroup) {
    return isDark
        ? (bg: const Color(0xFF2E2352), fg: const Color(0xFFC4B5FD))
        : (bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9));
  }
  return switch (kind) {
    DeviceIconKind.desktop || DeviceIconKind.laptop => isDark
        ? (bg: const Color(0xFF1E3658), fg: const Color(0xFF93C5FD))
        : (bg: const Color(0xFFE0ECFF), fg: const Color(0xFF2563EB)),
    DeviceIconKind.phone || DeviceIconKind.tablet => isDark
        ? (bg: const Color(0xFF143F38), fg: const Color(0xFF5EEAD4))
        : (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF0D9488)),
    DeviceIconKind.homeNode => isDark
        ? (bg: const Color(0xFF422C12), fg: const Color(0xFFFCD34D))
        : (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFD97706)),
    _ => isDark
        ? (bg: const Color(0xFF27303F), fg: const Color(0xFFCBD5E1))
        : (bg: const Color(0xFFE2E8F0), fg: const Color(0xFF475569)),
  };
}

/// Shared device avatar: renders the synced/uploaded photo when present on disk,
/// otherwise shows a clean hardware device icon (or fallback text if omitted).
class DeviceAvatar extends StatelessWidget {
  final String fallbackText;
  final DeviceIconKind? deviceKind;
  final IconData? fallbackIcon;
  final String? imagePath;
  final double radius;
  final Color accentColor;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;

  const DeviceAvatar({
    super.key,
    required this.fallbackText,
    required this.accentColor,
    this.deviceKind,
    this.fallbackIcon,
    this.imagePath,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final cleanPath = imagePath?.trim() ?? '';
    final hasFile = cleanPath.isNotEmpty && File(cleanPath).existsSync();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedIcon =
        fallbackIcon ?? (deviceKind != null ? deviceKindToIcon(deviceKind!) : null);
    final pastel = deviceKindPastelPalette(deviceKind, isDark: isDark);
    final bg = backgroundColor ??
        (resolvedIcon != null
            ? pastel.bg
            : accentColor.withValues(alpha: 0.14));
    final fg = foregroundColor ??
        (resolvedIcon != null ? pastel.fg : accentColor);

    Widget buildFallback() {
      return Container(
        width: diameter,
        height: diameter,
        color: bg,
        alignment: Alignment.center,
        child: resolvedIcon != null
            ? Icon(
                resolvedIcon,
                size: (radius * 1.05).clamp(14.0, 42.0),
                color: fg,
              )
            : Text(
                fallbackText,
                style: TextStyle(
                  fontSize: radius >= 30
                      ? 24
                      : (radius >= 22 ? 18 : (fallbackText.runes.length > 1 ? 11 : 14)),
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
      );
    }

    final child = hasFile
        ? Image.file(
            File(cleanPath),
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => buildFallback(),
          )
        : buildFallback();

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(width: diameter, height: diameter, child: child),
      );
    }
    return ClipOval(
      child: SizedBox(width: diameter, height: diameter, child: child),
    );
  }
}

/// Shared room avatar badge supporting DM device photos/icons or group badges.
class RoomAvatar extends StatelessWidget {
  final RoomDto room;
  final double size;
  final String? peerAvatarPath;
  final String? peerFallbackText;
  final DeviceIconKind? peerDeviceKind;
  final Color? peerAccentColor;

  const RoomAvatar({
    super.key,
    required this.room,
    this.size = 40,
    this.peerAvatarPath,
    this.peerFallbackText,
    this.peerDeviceKind,
    this.peerAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDm = room.roomType == 'dm' || room.isPinned;
    final cleanPath = peerAvatarPath?.trim() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDm &&
        ((cleanPath.isNotEmpty && File(cleanPath).existsSync()) ||
            peerDeviceKind != null)) {
      final accent = peerAccentColor ?? const Color(0xFF0088CC);
      return DeviceAvatar(
        fallbackText:
            peerFallbackText ?? AppLocalizations.of(context).defaultAvatarFallback,
        deviceKind: peerDeviceKind,
        imagePath: cleanPath,
        radius: size / 2,
        accentColor: accent,
      );
    }

    final pastel = deviceKindPastelPalette(
      null,
      isDark: isDark,
      isGroup: !isDm,
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pastel.bg,
      ),
      alignment: Alignment.center,
      child: isDm
          ? Icon(
              Icons.devices_outlined,
              color: pastel.fg,
              size: size * 0.48,
            )
          : Icon(
              Icons.groups_2_outlined,
              color: pastel.fg,
              size: size * 0.50,
            ),
    );
  }
}

Color senderAccentColor(String senderId) {
  const palette = [
    Color(0xFF0088CC),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDB2777),
  ];
  final hash = senderId.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return palette[hash % palette.length];
}

String transportLabel(String t, [AppStrings? strings]) {
  final s = strings ?? AppLocalizations.current;
  return switch (t) {
    'usb_tether' => s.transportUsbTether,
    'lan_direct' => s.transportLanDirect,
    'wan_p2p' || 'wan_p2p_relay' => s.transportWanP2p,
    'wan_relay' => s.transportWanRelay,
    _ => s.transportOffline,
  };
}

Color transportColor(String t) => switch (t) {
      'usb_tether' => const Color(0xFF0284C7),
      'lan_direct' => const Color(0xFF16A34A),
      'wan_p2p' || 'wan_p2p_relay' => const Color(0xFF2563EB),
      'wan_relay' => const Color(0xFFD97706),
      _ => const Color(0xFF64748B),
    };

String messageStatusText(String status, [AppStrings? strings]) {
  final s = strings ?? AppLocalizations.current;
  return switch (status) {
    'queued_offline' => s.msgStatusQueuedOffline,
    'handshaking' => s.msgStatusHandshaking,
    'transferring' => s.msgStatusTransferring,
    'paused_reconnecting' => s.msgStatusPausedReconnecting,
    'awaiting_download' => s.msgStatusAwaitingDownload,
    'delivered' => s.msgStatusDelivered,
    'failed_source_missing' => s.msgStatusFailedSourceMissing,
    _ => status,
  };
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

bool isImageFileName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif');
}
