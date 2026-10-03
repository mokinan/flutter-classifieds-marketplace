import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace/core/providers.dart';

/// The chosen app language; `null` follows the device.
class LocaleController extends Notifier<Locale?> {
  static const _key = 'locale';

  @override
  Locale? build() => switch (ref.watch(sharedPreferencesProvider).getString(_key)) {
    final String code => Locale(code),
    null => null,
  };

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(sharedPreferencesProvider).setString(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);
