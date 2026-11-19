import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';

import '../../controllers/app_workspace_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/platform_bridge.dart';
import '../../services/thumbnail_cache_service.dart';
import '../../src/rust/api.dart';
import '../theme/app_theme_tokens.dart';
import 'chat_dialogs.dart';
import 'room_avatar.dart';

class MessageBubble extends StatelessWidget {
  final MessageDto msg;
  final String myEndpointId;
  final AppWorkspaceController controller;
  final void Function(String nodeId, String displayName) onEditMemberProfile;
  final void Function(String filePath, String fileName) onOpenImagePreview;
  final void Function(MessageDto msg)? onForwardMessage;
  final void Function(MessageDto msg)? onDeleteMessage;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.myEndpointId,
    required this.controller,
    required this.onEditMemberProfile,
    required this.onOpenImagePreview,
    this.onForwardMessage,
    this.onDeleteMessage,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    final isMe = msg.isOutgoing;
    final bgColor = isMe ? tokens.outgoingBubbleBg : tokens.incomingBubbleBg;
    final textColor =
        isMe ? tokens.outgoingBubbleText : tokens.incomingBubbleText;
    final timeLabel = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(msg.createdAtMs),
    );
    final effectiveNodeId =
        controller.resolveEffectiveSenderNodeId(msg.senderId);
    final senderName = controller.resolveMemberDisplayName(msg.senderId);
    final senderColor = senderAccentColor(
      effectiveNodeId.isNotEmpty ? effectiveNodeId : msg.senderId,
    );

    final regularOthersCount = controller.activeRegularMembers
        .where((m) => m.nodeId != myEndpointId)
        .length;
    final isDmRoom = controller.activeRoom?.roomType == 'dm';
    final showSenderName = !isMe && !isDmRoom && senderName.isNotEmpty;
    final isAwaitingConfirm = isMe &&
        msg.isFile &&
        msg.deliveryScope == 'awaiting_confirm' &&
        msg.status != 'delivered';
    final isGroupOfferOutgoing = isMe &&
        msg.isFile &&
        msg.deliveryScope == 'group_offer' &&
        msg.status != 'delivered';
    final isAwaitingDownload =
        !isMe && msg.isFile && msg.status == 'awaiting_download';
    final isFullyAcked = isMe &&
        msg.status == 'delivered' &&
        (regularOthersCount == 0 ||
            msg.ackedPeers.length >= regularOthersCount);

    String statusLabel = isAwaitingConfirm
        ? s.statusLargeFileAwaitConfirm
        : isAwaitingDownload
            ? s.statusGroupFileAwaitDownload
            : messageStatusText(msg.status, s);
    if (isAwaitingDownload) {
      statusLabel = s.statusGroupFileAwaitDownload;
    } else if (isGroupOfferOutgoing) {
      statusLabel =
          s.groupOfferCardsSent(msg.ackedPeers.length, regularOthersCount);
    } else if (isMe && regularOthersCount > 0) {
      final acks = msg.ackedPeers.length;
      if (isDmRoom) {
        if (isAwaitingConfirm) {
          statusLabel = s.statusLargeFileAwaitConfirm;
        } else if (isFullyAcked || msg.status == 'delivered') {
          statusLabel = s.msgStatusDelivered;
        }
      } else {
        if (isAwaitingConfirm) {
          statusLabel = s.statusLargeFileAwaitConfirmCount(acks, regularOthersCount);
        } else if (isFullyAcked) {
          statusLabel = s.statusAllDeliveredCount(acks, regularOthersCount);
        } else if (msg.status == 'delivered') {
          statusLabel = s.statusDeliveredCount(acks, regularOthersCount);
        } else {
          statusLabel = '$statusLabel ($acks/$regularOthersCount)';
        }
      }
    }

    final statusIcon = isAwaitingConfirm
        ? const Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFFD97706))
        : isAwaitingDownload
            ? const Icon(
                Icons.download_for_offline_outlined,
                size: 14,
                color: Color(0xFF0284C7),
              )
            : isGroupOfferOutgoing
                ? Icon(
                    Icons.inventory_2_outlined,
                    size: 13,
                    color: tokens.mutedText,
                  )
                : isFullyAcked || msg.status == 'delivered'
                    ? const Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: Color(0xFF16A34A),
                      )
                    : Icon(Icons.schedule, size: 13, color: tokens.mutedText);

    final radius = BorderRadius.only(
      topLeft: Radius.circular(tokens.bubbleRadius),
      topRight: Radius.circular(tokens.bubbleRadius),
      bottomLeft: Radius.circular(
        isMe ? tokens.bubbleRadius : tokens.bubbleTailRadius,
      ),
      bottomRight: Radius.circular(
        isMe ? tokens.bubbleTailRadius : tokens.bubbleRadius,
      ),
    );

    final path = msg.localPath;
    final isRevoked = msg.status == 'revoked';
    final existingLocalPath =
        (!isRevoked && msg.isFile && path != null && File(path).existsSync())
            ? path
            : null;
    final hasImageThumbnail =
        existingLocalPath != null && isImageFileName(msg.fileName ?? '');
    final isLocalFileMissing = !isRevoked &&
        msg.isFile &&
        !isAwaitingDownload &&
        !isAwaitingConfirm &&
        existingLocalPath == null &&
        (msg.status == 'delivered' || msg.status == 'failed_source_missing');
    final isIncomingTransferring = !isMe &&
        (msg.status == 'transferring' ||
            msg.status == 'handshaking' ||
            msg.status == 'paused_reconnecting');
    final showFooterStatus = isMe ||
        isAwaitingDownload ||
        isLocalFileMissing ||
        isIncomingTransferring;

    final effectiveStatusLabel = isLocalFileMissing
        ? (isMe ? s.statusLocalSourceRemoved : s.statusLocalFileDeleted)
        : statusLabel;
    final effectiveStatusIcon = isLocalFileMissing
        ? const Icon(
            Icons.folder_off_outlined,
            size: 13.5,
            color: Color(0xFFD97706),
          )
        : statusIcon;

    Widget buildFooterRow() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeLabel,
            style: TextStyle(
              fontSize: 10.5,
              color: tokens.mutedText,
            ),
          ),
          if (showFooterStatus) ...[
            const SizedBox(width: 6),
            effectiveStatusIcon,
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                effectiveStatusLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isLocalFileMissing
                      ? const Color(0xFFB45309)
                      : tokens.mutedText,
                  fontWeight: isLocalFileMissing
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ],
      );
    }

    final bubble = GestureDetector(
      onSecondaryTapDown: (details) =>
          _showDesktopContextMenu(context, details.globalPosition),
      onLongPress: tokens.isDesktop ? null : () => _showMobileActionSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: isRevoked
            ? const EdgeInsets.fromLTRB(12, 9, 12, 8)
            : hasImageThumbnail
                ? const EdgeInsets.fromLTRB(5, 5, 5, 6)
                : const EdgeInsets.fromLTRB(12, 9, 12, 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          border: tokens.cardBorderWidth > 0 && !isMe
              ? Border.all(
                  color: tokens.subtleBorder,
                  width: tokens.cardBorderWidth,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: tokens.bubbleShadowOpacity),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: isRevoked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSenderName) ...[
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: senderColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block_rounded,
                        size: 15,
                        color: tokens.mutedText,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isMe ? s.revokedByMe : s.revokedByPeer,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: tokens.mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: tokens.mutedText,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSenderName) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: hasImageThumbnail ? 6 : 0,
                      ),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: senderColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (!msg.isFile)
                    _buildTextContent(
                      context,
                      s,
                      tokens,
                      msg.bodyText ?? '',
                      textColor,
                    )
                  else
                    _buildFileContent(
                      context,
                      s,
                      tokens,
                      textColor,
                      existingLocalPath: existingLocalPath,
                      isLocalFileMissing: isLocalFileMissing,
                    ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: hasImageThumbnail ? 6 : 0,
                    ),
                    child: buildFooterRow(),
                  ),
                ],
              ),
      ),
    );

    final maxBubbleWidth = MediaQuery.sizeOf(context).width >= 900
        ? 460.0
        : MediaQuery.sizeOf(context).width * 0.74;

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: bubble,
        ),
      );
    }

    final avatarText = controller.resolveMemberAvatar(msg.senderId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: Tooltip(
            message: effectiveNodeId.isNotEmpty
                ? s.tooltipEditPeerRemark
                : s.tooltipPeerAvatar,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: effectiveNodeId.isNotEmpty
                  ? () => onEditMemberProfile(effectiveNodeId, senderName)
                  : null,
              child: DeviceAvatar(
                radius: 15,
                fallbackText: avatarText,
                deviceKind: controller.resolveMemberDeviceKind(msg.senderId),
                imagePath: controller.resolveMemberAvatarPath(msg.senderId),
                accentColor: senderColor,
                backgroundColor: senderColor.withValues(alpha: 0.16),
                foregroundColor: senderColor,
              ),
            ),
          ),
        ),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: bubble,
          ),
        ),
      ],
    );
  }

  Widget _buildTextContent(
    BuildContext context,
    AppStrings s,
    AppThemeTokens tokens,
    String text,
    Color textColor,
  ) {
    final textStyle = TextStyle(
      fontSize: 14.5,
      height: 1.4,
      color: textColor,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: tokens.isDesktop
              ? SelectableText(text, style: textStyle)
              : Text(text, style: textStyle),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => _copyText(context, text, s.toastCopiedText),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.copy_rounded,
              size: 14,
              color: tokens.mutedText.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileContent(
    BuildContext context,
    AppStrings s,
    AppThemeTokens tokens,
    Color textColor, {
    required String? existingLocalPath,
    required bool isLocalFileMissing,
  }) {
    final name = msg.fileName ?? 'file.bin';
    final sizeLabel = formatBytes((msg.fileSize ?? BigInt.zero).toInt());
    final total = msg.totalChunks ?? 0;
    final progress =
        total > 0 ? (msg.completedChunks / total).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).round();
    final isImage = isImageFileName(name);
    final isAwaitingConfirm = msg.isOutgoing &&
        msg.deliveryScope == 'awaiting_confirm' &&
        msg.status != 'delivered';
    final isGroupOfferOutgoing = msg.isOutgoing &&
        msg.deliveryScope == 'group_offer' &&
        msg.status != 'delivered';
    final isAwaitingDownload =
        !msg.isOutgoing && msg.status == 'awaiting_download';
    final isTransferring =
        msg.status == 'transferring' || msg.status == 'handshaking';
    final speedLabel = controller.formatTransferSpeed(msg.msgId);
    final (fileColor, extLabel, fileIcon) = _fileTypeVisual(name);

    VoidCallback? cardTapAction;
    if (existingLocalPath != null && msg.status == 'delivered') {
      cardTapAction = () => OpenFilex.open(existingLocalPath);
    } else if (isLocalFileMissing && isImage) {
      cardTapAction = () => onOpenImagePreview(msg.localPath ?? '', name);
    } else if (isLocalFileMissing) {
      cardTapAction = () {
        if (onDeleteMessage != null) {
          onDeleteMessage!(msg);
        } else {
          showDeleteMessageConfirmDialog(context, controller, msg);
        }
      };
    } else if (isAwaitingDownload) {
      cardTapAction = () => controller.requestDownloadGroupFile(msg);
    } else if (isAwaitingConfirm) {
      cardTapAction = () => controller.confirmPendingFileTransfer(msg);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImage && existingLocalPath != null)
          Builder(
            builder: (context) {
              final cachedThumb = controller.lookupCachedThumbnail(
                msg.msgId,
                existingLocalPath,
              );
              final displayFile = File(cachedThumb?.path ?? existingLocalPath);
              final imageWidget = Image.file(
                displayFile,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: cachedThumb == null
                    ? ThumbnailCacheService.maxThumbWidth
                    : null,
                frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return Container(
                    width: cachedThumb != null ? double.infinity : 210,
                    height: cachedThumb != null ? double.infinity : 150,
                    color: msg.isOutgoing
                        ? tokens.fileCardBgOutgoing
                        : tokens.fileCardBgIncoming,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_outlined,
                      size: 28,
                      color: tokens.mutedText.withValues(alpha: 0.45),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => Container(
                  width: 220,
                  height: 120,
                  color: msg.isOutgoing
                      ? tokens.fileCardBgOutgoing
                      : tokens.fileCardBgIncoming,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 28,
                        color: tokens.mutedText,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.imageDeletedLocally,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              return GestureDetector(
                onTap: () => onOpenImagePreview(existingLocalPath, name),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.cardRadius * 0.75),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 240,
                        maxWidth: 300,
                      ),
                      child: cachedThumb != null
                          ? AspectRatio(
                              aspectRatio:
                                  cachedThumb.width / cachedThumb.height,
                              child: imageWidget,
                            )
                          : imageWidget,
                    ),
                  ),
                ),
              );
            },
          )
        else
          Material(
            color: msg.isOutgoing
                ? tokens.fileCardBgOutgoing
                : tokens.fileCardBgIncoming,
            borderRadius: BorderRadius.circular(tokens.cardRadius * 0.75),
            child: InkWell(
              onTap: cardTapAction,
              borderRadius: BorderRadius.circular(tokens.cardRadius * 0.75),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isLocalFileMissing
                            ? const Color(0xFFD97706).withValues(alpha: 0.14)
                            : fileColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          tokens.cardRadius * 0.6,
                        ),
                      ),
                      child: isLocalFileMissing
                          ? Icon(
                              isImage
                                  ? Icons.broken_image_outlined
                                  : Icons.file_present_outlined,
                              size: 22,
                              color: const Color(0xFFD97706),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(fileIcon, size: 20, color: fileColor),
                                if (extLabel.isNotEmpty)
                                  Text(
                                    extLabel,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: fileColor,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLocalFileMissing
                                ? (isImage
                                    ? (msg.isOutgoing
                                        ? s.fileSizeSourceImageRemoved(sizeLabel)
                                        : s.fileSizeImageDeletedTap(sizeLabel))
                                    : (msg.isOutgoing
                                        ? s.fileSizeSourceMissing(sizeLabel)
                                        : s.fileSizeFileDeleted(sizeLabel)))
                                : isAwaitingConfirm
                                    ? s.fileSizeAwaitConfirm(sizeLabel)
                                    : isAwaitingDownload
                                        ? s.fileSizeGroupAwaitDownload(sizeLabel)
                                        : isGroupOfferOutgoing
                                            ? s.fileSizeGroupOfferWaiting(sizeLabel)
                                            : isTransferring
                                                ? '$sizeLabel · $percent%${speedLabel != null ? " · $speedLabel" : ""}'
                                                : (!msg.isOutgoing &&
                                                        msg.status ==
                                                            'delivered')
                                                    ? sizeLabel
                                                    : '$sizeLabel · ${messageStatusText(msg.status, s)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isLocalFileMissing
                                  ? const Color(0xFFB45309)
                                  : tokens.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (isAwaitingDownload) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => controller.requestDownloadGroupFile(msg),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(s.btnDownloadToDevice(sizeLabel)),
            ),
          ),
        ],
        if (isAwaitingConfirm) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: controller.isRoomOnline
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFD97706),
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => controller.confirmPendingFileTransfer(msg),
              icon: const Icon(Icons.send_rounded, size: 15),
              label: Text(
                controller.isRoomOnline
                    ? s.btnConfirmSendNow(sizeLabel)
                    : s.btnConfirmQueueOffline,
              ),
            ),
          ),
        ],
        if (isTransferring) ...[
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (isImage && existingLocalPath != null) ? 6 : 0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? progress : null,
                minHeight: 5,
                backgroundColor: tokens.subtleBorder,
                valueColor: AlwaysStoppedAnimation<Color>(tokens.accentColor),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showDesktopContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final s = AppLocalizations.of(context);
    final isRevoked = msg.status == 'revoked';
    final path = msg.localPath;
    final fileExists = !isRevoked && path != null && File(path).existsSync();
    final items = <PopupMenuEntry<String>>[];

    if (!isRevoked && !msg.isFile && (msg.bodyText ?? '').trim().isNotEmpty) {
      items.add(
        PopupMenuItem(
          value: 'copy_text',
          child: Row(
            children: [
              const Icon(Icons.copy_rounded, size: 16),
              const SizedBox(width: 8),
              Text(s.actionCopyText),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem(
          value: 'forward',
          child: Row(
            children: [
              const Icon(Icons.shortcut_rounded, size: 16),
              const SizedBox(width: 8),
              Text(s.actionForward),
            ],
          ),
        ),
      );
    }
    if (!isRevoked && msg.isFile && fileExists) {
      items.add(
        PopupMenuItem(
          value: 'forward',
          child: Row(
            children: [
              const Icon(Icons.shortcut_rounded, size: 16),
              const SizedBox(width: 8),
              Text(s.actionForward),
            ],
          ),
        ),
      );
      items.add(
        PopupMenuItem(
          value: 'open_file',
          child: Row(
            children: [
              const Icon(Icons.open_in_new, size: 16),
              const SizedBox(width: 8),
              Text(s.actionOpenFile),
            ],
          ),
        ),
      );
      if (Platform.isWindows) {
        items.add(
          PopupMenuItem(
            value: 'reveal_file',
            child: Row(
              children: [
                const Icon(Icons.folder_open, size: 16),
                const SizedBox(width: 8),
                Text(s.actionRevealInFolder),
              ],
            ),
          ),
        );
      }
      items.add(
        PopupMenuItem(
          value: 'copy_path',
          child: Row(
            children: [
              const Icon(Icons.link, size: 16),
              const SizedBox(width: 8),
              Text(s.actionCopyFilePath),
            ],
          ),
        ),
      );
    }
    if (items.isNotEmpty) {
      items.add(const PopupMenuDivider(height: 8));
    }
    items.add(
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            const Icon(Icons.delete_outline, size: 16, color: Color(0xFFD93025)),
            const SizedBox(width: 8),
            Text(
              s.delete,
              style: const TextStyle(color: Color(0xFFD93025)),
            ),
          ],
        ),
      ),
    );

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: items,
    );
    if (!context.mounted || action == null) return;
    await _handleMenuAction(context, action);
  }

  Future<void> _showMobileActionSheet(BuildContext context) async {
    final s = AppLocalizations.of(context);
    final isRevoked = msg.status == 'revoked';
    final path = msg.localPath;
    final fileExists = !isRevoked && path != null && File(path).existsSync();
    final hasText =
        !isRevoked && !msg.isFile && (msg.bodyText ?? '').trim().isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasText) ...[
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(s.actionCopyText),
                onTap: () => Navigator.of(ctx).pop('copy_text'),
              ),
              ListTile(
                leading: const Icon(Icons.shortcut_rounded),
                title: Text(s.actionForward),
                onTap: () => Navigator.of(ctx).pop('forward'),
              ),
            ],
            if (!isRevoked && msg.isFile && fileExists) ...[
              ListTile(
                leading: const Icon(Icons.shortcut_rounded),
                title: Text(s.actionForward),
                onTap: () => Navigator.of(ctx).pop('forward'),
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(s.actionOpenFile),
                onTap: () => Navigator.of(ctx).pop('open_file'),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(s.actionCopyFilePath),
                onTap: () => Navigator.of(ctx).pop('copy_path'),
              ),
            ],
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFD93025),
              ),
              title: Text(
                s.delete,
                style: const TextStyle(color: Color(0xFFD93025)),
              ),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    await _handleMenuAction(context, action);
  }

  Future<void> _handleMenuAction(BuildContext context, String action) async {
    final s = AppLocalizations.of(context);
    final path = msg.localPath;
    switch (action) {
      case 'copy_text':
        await _copyText(context, msg.bodyText ?? '', s.toastCopiedText);
      case 'forward':
        if (onForwardMessage != null) {
          onForwardMessage!(msg);
        } else {
          await showForwardMessageDialog(context, controller, msg);
        }
      case 'open_file':
        if (path != null) await OpenFilex.open(path);
      case 'reveal_file':
        if (path != null) await PlatformBridge.revealFileInFolder(path);
      case 'copy_path':
        if (path != null) {
          await _copyText(context, path, s.toastCopiedPath(path));
        }
      case 'delete':
        if (onDeleteMessage != null) {
          onDeleteMessage!(msg);
        } else {
          await showDeleteMessageConfirmDialog(context, controller, msg);
        }
    }
  }

  Future<void> _copyText(
    BuildContext context,
    String text,
    String toast,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  (Color, String, IconData) _fileTypeVisual(String name) {
    final parts = name.toLowerCase().split('.');
    final ext = parts.length > 1 ? parts.last : '';
    return switch (ext) {
      'pdf' => (const Color(0xFFDC2626), 'PDF', Icons.picture_as_pdf_outlined),
      'doc' || 'docx' => (
          const Color(0xFF2563EB),
          'DOC',
          Icons.description_outlined,
        ),
      'xls' || 'xlsx' || 'csv' => (
          const Color(0xFF16A34A),
          'XLS',
          Icons.table_chart_outlined,
        ),
      'ppt' || 'pptx' => (
          const Color(0xFFEA580C),
          'PPT',
          Icons.slideshow_outlined,
        ),
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => (
          const Color(0xFFD97706),
          ext.toUpperCase(),
          Icons.folder_zip_outlined,
        ),
      'mp4' || 'mov' || 'mkv' || 'avi' => (
          const Color(0xFF7C3AED),
          ext.toUpperCase(),
          Icons.movie_outlined,
        ),
      'mp3' || 'flac' || 'wav' || 'aac' => (
          const Color(0xFFDB2777),
          ext.toUpperCase(),
          Icons.audiotrack_outlined,
        ),
      'apk' => (const Color(0xFF0D9488), 'APK', Icons.android),
      'exe' || 'msi' => (
          const Color(0xFF0284C7),
          ext.toUpperCase(),
          Icons.apps,
        ),
      'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => (
          const Color(0xFF0891B2),
          ext.toUpperCase(),
          Icons.image_outlined,
        ),
      _ => (
          const Color(0xFF475569),
          ext.length > 4 ? 'FILE' : ext.toUpperCase(),
          Icons.insert_drive_file_outlined,
        ),
    };
  }
}
