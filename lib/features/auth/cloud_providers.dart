import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/vault_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import 'cloud_access_gateway.dart';
import 'cloud_device_registration.dart';
import 'secure_auth_storage.dart';

final cloudConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.environment(),
);

final cloudGatewayProvider = FutureProvider<CloudAccessGateway>((ref) async {
  final config = ref.watch(cloudConfigProvider);
  final store = ref.watch(secureStoreProvider);
  config.validate(
    allowLocalDevelopment:
        kDebugMode && const bool.fromEnvironment('FAMILYVAULT_LOCAL_HTTP'),
  );
  if (!config.cloudConfigured) {
    throw const AppFailure(
      FailureCode.configuration,
      'Family access needs a configured server.',
    );
  }
  try {
    final instance = await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: secureAuthOptions(
        store: store,
        projectNamespace: cloudNamespace(config),
      ),
    );
    return SupabaseAccessGateway(instance.client);
  } catch (_) {
    throw const AppFailure(
      FailureCode.storage,
      'Family sign-in could not be initialized with secure storage.',
    );
  }
});

String cloudNamespace(AppConfig config) {
  final url = config.supabaseUrl.replaceFirst(RegExp(r'/+$'), '');
  return sha256.convert(utf8.encode(url)).toString().substring(0, 24);
}

final cloudRegistrationProvider = FutureProvider<CloudDeviceRegistration>((
  ref,
) async {
  final store = ref.watch(secureStoreProvider);
  final gate = ref.watch(deviceGateProvider);
  final config = ref.watch(cloudConfigProvider);
  final gateway = await ref.watch(cloudGatewayProvider.future);
  return CloudDeviceRegistration(
    store: store,
    gate: gate,
    gateway: gateway,
    namespace: cloudNamespace(config),
  );
});
