class AppConfig {
  // Raw env (as provided by --dart-define)
  static const String _supabaseUrlRaw = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKeyRaw =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String demoUserUuid = String.fromEnvironment('DEMO_USER_UUID');

  static const bool allowDemoFallback = bool.fromEnvironment(
    'ALLOW_DEMO_FALLBACK',
    defaultValue: false,
  );

  static const bool useProgressRpc = bool.fromEnvironment(
    'USE_PROGRESS_RPC',
    defaultValue: false,
  );

  static const bool useLocalStaticContent = bool.fromEnvironment(
    'USE_LOCAL_STATIC_CONTENT',
    defaultValue: true,
  );

  static const String _translateProviderRaw = String.fromEnvironment(
    'TRANSLATE_PROVIDER',
    defaultValue: 'libre',
  );

  static const String _translateEndpointRaw =
      String.fromEnvironment('TRANSLATE_ENDPOINT');

  static const String _translateApiKeyRaw =
      String.fromEnvironment('TRANSLATE_API_KEY');

  /// When true, LibreTranslate will try public community endpoints as
  /// fallback when the primary endpoint fails. Disabled by default for
  /// production safety (rate-limit, uptime, privacy risks).
  static const bool allowLibreFallbacks = bool.fromEnvironment(
    'ALLOW_LIBRE_FALLBACKS',
    defaultValue: false,
  );

  // Sanitized values (trim + normalize)
  static final String supabaseUrl = _normalizeUrl(_supabaseUrlRaw);
  static final String supabaseAnonKey = _supabaseAnonKeyRaw.trim();

  static final String translateProvider = _translateProviderRaw.trim();
  static final String translateEndpoint = _translateEndpointRaw.trim();
  static final String translateApiKey = _translateApiKeyRaw.trim();

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Returns fallback endpoints only when [allowLibreFallbacks] is enabled.
  static List<String> get libreFallbackEndpoints {
    if (!allowLibreFallbacks) {
      return const <String>[];
    }
    return const <String>[
      'https://translate.argosopentech.com/translate',
      'https://translate.astian.org/translate',
      'https://libretranslate.pussthecat.org/translate',
    ];
  }

  static String _normalizeUrl(String input) {
    var u = input.trim();

    // remove trailing slashes to be safe: https://xxx.supabase.co/
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }

    // tolerate user passing only host without scheme
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }

    return u;
  }
}

