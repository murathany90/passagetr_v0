import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/tts_service.dart';

/// Provides the singleton [TtsService] instance.
final Provider<TtsService> ttsServiceProvider = Provider<TtsService>(
  (Ref ref) => TtsService.instance,
);
