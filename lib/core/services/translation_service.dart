import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum TranslationProvider {
  libre('libre'),
  google('google');

  const TranslationProvider(this.value);
  final String value;

  static TranslationProvider fromRaw(String raw) {
    final String normalized = raw.trim().toLowerCase();
    return TranslationProvider.values.firstWhere(
      (TranslationProvider p) => p.value == normalized,
      orElse: () => TranslationProvider.libre,
    );
  }
}

abstract class TranslationService {
  String get providerKey;
  bool get isConfigured;

  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  });
}

class LibreTranslateService implements TranslationService {
  LibreTranslateService({
    required this.endpoint,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final String apiKey;
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);

  @override
  String get providerKey => TranslationProvider.libre.value;

  @override
  bool get isConfigured => endpoint.trim().isNotEmpty;

  @override
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    if (!isConfigured) {
      throw const TranslationException(
        'Ceviri yapilandirilmadi. Yoneticiye iletin.',
      );
    }

    final Uri uri = _resolveUri(endpoint);
    final Map<String, dynamic> payload = <String, dynamic>{
      'q': text,
      'source': sourceLang,
      'target': targetLang,
      'format': 'text',
    };
    if (apiKey.trim().isNotEmpty) {
      payload['api_key'] = apiKey;
    }

    try {
      final http.Response response = await _client
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _statusError(response.statusCode);
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const TranslationException(
            'Ceviri yaniti beklenen formatta degil.');
      }

      final String? translated = _extractTranslatedText(decoded);
      if (translated == null || translated.trim().isEmpty) {
        throw const TranslationException('Ceviri metni bos geldi.');
      }
      return translated.trim();
    } on TimeoutException {
      throw const TranslationException('Ceviri istegi zaman asimina ugradi.');
    } on SocketException {
      throw const TranslationException('Ag hatasi nedeniyle ceviri alinamadi.');
    } on http.ClientException {
      throw const TranslationException('Ceviri servisine baglanilamadi.');
    } on FormatException {
      throw const TranslationException('Ceviri yaniti gecersiz formatta.');
    }
  }

  Uri _resolveUri(String endpointRaw) {
    final Uri base = Uri.parse(endpointRaw.trim());
    if (base.path.endsWith('/translate')) {
      return base;
    }
    final String nextPath = base.path.endsWith('/')
        ? '${base.path}translate'
        : '${base.path}/translate';
    return base.replace(path: nextPath);
  }

  String? _extractTranslatedText(Map<String, dynamic> data) {
    final dynamic t1 = data['translatedText'];
    if (t1 is String && t1.isNotEmpty) {
      return t1;
    }
    final dynamic t2 = data['translated_text'];
    if (t2 is String && t2.isNotEmpty) {
      return t2;
    }

    final dynamic translationsNode = data['data'];
    if (translationsNode is Map<String, dynamic>) {
      final dynamic translations = translationsNode['translations'];
      if (translations is List && translations.isNotEmpty) {
        final dynamic first = translations.first;
        if (first is Map<String, dynamic>) {
          final dynamic t3 = first['translatedText'];
          if (t3 is String && t3.isNotEmpty) {
            return t3;
          }
        }
      }
    }
    return null;
  }

  TranslationException _statusError(int code) {
    if (code == 429) {
      return const TranslationException(
        'Ceviri servisi su an yogun. Daha sonra tekrar dene.',
      );
    }
    if (code == 401 || code == 403) {
      return const TranslationException(
        'Ceviri yetkilendirmesi gecersiz. API ayarlarini kontrol et.',
      );
    }
    if (code >= 500) {
      return const TranslationException(
        'Ceviri servisi gecici olarak kullanilamiyor.',
      );
    }
    return TranslationException('Ceviri servisi hata kodu: $code');
  }
}

class GoogleCloudTranslateService implements TranslationService {
  GoogleCloudTranslateService({
    required this.endpoint,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final String apiKey;
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);

  @override
  String get providerKey => TranslationProvider.google.value;

  @override
  bool get isConfigured =>
      endpoint.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  @override
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    if (!isConfigured) {
      throw const TranslationException(
        'Ceviri yapilandirilmadi. Yoneticiye iletin.',
      );
    }

    final Uri uri = _googleUri(endpoint, apiKey);
    final Map<String, dynamic> payload = <String, dynamic>{
      'q': text,
      'source': sourceLang,
      'target': targetLang,
      'format': 'text',
    };

    try {
      final http.Response response = await _client
          .post(
            uri,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _statusError(response.statusCode);
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const TranslationException(
          'Google ceviri yaniti beklenen formatta degil.',
        );
      }

      final dynamic data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const TranslationException(
            'Google ceviri data alani bulunamadi.');
      }
      final dynamic translations = data['translations'];
      if (translations is! List || translations.isEmpty) {
        throw const TranslationException('Google ceviri metni bulunamadi.');
      }
      final dynamic first = translations.first;
      if (first is! Map<String, dynamic>) {
        throw const TranslationException(
          'Google ceviri metni beklenen formatta degil.',
        );
      }
      final dynamic translated = first['translatedText'];
      if (translated is! String || translated.trim().isEmpty) {
        throw const TranslationException('Google ceviri metni bos geldi.');
      }
      return translated.trim();
    } on TimeoutException {
      throw const TranslationException('Ceviri istegi zaman asimina ugradi.');
    } on SocketException {
      throw const TranslationException('Ag hatasi nedeniyle ceviri alinamadi.');
    } on http.ClientException {
      throw const TranslationException('Ceviri servisine baglanilamadi.');
    } on FormatException {
      throw const TranslationException('Ceviri yaniti gecersiz formatta.');
    }
  }

  Uri _googleUri(String endpointRaw, String key) {
    final Uri base = Uri.parse(endpointRaw.trim());
    final Uri normalized = base.path.trim().isEmpty
        ? base.replace(path: '/language/translate/v2')
        : base;

    final Map<String, String> qp = <String, String>{
      ...normalized.queryParameters,
      'key': key,
    };
    return normalized.replace(queryParameters: qp);
  }

  TranslationException _statusError(int code) {
    if (code == 429) {
      return const TranslationException(
        'Ceviri servisi su an yogun. Daha sonra tekrar dene.',
      );
    }
    if (code == 401 || code == 403) {
      return const TranslationException(
        'Ceviri yetkilendirmesi gecersiz. API ayarlarini kontrol et.',
      );
    }
    if (code >= 500) {
      return const TranslationException(
        'Ceviri servisi gecici olarak kullanilamiyor.',
      );
    }
    return TranslationException('Ceviri servisi hata kodu: $code');
  }
}

class TranslationException implements Exception {
  const TranslationException(this.message);
  final String message;

  @override
  String toString() => message;
}
