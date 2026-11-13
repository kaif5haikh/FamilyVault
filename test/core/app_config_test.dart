import 'package:flutter_test/flutter_test.dart';
import 'package:familyvault/core/config/app_config.dart';
import 'package:familyvault/core/errors/app_failure.dart';

void main() {
  test('configuration defaults to offline without silently accepting secrets or insecure hosts', () {
    const AppConfig().validate();
    for (final config in [
      const AppConfig(
        supabaseUrl: 'http://external.invalid',
        publishableKey: 'sb_publishable_example',
      ),
      const AppConfig(
        supabaseUrl: 'https://project.invalid',
        publishableKey: 'sb_secret_forbidden',
      ),
      const AppConfig(
        supabaseUrl: 'https://user:password@project.invalid',
        publishableKey: 'sb_publishable_example',
      ),
      const AppConfig(supabaseUrl: 'https://project.invalid'),
    ]) {
      expect(config.validate, throwsA(isA<AppFailure>()));
    }
    const AppConfig(
      supabaseUrl: 'http://127.0.0.1:54321',
      publishableKey: 'sb_publishable_example',
    ).validate(allowLocalDevelopment: true);
  });
}
