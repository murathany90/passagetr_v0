import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/dictionary_bootstrap_state.dart';
import 'package:passagetr/state/content_providers.dart';

void main() {
  test('content hydration becomes ready on web after both bootstraps',
      () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        isWebPlatformProvider.overrideWith((Ref ref) => true),
        localStaticContentOverrideProvider.overrideWith(
          (Ref ref) => true,
        ),
        appContentBootstrapProvider.overrideWith((Ref ref) async {}),
        dictionaryAppBootstrapProvider.overrideWith((Ref ref) async {
          return const DictionaryBootstrapState(
            status: DictionaryBootstrapStatus.ready,
            datasetVersion: '20260305160340',
            batchId: 'seed',
            rowCount: 10,
            downloadedCount: 10,
            lastSeqId: 10,
            updatedAt: null,
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(contentHydrationControllerProvider.notifier)
        .ensureHydrated();

    final ContentHydrationState state =
        container.read(contentHydrationControllerProvider);
    expect(state.status, ContentHydrationStatus.ready);
    expect(state.progress, 1);
    expect(state.warningMessage, isNull);
  });

  test('content hydration stores failure state when a bootstrap fails',
      () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        isWebPlatformProvider.overrideWith((Ref ref) => true),
        localStaticContentOverrideProvider.overrideWith(
          (Ref ref) => true,
        ),
        appContentBootstrapProvider.overrideWith((Ref ref) async {
          throw StateError('seed import failed');
        }),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(contentHydrationControllerProvider.notifier)
        .ensureHydrated();

    final ContentHydrationState state =
        container.read(contentHydrationControllerProvider);
    expect(state.status, ContentHydrationStatus.ready);
    expect(
      container.read(effectiveUseLocalStaticContentProvider),
      isFalse,
    );
    expect(state.warningMessage, contains('Cevrimici veri kullaniliyor'));
  });

  test('web defaults to remote content mode', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        isWebPlatformProvider.overrideWith((Ref ref) => true),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(effectiveUseLocalStaticContentProvider), isFalse);
    expect(container.read(shouldUseContentHydrationProvider), isFalse);
  });
}
