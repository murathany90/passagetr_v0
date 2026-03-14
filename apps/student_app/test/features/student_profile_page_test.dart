import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/core/student_access_controller.dart';
import 'package:student_app/src/core/student_providers.dart';
import 'package:student_app/src/features/profile/profile_page.dart';

void main() {
  testWidgets('settings page refreshes content with loading and success UI', (
    tester,
  ) async {
    final syncRepository = _DelayedSyncRepository();
    final accessContext = AccessContext.preview(
      role: AppRole.user,
      plan: EntitlementPlan.free,
      isAnonymous: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentAccessProvider.overrideWith(
            (ref) => StudentAccessController(
              authRepository: _StaticAuthRepository(accessContext),
              initialAccessContext: accessContext,
            ),
          ),
          studentSyncRepositoryProvider.overrideWithValue(syncRepository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: StudentProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('profile_refresh_content_button')),
      findsOneWidget,
    );
    expect(find.text('Icerigi yenile'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('profile_refresh_content_button')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('profile_refresh_content_button')),
    );
    await tester.pump();

    expect(syncRepository.syncNowCalls, <SyncScope>[SyncScope.content]);
    expect(find.text('Icerik yenileniyor...'), findsWidgets);

    syncRepository.complete(const AppSuccess<void>(null));
    await tester.pumpAndSettle();

    expect(find.text('Icerik yenilendi.'), findsWidgets);
  });
}

class _DelayedSyncRepository implements SyncRepository {
  final List<SyncScope> syncNowCalls = <SyncScope>[];
  Completer<AppResult<void>>? _completer;

  void complete(AppResult<void> result) {
    _completer?.complete(result);
  }

  @override
  Future<AppResult<void>> syncIfStale(SyncScope scope) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<void>> syncNow(SyncScope scope) {
    syncNowCalls.add(scope);
    _completer = Completer<AppResult<void>>();
    return _completer!.future;
  }
}

class _StaticAuthRepository implements AuthRepository {
  const _StaticAuthRepository(this.accessContext);

  final AccessContext accessContext;

  @override
  Future<AuthSession> restoreSession() async => accessContext.session;

  @override
  Future<AppResult<AuthSession>> refreshSession() async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Stream<AccessContext> watchAccessContext() =>
      const Stream<AccessContext>.empty();

  @override
  Future<AppResult<AuthSession>> signInAnonymously() async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<void>> resendSignUpConfirmation({
    required String email,
  }) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<AuthSession>> updateDisplayName({
    required String displayName,
  }) async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<AuthSession>> upgradeAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<void>> signOut() async {
    return const AppSuccess<void>(null);
  }
}
