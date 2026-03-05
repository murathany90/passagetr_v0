import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/supabase_progress_repository.dart';
import '../data/repositories/supabase_reading_repository.dart';
import 'auth_providers.dart';

final Provider<SupabaseReadingRepository> supabaseReadingRepositoryProvider =
    Provider<SupabaseReadingRepository>((Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseReadingRepository(client);
});

final Provider<SupabaseProgressRepository> supabaseProgressRepositoryProvider =
    Provider<SupabaseProgressRepository>((Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseProgressRepository(client);
});

