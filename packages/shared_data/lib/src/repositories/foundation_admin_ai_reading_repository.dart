import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';

typedef AdminAiReadingFunctionInvoker =
    Future<AdminAiReadingFunctionResponse> Function(
      AdminAiGenerateReadingRequest request,
    );

class FoundationAdminAiReadingRepository implements AdminAiReadingRepository {
  const FoundationAdminAiReadingRepository({
    required AppConfig config,
    AdminAiReadingFunctionInvoker? functionInvoker,
  }) : _config = config,
       _functionInvoker = functionInvoker;

  final AppConfig _config;
  final AdminAiReadingFunctionInvoker? _functionInvoker;

  @override
  Future<AppResult<AdminAiGeneratedReadingDraft>> generateReadingDraft(
    AdminAiGenerateReadingRequest request,
  ) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminAiGeneratedReadingDraft>(
        'Preview modunda AI draft uretimi desteklenmiyor.',
      );
    }

    try {
      final response = await (_functionInvoker ?? _invokeGenerateDraft)(
        request,
      );
      final payload = _coerceMap(response.data);
      if (response.status >= 400) {
        return AppFailure<AdminAiGeneratedReadingDraft>(
          _messageFromErrorPayload(payload),
        );
      }

      if (payload.isEmpty) {
        return const AppFailure<AdminAiGeneratedReadingDraft>(
          'AI servisi beklenen JSON cevabini donmedi.',
        );
      }

      final draft = AdminAiGeneratedReadingDraft.fromJson(payload);
      final validationError = _validateDraft(draft);
      if (validationError != null) {
        return AppFailure<AdminAiGeneratedReadingDraft>(validationError);
      }

      return AppSuccess<AdminAiGeneratedReadingDraft>(draft);
    } catch (error) {
      return AppFailure<AdminAiGeneratedReadingDraft>(
        _messageFromException(error),
      );
    }
  }

  Future<AdminAiReadingFunctionResponse> _invokeGenerateDraft(
    AdminAiGenerateReadingRequest request,
  ) async {
    await SupabaseBootstrap.initialize(_config);
    final session = await _resolveSession();
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin_ai_generate_reading_draft',
        method: HttpMethod.post,
        headers: _functionHeadersForSession(session),
        body: request.toJson(),
      );
      return AdminAiReadingFunctionResponse(
        status: response.status,
        data: response.data,
      );
    } catch (error) {
      if (!_shouldRetryWithFreshSession(error)) {
        rethrow;
      }

      final refreshedSession = await _resolveSession(forceRefresh: true);
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'admin_ai_generate_reading_draft',
          method: HttpMethod.post,
          headers: _functionHeadersForSession(refreshedSession),
          body: request.toJson(),
        );
        return AdminAiReadingFunctionResponse(
          status: response.status,
          data: response.data,
        );
      } catch (retryError) {
        if (_shouldRetryWithFreshSession(retryError)) {
          await Supabase.instance.client.auth.signOut();
        }
        rethrow;
      }
    }
  }

  Future<Session?> _resolveSession({bool forceRefresh = false}) async {
    final auth = Supabase.instance.client.auth;
    final currentSession = auth.currentSession;
    final refreshToken = currentSession?.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      return currentSession;
    }

    final shouldRefresh =
        forceRefresh ||
        currentSession == null ||
        currentSession.isExpired ||
        _expiresSoon(currentSession);
    if (!shouldRefresh) {
      return currentSession;
    }

    try {
      final response = await auth.refreshSession();
      return response.session ?? auth.currentSession ?? currentSession;
    } catch (_) {
      return auth.currentSession ?? currentSession;
    }
  }

  bool _expiresSoon(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return false;
    }

    final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(
      expiresAt * 1000,
      isUtc: true,
    );
    return expiresAtDate.isBefore(
      DateTime.now().toUtc().add(const Duration(minutes: 2)),
    );
  }

  Map<String, String>? _functionHeadersForSession(Session? session) {
    final accessToken = session?.accessToken.trim();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  bool _shouldRetryWithFreshSession(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('invalid jwt') ||
        text.contains('jwt expired') ||
        text.contains('401');
  }

  String? _validateDraft(AdminAiGeneratedReadingDraft draft) {
    if (draft.title.trim().isEmpty) {
      return 'AI cevabi gecerli bir baslik icermiyor.';
    }
    if (draft.sentences.isEmpty) {
      return 'AI cevabi en az bir cumle icermeli.';
    }
    for (final sentence in draft.sentences) {
      if (sentence.sentenceEn.trim().isEmpty) {
        return 'AI cevabindaki cumlelerden biri bos geldi.';
      }
    }
    if (draft.questions.isEmpty) {
      return 'AI cevabi en az bir soru icermeli.';
    }
    for (final question in draft.questions) {
      if (question.question.trim().isEmpty) {
        return 'AI cevabindaki sorulardan biri bos geldi.';
      }
      if (question.options.length < 2) {
        return 'AI cevabindaki sorulardan biri yeterli secenek icermiyor.';
      }
      if (question.correctOptionIndex < 0 ||
          question.correctOptionIndex >= question.options.length) {
        return 'AI cevabindaki dogru secenek indeksi gecersiz.';
      }
    }
    return null;
  }

  String _messageFromErrorPayload(Map<String, dynamic> payload) {
    final message = payload['message']?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    final errorCode = payload['error']?.toString().trim().toLowerCase();
    return switch (errorCode) {
      'unauthenticated' ||
      'missing_authorization' => 'AI draft uretimi icin admin oturumu gerekli.',
      'forbidden' || 'role_lookup_failed' =>
        'Bu islemi yalniz admin veya developer yapabilir.',
      'rate_limited' =>
        'Secilen AI saglayicisi kota veya billing hatasi verdi. API planini kontrol edin.',
      'invalid_request' ||
      'invalid_input' => 'AI draft istegi gecersiz. Alanlari kontrol edin.',
      'invalid_ai_response' ||
      'invalid_response' => 'AI servisi beklenen draft semasini donmedi.',
      _ => 'AI draft olusturulamadi.',
    };
  }

  String _messageFromException(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('invalid jwt') ||
        text.contains('jwt expired') ||
        text.contains('refresh token')) {
      return 'Admin oturumu yenilenemedi. Cikis yapip tekrar giris yapin.';
    }
    if (text.contains('auth') || text.contains('forbidden')) {
      return 'AI draft uretimi icin yetkili admin oturumu gerekli.';
    }
    if (text.contains('json') || text.contains('format')) {
      return 'AI servisi gecersiz bir draft cevabi dondu.';
    }
    return 'AI draft olusturulamadi: $error';
  }
}

class AdminAiReadingFunctionResponse {
  const AdminAiReadingFunctionResponse({
    required this.status,
    required this.data,
  });

  final int status;
  final Object? data;
}

Map<String, dynamic> _coerceMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}
