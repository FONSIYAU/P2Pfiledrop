import 'package:material_ui/material_ui.dart';

import '../../controllers/app_workspace_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme_tokens.dart';
import 'room_avatar.dart';

/// Primary top-level sections modeled after WeChat navigation.
enum WorkspaceTab {
  chats,
  contacts,
  me,
}

/// Slim WeChat-style vertical navigation rail used on wide desktop layouts.
class DesktopNavRail extends StatelessWidget {
  final AppWorkspaceController controller;
  final WorkspaceTab activeTab;
  final int activeTransfersCount;
  final ValueChanged<WorkspaceTab> onSelectTab;
  final VoidCallback onOpenFolder;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenScanPair;

  const DesktopNavRail({
    super.key,
    required this.controller,
    required this.activeTab,
    required this.activeTransfersCount,
    required this.onSelectTab,
    required this.onOpenFolder,
    required this.onOpenFiles,
    required this.onOpenScanPair,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railBg = isDark ? const Color(0xFF15171C) : const Color(0xFFEEF2F8);
    final dividerColor = tokens.subtleBorder;
    final isOnline = controller.peers.any(
      (p) => (controller.getPeerTransport(p.nodeId) ?? 'offline') != 'offline',
    );

    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: railBg,
        border: Border(right: BorderSide(color: dividerColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Tooltip(
            message: s.tooltipSelfProfile(controller.deviceName),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelectTab(WorkspaceTab.me),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: activeTab == WorkspaceTab.me
                            ? tokens.accentColor
                            : tokens.subtleBorder,
                        width: 1.5,
                      ),
                    ),
                    child: DeviceAvatar(
                      radius: 20,
                      borderRadius: BorderRadius.circular(8.5),
                      fallbackText: controller.effectiveSelfAvatar,
                      deviceKind: controller.selfDeviceKind,
                      imagePath: controller.myAvatarPath,
                      accentColor: tokens.accentColor,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                        border: Border.all(color: railBg, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _RailNavButton(
            icon: Icons.swap_horiz_rounded,
            selectedIcon: Icons.swap_horizontal_circle_rounded,
            label: s.navTransfers,
            selected: activeTab == WorkspaceTab.chats,
            badgeCount: activeTransfersCount,
            accentColor: tokens.accentColor,
            subtleBorder: tokens.subtleBorder,
            onTap: () => onSelectTab(WorkspaceTab.chats),
          ),
          const SizedBox(height: 8),
          _RailNavButton(
            icon: Icons.devices_outlined,
            selectedIcon: Icons.devices_rounded,
            label: s.navDevices,
            selected: activeTab == WorkspaceTab.contacts,
            accentColor: tokens.accentColor,
            subtleBorder: tokens.subtleBorder,
            onTap: () => onSelectTab(WorkspaceTab.contacts),
          ),
          const SizedBox(height: 8),
          _RailNavButton(
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune_rounded,
            label: s.navThisDevice,
            selected: activeTab == WorkspaceTab.me,
            accentColor: tokens.accentColor,
            subtleBorder: tokens.subtleBorder,
            onTap: () => onSelectTab(WorkspaceTab.me),
          ),
          const Spacer(),
          _RailActionButton(
            icon: Icons.qr_code_scanner_rounded,
            label: s.navAdd,
            tooltip: s.tooltipScanPair,
            onTap: onOpenScanPair,
          ),
          const SizedBox(height: 6),
          _RailActionButton(
            icon: Icons.perm_media_outlined,
            label: s.navFiles,
            tooltip: s.tooltipAllFiles,
            onTap: onOpenFiles,
          ),
          const SizedBox(height: 6),
          _RailActionButton(
            icon: Icons.folder_open_rounded,
            label: s.navFolder,
            tooltip: s.tooltipOpenReceiveFolder(controller.effectiveDisplaySaveDir),
            highlighted: true,
            accentColor: tokens.accentColor,
            onTap: onOpenFolder,
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _RailNavButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badgeCount;
  final Color accentColor;
  final Color subtleBorder;
  final VoidCallback onTap;

  const _RailNavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.subtleBorder,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected
        ? accentColor
        : (isDark
            ? Colors.white.withValues(alpha: 0.78)
            : const Color(0xFF475569));
    final selectedBg =
        isDark ? const Color(0xFF252B35) : const Color(0xFFFFFFFF);
    return Tooltip(
      message: label,
      child: Material(
        color: selected ? selectedBg : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: selected
              ? BorderSide(color: subtleBorder)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 60,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 3,
                    height: selected ? 18 : 0,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(selected ? selectedIcon : icon, size: 22, color: fg),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 8,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool highlighted;
  final Color? accentColor;
  final VoidCallback onTap;

  const _RailActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = highlighted && accentColor != null
        ? accentColor!
        : (isDark
            ? Colors.white.withValues(alpha: 0.78)
            : const Color(0xFF475569));
    final bg = highlighted && accentColor != null
        ? accentColor!.withValues(alpha: isDark ? 0.20 : 0.12)
        : (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.65));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 60,
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            highlighted ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
