import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_loading_block.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_stat_tile.dart';
import '../../core/widgets/app_surface_card.dart';
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
          content: Text('Hizli basla icin uygun icerik bulunamadi.'),
        ),
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
              content: Text('Hizli basla icin kelime bulunamadi.'),
            ),
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
      loading: () => const AppLoadingBlock(message: 'Ana sayfa yukleniyor...'),
      error: (Object error, StackTrace stack) {
        return AppErrorState(
          title: 'Ana sayfa verisi yuklenemedi.',
          detail: error.toString(),
          onRetry: () => ref.invalidate(homeDashboardProvider),
        );
      },
      data: (HomeDashboardData data) {
        final String quickStartTitle = switch (data.quickStart.type) {
          QuickStartType.resumeReading => 'Okumaya Devam Et',
          QuickStartType.weakWords => 'Zorlandigin Kelimeler',
          QuickStartType.randomWords => 'Rastgele Flashcard',
          QuickStartType.unavailable => 'Hizli Basla su an kullanilamiyor',
        };

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeDashboardProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppSurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Bugunun Durumu',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gunluk hedefini hizli basla ile devam ettir.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 14),
                    AppGradientCtaButton(
                      label: 'Hizli Basla: $quickStartTitle',
                      icon: Icons.play_arrow_rounded,
                      enabled: data.quickStart.isAvailable,
                      onTap: () => _onQuickStart(data),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AppSectionHeader(title: 'Gunluk Metrikler'),
              const SizedBox(height: 8),
              AppStatTile(
                label: 'Bugun gorulen kelime',
                value: '${data.todayWordCount}',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: 8),
              AppStatTile(
                label: 'Bugun okunan cumle',
                value: '${data.todayReadSentenceCount}',
                icon: Icons.menu_book_outlined,
              ),
              const SizedBox(height: 8),
              AppStatTile(
                label: 'Bugun cozulen soru',
                value: data.todaySolvedQuestionText,
                icon: Icons.quiz_outlined,
              ),
            ],
          ),
        );
      },
    );
  }
}
