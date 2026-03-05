import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/supabase_grammar_repository.dart';
import '../domain/entities/grammar_module.dart';
import '../domain/entities/grammar_page.dart';
import '../domain/entities/grammar_page_detail.dart';
import '../domain/repositories/grammar_repository.dart';
import 'auth_providers.dart';

final Provider<GrammarRepository> grammarRepositoryProvider =
    Provider<GrammarRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseGrammarRepository(client);
});

final FutureProvider<List<GrammarModule>> grammarModulesProvider =
    FutureProvider<List<GrammarModule>>((Ref ref) async {
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getModules();
});

final grammarPagesProvider =
    FutureProvider.family<List<GrammarPage>, int>((Ref ref, int modulId) async {
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getPagesByModule(modulId: modulId);
});

final grammarPageDetailProvider =
    FutureProvider.family<GrammarPageDetail, int>((Ref ref, int sayfaId) async {
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getPageDetail(sayfaId: sayfaId);
});
