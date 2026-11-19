import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

/// Platform-native visual design language ("skin") applied on top of shared
/// business widgets.
enum AppUiStyle {
  androidExpressive,
  windowsFluent,
  appleCupertino,
}

AppUiStyle resolvePlatformUiStyle() {
  if (Platform.isWindows) return AppUiStyle.windowsFluent;
  if (Platform.isIOS || Platform.isMacOS) return AppUiStyle.appleCupertino;
  return AppUiStyle.androidExpressive;
}

/// Persists and notifies theme mode and app locale preferences.
class AppThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _localeCode = 'system';
  Directory? _dataDir;

  ThemeMode get themeMode => _themeMode;
  String get localeCode => _localeCode;
  Locale? get effectiveLocale => AppLocalizations.localeForCode(_localeCode);

  Future<void> load(Directory dataDir) async {
    _dataDir = dataDir;
    var changed = false;
    final themeFile =
        File('${dataDir.path}${Platform.pathSeparator}theme_mode.txt');
    if (themeFile.existsSync()) {
      final raw = (await themeFile.readAsString()).trim();
      final parsed = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      if (parsed != _themeMode) {
        _themeMode = parsed;
        changed = true;
      }
    }
    final localeFile =
        File('${dataDir.path}${Platform.pathSeparator}app_locale.txt');
    if (localeFile.existsSync()) {
      final raw = (await localeFile.readAsString()).trim();
      final parsed = AppLocalizations.normalizeLocaleCode(raw);
      if (parsed != _localeCode) {
        _localeCode = parsed;
        changed = true;
      }
    }
    AppLocalizations.setOverrideLocale(effectiveLocale);
    if (changed) notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}${Platform.pathSeparator}theme_mode.txt');
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await file.writeAsString(value);
  }

  Future<void> setLocaleCode(String code) async {
    final normalized = AppLocalizations.normalizeLocaleCode(code);
    if (_localeCode == normalized) return;
    _localeCode = normalized;
    AppLocalizations.setOverrideLocale(effectiveLocale);
    notifyListeners();
    final dir = _dataDir;
    if (dir == null) return;
    final file = File('${dir.path}${Platform.pathSeparator}app_locale.txt');
    await file.writeAsString(normalized);
  }
}

/// Design tokens bridging Material 3 Expressive (Android), Fluent Design
/// (Windows), and Cupertino/HIG (Apple) while keeping Light & Dark support.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final AppUiStyle style;
  final bool isDesktop;
  final Color accentColor;
  final Color canvasBg;
  final Color sidebarBg;
  final Color sidebarSelectedBg;
  final Color headerBg;
  final Color inputBarBg;
  final Color inputFillBg;
  final Color outgoingBubbleBg;
  final Color outgoingBubbleText;
  final Color incomingBubbleBg;
  final Color incomingBubbleText;
  final Color fileCardBgOutgoing;
  final Color fileCardBgIncoming;
  final Color subtleBorder;
  final Color mutedText;
  final Color dateChipBg;
  final Color dateChipText;
  final double bubbleRadius;
  final double bubbleTailRadius;
  final double cardRadius;
  final double pillRadius;
  final double dialogRadius;
  final double listItemRadius;
  final double cardBorderWidth;
  final double bubbleShadowOpacity;

  const AppThemeTokens({
    required this.style,
    required this.isDesktop,
    required this.accentColor,
    required this.canvasBg,
    required this.sidebarBg,
    required this.sidebarSelectedBg,
    required this.headerBg,
    required this.inputBarBg,
    required this.inputFillBg,
    required this.outgoingBubbleBg,
    required this.outgoingBubbleText,
    required this.incomingBubbleBg,
    required this.incomingBubbleText,
    required this.fileCardBgOutgoing,
    required this.fileCardBgIncoming,
    required this.subtleBorder,
    required this.mutedText,
    required this.dateChipBg,
    required this.dateChipText,
    required this.bubbleRadius,
    required this.bubbleTailRadius,
    required this.cardRadius,
    required this.pillRadius,
    required this.dialogRadius,
    required this.listItemRadius,
    required this.cardBorderWidth,
    required this.bubbleShadowOpacity,
  });

  static AppThemeTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeTokens>();
    if (ext != null) return ext;
    final scheme = Theme.of(context).colorScheme;
    return forStyle(resolvePlatformUiStyle(), scheme);
  }

  static AppThemeTokens forStyle(AppUiStyle style, ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    switch (style) {
      case AppUiStyle.windowsFluent:
        return AppThemeTokens(
          style: style,
          isDesktop: true,
          accentColor: isDark ? const Color(0xFF4CC2FF) : const Color(0xFF0067C0),
          canvasBg: isDark ? const Color(0xFF16181D) : const Color(0xFFF8FAFC),
          sidebarBg: isDark ? const Color(0xFF1C1F26) : const Color(0xFFF3F6FA),
          sidebarSelectedBg:
              isDark ? const Color(0xFF283240) : const Color(0xFFE5EFFA),
          headerBg: isDark ? const Color(0xFF20242C) : const Color(0xFFFFFFFF),
          inputBarBg: isDark ? const Color(0xFF20242C) : const Color(0xFFFFFFFF),
          inputFillBg: isDark ? const Color(0xFF282C35) : const Color(0xFFF3F5F8),
          outgoingBubbleBg:
              isDark ? const Color(0xFF0F3E5E) : const Color(0xFFDDF0FF),
          outgoingBubbleText:
              isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
          incomingBubbleBg:
              isDark ? const Color(0xFF232730) : const Color(0xFFFFFFFF),
          incomingBubbleText:
              isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827),
          fileCardBgOutgoing:
              isDark ? const Color(0x33000000) : const Color(0x88FFFFFF),
          fileCardBgIncoming:
              isDark ? const Color(0xFF222222) : const Color(0xFFF3F6F9),
          subtleBorder:
              isDark ? const Color(0xFF303540) : const Color(0xFFE2E8F0),
          mutedText:
              isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          dateChipBg:
              isDark ? const Color(0x99333333) : const Color(0xCC334155),
          dateChipText: Colors.white,
          bubbleRadius: 10,
          bubbleTailRadius: 4,
          cardRadius: 8,
          pillRadius: 8,
          dialogRadius: 12,
          listItemRadius: 8,
          cardBorderWidth: 1.0,
          bubbleShadowOpacity: isDark ? 0.16 : 0.05,
        );

      case AppUiStyle.appleCupertino:
        return AppThemeTokens(
          style: style,
          isDesktop: Platform.isMacOS,
          accentColor: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
          canvasBg: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          sidebarBg: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9FB),
          sidebarSelectedBg:
              isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          headerBg: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
          inputBarBg: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
          inputFillBg: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFF4),
          outgoingBubbleBg:
              isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
          outgoingBubbleText: Colors.white,
          incomingBubbleBg:
              isDark ? const Color(0xFF262629) : const Color(0xFFFFFFFF),
          incomingBubbleText:
              isDark ? const Color(0xFFF2F2F7) : const Color(0xFF111827),
          fileCardBgOutgoing: const Color(0x22FFFFFF),
          fileCardBgIncoming:
              isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
          subtleBorder:
              isDark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6),
          mutedText:
              isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70),
          dateChipBg:
              isDark ? const Color(0xAA2C2C2E) : const Color(0xAA3A3A3C),
          dateChipText: Colors.white,
          bubbleRadius: 18,
          bubbleTailRadius: 5,
          cardRadius: 14,
          pillRadius: 20,
          dialogRadius: 16,
          listItemRadius: 12,
          cardBorderWidth: 0.6,
          bubbleShadowOpacity: isDark ? 0.12 : 0.04,
        );

      case AppUiStyle.androidExpressive:
        final cloudCanvas =
            isDark ? const Color(0xFF111318) : const Color(0xFFF2F4F7);
        final cardSurface =
            isDark ? const Color(0xFF1C2026) : const Color(0xFFFFFFFF);
        return AppThemeTokens(
          style: style,
          isDesktop: false,
          accentColor: scheme.primary,
          canvasBg: cloudCanvas,
          sidebarBg: cloudCanvas,
          sidebarSelectedBg: scheme.secondaryContainer,
          headerBg: cardSurface,
          inputBarBg: cardSurface,
          inputFillBg:
              isDark ? const Color(0xFF252A32) : const Color(0xFFF2F4F7),
          outgoingBubbleBg: scheme.primaryContainer,
          outgoingBubbleText: scheme.onPrimaryContainer,
          incomingBubbleBg: cardSurface,
          incomingBubbleText: scheme.onSurface,
          fileCardBgOutgoing: isDark
              ? scheme.surface.withValues(alpha: 0.35)
              : scheme.surface.withValues(alpha: 0.65),
          fileCardBgIncoming:
              isDark ? const Color(0xFF252A32) : const Color(0xFFF4F6FA),
          subtleBorder: isDark
              ? const Color(0xFF2A2F38)
              : scheme.outlineVariant.withValues(alpha: 0.45),
          mutedText:
              isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          dateChipBg: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
          dateChipText: scheme.onSurfaceVariant,
          bubbleRadius: 20,
          bubbleTailRadius: 6,
          cardRadius: 20,
          pillRadius: 28,
          dialogRadius: 26,
          listItemRadius: 20,
          cardBorderWidth: 0.0,
          bubbleShadowOpacity: isDark ? 0.14 : 0.04,
        );
    }
  }

  @override
  AppThemeTokens copyWith({
    AppUiStyle? style,
    bool? isDesktop,
    Color? accentColor,
    Color? canvasBg,
    Color? sidebarBg,
    Color? sidebarSelectedBg,
    Color? headerBg,
    Color? inputBarBg,
    Color? inputFillBg,
    Color? outgoingBubbleBg,
    Color? outgoingBubbleText,
    Color? incomingBubbleBg,
    Color? incomingBubbleText,
    Color? fileCardBgOutgoing,
    Color? fileCardBgIncoming,
    Color? subtleBorder,
    Color? mutedText,
    Color? dateChipBg,
    Color? dateChipText,
    double? bubbleRadius,
    double? bubbleTailRadius,
    double? cardRadius,
    double? pillRadius,
    double? dialogRadius,
    double? listItemRadius,
    double? cardBorderWidth,
    double? bubbleShadowOpacity,
  }) {
    return AppThemeTokens(
      style: style ?? this.style,
      isDesktop: isDesktop ?? this.isDesktop,
      accentColor: accentColor ?? this.accentColor,
      canvasBg: canvasBg ?? this.canvasBg,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarSelectedBg: sidebarSelectedBg ?? this.sidebarSelectedBg,
      headerBg: headerBg ?? this.headerBg,
      inputBarBg: inputBarBg ?? this.inputBarBg,
      inputFillBg: inputFillBg ?? this.inputFillBg,
      outgoingBubbleBg: outgoingBubbleBg ?? this.outgoingBubbleBg,
      outgoingBubbleText: outgoingBubbleText ?? this.outgoingBubbleText,
      incomingBubbleBg: incomingBubbleBg ?? this.incomingBubbleBg,
      incomingBubbleText: incomingBubbleText ?? this.incomingBubbleText,
      fileCardBgOutgoing: fileCardBgOutgoing ?? this.fileCardBgOutgoing,
      fileCardBgIncoming: fileCardBgIncoming ?? this.fileCardBgIncoming,
      subtleBorder: subtleBorder ?? this.subtleBorder,
      mutedText: mutedText ?? this.mutedText,
      dateChipBg: dateChipBg ?? this.dateChipBg,
      dateChipText: dateChipText ?? this.dateChipText,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      bubbleTailRadius: bubbleTailRadius ?? this.bubbleTailRadius,
      cardRadius: cardRadius ?? this.cardRadius,
      pillRadius: pillRadius ?? this.pillRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      listItemRadius: listItemRadius ?? this.listItemRadius,
      cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
      bubbleShadowOpacity: bubbleShadowOpacity ?? this.bubbleShadowOpacity,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      style: t < 0.5 ? style : other.style,
      isDesktop: t < 0.5 ? isDesktop : other.isDesktop,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t)!,
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      sidebarSelectedBg:
          Color.lerp(sidebarSelectedBg, other.sidebarSelectedBg, t)!,
      headerBg: Color.lerp(headerBg, other.headerBg, t)!,
      inputBarBg: Color.lerp(inputBarBg, other.inputBarBg, t)!,
      inputFillBg: Color.lerp(inputFillBg, other.inputFillBg, t)!,
      outgoingBubbleBg:
          Color.lerp(outgoingBubbleBg, other.outgoingBubbleBg, t)!,
      outgoingBubbleText:
          Color.lerp(outgoingBubbleText, other.outgoingBubbleText, t)!,
      incomingBubbleBg:
          Color.lerp(incomingBubbleBg, other.incomingBubbleBg, t)!,
      incomingBubbleText:
          Color.lerp(incomingBubbleText, other.incomingBubbleText, t)!,
      fileCardBgOutgoing:
          Color.lerp(fileCardBgOutgoing, other.fileCardBgOutgoing, t)!,
      fileCardBgIncoming:
          Color.lerp(fileCardBgIncoming, other.fileCardBgIncoming, t)!,
      subtleBorder: Color.lerp(subtleBorder, other.subtleBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      dateChipBg: Color.lerp(dateChipBg, other.dateChipBg, t)!,
      dateChipText: Color.lerp(dateChipText, other.dateChipText, t)!,
      bubbleRadius: lerpDouble(bubbleRadius, other.bubbleRadius, t),
      bubbleTailRadius: lerpDouble(bubbleTailRadius, other.bubbleTailRadius, t),
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      pillRadius: lerpDouble(pillRadius, other.pillRadius, t),
      dialogRadius: lerpDouble(dialogRadius, other.dialogRadius, t),
      listItemRadius: lerpDouble(listItemRadius, other.listItemRadius, t),
      cardBorderWidth: lerpDouble(cardBorderWidth, other.cardBorderWidth, t),
      bubbleShadowOpacity:
          lerpDouble(bubbleShadowOpacity, other.bubbleShadowOpacity, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

ThemeData buildAppTheme({
  required Brightness brightness,
  AppUiStyle? styleOverride,
}) {
  final style = styleOverride ?? resolvePlatformUiStyle();
  final seed = switch (style) {
    AppUiStyle.windowsFluent => const Color(0xFF0078D4),
    AppUiStyle.appleCupertino => const Color(0xFF007AFF),
    AppUiStyle.androidExpressive => const Color(0xFF006B8F),
  };

  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final tokens = AppThemeTokens.forStyle(style, scheme);

  return ThemeData(
    useMaterial3: true,
    fontFamily: style == AppUiStyle.windowsFluent ? 'Microsoft YaHei UI' : null,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: tokens.canvasBg,
    visualDensity: style == AppUiStyle.windowsFluent
        ? VisualDensity.compact
        : VisualDensity.standard,
    cardTheme: CardThemeData(
      elevation: 0,
      color: tokens.incomingBubbleBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        side: tokens.cardBorderWidth > 0
            ? BorderSide(color: tokens.subtleBorder, width: tokens.cardBorderWidth)
            : BorderSide.none,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.headerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.dialogRadius),
        side: style == AppUiStyle.windowsFluent
            ? BorderSide(color: tokens.subtleBorder)
            : BorderSide.none,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.headerBg,
      showDragHandle: style == AppUiStyle.androidExpressive,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(style == AppUiStyle.windowsFluent ? 12 : 28),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            style == AppUiStyle.windowsFluent ? 6 : 24,
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            style == AppUiStyle.windowsFluent ? 6 : 24,
          ),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.canvasBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 70,
      indicatorColor: brightness == Brightness.dark
          ? const Color(0xFF233042)
          : const Color(0xFFDCE6F2),
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onSurface : tokens.mutedText,
        );
      }),
    ),
    extensions: [tokens],
  );
}
