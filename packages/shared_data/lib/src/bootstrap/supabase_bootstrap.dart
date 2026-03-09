import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize(AppConfig config) async {
    if (_initialized || !config.supabaseEnabled) {
      return;
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );

    _initialized = true;
  }
}
