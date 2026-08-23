import "dart:async";
import "dart:convert";
import "dart:developer" as developer;
import "dart:io";

import "package:http/http.dart" as http;
import "package:uuid/uuid.dart";
import "../core/secure_storage_service.dart";

/// API 명세서 §1 공통 규약 반영.
///
/// 오프라인 vs 인증실패 구분 원칙 (TRD §2.6):
/// - SocketException / HandshakeException / TimeoutException → NETWORK_ERROR (retryable: true)
///   클라이언트는 로그인 화면으로 보내지 않고 재시도 UI를 표시한다.
/// - 401 + refresh 실패 → UNAUTHORIZED (retryable: false)
///   이때만 로그인 화면으로 보낸다.
///
/// Idempotency-Key 규약:
/// 논리적 요청 1건당 1개만 발급하고, 401→refresh 재시도에서도 같은 키를
/// 재사용한다.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.retryable = false,
    this.statusCode,
  });

  final String code;
  final String message;
  final bool retryable;
  final int? statusCode;

  /// 네트워크 오류인지 판별 — UI가 "재연결 시 재시도" 안내를 할지 결정
  bool get isNetworkError => code == "NETWORK_ERROR";

  /// 세션이 완전히 만료되어 로그인이 필요한지 판별
  bool get isAuthExpired => code == "UNAUTHORIZED";

  @override
  String toString() => "ApiException($code, status=$statusCode): $message";
}

enum _RefreshStatus { success, rejected, retryableFailure, stale, discarded }

class _SessionSnapshot {
  const _SessionSnapshot({
    required this.generation,
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final int generation;
  final String? accessToken;
  final String? refreshToken;
  final String? userId;

  _SessionSnapshot withAccessToken(String accessToken) => _SessionSnapshot(
    generation: generation,
    accessToken: accessToken,
    refreshToken: refreshToken,
    userId: userId,
  );
}

class _RefreshOutcome {
  const _RefreshOutcome(
    this.status, [
    this.accessToken,
    this.error,
    this.stackTrace,
  ]);

  final _RefreshStatus status;
  final String? accessToken;
  final Object? error;
  final StackTrace? stackTrace;
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required SecureStorageService secureStorage,
    http.Client? httpClient,
    Future<void> Function(int generation)? onAuthExpired,
    Future<void> Function()? beforeRequestDispatch,
  }) : _secureStorage = secureStorage,
       _http = httpClient ?? http.Client(),
       _onAuthExpired = onAuthExpired,
       _beforeRequestDispatch = beforeRequestDispatch;

  final String baseUrl;
  final SecureStorageService _secureStorage;
  final http.Client _http;
  final _uuid = const Uuid();
  Future<void> Function(int generation)? _onAuthExpired;
  final Future<void> Function()? _beforeRequestDispatch;
  int _sessionGeneration = 0;
  int? _committedSessionGeneration = 0;
  Future<void> _sessionMutationTail = Future<void>.value();

  int get sessionGeneration => _sessionGeneration;

  /// 로그인/로그아웃 시작 시 즉시 이전 요청 세대를 무효화한다.
  int beginSessionTransition() => ++_sessionGeneration;

  bool isCurrentSessionGeneration(int generation) =>
      generation == _sessionGeneration;

  /// terminal 응답의 세대가 현재와 같을 때만 새 세대로 전환한다.
  int? invalidateSessionGeneration(int expectedGeneration) {
    if (!isCurrentSessionGeneration(expectedGeneration)) return null;
    return ++_sessionGeneration;
  }

  /// 앱 전역 인증 provider가 생성된 뒤 terminal 세션 만료 처리기를 연결한다.
  /// null을 전달하면 provider dispose 시 연결을 해제한다.
  void setAuthExpiredHandler(Future<void> Function(int generation)? handler) {
    _onAuthExpired = handler;
  }

  Future<void> _notifyAuthExpired(int generation) async {
    if (!isCurrentSessionGeneration(generation)) return;
    final handler = _onAuthExpired;
    if (handler != null) await handler(generation);
  }

  Future<T> _serializeSessionMutation<T>(Future<T> Function() mutation) {
    final completer = Completer<T>();
    _sessionMutationTail = _sessionMutationTail.catchError((_) {}).then((
      _,
    ) async {
      try {
        completer.complete(await mutation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> saveSession({
    required int expectedGeneration,
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) {
    return _serializeSessionMutation(() async {
      if (!isCurrentSessionGeneration(expectedGeneration)) return;
      try {
        await _secureStorage.saveSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
        );
      } catch (error, stackTrace) {
        await _rollbackSessionBestEffort(expectedGeneration);
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (!isCurrentSessionGeneration(expectedGeneration)) {
        await _rollbackSessionBestEffort(expectedGeneration);
        return;
      }
      _committedSessionGeneration = expectedGeneration;
    });
  }

  Future<void> clearSession({required int expectedGeneration}) {
    return _serializeSessionMutation(() async {
      if (!isCurrentSessionGeneration(expectedGeneration)) return;
      _committedSessionGeneration = null;
      await _secureStorage.clearSession();
    });
  }

  Future<void> _rollbackSessionBestEffort(int expectedGeneration) async {
    if (isCurrentSessionGeneration(expectedGeneration)) {
      _committedSessionGeneration = null;
    }
    try {
      await _secureStorage.clearSession();
    } catch (_) {
      // 원 mutation 오류를 보존하되 현재 프로세스에서는 capture를 차단한다.
    }
  }

  Future<_SessionSnapshot> _captureSession({
    int? expectedGeneration,
    bool allowUncommitted = false,
  }) async {
    final generation = expectedGeneration ?? _sessionGeneration;
    if (!isCurrentSessionGeneration(generation) ||
        (!allowUncommitted && _committedSessionGeneration != generation)) {
      throw _staleSessionException();
    }
    final values = await Future.wait<String?>([
      _secureStorage.accessToken,
      _secureStorage.refreshToken,
      _secureStorage.userId,
    ]);
    if (!isCurrentSessionGeneration(generation) ||
        (!allowUncommitted && _committedSessionGeneration != generation)) {
      throw _staleSessionException();
    }
    return _SessionSnapshot(
      generation: generation,
      accessToken: values[0],
      refreshToken: values[1],
      userId: values[2],
    );
  }

  Map<String, String> _readHeaders(String? accessToken) => {
    "Content-Type": "application/json",
    if (accessToken != null) "Authorization": "Bearer $accessToken",
  };

  Map<String, String> _writeHeaders(
    String idempotencyKey,
    String? accessToken,
  ) => {
    "Content-Type": "application/json",
    if (accessToken != null) "Authorization": "Bearer $accessToken",
    "Idempotency-Key": idempotencyKey,
  };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = path.startsWith("/") ? path.substring(1) : path;
    return Uri.parse(
      "$baseUrl/$cleaned",
    ).replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));
  }

  ApiException _staleSessionException() => ApiException(
    code: "STALE_SESSION",
    message: "이전 로그인 세션의 요청이 취소됐어요.",
    retryable: false,
  );

  /// 핵심 요청 처리기. 네트워크 오류와 인증 만료를 구분한다.
  Future<T> _handle<T>(
    Future<http.Response> Function(String? accessToken) request, {
    required _SessionSnapshot? session,
    required bool allowRefresh,
    bool hasRetried = false,
  }) async {
    if (session != null && !isCurrentSessionGeneration(session.generation)) {
      throw _staleSessionException();
    }
    final beforeRequestDispatch = _beforeRequestDispatch;
    if (session != null && beforeRequestDispatch != null) {
      await beforeRequestDispatch();
      if (!isCurrentSessionGeneration(session.generation)) {
        throw _staleSessionException();
      }
    }

    final http.Response response;
    try {
      response = await request(
        session?.accessToken,
      ).timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException(
        code: "NETWORK_ERROR",
        message: "네트워크에 연결할 수 없어요. 인터넷 연결을 확인해주세요.",
        retryable: true,
      );
    } on HandshakeException {
      throw ApiException(
        code: "NETWORK_ERROR",
        message: "보안 연결에 실패했어요. 잠시 후 다시 시도해주세요.",
        retryable: true,
      );
    } on HttpException {
      throw ApiException(
        code: "NETWORK_ERROR",
        message: "서버와 통신에 실패했어요.",
        retryable: true,
      );
    } on TimeoutException {
      throw ApiException(
        code: "NETWORK_ERROR",
        message: "서버 응답 시간이 초과됐어요.",
        retryable: true,
      );
    } on http.ClientException {
      throw ApiException(
        code: "NETWORK_ERROR",
        message: "서버와 통신에 실패했어요.",
        retryable: true,
      );
    }

    if (session != null && !isCurrentSessionGeneration(session.generation)) {
      throw _staleSessionException();
    }

    // ─── 보호 API 401 → 동일 요청 세대의 refresh 시도 ───────────
    if (response.statusCode == 401 && allowRefresh) {
      final protectedSession = session!;
      if (!hasRetried) {
        final refreshOutcome = await _tryRefresh(protectedSession);
        switch (refreshOutcome.status) {
          case _RefreshStatus.success:
            final refreshedSession = protectedSession.withAccessToken(
              refreshOutcome.accessToken!,
            );
            return _handle<T>(
              request,
              session: refreshedSession,
              allowRefresh: true,
              hasRetried: true,
            );
          case _RefreshStatus.retryableFailure:
            throw ApiException(
              code: "NETWORK_ERROR",
              message: "세션을 갱신하지 못했어요. 네트워크를 확인해주세요.",
              retryable: true,
            );
          case _RefreshStatus.discarded:
            // refresh write가 세션을 파기했다. 원 오류는 진단을 위해 남기고,
            // 현재 세대면 terminal로 인증 상태까지 만료시켜 storage와 provider를
            // 일치시킨다.
            developer.log(
              "refresh token write rollback: session discarded",
              name: "ApiClient",
              error: refreshOutcome.error,
              stackTrace: refreshOutcome.stackTrace,
            );
            if (isCurrentSessionGeneration(protectedSession.generation)) {
              await _notifyAuthExpired(protectedSession.generation);
            }
            throw ApiException(
              code: "UNAUTHORIZED",
              message: "세션이 만료됐어요. 다시 로그인해주세요.",
              retryable: false,
              statusCode: 401,
            );
          case _RefreshStatus.stale:
            throw _staleSessionException();
          case _RefreshStatus.rejected:
            break;
        }
      }

      // refresh 거부 또는 refresh 후 재401인 현재 세대만 terminal 처리한다.
      if (!isCurrentSessionGeneration(protectedSession.generation)) {
        throw _staleSessionException();
      }
      await _notifyAuthExpired(protectedSession.generation);
      throw ApiException(
        code: "UNAUTHORIZED",
        message: "세션이 만료됐어요. 다시 로그인해주세요.",
        retryable: false,
        statusCode: 401,
      );
    }

    // ─── 응답 파싱 ──────────────────────────────────────────────
    // 프록시/게이트웨이가 HTML 오류 페이지를 반환해도 FormatException을
    // 그대로 흘리지 않고 진단 가능한 API 오류로 정규화한다. 응답 본문은
    // 토큰이나 내부 정보가 섞일 수 있어 로그에 남기지 않는다.
    dynamic decoded = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (error, stackTrace) {
        developer.log(
          "non-JSON response: status=${response.statusCode}, "
          "contentType=${response.headers["content-type"]}",
          name: "ApiClient",
          error: error,
          stackTrace: stackTrace,
        );
        throw ApiException(
          code: "INVALID_SERVER_RESPONSE",
          message: "서버 응답을 확인하지 못했어요. 잠시 후 다시 시도해주세요.",
          retryable: response.statusCode >= 500,
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Case 1: {"data": ...} wrapper가 있으면 unwrap
      if (decoded is Map<String, dynamic> && decoded.containsKey("data")) {
        return decoded["data"] as T;
      }
      // Case 2: wrapper 없이 object/array 직접 반환
      return decoded as T;
    }

    // ─── 에러 응답 ──────────────────────────────────────────────
    // BE 에러 형식 2종 대응:
    //   중첩: {"error": {"code": "...", "message": "...", "retryable": bool}}
    //   평면: {"error": "INVALID_REQUEST", "message": "..."}
    final Map<String, dynamic> errorBody = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    final rawError = errorBody["error"];
    final Map<String, dynamic> error = rawError is Map<String, dynamic>
        ? rawError
        : errorBody;
    throw ApiException(
      code:
          error["code"] as String? ??
          (rawError is String ? rawError : "UNKNOWN_ERROR"),
      message: error["message"] as String? ?? "요청을 처리하지 못했어요.",
      retryable: error["retryable"] as bool? ?? false,
      statusCode: response.statusCode,
    );
  }

  /// 요청 시작 시 캡처한 refresh token만 사용한다. 응답 도착 전 세대가
  /// 바뀌면 storage를 갱신하지 않고 stale로 종료한다.
  Future<_RefreshOutcome> _tryRefresh(_SessionSnapshot session) async {
    if (!isCurrentSessionGeneration(session.generation)) {
      return const _RefreshOutcome(_RefreshStatus.stale);
    }
    final refreshToken = session.refreshToken;
    if (refreshToken == null) {
      return const _RefreshOutcome(_RefreshStatus.rejected);
    }

    final refreshIdempotencyKey = _uuid.v4();
    try {
      final response = await _http
          .post(
            _uri("/auth/refresh"),
            headers: {
              "Content-Type": "application/json",
              "Idempotency-Key": refreshIdempotencyKey,
            },
            body: jsonEncode({"refreshToken": refreshToken}),
          )
          .timeout(const Duration(seconds: 20));
      if (!isCurrentSessionGeneration(session.generation)) {
        return const _RefreshOutcome(_RefreshStatus.stale);
      }
      if ({400, 401, 403}.contains(response.statusCode)) {
        return const _RefreshOutcome(_RefreshStatus.rejected);
      }
      if (response.statusCode != 200) {
        return const _RefreshOutcome(_RefreshStatus.retryableFailure);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body["data"] ?? body) as Map<String, dynamic>;
      final accessToken = data["accessToken"] as String;
      return await _serializeSessionMutation(() async {
        if (!isCurrentSessionGeneration(session.generation)) {
          return const _RefreshOutcome(_RefreshStatus.stale);
        }
        try {
          await _secureStorage.updateAccessToken(accessToken);
        } catch (error, stackTrace) {
          // access token write가 side effect를 남긴 뒤 실패하면 세션 전체를
          // rollback한다. 세션을 파기했으므로 재시도가 아니라 terminal로
          // 인증 상태까지 동기화해야 provider/storage split-brain을 막는다.
          await _rollbackSessionBestEffort(session.generation);
          if (!isCurrentSessionGeneration(session.generation)) {
            return const _RefreshOutcome(_RefreshStatus.stale);
          }
          return _RefreshOutcome(
            _RefreshStatus.discarded,
            null,
            error,
            stackTrace,
          );
        }
        if (!isCurrentSessionGeneration(session.generation)) {
          await _rollbackSessionBestEffort(session.generation);
          return const _RefreshOutcome(_RefreshStatus.stale);
        }
        return _RefreshOutcome(_RefreshStatus.success, accessToken);
      });
    } catch (_) {
      return const _RefreshOutcome(_RefreshStatus.retryableFailure);
    }
  }

  // ─── Public HTTP methods ──────────────────────────────────────

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = true,
    bool includeRefreshToken = false,
  }) async {
    final session = requiresAuth ? await _captureSession() : null;
    final refreshToken = includeRefreshToken
        ? await _secureStorage.refreshToken
        : null;
    return _handle<T>(
      (accessToken) => _http.get(
        _uri(path, query),
        headers: {
          ..._readHeaders(accessToken),
          if (refreshToken != null) "X-Refresh-Token": refreshToken,
        },
      ),
      session: session,
      allowRefresh: requiresAuth,
    );
  }

  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    int? expectedGeneration,
    bool allowUncommittedSession = false,
  }) async {
    final idempotencyKey = _uuid.v4();
    final session = requiresAuth
        ? await _captureSession(
            expectedGeneration: expectedGeneration,
            allowUncommitted: allowUncommittedSession,
          )
        : null;
    return _handle<T>(
      (accessToken) => _http.post(
        _uri(path),
        headers: _writeHeaders(idempotencyKey, accessToken),
        body: jsonEncode(body ?? {}),
      ),
      session: session,
      allowRefresh: requiresAuth,
    );
  }

  Future<T> postPublic<T>(String path, {Map<String, dynamic>? body}) =>
      post<T>(path, body: body, requiresAuth: false);

  Future<T> getPublic<T>(String path, {Map<String, dynamic>? query}) =>
      get<T>(path, query: query, requiresAuth: false);

  Future<T> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    bool includeRefreshToken = false,
  }) async {
    final idempotencyKey = _uuid.v4();
    final session = requiresAuth ? await _captureSession() : null;
    final refreshToken = includeRefreshToken
        ? await _secureStorage.refreshToken
        : null;
    return _handle<T>(
      (accessToken) => _http.patch(
        _uri(path),
        headers: {
          ..._writeHeaders(idempotencyKey, accessToken),
          if (refreshToken != null) "X-Refresh-Token": refreshToken,
        },
        body: jsonEncode(body ?? {}),
      ),
      session: session,
      allowRefresh: requiresAuth,
    );
  }

  Future<T> delete<T>(
    String path, {
    bool requiresAuth = true,
    bool includeRefreshToken = false,
  }) async {
    final idempotencyKey = _uuid.v4();
    final session = requiresAuth ? await _captureSession() : null;
    final refreshToken = includeRefreshToken
        ? await _secureStorage.refreshToken
        : null;
    return _handle<T>(
      (accessToken) => _http.delete(
        _uri(path),
        headers: {
          ..._writeHeaders(idempotencyKey, accessToken),
          if (refreshToken != null) "X-Refresh-Token": refreshToken,
        },
      ),
      session: session,
      allowRefresh: requiresAuth,
    );
  }
}
