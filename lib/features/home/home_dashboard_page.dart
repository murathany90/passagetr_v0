import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/home_dashboard_data.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/reading_resume_item.dart';
import '../../state/providers.dart';
import '../flashcard/flashcard_session_page.dart';
import '../readings/reading_detail_page.dart';

class HomeDashboardPage extends ConsumerStatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  ConsumerState<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends ConsumerState<HomeDashboardPage> {
  Future<void> _onQuickStart(HomeDashboardData data) async {
    final QuickStartSuggestion quickStart = data.quickStart;
    if (!quickStart.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Hizli basla icin uygun icerik bulunamadi.')),
      );
      return;
    }

    bool shouldRefresh = false;

    switch (quickStart.type) {
      case QuickStartType.resumeReading:
        final ReadingResumeItem? resumeItem = quickStart.resumeItem;
        final Pack? pack = quickStart.pack;
        if (resumeItem == null || pack == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yarim kalan okuma acilamadi.')),
          );
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReadingDetailPage(
              passage: resumeItem.passage,
              pack: pack,
              initialLastIdx: resumeItem.progress.lastIdx,
            ),
          ),
        );
        shouldRefresh = true;
        break;
      case QuickStartType.weakWords:
      case QuickStartType.randomWords:
        final Pack? pack = quickStart.pack;
        final List<String> ids = quickStart.wordIds;
        if (pack == null || ids.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Hizli basla icin kelime bulunamadi.')),
          );
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FlashcardSessionPage(
              pack: pack,
              customWordIds: ids,
              sessionLabel: 'Hizli Basla',
            ),
          ),
        );
        shouldRefresh = true;
        break;
      case QuickStartType.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hizli basla hazir degil.')),
        );
        break;
    }

    if (mounted && shouldRefresh) {
      ref.invalidate(homeDashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<HomeDashboardData> dashboard = ref.watch(
      homeDashboardProvider,
    );

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Ana sayfa verisi yuklenemedi.'),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(homeDashboardProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
      data: (HomeDashboardData data) {
        final String quickStartText = switch (data.quickStart.type) {
          QuickStartType.resumeReading => 'Hizli Basla: Okumaya Devam Et',
          QuickStartType.weakWords => 'Hizli Basla: Zorlandigin Kelimeler',
          QuickStartType.randomWords => 'Hizli Basla: Rastgele Flashcard',
          QuickStartType.unavailable => 'Hizli Basla su an kullanilamiyor',
        };

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeDashboardProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Bugunun Durumu',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _MetricRow(
                        label: 'Bugun gorulen kelime',
                        value: '${data.todayWordCount}',
                      ),
                      _MetricRow(
                        label: 'Bugun okunan cumle',
                        value: '${data.todayReadSentenceCount}',
                      ),
                      _MetricRow(
                        label: 'Bugun cozulen soru',
                        value: data.todaySolvedQuestionText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: data.quickStart.isAvailable
                    ? () => _onQuickStart(data)
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(quickStartText),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
