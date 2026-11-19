import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/vault_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/secure_store.dart';
import 'drive_backup_api.dart';
import 'drive_backup_destination.dart';

const _driveConfigurationError = AppFailure(
  FailureCode.configuration,
  'Check the Google Drive setup for this app build.',
);

final class DriveBackupConnection {
  const DriveBackupConnection(this.email, this.destination);
  final String email;
  final DriveBackupDestination destination;
}

abstract interface class DriveSignIn {
  Future<bool> configured();
  Future<DriveBackupConnection?> connect();
  Future<void> disconnect();
}

final driveSignInProvider = Provider<DriveSignIn>(
  (ref) => NativeDriveSignIn(
    AppConfig.environment().googleServerClientId,
    ref.watch(secureStoreProvider),
  ),
);
final driveConfiguredProvider = FutureProvider<bool>(
  (ref) => ref.watch(driveSignInProvider).configured(),
);
final driveConnectionProvider =
    NotifierProvider<DriveConnectionController, DriveBackupConnection?>(
      DriveConnectionController.new,
    );

class DriveConnectionController extends Notifier<DriveBackupConnection?> {
  @override
  DriveBackupConnection? build() => null;

  Future<void> connect() async {
    state = await ref.read(driveSignInProvider).connect();
  }

  Future<void> disconnect() async {
    state = null;
    await ref.read(driveSignInProvider).disconnect();
  }
}

final class NativeDriveSignIn implements DriveSignIn {
  NativeDriveSignIn(this.serverClientId, this.store);

  final String serverClientId;
  final SecureStore store;
  static const _channel = MethodChannel('app.familyvault/drive');
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  static final _clientId = RegExp(
    r'^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$',
  );
  Future<void>? _initialized;
  DriveBackupConnection? _connected;
  GoogleSignIn get _sdk => GoogleSignIn.instance;

  @override
  Future<bool> configured() async {
    if (Platform.isAndroid) return _clientId.hasMatch(serverClientId);
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('configured') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<DriveBackupConnection?> connect() async {
    final current = _connected;
    if (current != null) return current;
    if (!await configured()) throw _driveConfigurationError;
    try {
      await (_initialized ??= _sdk.initialize(
        serverClientId: Platform.isAndroid ? serverClientId : null,
      ));
      if (!_sdk.supportsAuthenticate()) throw _driveConfigurationError;
      final account = await _sdk.authenticate();
      final authorization = account.authorizationClient;
      if (await authorization.authorizationForScopes(_scopes) == null) {
        await authorization.authorizeScopes(_scopes);
      }
      late final DriveBackupConnection connection;
      final api = GoogleDriveBackupApi(
        () async {
          try {
            if (!identical(_connected, connection)) return null;
            final grant = await authorization.authorizationForScopes(_scopes);
            return identical(_connected, connection)
                ? grant?.accessToken
                : null;
          } catch (_) {
            throw driveAccessRequired;
          }
        },
        clearRejectedToken: (token) async {
          try {
            await authorization.clearAuthorizationToken(accessToken: token);
          } catch (_) {
            throw driveAccessRequired;
          }
        },
      );
      connection = DriveBackupConnection(
        account.email,
        DriveBackupDestination(api: api, store: store, accountId: account.id),
      );
      return _connected = connection;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw _driveConfigurationError;
      }
      throw driveAccessRequired;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw driveAccessRequired;
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = null;
    try {
      await _sdk.signOut();
    } catch (_) {
      throw driveAccessRequired;
    }
  }
}
