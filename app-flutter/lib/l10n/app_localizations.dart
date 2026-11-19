import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app_strings.dart';
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_es.dart';
import 'strings_fr.dart';
import 'strings_ja.dart';
import 'strings_ko.dart';
import 'strings_pt.dart';
import 'strings_ru.dart';
import 'strings_uk.dart';
import 'strings_zh_cn.dart';
import 'strings_zh_tw.dart';

export 'app_strings.dart';

/// Metadata for an actively supported application language.
class AppLocaleOption {
  final String code;
  final Locale locale;
  final String nativeName;
  final String englishName;

  const AppLocaleOption({
    required this.code,
    required this.locale,
    required this.nativeName,
    required this.englishName,
  });
}

class AppLocalizations {
  AppLocalizations._();

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppLocalizationsDelegate();

  static final List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];

  /// Active supported languages (11 LTR languages: zh_CN, zh_TW, en, ja, ko,
  /// es, pt, fr, de, ru, uk).
  static const List<AppLocaleOption> supportedLocaleOptions = [
    AppLocaleOption(
      code: 'zh_CN',
      locale: Locale('zh', 'CN'),
      nativeName: '简体中文',
      englishName: 'Simplified Chinese',
    ),
    AppLocaleOption(
      code: 'zh_TW',
      locale: Locale('zh', 'TW'),
      nativeName: '繁體中文',
      englishName: 'Traditional Chinese',
    ),
    AppLocaleOption(
      code: 'en',
      locale: Locale('en'),
      nativeName: 'English',
      englishName: 'English',
    ),
    AppLocaleOption(
      code: 'ja',
      locale: Locale('ja'),
      nativeName: '日本語',
      englishName: 'Japanese',
    ),
    AppLocaleOption(
      code: 'ko',
      locale: Locale('ko'),
      nativeName: '한국어',
      englishName: 'Korean',
    ),
    AppLocaleOption(
      code: 'es',
      locale: Locale('es'),
      nativeName: 'Español',
      englishName: 'Spanish',
    ),
    AppLocaleOption(
      code: 'pt',
      locale: Locale('pt'),
      nativeName: 'Português',
      englishName: 'Portuguese',
    ),
    AppLocaleOption(
      code: 'fr',
      locale: Locale('fr'),
      nativeName: 'Français',
      englishName: 'French',
    ),
    AppLocaleOption(
      code: 'de',
      locale: Locale('de'),
      nativeName: 'Deutsch',
      englishName: 'German',
    ),
    AppLocaleOption(
      code: 'ru',
      locale: Locale('ru'),
      nativeName: 'Русский',
      englishName: 'Russian',
    ),
    AppLocaleOption(
      code: 'uk',
      locale: Locale('uk'),
      nativeName: 'Українська',
      englishName: 'Ukrainian',
    ),
  ];

  static final List<Locale> supportedLocales = supportedLocaleOptions
      .map((opt) => opt.locale)
      .toList(growable: false);

  static Locale? _overrideLocale;

  /// Synchronizes non-widget consumers (controllers, background notifications,
  /// platform helpers) with the user's selected locale (`null` = follow OS).
  static void setOverrideLocale(Locale? locale) {
    _overrideLocale = locale;
  }

  /// Normalizes persisted or user-selected locale codes (`'zh'` legacy -> `'zh_CN'`).
  static String normalizeLocaleCode(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == 'system') return 'system';
    if (trimmed == 'zh') return 'zh_CN';
    for (final opt in supportedLocaleOptions) {
      if (opt.code.toLowerCase() == trimmed.toLowerCase()) {
        return opt.code;
      }
    }
    return 'system';
  }

  static Locale? localeForCode(String code) {
    final normalized = normalizeLocaleCode(code);
    for (final opt in supportedLocaleOptions) {
      if (opt.code == normalized) return opt.locale;
    }
    return null;
  }

  static AppLocaleOption? optionForCode(String code) {
    final normalized = normalizeLocaleCode(code);
    for (final opt in supportedLocaleOptions) {
      if (opt.code == normalized) return opt;
    }
    return null;
  }

  /// Resolves the best supported [Locale] using the 4-tier fallback chain:
  /// 1) Walk OS preference list in order (`deviceLocales`)
  /// 2) Collapse regional/script variants (e.g. zh-HK/Hant -> zh_TW, es-MX -> es)
  /// 3) Exact language match against [supportedLocaleOptions]
  /// 4) Global fallback -> English (`en`)
  static Locale resolveAppLocale(
    List<Locale>? deviceLocales, [
    Iterable<Locale>? supported,
  ]) {
    final candidates = (deviceLocales != null && deviceLocales.isNotEmpty)
        ? deviceLocales
        : PlatformDispatcher.instance.locales;

    for (final loc in candidates) {
      final lang = loc.languageCode.toLowerCase();
      if (lang == 'zh') {
        final script = loc.scriptCode?.toLowerCase();
        final country = loc.countryCode?.toUpperCase();
        if (script == 'hant' ||
            country == 'TW' ||
            country == 'HK' ||
            country == 'MO') {
          return const Locale('zh', 'TW');
        }
        return const Locale('zh', 'CN');
      }
      for (final opt in supportedLocaleOptions) {
        if (opt.locale.languageCode.toLowerCase() == lang) {
          return opt.locale;
        }
      }
    }
    return const Locale('en');
  }

  static Locale? localeListResolutionCallback(
    List<Locale>? deviceLocales,
    Iterable<Locale> supported,
  ) {
    return resolveAppLocale(deviceLocales, supported);
  }

  static AppStrings stringsForLocale(Locale locale) {
    final resolved = resolveAppLocale([locale]);
    if (resolved.languageCode == 'zh') {
      final country = resolved.countryCode?.toUpperCase();
      final script = resolved.scriptCode?.toLowerCase();
      if (script == 'hant' ||
          country == 'TW' ||
          country == 'HK' ||
          country == 'MO') {
        return const StringsZhTw();
      }
      return const StringsZhCn();
    }
    return switch (resolved.languageCode) {
      'ja' => const StringsJa(),
      'ko' => const StringsKo(),
      'es' => const StringsEs(),
      'pt' => const StringsPt(),
      'fr' => const StringsFr(),
      'de' => const StringsDe(),
      'ru' => const StringsRu(),
      'uk' => const StringsUk(),
      _ => const StringsEn(),
    };
  }

  /// Active strings for non-widget contexts (controllers, background toasts,
  /// native tray sync).
  static AppStrings get current {
    final effective = _overrideLocale ??
        resolveAppLocale(PlatformDispatcher.instance.locales);
    return stringsForLocale(effective);
  }

  /// Reactive strings lookup for widgets inside a [MaterialApp].
  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ?? current;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    return lang == 'zh' ||
        AppLocalizations.supportedLocaleOptions.any(
          (opt) => opt.locale.languageCode.toLowerCase() == lang,
        );
  }

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(
      AppLocalizations.stringsForLocale(locale),
    );
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
