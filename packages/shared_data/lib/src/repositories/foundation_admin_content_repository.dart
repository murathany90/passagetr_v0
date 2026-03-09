import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';

class FoundationAdminContentRepository implements AdminContentRepository {
  const FoundationAdminContentRepository({required AppConfig config})
    : _config = config;

  final AppConfig _config;

  @override
  Future<AppResult<void>> setContentPublished({
    required String entityType,
    required String entityId,
    required bool isPublished,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      await Supabase.instance.client.rpc<void>(
        'admin_set_content_publish_state',
        params: <String, dynamic>{
          'p_entity_type': entityType,
          'p_entity_id': entityId,
          'p_is_published': isPublished,
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Icerik yayin durumu guncellenemedi: $error');
    }
  }
}
