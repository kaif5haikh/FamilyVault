import '../errors/app_failure.dart';

final class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.publishableKey = '',
    this.googleServerClientId = '',
  });
  factory AppConfig.environment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    googleServerClientId: String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
  );
  final String supabaseUrl;
  final String publishableKey;
  final String googleServerClientId;
  bool get cloudConfigured =>
      supabaseUrl.isNotEmpty && publishableKey.isNotEmpty;
  void validate({bool allowLocalDevelopment = false}) {
    if (supabaseUrl.isEmpty && publishableKey.isEmpty) return;
    final uri = Uri.tryParse(supabaseUrl);
    final local =
        uri != null &&
        ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host);
    if (!cloudConfigured ||
        uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' &&
            !(allowLocalDevelopment && local && uri.scheme == 'http')) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !publishableKey.startsWith('sb_publishable_')) {
      throw const AppFailure(
        FailureCode.configuration,
        'Cloud configuration is invalid. Use a publishable client key and secure URL.',
      );
    }
  }

  @override
  String toString() => 'AppConfig(cloudConfigured: $cloudConfigured)';
}
