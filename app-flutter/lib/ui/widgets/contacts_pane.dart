import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../controllers/app_workspace_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api.dart';
import '../theme/app_theme_tokens.dart';
import 'room_avatar.dart';

/// Shared WeChat-style 「通讯录」 device list pane.
class ContactsListPane extends StatefulWidget {
  final AppWorkspaceController controller;
  final String? selectedPeerId;
  final bool highlightSelectedPeer;
  final ValueChanged<PeerDto> onSelectPeer;
  final VoidCallback onOpenInviteScan;
  final VoidCallback onOpenCreateGroup;

  const ContactsListPane({
    super.key,
    required this.controller,
    required this.selectedPeerId,
    required this.highlightSelectedPeer,
    required this.onSelectPeer,
    required this.onOpenInviteScan,
    required this.onOpenCreateGroup,
  });

  @override
  State<ContactsListPane> createState() => _ContactsListPaneState();
}

class _ContactsListPaneState extends State<ContactsListPane> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final query = _searchCtrl.text.trim().toLowerCase();
    final controller = widget.controller;

    final peers = controller.peers.where((p) {
      if (query.isEmpty) return true;
      final resolved = controller
          .resolveMemberDisplayName(p.nodeId, fallbackName: p.displayName)
          .toLowerCase();
      return resolved.contains(query) ||
          p.displayName.toLowerCase().contains(query) ||
          p.nodeId.toLowerCase().contains(query);
    }).toList();

    final isMobileCard = !widget.highlightSelectedPeer;

    return Container(
      color: tokens.sidebarBg,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobileCard)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    child: Row(
                      children: [
                        Text(
                          s.devicesListTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: isMobileCard
                      ? const EdgeInsets.fromLTRB(16, 4, 16, 10)
                      : const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: isMobileCard ? 14.5 : 13),
                    decoration: InputDecoration(
                      hintText: s.searchPairedDevicesHint,
                      hintStyle: TextStyle(
                        fontSize: isMobileCard ? 14.5 : 12.5,
                        color: tokens.mutedText,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: isMobileCard ? 21 : 18,
                        color: tokens.mutedText,
                      ),
                      prefixIconConstraints: BoxConstraints(
                        minWidth: isMobileCard ? 44 : 34,
                      ),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close,
                                size: isMobileCard ? 18 : 16,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: isMobileCard
                          ? tokens.incomingBubbleBg
                          : tokens.headerBg,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobileCard ? 14 : 10,
                        vertical: isMobileCard ? 13 : 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          isMobileCard ? 28 : tokens.pillRadius,
                        ),
                        borderSide: isMobileCard
                            ? BorderSide.none
                            : BorderSide(color: tokens.subtleBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          isMobileCard ? 28 : tokens.pillRadius,
                        ),
                        borderSide: isMobileCard
                            ? BorderSide.none
                            : BorderSide(color: tokens.subtleBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          isMobileCard ? 28 : tokens.pillRadius,
                        ),
                        borderSide: isMobileCard
                            ? BorderSide.none
                            : BorderSide(color: tokens.accentColor, width: 1.4),
                      ),
                    ),
                  ),
                ),
                if (query.isEmpty) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobileCard ? 16 : 12),
                    child: isMobileCard
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _QuickPillButton(
                                    icon: Icons.person_add_alt_1_outlined,
                                    title: s.btnAddNewDevice,
                                    onTap: widget.onOpenInviteScan,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _QuickPillButton(
                                    icon: Icons.groups_2_outlined,
                                    title: s.btnNewSharedGroup,
                                    onTap: widget.onOpenCreateGroup,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _DesktopFluentActionBtn(
                                  icon: Icons.person_add_alt_1_outlined,
                                  title: s.btnAddDeviceShort,
                                  onTap: widget.onOpenInviteScan,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _DesktopFluentActionBtn(
                                  icon: Icons.groups_2_outlined,
                                  title: s.btnNewGroupShort,
                                  onTap: widget.onOpenCreateGroup,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isMobileCard ? 20 : 14,
                      isMobileCard ? 18 : 8,
                      isMobileCard ? 20 : 14,
                      isMobileCard ? 6 : 4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          s.pairedDevicesCount(peers.length),
                          style: TextStyle(
                            fontSize: isMobileCard ? 17 : 11.5,
                            fontWeight: isMobileCard ? FontWeight.w700 : FontWeight.w600,
                            color: isMobileCard ? scheme.onSurface : tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!isMobileCard) Divider(height: 1, color: tokens.subtleBorder),
              ],
            ),
          ),
          if (peers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    query.isNotEmpty
                        ? s.emptyDevicesSearch
                        : s.emptyDevicesNone,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.mutedText,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: isMobileCard
                  ? const EdgeInsets.fromLTRB(16, 4, 16, 20)
                  : const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
              sliver: SliverList.builder(
                itemCount: peers.length,
                itemBuilder: (context, index) {
                      final peer = peers[index];
                      final selected = widget.highlightSelectedPeer &&
                          peer.nodeId == widget.selectedPeerId;
                      final resolvedName = controller.resolveMemberDisplayName(
                        peer.nodeId,
                        fallbackName: peer.displayName,
                      );
                      final avatarText = controller.resolveMemberAvatar(
                        peer.nodeId,
                        fallbackName: peer.displayName,
                      );
                      final transport =
                          controller.getPeerTransport(peer.nodeId) ?? 'offline';
                      final online = transport != 'offline';
                      final tColor = transportColor(transport);
                      final shortId = peer.nodeId.length > 8
                          ? peer.nodeId.substring(0, 8)
                          : peer.nodeId;
                      final itemRadius =
                          isMobileCard ? 20.0 : tokens.listItemRadius;
                      final cardBg = isMobileCard
                          ? tokens.incomingBubbleBg
                          : (selected
                              ? tokens.sidebarSelectedBg
                              : Colors.transparent);

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: isMobileCard ? 5.5 : 2,
                        ),
                        child: Material(
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(itemRadius),
                            side: selected && !isMobileCard
                                ? BorderSide(color: tokens.subtleBorder)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(itemRadius),
                            onTap: () => widget.onSelectPeer(peer),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobileCard ? 16 : 10,
                                vertical: isMobileCard ? 14 : 9,
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      DeviceAvatar(
                                        radius: isMobileCard ? 24 : 20,
                                        fallbackText: avatarText,
                                        deviceKind:
                                            controller.resolveMemberDeviceKind(
                                          peer.nodeId,
                                          fallbackName: peer.displayName,
                                        ),
                                        imagePath: controller
                                            .resolveMemberAvatarPath(peer.nodeId),
                                        accentColor: tColor,
                                      ),
                                      if (online)
                                        Positioned(
                                          right: -1,
                                          bottom: -1,
                                          child: Container(
                                            width: isMobileCard ? 13 : 11,
                                            height: isMobileCard ? 13 : 11,
                                            decoration: BoxDecoration(
                                              color: tColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isMobileCard
                                                    ? tokens.incomingBubbleBg
                                                    : (selected
                                                        ? tokens.sidebarSelectedBg
                                                        : tokens.sidebarBg),
                                                width: 2.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(width: isMobileCard ? 14 : 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          resolvedName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: isMobileCard ? 16 : 13.5,
                                            fontWeight: isMobileCard
                                                ? FontWeight.w700
                                                : (selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600),
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        SizedBox(height: isMobileCard ? 4 : 2),
                                        if (isMobileCard)
                                          Text(
                                            'ID · $shortId',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: tokens.mutedText,
                                            ),
                                          )
                                        else
                                          Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: transportLabel(transport, s),
                                                  style: TextStyle(
                                                    fontWeight: online
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    color: online
                                                        ? tColor
                                                        : tokens.mutedText,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: ' · ID $shortId',
                                                  style: TextStyle(
                                                    color: tokens.mutedText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11.5),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickPillButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickPillButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final pillBg = isDark ? const Color(0xFF233042) : const Color(0xFFDCE6F2);

    return Material(
      color: pillBg,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: scheme.onSurface),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopFluentActionBtn extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DesktopFluentActionBtn({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: tokens.headerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: tokens.subtleBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: tokens.accentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WeChat-style contact profile card used in Desktop right pane and Mobile
/// contact detail sheet.
class ContactDetailPane extends StatelessWidget {
  final AppWorkspaceController controller;
  final PeerDto? peer;
  final Future<void> Function(PeerDto peer) onStartChat;
  final void Function(PeerDto peer, String resolvedName) onEditProfile;
  final Future<void> Function(PeerDto peer, String resolvedName) onDeletePeer;
  final VoidCallback onOpenScanPair;

  const ContactDetailPane({
    super.key,
    required this.controller,
    required this.peer,
    required this.onStartChat,
    required this.onEditProfile,
    required this.onDeletePeer,
    required this.onOpenScanPair,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final target = peer;

    if (target == null) {
      return Container(
        color: tokens.canvasBg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.devices_other_rounded,
                  size: 52,
                  color: tokens.mutedText.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 14),
                Text(
                  controller.peers.isEmpty
                      ? s.emptyDevicesNone.split('\n').first
                      : s.selectDevicePrompt,
                  style: TextStyle(fontSize: 14, color: tokens.mutedText),
                ),
                if (controller.peers.isEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onOpenScanPair,
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: Text(s.btnScanFirstDevice),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final resolvedName = controller.resolveMemberDisplayName(
      target.nodeId,
      fallbackName: target.displayName,
    );
    final avatarText = controller.resolveMemberAvatar(
      target.nodeId,
      fallbackName: target.displayName,
    );
    final transport = controller.getPeerTransport(target.nodeId) ?? 'offline';
    final tColor = transportColor(transport);

    return Container(
      color: tokens.canvasBg,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        DeviceAvatar(
                          radius: 32,
                          fallbackText: avatarText,
                          deviceKind: controller.resolveMemberDeviceKind(
                            target.nodeId,
                            fallbackName: target.displayName,
                          ),
                          imagePath: controller
                              .resolveMemberAvatarPath(target.nodeId),
                          accentColor: tColor,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resolvedName,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                              if (target.displayName.trim().isNotEmpty &&
                                  target.displayName.trim() != resolvedName)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    s.originalNameLabel(target.displayName),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.mutedText,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: tColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  transportLabel(transport, s),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: tColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(height: 1, color: tokens.subtleBorder),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.deviceNodeIdLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: tokens.mutedText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                target.nodeId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: s.tooltipCopyDeviceId,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: target.nodeId),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(s.toastCopiedDeviceId)),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => onStartChat(target),
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 18),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(s.btnSendMessageOrFile),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onEditProfile(target, resolvedName),
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: Text(s.btnEditRemark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                            onPressed: () => onDeletePeer(target, resolvedName),
                            icon: const Icon(Icons.delete_outline, size: 17),
                            label: Text(s.btnDeleteDevice),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows confirmation and removes [peer] from Contacts + 1v1 DM history.
Future<bool> confirmAndDeletePeer({
  required BuildContext context,
  required AppWorkspaceController controller,
  required PeerDto peer,
  required String resolvedName,
}) async {
  final s = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.deletePeerDialogTitle),
      content: Text(s.deletePeerDialogBody(resolvedName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(s.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(s.btnConfirmDelete),
        ),
      ],
    ),
  );
  if (ok == true) {
    await controller.deletePairedPeer(peer.nodeId);
    return true;
  }
  return false;
}

/// Mobile bottom sheet showing device details & 1-tap actions.
Future<void> showMobileContactSheet({
  required BuildContext context,
  required AppWorkspaceController controller,
  required PeerDto peer,
  required Future<void> Function(PeerDto peer) onStartChat,
  required void Function(PeerDto peer, String resolvedName) onEditProfile,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) {
        final s = AppLocalizations.of(ctx);
        final livePeer = controller.peers.firstWhere(
          (p) => p.nodeId == peer.nodeId,
          orElse: () => peer,
        );
        final resolvedName = controller.resolveMemberDisplayName(
          livePeer.nodeId,
          fallbackName: livePeer.displayName,
        );
        final tokens = AppThemeTokens.of(ctx);
        final avatarText = controller.resolveMemberAvatar(
          livePeer.nodeId,
          fallbackName: livePeer.displayName,
        );
        final transport =
            controller.getPeerTransport(livePeer.nodeId) ?? 'offline';
        final tColor = transportColor(transport);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DeviceAvatar(
                      radius: 26,
                      fallbackText: avatarText,
                      deviceKind: controller.resolveMemberDeviceKind(
                        livePeer.nodeId,
                        fallbackName: livePeer.displayName,
                      ),
                      imagePath:
                          controller.resolveMemberAvatarPath(livePeer.nodeId),
                      accentColor: tColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolvedName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${transportLabel(transport, s)} · ${livePeer.nodeId.substring(0, livePeer.nodeId.length.clamp(0, 14))}...',
                            style: TextStyle(fontSize: 12, color: tColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: s.tooltipCopyDeviceId,
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 19,
                        color: tokens.mutedText,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: livePeer.nodeId),
                        );
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(s.toastCopiedDeviceId)),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await onStartChat(livePeer);
                  },
                  icon:
                      const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(s.btnSendMessageOrFile),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onEditProfile(livePeer, resolvedName);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: Text(s.btnEditRemark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () async {
                          final deleted = await confirmAndDeletePeer(
                            context: ctx,
                            controller: controller,
                            peer: livePeer,
                            resolvedName: resolvedName,
                          );
                          if (deleted && ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: Text(s.btnDeleteDevice),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
