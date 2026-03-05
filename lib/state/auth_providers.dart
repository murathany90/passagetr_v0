import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_session_service.dart';

final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) {
  return Supabase.instance.client;
});

final Provider<AuthSessionService> authSessionServiceProvider =
    Provider<AuthSessionService>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return AuthSessionService(client);
});

final FutureProvider<void> authBootstrapProvider = FutureProvider<void>((
  Ref ref,
) async {
  await ref.watch(authSessionServiceProvider).ensureAnonymousSession();
});
