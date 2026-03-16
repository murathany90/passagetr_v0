import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';

typedef AdminAiReadingFunctionInvoker =
    Future<AdminAiReadingFunctionResponse> Function(
      AdminAiGenerateReadingRequest request,
    );

typedef AdminAiReadingNamedFunctionInvoker =
    Future<AdminAiReadingFunctionResponse> Function(
      String functionName,
      Object? body,
    );

typedef AdminAiReadingRpcInvoker =
    Future<dynamic> Function(
      String functionName, {
      Map<String, dynamic> params,
    });

class FoundationAdminAiReadingRepository implements AdminAiReadingRepository {
  const FoundationAdminAiReadingRepository({
    required AppConfig config,
    required AuthRepository authRepository,
    AdminAiReadingFunctionInvoker? functionInvoker,
    AdminAiReadingNamedFunctionInvoker? namedFunctionInvoker,
    AdminAiReadingRpcInvoker? rpcInvoker,
  }) : _config = config,
       _authRepository = authRepository,
       _functionInvoker = functionInvoker,
       _namedFunctionInvoker = namedFunctionInvoker,
       _rpcInvoker = rpcInvoker;

  final AppConfig _config;
  final AuthRepository _authRepository;
  final AdminAiReadingFunctionInvoker? _functionInvoker;
  final AdminAiReadingNamedFunctionInvoker? _namedFunctionInvoker;
  final AdminAiReadingRpcInvoker? _rpcInvoker;

  void _handleError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '401' || error.code == '403') {
        _authRepository.notifySessionExpired();
      }
    } else if (error is AuthException) {
      if (error.statusCode == '401' || error.statusCode == '403') {
        _authRepository.notifySessionExpired();
      }
    } else if (error is FunctionException) {
      if (error.status == 401 || error.status == 403) {
        _authRepository.notifySessionExpired();
      }
    }
  }

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
      _handleError(error);
      return AppFailure<AdminAiGeneratedReadingDraft>(
        _messageFromException(error),
      );
    }
  }

  @override
  Future<AppResult<AdminAiGeneratedReadingQuestions>> generateReadingQuestions(
    AdminAiGenerateReadingQuestionsRequest request,
  ) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminAiGeneratedReadingQuestions>(
        'Preview modunda AI soru uretimi desteklenmiyor.',
      );
    }

    try {
      final response = await _invokeNamedFunction(
        'admin_ai_generate_reading_questions',
        request.toJson(),
      );
      final payload = _coerceMap(response.data);
      if (response.status >= 400) {
        return AppFailure<AdminAiGeneratedReadingQuestions>(
          _messageFromErrorPayload(payload),
        );
      }

      final result = AdminAiGeneratedReadingQuestions.fromJson(payload);
      if (result.questions.isEmpty) {
        return const AppFailure<AdminAiGeneratedReadingQuestions>(
          'AI servisi soru uretmedi.',
        );
      }
      return AppSuccess<AdminAiGeneratedReadingQuestions>(result);
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminAiGeneratedReadingQuestions>(
        _messageFromException(error),
      );
    }
  }

  @override
  Future<AppResult<AdminReadingDetail>> generateReadingCover(
    AdminAiGenerateReadingCoverRequest request,
  ) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminReadingDetail>(
        'Preview modunda AI cover uretimi desteklenmiyor.',
      );
    }

    try {
      final response = await _invokeNamedFunction(
        'admin_ai_generate_reading_cover',
        request.toJson(),
      );
      final payload = _coerceMap(response.data);
      if (response.status >= 400) {
        return AppFailure<AdminReadingDetail>(_messageFromErrorPayload(payload));
      }
      return AppSuccess<AdminReadingDetail>(AdminReadingDetail.fromJson(payload));
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminReadingDetail>(_messageFromException(error));
    }
  }

  @override
  Future<AppResult<AdminAiCoverPoolStatus>> fetchAiCoverPoolStatus() async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminAiCoverPoolStatus>(_previewCoverPoolStatus());
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_get_ai_cover_pool_status',
        params: const <String, dynamic>{},
      );
      return AppSuccess<AdminAiCoverPoolStatus>(
        AdminAiCoverPoolStatus.fromJson(payload),
      );
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminAiCoverPoolStatus>(
        'AI cover havuz durumu okunamadi: $error',
      );
    }
  }

  @override
  Future<AppResult<AdminAiReadingRun>> createReadingAiRun(
    AdminAiReadingRunRequest request,
  ) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminAiReadingRun>(
        'Preview modunda toplu AI run desteklenmiyor.',
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_create_reading_ai_run',
        params: <String, dynamic>{'p_payload': request.toJson()},
      );
      return AppSuccess<AdminAiReadingRun>(AdminAiReadingRun.fromJson(payload));
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminAiReadingRun>(
        'AI batch run baslatilamadi: $error',
      );
    }
  }

  @override
  Future<AppResult<AdminAiReadingRun>> getReadingAiRun(String runId) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminAiReadingRun>(
        'Preview modunda toplu AI run desteklenmiyor.',
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_get_reading_ai_run',
        params: <String, dynamic>{'p_run_id': runId},
      );
      return AppSuccess<AdminAiReadingRun>(AdminAiReadingRun.fromJson(payload));
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminAiReadingRun>('AI batch run okunamadi: $error');
    }
  }

  @override
  Future<AppResult<List<AdminAiReadingRun>>> listActiveReadingAiRuns() async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<List<AdminAiReadingRun>>(
        'Preview modunda toplu AI run desteklenmiyor.',
      );
    }

    try {
      final payload = await _invokeJsonRpcRaw('admin_list_active_reading_ai_runs');
      final rows = switch (payload) {
        List<dynamic>() => payload,
        _ => const <dynamic>[],
      };
      final runs = rows
          .map((item) => AdminAiReadingRun.fromJson(_coerceMap(item)))
          .toList(growable: false);
      return AppSuccess<List<AdminAiReadingRun>>(runs);
    } catch (error) {
      _handleError(error);
      return AppFailure<List<AdminAiReadingRun>>(
        'Aktif AI batch run listesi okunamadi: $error',
      );
    }
  }

  @override
  Future<AppResult<AdminAiReadingRun>> processReadingAiRun({
    required String runId,
    int batchSize = 3,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminAiReadingRun>(
        'Preview modunda toplu AI run desteklenmiyor.',
      );
    }

    try {
      final response = await _invokeNamedFunction(
        'admin_ai_process_reading_run',
        <String, dynamic>{'run_id': runId, 'batch_size': batchSize},
      );
      final payload = _coerceMap(response.data);
      if (response.status >= 400) {
        return AppFailure<AdminAiReadingRun>(_messageFromErrorPayload(payload));
      }
      return AppSuccess<AdminAiReadingRun>(AdminAiReadingRun.fromJson(payload));
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminAiReadingRun>('AI batch run islenemedi: $error');
    }
  }

  @override
  Future<AppResult<AdminAiReadingRun>> controlReadingAiRun({
    required String runId,
    required String action,
    String? provider,
    String? model,
    int? questionCount,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminAiReadingRun>(
        'Preview modunda toplu AI run desteklenmiyor.',
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_control_reading_ai_run',
        params: <String, dynamic>{
          'p_payload': <String, dynamic>{
            'run_id': runId,
            'action': action,
            'provider': provider,
            'model': model,
            'question_count': questionCount,
          },
        },
      );
      return AppSuccess<AdminAiReadingRun>(AdminAiReadingRun.fromJson(payload));
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminAiReadingRun>('AI batch run kontrol edilemedi: $error');
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
      _handleError(error);
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

  Future<AdminAiReadingFunctionResponse> _invokeNamedFunction(
    String functionName,
    Object? body,
  ) async {
    if (_namedFunctionInvoker != null) {
      return _namedFunctionInvoker(functionName, body);
    }

    await SupabaseBootstrap.initialize(_config);
    final session = await _resolveSession();
    try {
      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        method: HttpMethod.post,
        headers: _functionHeadersForSession(session),
        body: body,
      );
      return AdminAiReadingFunctionResponse(
        status: response.status,
        data: response.data,
      );
    } catch (error) {
      _handleError(error);
      if (!_shouldRetryWithFreshSession(error)) {
        rethrow;
      }

      final refreshedSession = await _resolveSession(forceRefresh: true);
      final response = await Supabase.instance.client.functions.invoke(
        functionName,
        method: HttpMethod.post,
        headers: _functionHeadersForSession(refreshedSession),
        body: body,
      );
      return AdminAiReadingFunctionResponse(
        status: response.status,
        data: response.data,
      );
    }
  }

  Future<Map<String, dynamic>> _invokeJsonRpc(
    String functionName, {
    required Map<String, dynamic> params,
  }) async {
    final response = await _invokeJsonRpcRaw(functionName, params: params);
    return _coerceMap(response);
  }

  Future<dynamic> _invokeJsonRpcRaw(
    String functionName, {
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    if (_rpcInvoker != null) {
      return _rpcInvoker(functionName, params: params);
    }

    await SupabaseBootstrap.initialize(_config);
    return Supabase.instance.client.rpc<dynamic>(
      functionName,
      params: params,
    );
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

AdminAiCoverPoolStatus _previewCoverPoolStatus() {
  final models = adminDefaultAiCoverModelConfigs()
      .map(
        (item) => AdminAiCoverModelUsageStatus(
          provider: item.provider,
          model: item.modelId,
          enabled: item.enabled,
          priority: item.priority,
          dailyCap: item.dailyCap,
          lifetimeCap: item.lifetimeCap,
        ),
      )
      .toList(growable: false);
  return AdminAiCoverPoolStatus(
    usageDateUtc: DateTime.now().toUtc(),
    localCapsEnabled: true,
    models: models,
  );
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
