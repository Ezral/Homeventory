/// Runtime configuration injected via `--dart-define`.
///
/// Never embed the Supabase service-role key in the client.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleWebClientId,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String googleWebClientId;

  bool get isConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty;
  }

  bool get hasGoogleClient => googleWebClientId.isNotEmpty;
}
