import 'package:admin_console/src/core/admin_console_models.dart';
import 'package:admin_console/src/core/admin_providers.dart';
import 'package:admin_console/src/features/common/admin_page_parts.dart';
import 'package:admin_console/src/features/content/content_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('readings CMS renders CSV import actions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminContentPage(destination: AdminDestination.readings),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Okuma Operasyonlari'), findsOneWidget);
    expect(find.text('Tumune Ata'), findsOneWidget);
    expect(find.text('CSV Yukle'), findsOneWidget);
    expect(find.text('Yeni Parca Ekle'), findsOneWidget);
    expect(find.text('Eksik Mini Testler'), findsOneWidget);
    expect(find.text('Eksik Kapaklar'), findsOneWidget);
    expect(find.text('Mini Test'), findsOneWidget);
    expect(find.text('Gorsel'), findsOneWidget);
    expect(find.text('Filtreleri sifirla'), findsOneWidget);
    expect(find.textContaining('odak 0'), findsWidgets);
  });

  testWidgets(
    'active cover run waits for explicit continue before processing',
    (tester) async {
      final repository = _FakeAdminAiReadingRepository(
        activeRuns: const [
          AdminAiReadingRun(
            id: 'run-1',
            jobType: 'cover_backfill',
            status: 'running',
            provider: adminAiProviderCoverAuto,
            model: adminAiCoverAutoModel,
            questionCount: 3,
            totalCount: 5,
            processedCount: 1,
            succeededCount: 1,
            failedCount: 0,
            skippedCount: 0,
            filterSnapshot: <String, dynamic>{
              'target_count': 5,
              'has_cover': false,
            },
          ),
        ],
        processResult: const AdminAiReadingRun(
          id: 'run-1',
          jobType: 'cover_backfill',
          status: 'completed',
          provider: adminAiProviderCoverAuto,
          model: adminAiCoverAutoModel,
          questionCount: 3,
          totalCount: 5,
          processedCount: 2,
          succeededCount: 2,
          failedCount: 0,
          skippedCount: 0,
          filterSnapshot: <String, dynamic>{
            'target_count': 5,
            'has_cover': false,
          },
        ),
      );

      await _pumpReadingsPage(tester, repository: repository);

      await tester.tap(find.widgetWithText(FilledButton, 'Eksik Kapaklar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text("Bu run aktif durumda. Isleme devam etmek icin Devam Et'e basin."),
        findsOneWidget,
      );
      expect(repository.createRunCalls, 0);
      expect(repository.processRunCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Devam Et'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.processRunCalls, 1);
    },
  );
}

Future<void> _pumpReadingsPage(
  WidgetTester tester, {
  required _FakeAdminAiReadingRepository repository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1920, 1200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAppConfigProvider.overrideWith(
          (ref) => const AppConfig(
            appName: 'PASSAGETR Admin Console',
            environment: AppEnvironment.dev,
            platformMode: PlatformMode.web,
            supabaseUrl: 'https://example.supabase.co',
            supabaseAnonKey: 'anon-key',
            adminConsoleUrl: 'https://admin.example.com',
            adminPreviewEnabled: false,
          ),
        ),
        adminAccessProvider.overrideWith(
          (ref) => AccessContext.preview(
            role: AppRole.admin,
            plan: EntitlementPlan.pro,
            isAnonymous: false,
          ),
        ),
        adminDefaultListPageSizeProvider.overrideWith((ref) => 50),
        adminAiReadingRepositoryProvider.overrideWith((ref) => repository),
        adminPacksProvider.overrideWith(
          (ref) async => const [
            AdminPackRecord(
              id: 'pack-1',
              name: 'Starter Pack',
              wordCount: 10,
              isPublished: true,
              updatedAtLabel: 'now',
            ),
          ],
        ),
        adminReadingPageProvider.overrideWith(
          (ref, request) async => const AdminPage<AdminReadingRecord>(
            items: [
              AdminReadingRecord(
                id: 'reading-1',
                packId: 'pack-1',
                packName: 'Starter Pack',
                title: '001-First Reading',
                level: 'A1',
                category: 'general',
                tagsRaw: 'starter',
                isPro: false,
                isPublished: true,
                linkedWordCount: 0,
                questionCount: 0,
                hasCover: false,
                updatedAtLabel: 'now',
              ),
            ],
            totalCount: 1,
            offset: 0,
            limit: 50,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const AdminContentPage(destination: AdminDestination.readings),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _FakeAdminAiReadingRepository implements AdminAiReadingRepository {
  _FakeAdminAiReadingRepository({
    this.activeRuns = const <AdminAiReadingRun>[],
    this.processResult,
  });

  final List<AdminAiReadingRun> activeRuns;
  final AdminAiReadingRun? processResult;
  int createRunCalls = 0;
  int processRunCalls = 0;

  @override
  Future<AppResult<List<AdminAiReadingRun>>> listActiveReadingAiRuns() async {
    return AppSuccess<List<AdminAiReadingRun>>(activeRuns);
  }

  @override
  Future<AppResult<AdminAiCoverPoolStatus>> fetchAiCoverPoolStatus() async {
    return AppSuccess<AdminAiCoverPoolStatus>(
      AdminAiCoverPoolStatus(
        usageDateUtc: DateTime.utc(2026, 3, 16),
        localCapsEnabled: true,
        models: const [
          AdminAiCoverModelUsageStatus(
            provider: adminAiProviderImageRouter,
            model: 'google/nano-banana-2:free',
            enabled: true,
            priority: 1,
            dailyCap: 3,
          ),
        ],
      ),
    );
  }

  @override
  Future<AppResult<AdminAiReadingRun>> createReadingAiRun(
    AdminAiReadingRunRequest request,
  ) async {
    createRunCalls += 1;
    return AppSuccess<AdminAiReadingRun>(
      processResult ??
          const AdminAiReadingRun(
            id: 'run-created',
            jobType: 'cover_backfill',
            status: 'queued',
            provider: adminAiProviderCoverAuto,
            model: adminAiCoverAutoModel,
            questionCount: 3,
            totalCount: 1,
            processedCount: 0,
            succeededCount: 0,
            failedCount: 0,
            skippedCount: 0,
          ),
    );
  }

  @override
  Future<AppResult<AdminAiReadingRun>> processReadingAiRun({
    required String runId,
    int batchSize = 3,
  }) async {
    processRunCalls += 1;
    return AppSuccess<AdminAiReadingRun>(
      processResult ??
          const AdminAiReadingRun(
            id: 'run-1',
            jobType: 'cover_backfill',
            status: 'completed',
            provider: adminAiProviderCoverAuto,
            model: adminAiCoverAutoModel,
            questionCount: 3,
            totalCount: 1,
            processedCount: 1,
            succeededCount: 1,
            failedCount: 0,
            skippedCount: 0,
          ),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
