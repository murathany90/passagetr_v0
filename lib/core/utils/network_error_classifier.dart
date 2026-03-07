import 'dart:async';

import 'package:http/http.dart' as http;

class NetworkErrorClassifier {
  const NetworkErrorClassifier._();

  static bool isNetworkLikeError(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return true;
    }
    final String text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('xmlhttprequest error') ||
        text.contains('typeerror: failed to fetch') ||
        text.contains('network request failed') ||
        text.contains('clientexception');
  }

  static bool isAuthTransientError(Object error) {
    final String text = error.toString().toLowerCase();
    return text.contains('auth session yok') ||
        text.contains('unauthenticated') ||
        text.contains('anonymous giris') ||
        text.contains('invalid jwt') ||
        text.contains('session_not_found');
  }

  static String toUserSafeMessage(
    Object error, {
    required String fallback,
  }) {
    final String text = error.toString().toLowerCase();
    if (isNetworkLikeError(error)) {
      return 'Internet baglantisi gerekli. Daha sonra tekrar dene.';
    }
    if (isAuthTransientError(error)) {
      return 'Oturum gecici olarak kullanilamiyor. Tekrar deneyin.';
    }
    if (text.contains('429') || text.contains('siniri asildi')) {
      return 'Servis siniri asildi, biraz sonra tekrar dene.';
    }
    if (text.contains('403') ||
        text.contains('401') ||
        text.contains('yetkilendirme')) {
      return 'Servis yetkilendirmesi gecersiz.';
    }
    return fallback;
  }
}
