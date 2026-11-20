import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/app_database.dart';
import '../core/security/vault_lifecycle.dart';
import 'vault_providers.dart';

const languageChoices = [
  (Locale('en', 'IN'), 'English (India)'),
  (Locale('hi', 'IN'), 'हिन्दी (भारत)'),
  (Locale('mr', 'IN'), 'मराठी (भारत)'),
];

final class AppAppearance {
  const AppAppearance({
    this.theme = ThemeMode.system,
    this.locale = const Locale('en', 'IN'),
    this.saved = true,
  });
  final ThemeMode theme;
  final Locale locale;
  final bool saved;
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppAppearance>(
      AppearanceController.new,
    );

class AppearanceController extends Notifier<AppAppearance> {
  static const _phoneLanguage = 'ui.phone_language';
  int _epoch = 0;
  @override
  AppAppearance build() {
    ref.listen(vaultProvider, (_, next) {
      if (next.phase == VaultPhase.open && next.session != null) {
        unawaited(_load(next.session!));
      }
    });
    final session = ref.read(vaultProvider).session;
    if (session != null) {
      unawaited(Future<void>.microtask(() => _load(session)));
    } else {
      unawaited(Future<void>.microtask(_loadPhoneLanguage));
    }
    return const AppAppearance();
  }

  Locale? _locale(String? code) => languageChoices
      .map((choice) => choice.$1)
      .where((locale) => locale.languageCode == code)
      .firstOrNull;

  Future<Locale?> _preferredLanguage() async {
    try {
      return _locale(await ref.read(secureStoreProvider).read(_phoneLanguage));
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPhoneLanguage() async {
    final epoch = _epoch;
    final locale = await _preferredLanguage();
    if (locale != null && ref.mounted && epoch == _epoch) {
      state = AppAppearance(theme: state.theme, locale: locale);
    }
  }

  Future<void> _load(VaultSession session) async {
    final epoch = ++_epoch;
    try {
      final rows = await session.db.select(session.db.vaultPreferences).get();
      final values = {for (final row in rows) row.key: row.value};
      final locale =
          _locale(values['ui.language']) ?? await _preferredLanguage();
      if (!ref.mounted || epoch != _epoch || session.closed) {
        return;
      }
      state = AppAppearance(
        theme:
            ThemeMode.values
                .where((t) => t.name == values['ui.theme'])
                .firstOrNull ??
            ThemeMode.system,
        locale: locale ?? state.locale,
      );
    } catch (_) {
      /* Presentation preferences are optional; no data/key fallback. */
    }
  }

  Future<void> change({ThemeMode? theme, Locale? locale}) async {
    ++_epoch;
    final next = AppAppearance(
      theme: theme ?? state.theme,
      locale: locale ?? state.locale,
    );
    state = next;
    if (locale != null) {
      try {
        await ref
            .read(secureStoreProvider)
            .write(_phoneLanguage, next.locale.languageCode);
      } catch (_) {
        // An open vault can still save the preference.
      }
    }
    if (!ref.mounted || !identical(state, next)) return;
    final session = ref.read(vaultProvider).session;
    if (session == null || session.closed) {
      return;
    }
    try {
      await session.db.transaction(() async {
        await session.db
            .into(session.db.vaultPreferences)
            .insertOnConflictUpdate(
              VaultPreferencesCompanion.insert(
                key: 'ui.theme',
                value: next.theme.name,
              ),
            );
        await session.db
            .into(session.db.vaultPreferences)
            .insertOnConflictUpdate(
              VaultPreferencesCompanion.insert(
                key: 'ui.language',
                value: next.locale.languageCode,
              ),
            );
      });
    } catch (_) {
      if (ref.mounted && identical(state, next)) {
        state = AppAppearance(
          theme: next.theme,
          locale: next.locale,
          saved: false,
        );
      }
    }
  }
}
