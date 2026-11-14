import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/database/app_database.dart';
import '../core/security/vault_lifecycle.dart';
import 'vault_providers.dart';

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
    }
    return const AppAppearance();
  }

  Future<void> _load(VaultSession session) async {
    final epoch = ++_epoch;
    try {
      final rows = await session.db.select(session.db.vaultPreferences).get();
      if (!ref.mounted || epoch != _epoch || session.closed) {
        return;
      }
      final values = {for (final row in rows) row.key: row.value};
      state = AppAppearance(
        theme:
            ThemeMode.values
                .where((t) => t.name == values['ui.theme'])
                .firstOrNull ??
            ThemeMode.system,
        locale: Locale(values['ui.language'] == 'hi' ? 'hi' : 'en', 'IN'),
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
