import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../src/rust/api.dart';
import '../theme/app_theme_tokens.dart';
import 'room_avatar.dart';

/// Minimum number of consecutive images from the same sender on the same day
/// before they collapse into a single expandable album card.
const int kMinCollapsedImageGroupCount = 5;

/// Mainstream reverse-anchored chat timeline (`reverse: true` so offset `0` is
/// always the newest message at the bottom).
///
/// Opening or switching rooms lands immediately on the newest message without
/// scrolling through history from the top. Scrolling up pauses auto-follow
/// and surfaces a floating return-to-bottom button (with an unread counter if
/// new incoming messages arrive below).
class ChatTimelineView extends StatefulWidget {
  final String roomId;

  /// Chronologically sorted messages (oldest first, newest last).
  final List<MessageDto> messages;

  /// Builds a single message item; [showDateChip] is true for the earliest
  /// message of each local calendar day and should render above the bubble.
  final Widget Function(
    BuildContext context,
    MessageDto msg,
    bool showDateChip,
  ) itemBuilder;

  /// Increment to force scrolling back to the newest message (e.g. after the
  /// local user sends a text or file).
  final int scrollToBottomRequestId;

  const ChatTimelineView({
    super.key,
    required this.roomId,
    required this.messages,
    required this.itemBuilder,
    this.scrollToBottomRequestId = 0,
  });

  @override
  State<ChatTimelineView> createState() => _ChatTimelineViewState();
}

class _ChatTimelineViewState extends State<ChatTimelineView> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedGroupKeys = {};

  bool _stickToBottom = true;
  bool _showScrollToBottom = false;
  int _unreadBelowCount = 0;
  String? _lastNewestMsgId;

  @override
  void initState() {
    super.initState();
    _lastNewestMsgId =
        widget.messages.isNotEmpty ? widget.messages.last.msgId : null;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChatTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.roomId != widget.roomId) {
      _expandedGroupKeys.clear();
      _stickToBottom = true;
      _showScrollToBottom = false;
      _unreadBelowCount = 0;
      _lastNewestMsgId =
          widget.messages.isNotEmpty ? widget.messages.last.msgId : null;
      _jumpToBottom();
      return;
    }

    if (oldWidget.scrollToBottomRequestId != widget.scrollToBottomRequestId) {
      _stickToBottom = true;
      _showScrollToBottom = false;
      _unreadBelowCount = 0;
      _lastNewestMsgId =
          widget.messages.isNotEmpty ? widget.messages.last.msgId : null;
      _animateToBottom();
      return;
    }

    final newest = widget.messages.isNotEmpty ? widget.messages.last : null;
    if (newest == null) {
      _lastNewestMsgId = null;
      if (_unreadBelowCount != 0 || _showScrollToBottom) {
        _unreadBelowCount = 0;
        _showScrollToBottom = false;
      }
      return;
    }

    if (newest.msgId != _lastNewestMsgId) {
      final prevNewestId = _lastNewestMsgId;
      _lastNewestMsgId = newest.msgId;

      if (prevNewestId == null) {
        // Initial population of the room's messages after an empty/loading frame.
        _stickToBottom = true;
        _unreadBelowCount = 0;
        _jumpToBottom();
        return;
      }

      if (newest.isOutgoing || _stickToBottom) {
        _stickToBottom = true;
        _unreadBelowCount = 0;
        _showScrollToBottom = false;
        _animateToBottom();
      } else {
        final prevIdx = widget.messages.lastIndexWhere(
          (m) => m.msgId == prevNewestId,
        );
        final addedCount =
            prevIdx >= 0 ? (widget.messages.length - 1 - prevIdx) : 1;
        _unreadBelowCount += addedCount > 0 ? addedCount : 1;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _scrollController.positions.length != 1) {
      return;
    }
    final offset = _scrollController.offset;
    final nearBottom = offset < 120.0;
    final shouldShow = offset > 240.0;
    _stickToBottom = nearBottom;

    if ((nearBottom && _unreadBelowCount != 0) ||
        shouldShow != _showScrollToBottom) {
      setState(() {
        if (nearBottom) {
          _unreadBelowCount = 0;
        }
        _showScrollToBottom = shouldShow;
      });
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          _scrollController.positions.length != 1) {
        return;
      }
      if (_scrollController.offset != 0.0) {
        _scrollController.jumpTo(0.0);
      }
    });
  }

  void _animateToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          _scrollController.positions.length != 1) {
        return;
      }
      if (_scrollController.offset <= 0.5) {
        if (_scrollController.offset != 0.0) {
          _scrollController.jumpTo(0.0);
        }
        return;
      }
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  static bool _isSameLocalDay(int aMs, int bMs) {
    final a = DateTime.fromMillisecondsSinceEpoch(aMs);
    final b = DateTime.fromMillisecondsSinceEpoch(bMs);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isCollapsibleImage(MessageDto msg) {
    return msg.status != 'revoked' &&
        msg.isFile &&
        isImageFileName(msg.fileName ?? '');
  }

  static String _effectiveSender(MessageDto msg) {
    return msg.senderId.isNotEmpty ? msg.senderId : msg.peerId;
  }

  static String? _normalizedBatchId(MessageDto msg) {
    final raw = msg.batchId?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  static const int _legacyGroupMaxGapMs = 30 * 1000;

  List<_TimelineRenderEntry> _buildRenderEntries(List<MessageDto> messages) {
    final entries = <_TimelineRenderEntry>[];
    var i = 0;
    while (i < messages.length) {
      final first = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      final firstShowDateChip =
          prev == null || !_isSameLocalDay(prev.createdAtMs, first.createdAtMs);

      if (_isCollapsibleImage(first)) {
        final sender = _effectiveSender(first);
        final firstBatch = _normalizedBatchId(first);
        var j = i + 1;
        while (j < messages.length) {
          final next = messages[j];
          if (!_isCollapsibleImage(next)) break;
          if (next.isOutgoing != first.isOutgoing) break;
          if (_effectiveSender(next) != sender) break;
          if (!_isSameLocalDay(first.createdAtMs, next.createdAtMs)) break;
          final nextBatch = _normalizedBatchId(next);
          if (firstBatch != null || nextBatch != null) {
            if (firstBatch != nextBatch) break;
          } else {
            final prevInRun = messages[j - 1];
            if ((next.createdAtMs - prevInRun.createdAtMs).abs() >
                _legacyGroupMaxGapMs) {
              break;
            }
          }
          j++;
        }

        final runLength = j - i;
        if (runLength >= kMinCollapsedImageGroupCount) {
          final run = messages.sublist(i, j);
          final groupKey = first.msgId;
          if (_expandedGroupKeys.contains(groupKey)) {
            for (var k = 0; k < run.length; k++) {
              entries.add(
                _TimelineRenderEntry.single(
                  msg: run[k],
                  showDateChip: k == 0 && firstShowDateChip,
                ),
              );
            }
            entries.add(
              _TimelineRenderEntry.collapseBar(
                groupKey: groupKey,
                count: run.length,
                isOutgoing: first.isOutgoing,
              ),
            );
          } else {
            entries.add(
              _TimelineRenderEntry.collapsedGroup(
                groupKey: groupKey,
                messages: run,
                showDateChip: firstShowDateChip,
              ),
            );
          }
          i = j;
          continue;
        }
      }

      entries.add(
        _TimelineRenderEntry.single(
          msg: first,
          showDateChip: firstShowDateChip,
        ),
      );
      i++;
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildRenderEntries(widget.messages);
    final tokens = AppThemeTokens.of(context);

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[entries.length - 1 - index];
            if (entry.msg != null) {
              final msg = entry.msg!;
              return KeyedSubtree(
                key: ValueKey('msg_${msg.msgId}'),
                child: widget.itemBuilder(context, msg, entry.showDateChip),
              );
            }
            if (entry.groupMessages != null) {
              final groupMsgs = entry.groupMessages!;
              final groupKey = entry.groupKey!;
              return KeyedSubtree(
                key: ValueKey('img_group_$groupKey'),
                child: Column(
                  children: [
                    if (entry.showDateChip)
                      _DateChipBanner(
                        createdAtMs: groupMsgs.first.createdAtMs,
                        tokens: tokens,
                      ),
                    _CollapsedImageGroupCard(
                      messages: groupMsgs,
                      tokens: tokens,
                      onExpand: () =>
                          setState(() => _expandedGroupKeys.add(groupKey)),
                    ),
                  ],
                ),
              );
            }
            final groupKey = entry.groupKey!;
            return KeyedSubtree(
              key: ValueKey('img_collapse_$groupKey'),
              child: _CollapseGroupBar(
                count: entry.collapseCount,
                isOutgoing: entry.isOutgoing,
                tokens: tokens,
                onCollapse: () =>
                    setState(() => _expandedGroupKeys.remove(groupKey)),
              ),
            );
          },
        ),
        if (_showScrollToBottom)
          Positioned(
            right: 16,
            bottom: 14,
            child: _ScrollToBottomButton(
              tokens: tokens,
              unreadCount: _unreadBelowCount,
              onPressed: () {
                setState(() {
                  _stickToBottom = true;
                  _unreadBelowCount = 0;
                  _showScrollToBottom = false;
                });
                _animateToBottom();
              },
            ),
          ),
      ],
    );
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  final AppThemeTokens tokens;
  final int unreadCount;
  final VoidCallback onPressed;

  const _ScrollToBottomButton({
    required this.tokens,
    required this.unreadCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final hasUnread = unreadCount > 0;
    return Material(
      color: tokens.headerBg,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: hasUnread
          ? StadiumBorder(
              side: BorderSide(color: tokens.subtleBorder),
            )
          : CircleBorder(
              side: BorderSide(color: tokens.subtleBorder),
            ),
      child: InkWell(
        onTap: onPressed,
        customBorder: hasUnread ? const StadiumBorder() : const CircleBorder(),
        child: Padding(
          padding: hasUnread
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : const EdgeInsets.all(9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasUnread) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
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
                const SizedBox(width: 6),
                Text(
                  s.newMessagesBelowSuffix,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.incomingBubbleText,
                  ),
                ),
                const SizedBox(width: 2),
              ],
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: hasUnread
                    ? tokens.accentColor
                    : tokens.incomingBubbleText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRenderEntry {
  final MessageDto? msg;
  final String? groupKey;
  final List<MessageDto>? groupMessages;
  final int collapseCount;
  final bool isOutgoing;
  final bool showDateChip;

  const _TimelineRenderEntry._({
    this.msg,
    this.groupKey,
    this.groupMessages,
    this.collapseCount = 0,
    this.isOutgoing = false,
    this.showDateChip = false,
  });

  factory _TimelineRenderEntry.single({
    required MessageDto msg,
    required bool showDateChip,
  }) =>
      _TimelineRenderEntry._(msg: msg, showDateChip: showDateChip);

  factory _TimelineRenderEntry.collapsedGroup({
    required String groupKey,
    required List<MessageDto> messages,
    required bool showDateChip,
  }) =>
      _TimelineRenderEntry._(
        groupKey: groupKey,
        groupMessages: messages,
        showDateChip: showDateChip,
      );

  factory _TimelineRenderEntry.collapseBar({
    required String groupKey,
    required int count,
    required bool isOutgoing,
  }) =>
      _TimelineRenderEntry._(
        groupKey: groupKey,
        collapseCount: count,
        isOutgoing: isOutgoing,
      );
}

class _DateChipBanner extends StatelessWidget {
  final int createdAtMs;
  final AppThemeTokens tokens;

  const _DateChipBanner({
    required this.createdAtMs,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAtMs).toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.dateChipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            s.formatFullDate(dt),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tokens.dateChipText,
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedImageGroupCard extends StatelessWidget {
  final List<MessageDto> messages;
  final AppThemeTokens tokens;
  final VoidCallback onExpand;

  const _CollapsedImageGroupCard({
    required this.messages,
    required this.tokens,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final isOutgoing = messages.first.isOutgoing;
    final bubbleBg =
        isOutgoing ? tokens.outgoingBubbleBg : tokens.incomingBubbleBg;
    final textColor =
        isOutgoing ? tokens.outgoingBubbleText : tokens.incomingBubbleText;
    final previewItems = messages.take(4).toList();
    final extraCount = messages.length - previewItems.length;

    final deliveredCount =
        messages.where((m) => m.status == 'delivered').length;
    final failedCount = messages.where((m) => m.status == 'failed').length;
    final missingLocalCount = messages.where((m) {
      if (m.status != 'delivered') return false;
      final p = m.localPath?.trim() ?? '';
      return p.isEmpty || !File(p).existsSync();
    }).length;
    final statusLabel = failedCount > 0
        ? s.albumFailedCount(failedCount)
        : deliveredCount == messages.length
            ? (missingLocalCount > 0
                ? (isOutgoing
                    ? s.albumDeliveredSourceMissing(missingLocalCount)
                    : s.albumDeliveredLocalDeleted(missingLocalCount))
                : s.albumAllDelivered)
            : s.albumTransferringProgress(deliveredCount, messages.length);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 268),
          child: Material(
            color: bubbleBg,
            borderRadius: BorderRadius.circular(14),
            elevation: tokens.bubbleShadowOpacity > 0 ? 1 : 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onExpand,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: previewItems.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                      ),
                      itemBuilder: (context, idx) {
                        final msg = previewItems[idx];
                        final path = msg.localPath?.trim();
                        final showExtra = idx == 3 && extraCount > 0;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (path != null &&
                                  path.isNotEmpty &&
                                  File(path).existsSync())
                                Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  cacheWidth: 240,
                                  errorBuilder: (_, _, _) =>
                                      _thumbPlaceholder(tokens),
                                )
                              else
                                _thumbPlaceholder(tokens),
                              if (showExtra)
                                Container(
                                  color: Colors.black54,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+$extraCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.albumImageCount(messages.length),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: tokens.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: onExpand,
                            icon: const Icon(
                              Icons.unfold_more_rounded,
                              size: 16,
                            ),
                            label: Text(
                              s.btnExpand,
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
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
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(AppThemeTokens tokens) {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: Icon(
        Icons.photo_outlined,
        size: 24,
        color: tokens.mutedText,
      ),
    );
  }
}

class _CollapseGroupBar extends StatelessWidget {
  final int count;
  final bool isOutgoing;
  final AppThemeTokens tokens;
  final VoidCallback onCollapse;

  const _CollapseGroupBar({
    required this.count,
    required this.isOutgoing,
    required this.tokens,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onCollapse,
          icon: const Icon(Icons.unfold_less_rounded, size: 16),
          label: Text(
            s.collapseImagesCount(count),
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: tokens.mutedText,
            side: BorderSide(color: tokens.subtleBorder),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      ),
    );
  }
}
