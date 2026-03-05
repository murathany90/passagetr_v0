import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/services/offline_sync_controller.dart';
import 'package:passagetr/features/shell/main_shell_page.dart';

void main() {
  testWidgets('shows pending count in offline sync banner', (
    WidgetTester tester,
  ) async {
    const OfflineSyncStatus status = OfflineSyncStatus(
      pendingReadingCount: 2,
      pendingWordEventCount: 3,
      isOfflineLikely: true,
      isFlushing: false,
      lastFlushAtMillis: null,
      droppedCount: 0,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OfflineSyncBanner(status: status),
        ),
      ),
    );

    expect(find.textContaining('Cevrimdisi'), findsOneWidget);
    expect(find.textContaining('(5)'), findsOneWidget);
  });
}

