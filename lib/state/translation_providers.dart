import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/services/translation_service.dart';
import 'auth_providers.dart';

final Provider<TranslationService> translationServiceProvider =
    Provider<TranslationService>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  final TranslationProvider provider =
      TranslationProvider.fromRaw(AppConfig.translateProvider);

  switch (provider) {
    case TranslationProvider.libre:
      return LibreTranslateService(
        endpoint: AppConfig.translateEndpoint,
        apiKey: AppConfig.translateApiKey,
        fallbackEndpoints: AppConfig.libreFallbackEndpoints,
      );
    case TranslationProvider.google:
      return GoogleCloudTranslateService(
        endpoint: AppConfig.translateEndpoint,
        apiKey: AppConfig.translateApiKey,
      );
    case TranslationProvider.deepl:
      return DeeplEdgeFunctionTranslationService(client: client);
  }
});
