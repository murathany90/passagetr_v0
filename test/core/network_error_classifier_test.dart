import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/utils/network_error_classifier.dart';

void main() {
  test('isNetworkLikeError detects socket failures', () {
    const SocketException error = SocketException('Failed host lookup');
    expect(NetworkErrorClassifier.isNetworkLikeError(error), isTrue);
  });

  test('isAuthTransientError detects auth/session text', () {
    const String message = 'Auth session yok. Progress yazimi auth olmadan baslatilamaz.';
    expect(NetworkErrorClassifier.isAuthTransientError(message), isTrue);
  });

  test('toUserSafeMessage hides technical host details', () {
    const String raw =
        "ClientException with SocketException: Failed host lookup: 'example.supabase.co'";
    final String safe = NetworkErrorClassifier.toUserSafeMessage(
      raw,
      fallback: 'fallback',
    );
    expect(safe.toLowerCase(), contains('internet'));
    expect(safe, isNot(contains('supabase.co')));
  });
}
