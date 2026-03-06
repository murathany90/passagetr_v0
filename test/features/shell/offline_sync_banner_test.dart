import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/services/offline_sync_controller.dart';
import 'package:passagetr/features/shell/main_shell_page.dart';

void main() {
  testWidgets('shows pending count in offline status action', (
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
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              OfflineSyncStatusAction(
                status: status,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Senkron durumu'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
