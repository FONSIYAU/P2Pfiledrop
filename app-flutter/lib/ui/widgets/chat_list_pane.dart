import 'package:material_ui/material_ui.dart';

import '../../controllers/app_workspace_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api.dart';
import '../theme/app_theme_tokens.dart';
import 'room_avatar.dart';

/// Shared WeChat-style 「聊天」 conversation list pane for both mobile landing
/// tab and desktop middle column.
class ChatListPane extends StatefulWidget {
  final AppWorkspaceController controller;
  final bool showDesktopHeaderActions;
  final bool highlightActiveRoom;
  final ValueChanged<RoomDto> onSelectRoom;
  final VoidCallback onOpenInviteScan;
  final VoidCallback onOpenCreateGroup;
  final VoidCallback onSwitchToContacts;

  const ChatListPane({
    super.key,
    required this.controller,
    required this.showDesktopHeaderActions,
    required this.highlightActiveRoom,
    required this.onSelectRoom,
    required this.onOpenInviteScan,
    required this.onOpenCreateGroup,
    required this.onSwitchToContacts,
  });

  @override
  State<ChatListPane> createState() => _ChatListPaneState();
}

class _ChatListPaneState extends State<ChatListPane> {
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
    final activeId = controller.activeRoom?.roomId;

    final rooms = controller.rooms.where((r) {
      if (query.isEmpty) return true;
      final resolved = controller.resolveRoomTitle(r).toLowerCase();
      return resolved.contains(query) || r.roomId.toLowerCase().contains(query);
    }).toList();

    final isMobileCard = !widget.highlightActiveRoom;

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
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.chatListTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (widget.showDesktopHeaderActions)
                          PopupMenuButton<String>(
                            tooltip: s.chatListNewActionTooltip,
                            icon: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: tokens.headerBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: tokens.subtleBorder),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: scheme.onSurface,
                              ),
                            ),
                            onSelected: (value) {
                              if (value == 'pair') {
                                widget.onOpenInviteScan();
                              } else if (value == 'group') {
                                widget.onOpenCreateGroup();
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'pair',
                                child: Row(
                                  children: [
                                    const Icon(Icons.qr_code_scanner, size: 18),
                                    const SizedBox(width: 8),
                                    Text(s.menuScanPairOrJoin),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'group',
                                child: Row(
                                  children: [
                                    const Icon(Icons.group_add_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(s.menuCreateGroup),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: isMobileCard
                      ? const EdgeInsets.fromLTRB(16, 4, 16, 10)
                      : const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: isMobileCard ? 14.5 : 13),
                    decoration: InputDecoration(
                      hintText: s.searchChatsHint,
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
                if (!isMobileCard) Divider(height: 1, color: tokens.subtleBorder),
              ],
            ),
          ),
          if (rooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(s, tokens, query.isNotEmpty),
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
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                      final r = rooms[index];
                      final selected =
                          widget.highlightActiveRoom && r.roomId == activeId;
                      final isDm = r.roomType == 'dm';
                      final roomTitle = controller.resolveRoomTitle(r);
                      final dmPeerId = controller.resolveDmPeerId(r);
                      final dmTransport = dmPeerId != null
                          ? (controller.getPeerTransport(dmPeerId) ?? 'offline')
                          : null;
                      final dmOnline =
                          dmTransport != null && dmTransport != 'offline';
                      final groupSummary =
                          isDm ? null : controller.getRoomOnlineSummary(r);
                      final lastMsg = controller.getLastMessageForRoom(r.roomId);
                      final timeText = lastMsg != null
                          ? _formatListTime(s, lastMsg.createdAtMs)
                          : null;
                      final unreadCount = controller.getUnreadCount(r.roomId);
                      final statusText = isDm
                          ? transportLabel(dmTransport ?? 'offline', s)
                          : (groupSummary!.hasOnlinePeer
                              ? s.groupOnlineCount(
                                  groupSummary.online,
                                  groupSummary.total,
                                )
                              : s.groupOfflineCount(groupSummary.total));
                      final subtitleOnline =
                          isDm ? dmOnline : groupSummary!.hasOnlinePeer;
                      final subtitleColor = subtitleOnline
                          ? (isDm
                              ? transportColor(dmTransport!)
                              : const Color(0xFF16A34A))
                          : tokens.mutedText;
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
                            onTap: () => widget.onSelectRoom(r),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobileCard ? 16 : 10,
                                vertical: isMobileCard ? 15 : 10,
                              ),
                              child: Row(
                                children: [
                                  if (tokens.style == AppUiStyle.windowsFluent &&
                                      widget.highlightActiveRoom)
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      width: 3,
                                      height: selected ? 24 : 0,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: tokens.accentColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      RoomAvatar(
                                        room: r,
                                        size: isMobileCard ? 48 : 42,
                                        peerAvatarPath: dmPeerId != null
                                            ? controller
                                                .resolveMemberAvatarPath(dmPeerId)
                                            : null,
                                        peerFallbackText: dmPeerId != null
                                            ? controller.resolveMemberAvatar(
                                                dmPeerId,
                                                fallbackName: roomTitle,
                                              )
                                            : null,
                                        peerDeviceKind: dmPeerId != null
                                            ? controller
                                                .resolveMemberDeviceKind(
                                                dmPeerId,
                                                fallbackName: roomTitle,
                                              )
                                            : null,
                                        peerAccentColor: dmPeerId != null
                                            ? senderAccentColor(dmPeerId)
                                            : null,
                                      ),
                                      if (dmOnline)
                                        Positioned(
                                          right: -1,
                                          bottom: -1,
                                          child: Container(
                                            width: isMobileCard ? 13 : 12,
                                            height: isMobileCard ? 13 : 12,
                                            decoration: BoxDecoration(
                                              color:
                                                  transportColor(dmTransport),
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
                                  SizedBox(width: isMobileCard ? 14 : 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                roomTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize:
                                                      isMobileCard ? 16 : 14,
                                                  fontWeight: isMobileCard
                                                      ? FontWeight.w700
                                                      : (selected
                                                          ? FontWeight.w700
                                                          : FontWeight.w600),
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            if (timeText != null) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                timeText,
                                                style: TextStyle(
                                                  fontSize:
                                                      isMobileCard ? 12 : 11,
                                                  color: tokens.mutedText,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        SizedBox(height: isMobileCard ? 5 : 3),
                                        Text(
                                          statusText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: isMobileCard ? 13 : 12,
                                            fontWeight: subtitleOnline
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                            color: subtitleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.accentColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        unreadCount > 99 ? '99+' : '$unreadCount',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
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

  Widget _buildEmptyState(AppStrings s, AppThemeTokens tokens, bool hasSearch) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off_rounded : Icons.forum_outlined,
              size: 40,
              color: tokens.mutedText.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch ? s.emptyChatsSearch : s.emptyChatsNoRooms,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: tokens.mutedText,
                height: 1.5,
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: widget.onOpenInviteScan,
                    icon: const Icon(Icons.qr_code_scanner, size: 17),
                    label: Text(s.btnScanPairDevice),
                  ),
                  if (widget.controller.peers.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: widget.onSwitchToContacts,
                      icon: const Icon(Icons.devices_outlined, size: 17),
                      label: Text(s.btnGoToDevices),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatListTime(AppStrings s, int createdAtMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAtMs).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(msgDay).inDays;
    if (diffDays == 0) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    if (diffDays == 1) return s.yesterdayLabel;
    return '${dt.month}/${dt.day}';
  }
}
