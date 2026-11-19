import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme_tokens.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasRoom;
  final VoidCallback onSend;
  final VoidCallback onPickFiles;
  final VoidCallback? onPickGallery;
  final VoidCallback onPasteClipboard;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.hasRoom,
    required this.onSend,
    required this.onPickFiles,
    this.onPickGallery,
    required this.onPasteClipboard,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final tokens = AppThemeTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isExpressive = tokens.style == AppUiStyle.androidExpressive;

    return Container(
      decoration: BoxDecoration(
        color: tokens.inputBarBg,
        border: Border(top: BorderSide(color: tokens.subtleBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        isExpressive ? 10 : 8,
        10,
        isExpressive ? 12 : 10,
      ),
      child: SafeArea(
        top: false,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                onPasteClipboard,
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (Platform.isAndroid && onPickGallery != null) ...[
                _buildActionBtn(
                  context: context,
                  tokens: tokens,
                  isExpressive: isExpressive,
                  tooltip: s.tooltipGalleryImages,
                  icon: Icons.photo_outlined,
                  onPressed: hasRoom ? onPickGallery : null,
                ),
                if (isExpressive) const SizedBox(width: 8),
              ],
              _buildActionBtn(
                context: context,
                tokens: tokens,
                isExpressive: isExpressive,
                tooltip: Platform.isAndroid
                    ? s.tooltipSendFile
                    : s.tooltipSendImageOrFile,
                icon: Icons.attach_file_rounded,
                onPressed: hasRoom ? onPickFiles : null,
              ),
              SizedBox(width: isExpressive ? 8 : 6),
              if (Platform.isWindows) ...[
                _buildActionBtn(
                  context: context,
                  tokens: tokens,
                  isExpressive: isExpressive,
                  tooltip: s.tooltipPasteClipboard,
                  icon: Icons.content_paste_go,
                  onPressed: hasRoom ? onPasteClipboard : null,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (!Platform.isWindows) return KeyEventResult.ignored;
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      if (hasRoom) onSend();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: controller,
                    enabled: hasRoom,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: Platform.isWindows
                        ? TextInputAction.newline
                        : TextInputAction.send,
                    onSubmitted: Platform.isWindows ? null : (_) => onSend(),
                    style: TextStyle(color: scheme.onSurface),
                    decoration: InputDecoration(
                      hintText: hasRoom
                          ? (Platform.isWindows
                              ? s.inputHintWindows
                              : s.inputHintMobile)
                          : s.inputHintNoRoom,
                      hintMaxLines: 1,
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: tokens.mutedText,
                      ),
                      filled: true,
                      fillColor: tokens.inputFillBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.pillRadius),
                        borderSide: isExpressive
                            ? BorderSide.none
                            : BorderSide(color: tokens.subtleBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.pillRadius),
                        borderSide: isExpressive
                            ? BorderSide.none
                            : BorderSide(color: tokens.subtleBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(tokens.pillRadius),
                        borderSide: isExpressive
                            ? BorderSide.none
                            : BorderSide(color: tokens.accentColor, width: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: hasRoom
                    ? tokens.accentColor
                    : tokens.mutedText.withValues(alpha: 0.35),
                shape: isExpressive ? const CircleBorder() : null,
                borderRadius: isExpressive ? null : BorderRadius.circular(8),
                child: InkWell(
                  customBorder: isExpressive ? const CircleBorder() : null,
                  borderRadius: isExpressive ? null : BorderRadius.circular(8),
                  onTap: hasRoom ? onSend : null,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Tooltip(
                      message: s.tooltipSendMessage,
                      child: Icon(
                        Icons.send_rounded,
                        color: hasRoom ? scheme.onPrimary : Colors.white70,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required BuildContext context,
    required AppThemeTokens tokens,
    required bool isExpressive,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (!isExpressive) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: tokens.inputFillBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: tokens.subtleBorder),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                icon,
                size: 18,
                color: onPressed != null
                    ? scheme.onSurfaceVariant
                    : tokens.mutedText.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleBg =
        isDark ? const Color(0xFF233042) : const Color(0xFFE8EEF5);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: circleBg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: onPressed != null
                  ? scheme.onSurfaceVariant
                  : tokens.mutedText.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
