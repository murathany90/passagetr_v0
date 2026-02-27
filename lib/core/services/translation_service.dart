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

  Future<String> translateEnToTr(String text) {
    return translate(
      text: text,
      sourceLang: 'en',
      targetLang: 'tr',
    );
  }

  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  });
}

class LibreTranslateService extends TranslationService {
  LibreTranslateService({
    required this.endpoint,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final String apiKey;
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);
  static const List<String> _fallbackEndpoints = <String>[
    'https://translate.argosopentech.com/translate',
    'https://translate.astian.org/translate',
    'https://libretranslate.pussthecat.org/translate',
  ];

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

    final Map<String, dynamic> payload = <String, dynamic>{
      'q': text,
      'source': sourceLang,
      'target': targetLang,
      'format': 'text',
    };
    if (apiKey.trim().isNotEmpty) {
      payload['api_key'] = apiKey;
    }
    final String body = jsonEncode(payload);
    TranslationException? lastError;

    for (final Uri uri in _buildCandidateUris()) {
      try {
        final http.Response response = await _postWithRedirect(
          uri: uri,
          body: body,
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw _statusError(response: response, endpointUri: uri);
        }

        final dynamic decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const TranslationException(
            'Ceviri yaniti beklenen formatta degil.',
          );
        }

        final String? translated = _extractTranslatedText(decoded);
        if (translated == null || translated.trim().isEmpty) {
          throw const TranslationException('Ceviri metni bos geldi.');
        }
        return translated.trim();
      } on TimeoutException {
        lastError = TranslationException(
          'Ceviri istegi zaman asimina ugradi. endpoint: $uri',
        );
      } on SocketException {
        lastError = TranslationException(
          'Ag hatasi nedeniyle ceviri alinamadi. endpoint: $uri',
        );
      } on http.ClientException {
        lastError = TranslationException(
          'Ceviri servisine baglanilamadi. endpoint: $uri',
        );
      } on FormatException {
        lastError = TranslationException(
          'Ceviri yaniti gecersiz formatta. endpoint: $uri',
        );
      } on TranslationException catch (error) {
        lastError = error;
      }
    }

    throw lastError ?? const TranslationException('Ceviri su an alinamadi.');
  }

  Uri _resolveUri(String endpointRaw) {
    final Uri base = Uri.parse(_normalizeEndpoint(endpointRaw));
    if (base.path.trim().isEmpty) {
      return base.replace(path: '/translate/');
    }
    if (base.path.endsWith('/translate/')) {
      return base;
    }
    if (base.path.endsWith('/translate')) {
      return base.replace(path: '${base.path}/');
    }
    final String nextPath = base.path.endsWith('/')
        ? '${base.path}translate/'
        : '${base.path}/translate/';
    return base.replace(path: nextPath);
  }

  String _normalizeEndpoint(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.endsWith('/translate')) {
      return '$trimmed/';
    }
    return trimmed;
  }

  List<Uri> _buildCandidateUris() {
    final Set<String> seen = <String>{};
    final List<Uri> uris = <Uri>[];
    for (final String raw in <String>[endpoint, ..._fallbackEndpoints]) {
      final String normalized = _normalizeEndpoint(raw);
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      uris.add(_resolveUri(normalized));
    }
    return uris;
  }

  Future<http.Response> _postWithRedirect({
    required Uri uri,
    required String body,
  }) async {
    const Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final http.Response first = await _client
        .post(
          uri,
          headers: headers,
          body: body,
        )
        .timeout(_timeout);

    if (first.statusCode != 301 && first.statusCode != 302) {
      return first;
    }

    final String? location = first.headers['location'];
    if (location == null || location.trim().isEmpty) {
      return first;
    }

    final Uri rawRedirect = Uri.parse(location.trim()).hasScheme
        ? Uri.parse(location.trim())
        : uri.resolve(location.trim());

    final Uri redirectUri = _resolveUri(rawRedirect.toString());

    return _client
        .post(
          redirectUri,
          headers: headers,
          body: body,
        )
        .timeout(_timeout);
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

  TranslationException _statusError({
    required http.Response response,
    required Uri endpointUri,
  }) {
    final int code = response.statusCode;
    final String location = response.headers['location'] ?? '-';
    final String headers = response.headers.entries
        .map((MapEntry<String, String> e) => '${e.key}:${e.value}')
        .join(', ');

    if (code == 429) {
      return TranslationException(
        'Ceviri siniri asildi, biraz sonra tekrar dene. '
        '(status:$code endpoint:$endpointUri location:$location headers:$headers)',
      );
    }
    if (code == 401 || code == 403) {
      return TranslationException(
        'Ceviri yetkilendirmesi gecersiz. API ayarlarini kontrol et. '
        '(status:$code endpoint:$endpointUri location:$location headers:$headers)',
      );
    }
    if (code >= 500) {
      return TranslationException(
        'Ceviri servisi gecici olarak kullanilamiyor. '
        '(status:$code endpoint:$endpointUri location:$location headers:$headers)',
      );
    }
    return TranslationException(
      'Ceviri servisi hata kodu: $code '
      '(endpoint:$endpointUri location:$location headers:$headers)',
    );
  }
}

class GoogleCloudTranslateService extends TranslationService {
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
        'Ceviri siniri asildi, biraz sonra tekrar dene.',
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
