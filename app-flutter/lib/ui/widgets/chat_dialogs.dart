import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';

import '../../controllers/app_workspace_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/avatar_helper.dart';
import '../../services/platform_bridge.dart';
import '../../src/rust/api.dart';
import '../theme/app_theme_tokens.dart';
import 'room_avatar.dart';

Future<void> showCreateRoomDialog(
  BuildContext context,
  AppWorkspaceController controller, {
  Set<String>? initialSelectedIds,
}) async {
  final s = AppLocalizations.of(context);
  final tokens = AppThemeTokens.of(context);
  final peers = controller.peers;
  final selectedIds = initialSelectedIds != null
      ? peers
          .where((p) => initialSelectedIds.contains(p.nodeId))
          .map((p) => p.nodeId)
          .toSet()
      : peers.map((p) => p.nodeId).toSet();
  final nameCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.groups_2_outlined, color: tokens.accentColor),
            const SizedBox(width: 8),
            Expanded(child: Text(s.createGroupTitle)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.createGroupDesc,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tokens.mutedText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.groupNameOptionalLabel,
                    hintText: s.groupNameAutoHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (peers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.sidebarBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.subtleBorder),
                    ),
                    child: Text(
                      s.createGroupNoPeersNotice,
                      style: TextStyle(fontSize: 12, color: tokens.mutedText),
                    ),
                  )
                else ...[
                  Text(
                    s.selectGroupDevicesCount(selectedIds.length),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.mutedText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: peers.map((p) {
                          final checked = selectedIds.contains(p.nodeId);
                          final displayName =
                              controller.resolveMemberDisplayName(
                            p.nodeId,
                            fallbackName: p.displayName,
                          );
                          final avatar = controller.resolveMemberAvatar(
                            p.nodeId,
                            fallbackName: p.displayName,
                          );
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: checked,
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  selectedIds.add(p.nodeId);
                                } else {
                                  selectedIds.remove(p.nodeId);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              radius: 15,
                              backgroundColor:
                                  tokens.accentColor.withValues(alpha: 0.14),
                              child: Text(
                                avatar,
                                style: TextStyle(
                                  fontSize: avatar.runes.length > 1 ? 10 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.accentColor,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            subtitle: Text(
                              p.nodeId.length > 12
                                  ? '${p.nodeId.substring(0, 12)}...'
                                  : p.nodeId,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.mutedText,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.btnCreateGroup),
          ),
        ],
      ),
    ),
  );

  final rawName = nameCtrl.text.trim();
  nameCtrl.dispose();
  if (confirmed != true) return;

  await controller.createGroupWithPeers(rawName, selectedIds.toList());
}

Future<void> _showAddGroupMembersDialog(
  BuildContext context,
  AppWorkspaceController controller,
  List<PeerDto> availablePeers,
) async {
  final s = AppLocalizations.of(context);
  final tokens = AppThemeTokens.of(context);
  final selected = availablePeers.map((p) => p.nodeId).toSet();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(s.addMembersToGroupTitle),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availablePeers.map((p) {
                final checked = selected.contains(p.nodeId);
                final name = controller.resolveMemberDisplayName(
                  p.nodeId,
                  fallbackName: p.displayName,
                );
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == true) {
                        selected.add(p.nodeId);
                      } else {
                        selected.remove(p.nodeId);
                      }
                    });
                  },
                  title: Text(name, style: const TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                    p.nodeId.length > 12
                        ? '${p.nodeId.substring(0, 12)}...'
                        : p.nodeId,
                    style: TextStyle(fontSize: 11, color: tokens.mutedText),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.of(ctx).pop(true),
            child: Text(s.btnConfirmInvite),
          ),
        ],
      ),
    ),
  );
  if (confirmed == true && selected.isNotEmpty) {
    await controller.addMembersToActiveGroup(selected.toList());
  }
}

Future<void> showInviteContactsToActiveGroupDialog(
  BuildContext context,
  AppWorkspaceController controller,
) async {
  final s = AppLocalizations.of(context);
  final room = controller.activeRoom;
  if (room == null || room.roomType == 'dm') return;
  final members = controller.activeRegularMembers;
  final availableToAdd = controller.peers
      .where((p) => !members.any((m) => m.nodeId == p.nodeId))
      .toList();
  if (availableToAdd.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.allPeersAlreadyInGroupToast)),
    );
    return;
  }
  await _showAddGroupMembersDialog(context, controller, availableToAdd);
}

void showRoomMembersDialog({
  required BuildContext context,
  required AppWorkspaceController controller,
  required String myEndpointId,
  required VoidCallback onOpenInvite,
}) {
  final room = controller.activeRoom;
  if (room == null) return;
  final isDm = room.roomType == 'dm';
  final tokens = AppThemeTokens.of(context);
  final useBottomSheet =
      !tokens.isDesktop && MediaQuery.sizeOf(context).width < 640;

  Widget buildMembersBody(BuildContext ctx) {
    final s = AppLocalizations.of(ctx);
    final scheme = Theme.of(ctx).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) {
        final rawMembers = controller.activeRegularMembers;
        final members = [
          ...rawMembers.where((m) => m.nodeId == myEndpointId),
          ...rawMembers.where((m) => m.nodeId != myEndpointId),
        ];
        final roomTitle = controller.resolveRoomTitle(room);
        final availableToAdd = isDm
            ? const <PeerDto>[]
            : controller.peers
                .where((p) => !members.any((m) => m.nodeId == p.nodeId))
                .toList();
        final dmPeerId = isDm ? controller.resolveDmPeerId(room) : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                RoomAvatar(
                  room: room,
                  size: 38,
                  peerAvatarPath: dmPeerId != null
                      ? controller.resolveMemberAvatarPath(dmPeerId)
                      : null,
                  peerDeviceKind: dmPeerId != null
                      ? controller.resolveMemberDeviceKind(
                          dmPeerId,
                          fallbackName: roomTitle,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomTitle,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: scheme.onSurface,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDm
                            ? s.subtitleDmE2ee
                            : s.subtitleGroupE2ee(members.length),
                        style: TextStyle(fontSize: 12, color: tokens.mutedText),
                      ),
                    ],
                  ),
                ),
                if (!isDm)
                  IconButton(
                    tooltip: s.tooltipEditGroupName,
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    onPressed: () => showEditRoomNameDialog(
                      context: ctx,
                      controller: controller,
                      room: room,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...members.map((m) {
                      final isSelf = m.nodeId == myEndpointId;
                      final resolvedName = controller.resolveMemberDisplayName(
                        m.nodeId,
                        fallbackName: m.displayName,
                      );
                      final resolvedAvatar = controller.resolveMemberAvatar(
                        m.nodeId,
                        fallbackName: m.displayName,
                      );
                      final transport = isSelf
                          ? s.badgeThisTerminal
                          : transportLabel(
                              controller.getPeerTransport(m.nodeId) ?? 'offline',
                              s,
                            );
                      final color = isSelf
                          ? tokens.accentColor
                          : transportColor(
                              controller.getPeerTransport(m.nodeId) ?? 'offline',
                            );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.sidebarBg,
                          borderRadius:
                              BorderRadius.circular(tokens.cardRadius * 0.8),
                          border: tokens.cardBorderWidth > 0
                              ? Border.all(
                                  color: tokens.subtleBorder,
                                  width: tokens.cardBorderWidth,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            DeviceAvatar(
                              radius: 19,
                              imagePath:
                                  controller.resolveMemberAvatarPath(m.nodeId),
                              fallbackText: resolvedAvatar,
                              deviceKind: controller.resolveMemberDeviceKind(
                                m.nodeId,
                                fallbackName: m.displayName,
                                role: m.role,
                              ),
                              accentColor: isSelf
                                  ? tokens.accentColor
                                  : const Color(0xFF2E7D32),
                              backgroundColor: isSelf
                                  ? tokens.accentColor.withValues(alpha: 0.14)
                                  : null,
                              foregroundColor: isSelf
                                  ? tokens.accentColor
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    resolvedName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                      height: 1.2,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          transport,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${isSelf ? s.roleThisDevice : (isDm ? s.rolePeerDevice : s.roleGroupMember)} · ${m.nodeId.substring(0, m.nodeId.length.clamp(0, 8))}...',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: tokens.mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: isSelf
                                  ? s.tooltipEditSelfProfile
                                  : s.tooltipEditPeerRemark,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: tokens.mutedText,
                              ),
                              onPressed: () => showEditProfileDialog(
                                context: context,
                                controller: controller,
                                myEndpointId: myEndpointId,
                                nodeId: m.nodeId,
                                initialDisplayName: resolvedName,
                                rawDefaultName: m.displayName,
                              ),
                            ),
                            if (!isDm && !isSelf)
                              IconButton(
                                tooltip: s.tooltipRemoveFromGroup,
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.person_remove_outlined,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () =>
                                    controller.removeMemberFromActiveGroup(
                                  m.nodeId,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (!isDm && availableToAdd.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showAddGroupMembersDialog(
                      ctx,
                      controller,
                      availableToAdd,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: Text(s.btnAddDeviceShort),
                  ),
                if (isDm && dmPeerId != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: Text(s.deletePeerDialogTitle),
                          content: Text(s.deletePeerQuickConfirm(roomTitle)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dctx).pop(false),
                              child: Text(s.cancel),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              onPressed: () => Navigator.of(dctx).pop(true),
                              child: Text(s.btnConfirmDelete),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await controller.deletePairedPeer(dmPeerId);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(s.btnDeleteDevice),
                  )
                else if (!isDm)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: Text(s.deleteGroupTitle),
                          content: Text(s.deleteGroupConfirm(roomTitle)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dctx).pop(false),
                              child: Text(s.cancel),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              onPressed: () => Navigator.of(dctx).pop(true),
                              child: Text(s.btnConfirmDelete),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await controller.deleteChatRoom(room.roomId);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(s.btnDeleteAndLeave),
                  ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onOpenInvite();
                  },
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: Text(
                    isDm ? s.tabDevicePairingQr : s.btnInviteNewDevice,
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(s.close),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  if (useBottomSheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
            ),
            child: buildMembersBody(ctx),
          ),
        ),
      ),
    );
    return;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: buildMembersBody(ctx),
        ),
      ),
    ),
  );
}

Future<void> showEditRoomNameDialog({
  required BuildContext context,
  required AppWorkspaceController controller,
  required RoomDto room,
}) async {
  final s = AppLocalizations.of(context);
  final defaultRoomName = controller.resolveDefaultRoomName(room);
  final currentResolved = controller.resolveRoomTitle(room);
  final hasCustom = currentResolved != defaultRoomName &&
      currentResolved != room.name;
  final nameCtrl = TextEditingController(
    text: hasCustom ? currentResolved : '',
  );

  final result = await showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.editGroupNameTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            maxLength: 32,
            decoration: InputDecoration(
              labelText: s.localDisplayNameLabel,
              hintText: defaultRoomName,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          const SizedBox(height: 4),
          Text(
            s.editGroupNameHint(defaultRoomName),
            style: TextStyle(
              fontSize: 12,
              color: AppThemeTokens.of(ctx).mutedText,
            ),
          ),
        ],
      ),
      actions: [
        if (hasCustom)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: Text(s.resetDefault),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(nameCtrl.text),
          child: Text(s.save),
        ),
      ],
    ),
  );
  nameCtrl.dispose();
  if (result == null) return;
  await controller.updateRoomNickname(room.roomId, result);
}

Future<void> showEditProfileDialog({
  required BuildContext context,
  required AppWorkspaceController controller,
  required String myEndpointId,
  required String nodeId,
  required String initialDisplayName,
  String? rawDefaultName,
}) async {
  final s = AppLocalizations.of(context);
  final tokens = AppThemeTokens.of(context);
  final isSelf = nodeId == myEndpointId;
  final override = controller.getProfileOverride(nodeId);
  final fallbackModel = isSelf
      ? controller.hardwareModelName
      : (rawDefaultName != null &&
                rawDefaultName.trim().isNotEmpty &&
                rawDefaultName.trim() != '本机设备' &&
                rawDefaultName.trim() != '对端设备'
            ? rawDefaultName.trim()
            : initialDisplayName);

  final nameCtrl = TextEditingController(text: override.nickname ?? '');
  final existingAvatarPath = controller.resolveMemberAvatarPath(nodeId);
  Uint8List? pendingAvatarBytes;
  bool clearAvatar = false;
  bool pickingImage = false;
  bool copiedId = false;
  bool dialogDisposed = false;
  String? imageError;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final effectiveName = nameCtrl.text.trim().isNotEmpty
            ? nameCtrl.text.trim()
            : fallbackModel;
        final previewInitial = AppWorkspaceController.firstGrapheme(effectiveName);

        Future<void> pickImage() async {
          if (!isSelf || pickingImage) return;
          setDialogState(() {
            pickingImage = true;
            imageError = null;
          });
          try {
            final res = await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: false,
            );
            final pickedPath = res?.files.single.path;
            if (pickedPath != null && pickedPath.isNotEmpty) {
              final compressed = await compressAvatarImageFile(pickedPath);
              if (ctx.mounted) {
                setDialogState(() {
                  pendingAvatarBytes = compressed;
                  clearAvatar = false;
                });
              }
            }
          } catch (e) {
            if (ctx.mounted) {
              setDialogState(() => imageError = s.processImageFailed(e));
            }
          } finally {
            if (ctx.mounted) {
              setDialogState(() => pickingImage = false);
            }
          }
        }

        final hasPendingBytes = pendingAvatarBytes != null;
        final hasDiskImage =
            !clearAvatar && existingAvatarPath != null && existingAvatarPath.isNotEmpty;
        final hasAnyPhoto = hasPendingBytes || hasDiskImage;

        Widget buildLargePreview() {
          if (hasPendingBytes) {
            return ClipOval(
              child: Image.memory(
                pendingAvatarBytes!,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
              ),
            );
          }
          return DeviceAvatar(
            radius: 38,
            fallbackText: previewInitial,
            deviceKind: controller.resolveMemberDeviceKind(
              nodeId,
              fallbackName: initialDisplayName,
            ),
            imagePath: hasDiskImage ? existingAvatarPath : null,
            accentColor: tokens.accentColor,
          );
        }

        return AlertDialog(
          title: Text(
            isSelf ? s.editProfileSelfTitle : s.editProfilePeerTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(48),
                      onTap: isSelf ? pickImage : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          buildLargePreview(),
                          if (isSelf)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: tokens.accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: tokens.headerBg,
                                    width: 2,
                                  ),
                                ),
                                child: pickingImage
                                    ? const Padding(
                                        padding: EdgeInsets.all(5),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isSelf) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: pickingImage ? null : pickImage,
                          icon: const Icon(Icons.photo_library_outlined, size: 17),
                          label: Text(
                            hasAnyPhoto ? s.btnChangeAvatar : s.btnUploadAvatar,
                          ),
                        ),
                        if (hasAnyPhoto)
                          OutlinedButton.icon(
                            onPressed: pickingImage
                                ? null
                                : () => setDialogState(() {
                                      pendingAvatarBytes = null;
                                      clearAvatar = true;
                                      imageError = null;
                                    }),
                            icon: const Icon(Icons.delete_outline, size: 17),
                            label: Text(s.btnRemoveImage),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      imageError ?? s.avatarSyncNoticeSelf,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: imageError != null ? Colors.redAccent : tokens.mutedText,
                      ),
                    ),
                  ] else
                    Text(
                      s.avatarSyncNoticePeer,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: tokens.mutedText),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: isSelf
                          ? s.selfDisplayNameLabel
                          : s.peerRemarkNameLabel,
                      hintText: s.customDeviceNameHint,
                      border: const OutlineInputBorder(),
                      suffixIcon: nameCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: s.clear,
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                nameCtrl.clear();
                                setDialogState(() {});
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.defaultNameDisplay(fallbackModel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: tokens.mutedText),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          nameCtrl.clear();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.restore, size: 16),
                        label: Text(
                          s.resetDefault,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: tokens.sidebarBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.subtleBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.deviceIdLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.mutedText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SelectableText(
                                nodeId,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: nodeId));
                            if (!dialogDisposed && ctx.mounted) {
                              setDialogState(() => copiedId = true);
                              Future.delayed(
                                const Duration(milliseconds: 1600),
                                () {
                                  if (!dialogDisposed && ctx.mounted) {
                                    setDialogState(() => copiedId = false);
                                  }
                                },
                              );
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(s.toastCopiedFullDeviceId),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            copiedId
                                ? Icons.check_rounded
                                : Icons.copy_rounded,
                            size: 16,
                            color: copiedId ? Colors.green : null,
                          ),
                          label: Text(
                            copiedId
                                ? s.deviceIdCopiedBadge
                                : s.tooltipCopyDeviceId,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: pickingImage ? null : () => Navigator.of(ctx).pop(true),
              child: Text(s.save),
            ),
          ],
        );
      },
    ),
  );

  dialogDisposed = true;
  final nextNick = nameCtrl.text.trim();
  nameCtrl.dispose();

  if (saved == true) {
    await controller.updateDeviceProfile(
      nodeId: nodeId,
      nickname: nextNick.isEmpty ? null : nextNick,
      avatarPngBytes: isSelf ? pendingAvatarBytes : null,
      clearAvatar: isSelf && clearAvatar,
    );
  }
}

typedef RoomOrPeerSelection = ({RoomDto? room, PeerDto? peer});

enum _ShareConfirmAction { send, reselect, cancel }

String _basenameOfPath(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  return parts.isNotEmpty && parts.last.isNotEmpty ? parts.last : path;
}

int _safeFileSize(String path) {
  try {
    final f = File(path);
    return f.existsSync() ? f.lengthSync() : 0;
  } catch (_) {
    return 0;
  }
}

/// Shows the WeChat-style two-step external share flow:
/// 1) Pick a target room or paired device («分享到...»)
/// 2) Confirm in a compact preview card («发送给 Target»), with «重选» support.
/// Returns the confirmed target, or `null` if cancelled.
Future<RoomOrPeerSelection?> showExternalShareDialog(
  BuildContext context,
  AppWorkspaceController controller,
  List<SharedPayloadItem> items,
) async {
  final s = AppLocalizations.of(context);
  final filePaths = items
      .where((i) => i.type == 'file' && i.value.trim().isNotEmpty)
      .map((i) => i.value.trim())
      .toList();
  final texts = items
      .where((i) => i.type == 'text' && i.value.trim().isNotEmpty)
      .map((i) => i.value.trim())
      .toList();
  if (filePaths.isEmpty && texts.isEmpty) return null;

  final tokens = AppThemeTokens.of(context);
  final summaryHeader = _buildExternalShareSummaryBanner(
    s: s,
    tokens: tokens,
    filePaths: filePaths,
    texts: texts,
  );

  while (true) {
    if (!context.mounted) return null;
    final picked = await _showRoomOrPeerPickerDialog(
      context: context,
      controller: controller,
      title: s.shareToTitle,
      titleIcon: Icons.share_outlined,
      headerWidget: summaryHeader,
      currentRoomLast: false,
      trailingIcon: Icons.chevron_right_rounded,
    );
    if (picked == null || !context.mounted) return null;

    final action = await _showShareConfirmCard(
      context: context,
      controller: controller,
      target: picked,
      filePaths: filePaths,
      texts: texts,
    );
    if (action == _ShareConfirmAction.send) {
      return picked;
    }
    if (action != _ShareConfirmAction.reselect) {
      return null;
    }
  }
}

Widget _buildExternalShareSummaryBanner({
  required AppStrings s,
  required AppThemeTokens tokens,
  required List<String> filePaths,
  required List<String> texts,
}) {
  final allImages =
      filePaths.isNotEmpty && filePaths.every((p) => isImageFileName(_basenameOfPath(p)));
  final totalBytes = filePaths.fold<int>(0, (sum, p) => sum + _safeFileSize(p));

  final String summaryText;
  if (filePaths.isNotEmpty) {
    final firstName = _basenameOfPath(filePaths.first);
    if (filePaths.length == 1) {
      summaryText = s.shareSummarySingle(
        allImages,
        firstName,
        formatBytes(totalBytes),
      );
    } else {
      summaryText = s.shareSummaryMulti(
        filePaths.length,
        allImages,
        formatBytes(totalBytes),
      );
    }
  } else {
    summaryText = s.shareSummaryText(texts.join('\n'));
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: tokens.inputFillBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        if (filePaths.length == 1 && allImages)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(filePaths.first),
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                cacheWidth: 100,
                errorBuilder: (_, _, _) => Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: tokens.accentColor,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              filePaths.isNotEmpty
                  ? (allImages ? Icons.photo_library_outlined : Icons.insert_drive_file_outlined)
                  : Icons.text_snippet_outlined,
              size: 20,
              color: tokens.accentColor,
            ),
          ),
        Expanded(
          child: Text(
            summaryText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: tokens.mutedText),
          ),
        ),
      ],
    ),
  );
}

Future<_ShareConfirmAction> _showShareConfirmCard({
  required BuildContext context,
  required AppWorkspaceController controller,
  required RoomOrPeerSelection target,
  required List<String> filePaths,
  required List<String> texts,
}) async {
  final s = AppLocalizations.of(context);
  final tokens = AppThemeTokens.of(context);
  final scheme = Theme.of(context).colorScheme;
  final totalCount = filePaths.length + texts.length;
  final totalBytes = filePaths.fold<int>(0, (sum, p) => sum + _safeFileSize(p));
  final allImages =
      filePaths.isNotEmpty && filePaths.every((p) => isImageFileName(_basenameOfPath(p)));

  final room = target.room;
  final peer = target.peer;
  final targetTitle = room != null
      ? controller.resolveRoomTitle(room)
      : controller.resolveMemberDisplayName(
          peer!.nodeId,
          fallbackName: peer.displayName,
        );
  final dmPeerId = room != null ? controller.resolveDmPeerId(room) : peer?.nodeId;
  final targetSubtitle = room != null
      ? (room.roomType == 'dm'
          ? s.targetTypeDm
          : s.targetTypeGroup(room.memberCount))
      : s.targetTypePairedPeer;

  final res = await showDialog<_ShareConfirmAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        s.sendToTitle,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (room != null)
                  RoomAvatar(
                    room: room,
                    size: 40,
                    peerAvatarPath: dmPeerId != null
                        ? controller.resolveMemberAvatarPath(dmPeerId)
                        : null,
                    peerFallbackText: dmPeerId != null
                        ? controller.resolveMemberAvatar(
                            dmPeerId,
                            fallbackName: targetTitle,
                          )
                        : null,
                    peerDeviceKind: dmPeerId != null
                        ? controller.resolveMemberDeviceKind(
                            dmPeerId,
                            fallbackName: targetTitle,
                          )
                        : null,
                  )
                else if (peer != null)
                  DeviceAvatar(
                    fallbackText: controller.resolveMemberAvatar(
                      peer.nodeId,
                      fallbackName: targetTitle,
                    ),
                    deviceKind: controller.resolveMemberDeviceKind(
                      peer.nodeId,
                      fallbackName: peer.displayName,
                    ),
                    imagePath: controller.resolveMemberAvatarPath(peer.nodeId),
                    radius: 20,
                    accentColor: tokens.accentColor,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        targetSubtitle,
                        style: TextStyle(fontSize: 12, color: tokens.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: tokens.subtleBorder),
            const SizedBox(height: 14),
            if (filePaths.length == 1 && allImages)
              _buildSingleImageConfirmPreview(
                path: filePaths.first,
                totalBytes: totalBytes,
                tokens: tokens,
              )
            else if (filePaths.length > 1 && allImages)
              _buildMultiImageConfirmPreview(
                s: s,
                filePaths: filePaths,
                totalBytes: totalBytes,
                tokens: tokens,
              )
            else if (filePaths.isNotEmpty)
              _buildFileListConfirmPreview(
                s: s,
                filePaths: filePaths,
                totalBytes: totalBytes,
                tokens: tokens,
                scheme: scheme,
              ),
            if (texts.isNotEmpty) ...[
              if (filePaths.isNotEmpty) const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.inputFillBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  texts.join('\n'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_ShareConfirmAction.reselect),
          child: Text(s.btnReselect),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_ShareConfirmAction.cancel),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(_ShareConfirmAction.send),
          style: FilledButton.styleFrom(
            backgroundColor: tokens.accentColor,
            foregroundColor: Colors.white,
          ),
          child: Text(totalCount > 1 ? s.btnSendCount(totalCount) : s.btnSend),
        ),
      ],
    ),
  );
  return res ?? _ShareConfirmAction.cancel;
}

Widget _buildSingleImageConfirmPreview({
  required String path,
  required int totalBytes,
  required AppThemeTokens tokens,
}) {
  final name = _basenameOfPath(path);
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                height: 110,
                width: 140,
                color: tokens.inputFillBg,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined, color: tokens.mutedText),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '$name · ${formatBytes(totalBytes)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: tokens.mutedText),
      ),
    ],
  );
}

Widget _buildMultiImageConfirmPreview({
  required AppStrings s,
  required List<String> filePaths,
  required int totalBytes,
  required AppThemeTokens tokens,
}) {
  const maxThumbs = 6;
  final shown = filePaths.take(maxThumbs).toList();
  final overflow = filePaths.length - shown.length;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < shown.length; i++)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(shown[i]),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    errorBuilder: (_, _, _) => Container(
                      width: 56,
                      height: 56,
                      color: tokens.inputFillBg,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 20,
                        color: tokens.mutedText,
                      ),
                    ),
                  ),
                ),
                if (i == shown.length - 1 && overflow > 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+$overflow',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        s.shareSummaryMulti(filePaths.length, true, formatBytes(totalBytes)),
        style: TextStyle(fontSize: 12, color: tokens.mutedText),
      ),
    ],
  );
}

Widget _buildFileListConfirmPreview({
  required AppStrings s,
  required List<String> filePaths,
  required int totalBytes,
  required AppThemeTokens tokens,
  required ColorScheme scheme,
}) {
  final shown = filePaths.take(3).toList();
  final extra = filePaths.length - shown.length;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: tokens.inputFillBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  isImageFileName(_basenameOfPath(p))
                      ? Icons.image_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 17,
                  color: tokens.accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _basenameOfPath(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          extra > 0
              ? s.shareFileListMore(filePaths.length, formatBytes(totalBytes))
              : s.shareFileListExact(filePaths.length, formatBytes(totalBytes)),
          style: TextStyle(fontSize: 11.5, color: tokens.mutedText),
        ),
      ],
    ),
  );
}

Future<void> showForwardMessageDialog(
  BuildContext context,
  AppWorkspaceController controller,
  MessageDto msg,
) async {
  final s = AppLocalizations.of(context);
  final tokens = AppThemeTokens.of(context);
  final isImage = msg.isFile && isImageFileName(msg.fileName ?? '');
  final summaryLabel = msg.isFile
      ? s.forwardSummaryFile(isImage, msg.fileName ?? 'file.bin')
      : s.forwardSummaryText((msg.bodyText ?? '').trim());

  final picked = await _showRoomOrPeerPickerDialog(
    context: context,
    controller: controller,
    title: s.forwardToTitle,
    titleIcon: Icons.shortcut_rounded,
    headerWidget: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.inputFillBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        summaryLabel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: tokens.mutedText),
      ),
    ),
    currentRoomLast: true,
    trailingIcon: Icons.send_rounded,
  );
  if (picked == null) return;

  if (picked.room != null) {
    await controller.forwardMessageToRoom(
      message: msg,
      targetRoomId: picked.room!.roomId,
    );
  } else if (picked.peer != null) {
    await controller.forwardMessageToPeer(
      message: msg,
      peerId: picked.peer!.nodeId,
    );
  }
}

Future<RoomOrPeerSelection?> _showRoomOrPeerPickerDialog({
  required BuildContext context,
  required AppWorkspaceController controller,
  required String title,
  required IconData titleIcon,
  required Widget headerWidget,
  required bool currentRoomLast,
  required IconData trailingIcon,
}) async {
  final s = AppLocalizations.of(context);
  final tokens = AppThemeTokens.of(context);
  final activeRoomId = controller.activeRoom?.roomId;

  // Build deduplicated targets: existing rooms + paired peers without a DM room yet.
  final dmPeerIdsWithRooms = <String>{};
  final otherRooms = <RoomDto>[];
  final currentRooms = <RoomDto>[];
  for (final r in controller.rooms) {
    final dmPeerId = controller.resolveDmPeerId(r);
    if (dmPeerId != null) dmPeerIdsWithRooms.add(dmPeerId);
    if (currentRoomLast && r.roomId == activeRoomId) {
      currentRooms.add(r);
    } else {
      otherRooms.add(r);
    }
  }
  final orderedRooms = [...otherRooms, ...currentRooms];
  final extraPeers = controller.peers
      .where((p) => !dmPeerIdsWithRooms.contains(p.nodeId))
      .toList();

  var query = '';

  return showDialog<RoomOrPeerSelection>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final q = query.trim().toLowerCase();
        final filteredRooms = orderedRooms.where((r) {
          if (q.isEmpty) return true;
          return controller.resolveRoomTitle(r).toLowerCase().contains(q);
        }).toList();
        final filteredPeers = extraPeers.where((p) {
          if (q.isEmpty) return true;
          final name = controller
              .resolveMemberDisplayName(p.nodeId, fallbackName: p.displayName)
              .toLowerCase();
          return name.contains(q);
        }).toList();

        return AlertDialog(
          title: Row(
            children: [
              Icon(titleIcon, color: tokens.accentColor),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerWidget,
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setDialogState(() => query = v),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: s.searchRoomOrDeviceHint,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: tokens.inputFillBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.pillRadius),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (filteredRooms.isEmpty && filteredPeers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        orderedRooms.isEmpty && extraPeers.isEmpty
                            ? s.noAvailableTargets
                            : s.noMatchingTargets,
                        style: TextStyle(color: tokens.mutedText, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in filteredRooms)
                          _buildTargetRoomTile(
                            ctx,
                            s,
                            controller,
                            r,
                            isCurrentRoom: currentRoomLast && r.roomId == activeRoomId,
                            tokens: tokens,
                            trailingIcon: trailingIcon,
                            onSelect: () => Navigator.of(ctx).pop((room: r, peer: null)),
                          ),
                        for (final p in filteredPeers)
                          _buildTargetPeerTile(
                            ctx,
                            s,
                            controller,
                            p,
                            tokens: tokens,
                            trailingIcon: trailingIcon,
                            onSelect: () => Navigator.of(ctx).pop((room: null, peer: p)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(s.cancel),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildTargetRoomTile(
  BuildContext context,
  AppStrings s,
  AppWorkspaceController controller,
  RoomDto room, {
  required bool isCurrentRoom,
  required AppThemeTokens tokens,
  required IconData trailingIcon,
  required VoidCallback onSelect,
}) {
  final title = controller.resolveRoomTitle(room);
  final dmPeerId = controller.resolveDmPeerId(room);
  final avatarPath =
      dmPeerId != null ? controller.resolveMemberAvatarPath(dmPeerId) : null;
  final fallback = dmPeerId != null
      ? controller.resolveMemberAvatar(dmPeerId, fallbackName: title)
      : null;

  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    leading: RoomAvatar(
      room: room,
      size: 36,
      peerAvatarPath: avatarPath,
      peerFallbackText: fallback,
      peerDeviceKind: dmPeerId != null
          ? controller.resolveMemberDeviceKind(
              dmPeerId,
              fallbackName: title,
            )
          : null,
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    subtitle: Text(
      isCurrentRoom
          ? s.currentConversationLabel
          : (room.roomType == 'dm'
              ? s.targetTypeDm
              : s.targetTypeGroup(room.memberCount)),
      style: TextStyle(fontSize: 11.5, color: tokens.mutedText),
    ),
    trailing: Icon(
      trailingIcon,
      size: 18,
      color: tokens.accentColor,
    ),
    onTap: onSelect,
  );
}

Widget _buildTargetPeerTile(
  BuildContext context,
  AppStrings s,
  AppWorkspaceController controller,
  PeerDto peer, {
  required AppThemeTokens tokens,
  required IconData trailingIcon,
  required VoidCallback onSelect,
}) {
  final title = controller.resolveMemberDisplayName(
    peer.nodeId,
    fallbackName: peer.displayName,
  );
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    leading: DeviceAvatar(
      fallbackText: controller.resolveMemberAvatar(
        peer.nodeId,
        fallbackName: title,
      ),
      deviceKind: controller.resolveMemberDeviceKind(
        peer.nodeId,
        fallbackName: peer.displayName,
      ),
      imagePath: controller.resolveMemberAvatarPath(peer.nodeId),
      radius: 18,
      accentColor: tokens.accentColor,
    ),
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    subtitle: Text(
      s.targetTypePairedPeer,
      style: TextStyle(fontSize: 11.5, color: tokens.mutedText),
    ),
    trailing: Icon(
      trailingIcon,
      size: 18,
      color: tokens.accentColor,
    ),
    onTap: onSelect,
  );
}

Future<void> showImagePreviewDialog(
  BuildContext context,
  String filePath,
  String fileName, {
  VoidCallback? onForward,
  VoidCallback? onDeleteRecord,
}) async {
  final s = AppLocalizations.of(context);
  final trimmedPath = filePath.trim();
  final fileExists = trimmedPath.isNotEmpty && File(trimmedPath).existsSync();

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: fileExists
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(
                      child: Image.file(
                        File(trimmedPath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => _DeletedImagePreviewState(
                          fileName: fileName,
                          onDeleteRecord: onDeleteRecord == null
                              ? null
                              : () {
                                  Navigator.of(ctx).pop();
                                  onDeleteRecord();
                                },
                          onClose: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ),
                  )
                : _DeletedImagePreviewState(
                    fileName: fileName,
                    onDeleteRecord: onDeleteRecord == null
                        ? null
                        : () {
                            Navigator.of(ctx).pop();
                            onDeleteRecord();
                          },
                    onClose: () => Navigator.of(ctx).pop(),
                  ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (fileExists && onForward != null)
                      IconButton(
                        tooltip: s.actionForward,
                        icon: const Icon(
                          Icons.shortcut_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onForward();
                        },
                      ),
                    if (fileExists && Platform.isWindows)
                      IconButton(
                        tooltip: s.actionRevealInFolder,
                        icon: const Icon(Icons.folder_open, color: Colors.white),
                        onPressed: () =>
                            PlatformBridge.revealFileInFolder(trimmedPath),
                      ),
                    if (fileExists)
                      IconButton(
                        tooltip: s.tooltipOpenWithDefaultApp,
                        icon: const Icon(Icons.open_in_new, color: Colors.white),
                        onPressed: () => OpenFilex.open(trimmedPath),
                      ),
                    if (onDeleteRecord != null)
                      IconButton(
                        tooltip: s.tooltipDeleteMessage,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onDeleteRecord();
                        },
                      ),
                    IconButton(
                      tooltip: s.tooltipClosePreview,
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DeletedImagePreviewState extends StatelessWidget {
  final String fileName;
  final VoidCallback? onDeleteRecord;
  final VoidCallback onClose;

  const _DeletedImagePreviewState({
    required this.fileName,
    this.onDeleteRecord,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2429),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.broken_image_outlined,
                  size: 32,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.deletedImagePreviewTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                s.deletedImagePreviewBody(fileName),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (onDeleteRecord != null)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD93025),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onDeleteRecord,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(s.btnDeleteThisRecord),
                    ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                    ),
                    onPressed: onClose,
                    child: Text(s.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WhatsApp-style delete & remote-revoke dialog.
///
/// Strict guarantee: for outgoing messages (`msg.isOutgoing`), the sender's
/// local source file at `msg.localPath` is NEVER offered for deletion and NEVER touched.
Future<void> showDeleteMessageConfirmDialog(
  BuildContext context,
  AppWorkspaceController controller,
  MessageDto msg,
) async {
  final s = AppLocalizations.of(context);
  final tokens = AppThemeTokens.of(context);
  if (msg.status == 'revoked') {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.removeRevokeNoticeTitle),
        content: Text(s.removeRevokeNoticeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD93025),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.remove),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await controller.deleteMessageForMe(msg, deleteReceivedFile: false);
    }
    return;
  }

  if (msg.isOutgoing) {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          msg.isFile ? s.deleteOutgoingFileTitle : s.deleteOutgoingTextTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.chooseDeleteMethod,
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              msg.isFile
                  ? s.deleteOutgoingFileDetail
                  : s.deleteOutgoingTextDetail,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: tokens.mutedText,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('local'),
            child: Text(s.btnRemoveLocalOnly),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD93025),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop('revoke'),
            icon: const Icon(Icons.undo_rounded, size: 17),
            label: Text(s.btnRevokeForAll),
          ),
        ],
      ),
    );

    if (choice == 'revoke') {
      await controller.revokeMessageForAll(msg);
    } else if (choice == 'local') {
      await controller.deleteMessageForMe(msg, deleteReceivedFile: false);
    }
    return;
  }

  final localPath = msg.localPath?.trim() ?? '';
  final hasReceivedFile =
      msg.isFile && localPath.isNotEmpty && File(localPath).existsSync();
  var deleteLocalFile = hasReceivedFile;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(
          msg.isFile ? s.deleteIncomingFileTitle : s.deleteIncomingTextTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.deleteIncomingNote,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: tokens.mutedText,
              ),
            ),
            if (hasReceivedFile) ...[
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: deleteLocalFile,
                onChanged: (v) => setState(() => deleteLocalFile = v ?? true),
                title: Text(
                  s.checkboxDeleteLocalFile,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  msg.fileName ?? localPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ] else if (msg.isFile) ...[
              const SizedBox(height: 8),
              Text(
                s.incomingFileAlreadyMissing,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.mutedText,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD93025),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    ),
  );

  if (confirm == true) {
    await controller.deleteMessageForMe(
      msg,
      deleteReceivedFile: hasReceivedFile && deleteLocalFile,
    );
  }
}
