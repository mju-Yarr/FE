import "dart:async";
import "dart:convert";
import "dart:io";

import "package:ensom/core/async_session_lifecycle.dart";

import "package:ensom/core/auth_service.dart";
import "package:ensom/core/secure_storage_service.dart";
import "package:ensom/network/api_client.dart";
import "package:ensom/providers/auth_providers.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

void main() {
  group("terminal auth expiry propagation", () {
    test(
      "refresh rejection clears session and draft, then unauthenticates",
      () async {
        final harness = await _createHarness(
          MockClient((request) async {
            if (request.url.path.endsWith("/auth/refresh")) {
              return http.Response("{}", 401);
            }
            return http.Response("{}", 401);
          }),
        );
        addTearDown(harness.dispose);

        await expectLater(
          harness.apiClient.get<Map<String, dynamic>>("/protected"),
          throwsA(
            isA<ApiException>()
                .having((error) => error.isAuthExpired, "isAuthExpired", isTrue)
                .having((error) => error.retryable, "retryable", isFalse),
          ),
        );

        expect(harness.notifier.state.status, AuthStatus.unauthenticated);
        expect(harness.storage.clearSessionCount, 1);
        expect(harness.draftClearCount, 1);
      },
    );

    test("401 after successful refresh is also terminal", () async {
      final harness = await _createHarness(
        MockClient((request) async {
          if (request.url.path.endsWith("/auth/refresh")) {
            return http.Response(
              '{"data":{"accessToken":"renewed-access-token"}}',
              200,
            );
          }
          return http.Response("{}", 401);
        }),
      );
      addTearDown(harness.dispose);

      await expectLater(
        harness.apiClient.get<Map<String, dynamic>>("/protected"),
        throwsA(
          isA<ApiException>().having(
            (error) => error.isAuthExpired,
            "isAuthExpired",
            isTrue,
          ),
        ),
      );

      expect(harness.notifier.state.status, AuthStatus.unauthenticated);
      expect(harness.storage.clearSessionCount, 1);
      expect(harness.draftClearCount, 1);
    });

    test("refresh network failure keeps auth state and draft", () async {
      final harness = await _createHarness(
        MockClient((request) async {
          if (request.url.path.endsWith("/auth/refresh")) {
            throw const SocketException("offline");
          }
          return http.Response("{}", 401);
        }),
      );
      addTearDown(harness.dispose);

      await expectLater(
        harness.apiClient.get<Map<String, dynamic>>("/protected"),
        throwsA(
          isA<ApiException>()
              .having((error) => error.isNetworkError, "isNetworkError", isTrue)
              .having((error) => error.retryable, "retryable", isTrue),
        ),
      );

      expect(harness.notifier.state.status, AuthStatus.consentRequired);
      expect(harness.storage.clearSessionCount, 0);
      expect(harness.draftClearCount, 0);
    });

    test(
      "refresh write rollback also expires the authenticated state",
      () async {
        final harness = await _createHarness(
          MockClient((request) async {
            if (request.url.path.endsWith("/auth/refresh")) {
              return http.Response(
                '{"data":{"accessToken":"renewed-access-token"}}',
                200,
              );
            }
            return http.Response("{}", 401);
          }),
        );
        addTearDown(harness.dispose);

        // refresh 성공 후 access token write가 side effect를 남기고 실패한다.
        harness.storage.accessUpdateErrorAfterWrite = StateError(
          "keychain write failed",
        );

        await expectLater(
          harness.apiClient.get<Map<String, dynamic>>("/protected"),
          throwsA(
            isA<ApiException>()
                .having((error) => error.isAuthExpired, "isAuthExpired", isTrue)
                .having((error) => error.retryable, "retryable", isFalse),
          ),
        );

        // 세션을 rollback했으면 provider 상태도 동기화돼야 한다.
        expect(harness.notifier.state.status, AuthStatus.unauthenticated);
        expect(harness.storage.accessTokenValue, isNull);
        expect(harness.storage.refreshTokenValue, isNull);
        expect(harness.storage.userIdValue, isNull);
        expect(harness.draftClearCount, 1);
      },
    );

    test("cleanup failures do not mask terminal transition", () async {
      var deviceTokenDeleteCount = 0;
      final harness = await _createHarness(
        MockClient((request) async => http.Response("{}", 401)),
        failSessionCleanup: true,
        failDraftCleanup: true,
        fcmDisposer: () async => deviceTokenDeleteCount++,
      );
      addTearDown(harness.dispose);

      await expectLater(
        harness.apiClient.get<Map<String, dynamic>>("/protected"),
        throwsA(
          isA<ApiException>().having(
            (error) => error.isAuthExpired,
            "isAuthExpired",
            isTrue,
          ),
        ),
      );

      expect(harness.notifier.state.status, AuthStatus.unauthenticated);
      expect(harness.storage.clearSessionCount, 1);
      expect(harness.draftClearCount, 1);
      expect(harness.fcmDisposeCount, 1);
      expect(deviceTokenDeleteCount, 1);
    });

    test("concurrent terminal responses run cleanup only once", () async {
      final harness = await _createHarness(
        MockClient((request) async => http.Response("{}", 401)),
      );
      addTearDown(harness.dispose);

      final results = await Future.wait(
        [
          harness.apiClient.get<Map<String, dynamic>>("/protected/a"),
          harness.apiClient.get<Map<String, dynamic>>("/protected/b"),
        ].map((request) async {
          try {
            await request;
            return "success";
          } on ApiException catch (error) {
            return error.code;
          }
        }),
      );

      expect(results, everyElement(anyOf("UNAUTHORIZED", "STALE_SESSION")));
      expect(harness.storage.clearSessionCount, 1);
      expect(harness.draftClearCount, 1);
      expect(harness.fcmDisposeCount, 1);
      expect(harness.notifier.state.status, AuthStatus.unauthenticated);
    });

    test(
      "terminal transition does not wait for a stuck FCM installer",
      () async {
        final lifecycle = AsyncSessionLifecycle(
          cancellationTimeout: const Duration(milliseconds: 20),
        );
        final installStarted = Completer<void>();
        final neverInstalled = Completer<List<StreamSubscription<dynamic>>>();
        final initializing = lifecycle.initialize((generation, isCurrent) {
          installStarted.complete();
          return neverInstalled.future;
        });
        unawaited(initializing);
        await installStarted.future;

        final harness = await _createHarness(
          MockClient((request) async => http.Response("{}", 401)),
          fcmDisposer: lifecycle.dispose,
        );
        addTearDown(harness.dispose);

        await harness.notifier
            .onTerminalAuthExpired(harness.apiClient.sessionGeneration)
            .timeout(const Duration(milliseconds: 200));

        expect(harness.fcmDisposeCount, 1);
        expect(harness.notifier.state.status, AuthStatus.unauthenticated);
      },
    );
  });

  group("session generation boundaries", () {
    test("public login 401 preserves the server auth error", () async {
      var refreshCalls = 0;
      var expiryCalls = 0;
      final storage = _MemorySecureStorage();
      final client = ApiClient(
        baseUrl: "https://api.ensom.test/v1",
        secureStorage: storage,
        onAuthExpired: (_) async => expiryCalls++,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith("/auth/refresh")) refreshCalls++;
          expect(request.headers.containsKey("Authorization"), isFalse);
          return http.Response(
            '{"error":{"code":"AUTH_INVALID_CREDENTIALS","message":"invalid","retryable":false}}',
            401,
          );
        }),
      );

      await expectLater(
        client.postPublic<Map<String, dynamic>>(
          "/auth/email/login",
          body: {"email": "user@example.com", "password": "wrong"},
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, "code", "AUTH_INVALID_CREDENTIALS")
              .having((error) => error.statusCode, "statusCode", 401),
        ),
      );
      expect(refreshCalls, 0);
      expect(expiryCalls, 0);
    });

    test(
      "a delayed request from user A cannot refresh or clear user B",
      () async {
        final storage = _MemorySecureStorage()
          ..accessTokenValue = "access-a"
          ..refreshTokenValue = "refresh-a"
          ..userIdValue = "user-a";
        final responseGate = Completer<http.Response>();
        final requestStarted = Completer<void>();
        var refreshCalls = 0;
        var expiryCalls = 0;
        final client = ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: storage,
          onAuthExpired: (_) async => expiryCalls++,
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith("/auth/refresh")) {
              refreshCalls++;
              return http.Response("{}", 401);
            }
            requestStarted.complete();
            return responseGate.future;
          }),
        );

        final staleRequest = client.post<Map<String, dynamic>>(
          "/protected",
          body: {"owner": "user-a"},
        );
        await requestStarted.future;

        final loginGeneration = client.beginSessionTransition();
        await client.saveSession(
          expectedGeneration: loginGeneration,
          accessToken: "access-b",
          refreshToken: "refresh-b",
          userId: "user-b",
        );
        responseGate.complete(http.Response("{}", 401));

        await expectLater(
          staleRequest,
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              "code",
              "STALE_SESSION",
            ),
          ),
        );
        expect(refreshCalls, 0);
        expect(expiryCalls, 0);
        expect(storage.accessTokenValue, "access-b");
        expect(storage.refreshTokenValue, "refresh-b");
        expect(storage.userIdValue, "user-b");
      },
    );

    test(
      "later-started login wins when responses arrive out of order",
      () async {
        final storage = _MemorySecureStorage();
        final loginAStarted = Completer<void>();
        final loginBStarted = Completer<void>();
        final loginAResponse = Completer<http.Response>();
        final loginBResponse = Completer<http.Response>();
        final apiClient = ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: storage,
          httpClient: MockClient((request) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final email = body["email"] as String;
            if (email == "a@example.com") {
              loginAStarted.complete();
              return loginAResponse.future;
            }
            loginBStarted.complete();
            return loginBResponse.future;
          }),
        );
        final initialDraftClear = Completer<void>();
        final notifier = AuthNotifier(
          authService: AuthService(apiClient: apiClient),
          secureStorage: storage,
          apiClient: apiClient,
          clearMapDraft: () async {
            if (!initialDraftClear.isCompleted) initialDraftClear.complete();
          },
          initializeFcm: (_, _) async {},
          disposeFcm: () async {},
        );
        addTearDown(notifier.dispose);
        await initialDraftClear.future;

        final loginA = notifier.loginWithEmail(
          email: "a@example.com",
          password: "password-a",
        );
        await loginAStarted.future;
        final loginB = notifier.loginWithEmail(
          email: "b@example.com",
          password: "password-b",
        );
        await loginBStarted.future;

        loginBResponse.complete(_loginResponse("b"));
        await loginB;
        loginAResponse.complete(_loginResponse("a"));
        await loginA;

        expect(storage.accessTokenValue, "access-b");
        expect(storage.refreshTokenValue, "refresh-b");
        expect(storage.userIdValue, "user-b");
        expect(notifier.state.status, AuthStatus.authenticated);
        expect(notifier.state.userId, "user-b");
      },
    );

    test(
      "a session write that becomes stale is rolled back before commit",
      () async {
        final storage = _MemorySecureStorage()
          ..sessionSaveStarted = Completer<void>()
          ..sessionSaveGate = Completer<void>();
        final apiClient = ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: storage,
          httpClient: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body["email"] == "a@example.com") {
              return _loginResponse("a");
            }
            return http.Response(
              '{"error":{"code":"AUTH_INVALID_CREDENTIALS","message":"invalid","retryable":false}}',
              401,
            );
          }),
        );
        final notifier = AuthNotifier(
          authService: AuthService(apiClient: apiClient),
          secureStorage: storage,
          apiClient: apiClient,
          clearMapDraft: () async {},
          initializeFcm: (_, _) async {},
          disposeFcm: () async {},
        );
        addTearDown(notifier.dispose);
        await notifier.sessionCheckCompletion;

        final loginA = notifier.loginWithEmail(
          email: "a@example.com",
          password: "password-a",
        );
        await storage.sessionSaveStarted!.future;

        final loginB = notifier.loginWithEmail(
          email: "b@example.com",
          password: "password-b",
        );
        await Future<void>.delayed(Duration.zero);
        storage.sessionSaveGate!.complete();
        await expectLater(
          loginB,
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              "code",
              "AUTH_INVALID_CREDENTIALS",
            ),
          ),
        );

        await loginA;

        expect(storage.accessTokenValue, isNull);
        expect(storage.refreshTokenValue, isNull);
        expect(storage.userIdValue, isNull);
        expect(storage.clearSessionCount, 2);
        expect(notifier.state.status, AuthStatus.unauthenticated);
      },
    );

    test(
      "a transition cannot capture the previously committed token",
      () async {
        final storage = _MemorySecureStorage()
          ..accessTokenValue = "access-a"
          ..refreshTokenValue = "refresh-a"
          ..userIdValue = "user-a";
        var protectedHttpCalls = 0;
        var refreshCalls = 0;
        final client = ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: storage,
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith("/auth/refresh")) refreshCalls++;
            protectedHttpCalls++;
            return http.Response("{}", 401);
          }),
        );

        final loginGeneration = client.beginSessionTransition();
        await expectLater(
          client.get<Map<String, dynamic>>("/protected"),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              "code",
              "STALE_SESSION",
            ),
          ),
        );
        await client.saveSession(
          expectedGeneration: loginGeneration,
          accessToken: "access-b",
          refreshToken: "refresh-b",
          userId: "user-b",
        );

        expect(protectedHttpCalls, 0);
        expect(refreshCalls, 0);
        expect(storage.accessTokenValue, "access-b");
        expect(storage.refreshTokenValue, "refresh-b");
        expect(storage.userIdValue, "user-b");
      },
    );

    test(
      "a partial session save is rolled back and preserves its error",
      () async {
        final originalError = StateError("refresh key write failed");
        final storage = _MemorySecureStorage()
          ..accessTokenValue = "access-a"
          ..refreshTokenValue = "refresh-a"
          ..userIdValue = "user-a"
          ..saveSessionErrorAfterAccessToken = originalError;
        final client = ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: storage,
          httpClient: MockClient((_) async => http.Response("{}", 200)),
        );
        final generation = client.beginSessionTransition();

        await expectLater(
          client.saveSession(
            expectedGeneration: generation,
            accessToken: "access-b",
            refreshToken: "refresh-b",
            userId: "user-b",
          ),
          throwsA(same(originalError)),
        );

        expect(storage.clearSessionCount, 1);
        expect(storage.accessTokenValue, isNull);
        expect(storage.refreshTokenValue, isNull);
        expect(storage.userIdValue, isNull);
        await expectLater(
          client.get<Map<String, dynamic>>("/protected"),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              "code",
              "STALE_SESSION",
            ),
          ),
        );
      },
    );

    test(
      "a stale refresh rollback completes before the next session save",
      () async {
        final storage = _MemorySecureStorage()
          ..accessTokenValue = "access-a"
          ..refreshTokenValue = "refresh-a"
          ..userIdValue = "user-a"
          ..accessUpdateStarted = Completer<void>()
          ..accessUpdateGate = Completer<void>();
        final client = ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: storage,
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith("/auth/refresh")) {
              return http.Response(
                '{"data":{"accessToken":"refreshed-a"}}',
                200,
              );
            }
            return http.Response("{}", 401);
          }),
        );

        final staleRequest = client.get<Map<String, dynamic>>("/protected");
        await storage.accessUpdateStarted!.future;
        final loginGeneration = client.beginSessionTransition();
        final saveB = client.saveSession(
          expectedGeneration: loginGeneration,
          accessToken: "access-b",
          refreshToken: "refresh-b",
          userId: "user-b",
        );
        storage.accessUpdateGate!.complete();

        await expectLater(
          staleRequest,
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              "code",
              "STALE_SESSION",
            ),
          ),
        );
        await saveB;

        expect(storage.clearSessionCount, 1);
        expect(storage.accessTokenValue, "access-b");
        expect(storage.refreshTokenValue, "refresh-b");
        expect(storage.userIdValue, "user-b");
      },
    );

    test("a partial refresh-token update expires the whole session", () async {
      final storage = _MemorySecureStorage()
        ..accessTokenValue = "access-a"
        ..refreshTokenValue = "refresh-a"
        ..userIdValue = "user-a"
        ..accessUpdateErrorAfterWrite = StateError("access write failed");
      var expiryCalls = 0;
      final client = ApiClient(
        baseUrl: "https://api.ensom.test/v1",
        secureStorage: storage,
        onAuthExpired: (_) async => expiryCalls++,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith("/auth/refresh")) {
            return http.Response('{"data":{"accessToken":"refreshed-a"}}', 200);
          }
          return http.Response("{}", 401);
        }),
      );

      await expectLater(
        client.get<Map<String, dynamic>>("/protected"),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, "code", "UNAUTHORIZED")
              .having((error) => error.retryable, "retryable", isFalse),
        ),
      );
      // 세션을 파기했으면 terminal handler로 상태를 동기화한다.
      expect(expiryCalls, 1);
      expect(storage.clearSessionCount, 1);
      expect(storage.accessTokenValue, isNull);
      expect(storage.refreshTokenValue, isNull);
      expect(storage.userIdValue, isNull);
    });

    test(
      "a stale logout is stopped immediately before HTTP dispatch",
      () async {
        final storage = _MemorySecureStorage()
          ..accessTokenValue = "access-a"
          ..refreshTokenValue = "refresh-a"
          ..userIdValue = "user-a";
        final dispatchReached = Completer<void>();
        final dispatchGate = Completer<void>();
        var logoutHttpCalls = 0;
        final client = ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: storage,
          beforeRequestDispatch: () async {
            dispatchReached.complete();
            await dispatchGate.future;
          },
          httpClient: MockClient((request) async {
            logoutHttpCalls++;
            return http.Response('{"data":{}}', 200);
          }),
        );

        final logout = client.post<Map<String, dynamic>>(
          "/auth/logout",
          expectedGeneration: client.sessionGeneration,
          allowUncommittedSession: true,
        );
        await dispatchReached.future;
        client.beginSessionTransition();
        dispatchGate.complete();

        await expectLater(
          logout,
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              "code",
              "STALE_SESSION",
            ),
          ),
        );
        expect(logoutHttpCalls, 0);
      },
    );

    test("a delayed logout cannot clear a newer login session", () async {
      final storage = _MemorySecureStorage();
      final logoutStarted = Completer<void>();
      final logoutResponse = Completer<http.Response>();
      final apiClient = ApiClient(
        baseUrl: "https://api.ensom.test/v1",
        secureStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith("/auth/logout")) {
            logoutStarted.complete();
            return logoutResponse.future;
          }
          if (request.url.path.endsWith("/auth/email/login")) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final owner = (body["email"] as String).startsWith("a") ? "a" : "b";
            return _loginResponse(owner);
          }
          return http.Response("{}", 200);
        }),
      );
      final initialDraftClear = Completer<void>();
      final notifier = AuthNotifier(
        authService: AuthService(apiClient: apiClient),
        secureStorage: storage,
        apiClient: apiClient,
        clearMapDraft: () async {
          if (!initialDraftClear.isCompleted) initialDraftClear.complete();
        },
        initializeFcm: (_, _) async {},
        disposeFcm: () async {},
      );
      addTearDown(notifier.dispose);
      await initialDraftClear.future;

      await notifier.loginWithEmail(
        email: "a@example.com",
        password: "password-a",
      );
      final logout = notifier.logout();
      await logoutStarted.future;

      await notifier.loginWithEmail(
        email: "b@example.com",
        password: "password-b",
      );
      logoutResponse.complete(http.Response('{"data":{}}', 200));
      await logout;

      expect(storage.accessTokenValue, "access-b");
      expect(storage.refreshTokenValue, "refresh-b");
      expect(storage.userIdValue, "user-b");
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.userId, "user-b");
    });

    test("logout capture cannot migrate to a newer login session", () async {
      final storage = _MemorySecureStorage();
      var logoutHttpCalls = 0;
      final apiClient = ApiClient(
        baseUrl: "https://api.ensom.test/v1",
        secureStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith("/auth/logout")) {
            logoutHttpCalls++;
            return http.Response('{"data":{}}', 200);
          }
          if (request.url.path.endsWith("/auth/email/login")) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final owner = (body["email"] as String).startsWith("a") ? "a" : "b";
            return _loginResponse(owner);
          }
          return http.Response("{}", 200);
        }),
      );
      final notifier = AuthNotifier(
        authService: AuthService(apiClient: apiClient),
        secureStorage: storage,
        apiClient: apiClient,
        clearMapDraft: () async {},
        initializeFcm: (_, _) async {},
        disposeFcm: () async {},
      );
      addTearDown(notifier.dispose);
      await notifier.sessionCheckCompletion;
      await notifier.loginWithEmail(
        email: "a@example.com",
        password: "password-a",
      );

      storage
        ..sessionReadStarted = Completer<void>()
        ..sessionReadGate = Completer<void>();
      final logout = notifier.logout();
      await storage.sessionReadStarted!.future;

      await notifier.loginWithEmail(
        email: "b@example.com",
        password: "password-b",
      );
      storage.sessionReadGate!.complete();
      await logout;

      expect(logoutHttpCalls, 0);
      expect(storage.accessTokenValue, "access-b");
      expect(storage.refreshTokenValue, "refresh-b");
      expect(storage.userIdValue, "user-b");
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.userId, "user-b");
    });

    test("failed explicit logout still deletes the device token", () async {
      final storage = _MemorySecureStorage();
      var deviceTokenDeleteCount = 0;
      var logoutHttpCount = 0;
      final apiClient = ApiClient(
        baseUrl: "https://api.ensom.test/v1",
        secureStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith("/auth/logout")) {
            logoutHttpCount++;
            throw const SocketException("offline");
          }
          if (request.url.path.endsWith("/auth/email/login")) {
            return _loginResponse("a");
          }
          return http.Response("{}", 200);
        }),
      );
      final notifier = AuthNotifier(
        authService: AuthService(apiClient: apiClient),
        secureStorage: storage,
        apiClient: apiClient,
        clearMapDraft: () async {},
        initializeFcm: (_, _) async {},
        disposeFcm: () async => deviceTokenDeleteCount++,
      );
      addTearDown(notifier.dispose);
      await notifier.sessionCheckCompletion;
      await notifier.loginWithEmail(
        email: "a@example.com",
        password: "password-a",
      );

      await notifier.logout();

      expect(logoutHttpCount, 1);
      expect(deviceTokenDeleteCount, 1);
      expect(storage.accessTokenValue, isNull);
      expect(storage.refreshTokenValue, isNull);
      expect(storage.userIdValue, isNull);
      expect(notifier.state.status, AuthStatus.unauthenticated);
    });

    test("a stale bootstrap cannot expire a newer login session", () async {
      final storage = _MemorySecureStorage()
        ..accessTokenValue = "access-a"
        ..refreshTokenValue = "refresh-a"
        ..userIdValue = "user-a";
      final bootstrapStarted = Completer<void>();
      final bootstrapResponse = Completer<http.Response>();
      final apiClient = ApiClient(
        baseUrl: "https://api.ensom.test/v1",
        secureStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith("/me/bootstrap")) {
            bootstrapStarted.complete();
            return bootstrapResponse.future;
          }
          if (request.url.path.endsWith("/auth/email/login")) {
            return _loginResponse("b");
          }
          return http.Response("{}", 200);
        }),
      );
      var draftClearCount = 0;
      final notifier = AuthNotifier(
        authService: AuthService(apiClient: apiClient),
        secureStorage: storage,
        apiClient: apiClient,
        clearMapDraft: () async => draftClearCount++,
        initializeFcm: (_, _) async {},
        disposeFcm: () async {},
      );
      addTearDown(notifier.dispose);
      apiClient.setAuthExpiredHandler(notifier.onTerminalAuthExpired);
      addTearDown(() => apiClient.setAuthExpiredHandler(null));
      await bootstrapStarted.future;

      await notifier.loginWithEmail(
        email: "b@example.com",
        password: "password-b",
      );
      bootstrapResponse.complete(http.Response("{}", 401));
      await notifier.sessionCheckCompletion;

      expect(storage.accessTokenValue, "access-b");
      expect(storage.refreshTokenValue, "refresh-b");
      expect(storage.userIdValue, "user-b");
      expect(storage.clearSessionCount, 0);
      expect(draftClearCount, 0);
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.userId, "user-b");
    });

    test(
      "terminal expiry disposes FCM and relogin initializes it again",
      () async {
        final storage = _MemorySecureStorage();
        final apiClient = ApiClient(
          baseUrl: "https://api.ensom.test/v1",
          secureStorage: storage,
          httpClient: MockClient((request) async => http.Response("{}", 200)),
        );
        final initialDraftClear = Completer<void>();
        var initializeCount = 0;
        var disposeCount = 0;
        final notifier = AuthNotifier(
          authService: _AuthenticatedAuthService(apiClient: apiClient),
          secureStorage: storage,
          apiClient: apiClient,
          clearMapDraft: () async {
            if (!initialDraftClear.isCompleted) initialDraftClear.complete();
          },
          initializeFcm: (_, _) async => initializeCount++,
          disposeFcm: () async => disposeCount++,
        );
        addTearDown(notifier.dispose);
        await initialDraftClear.future;

        storage
          ..accessTokenValue = "access-a"
          ..refreshTokenValue = "refresh-a"
          ..userIdValue = "user-a";
        await notifier.loginWithEmail(
          email: "a@example.com",
          password: "password",
        );
        await Future<void>.delayed(Duration.zero);
        expect(initializeCount, 1);

        final expiredGeneration = apiClient.sessionGeneration;
        await notifier.onTerminalAuthExpired(expiredGeneration);
        expect(disposeCount, 1);
        expect(notifier.state.status, AuthStatus.unauthenticated);

        storage
          ..accessTokenValue = "access-b"
          ..refreshTokenValue = "refresh-b"
          ..userIdValue = "user-b";
        await notifier.loginWithEmail(
          email: "b@example.com",
          password: "password",
        );
        await Future<void>.delayed(Duration.zero);
        expect(initializeCount, 2);
        expect(notifier.state.status, AuthStatus.authenticated);
      },
    );
  });
}

http.Response _loginResponse(String owner) => http.Response(
  jsonEncode({
    "data": {
      "accessToken": "access-$owner",
      "refreshToken": "refresh-$owner",
      "user": {
        "userId": "user-$owner",
        "nickname": "tester-$owner",
        "timezone": "Asia/Seoul",
        "isNew": false,
      },
      "consentRequired": <String>[],
    },
  }),
  200,
);

Future<_Harness> _createHarness(
  MockClient httpClient, {
  bool failSessionCleanup = false,
  bool failDraftCleanup = false,
  Future<void> Function()? fcmDisposer,
}) async {
  final storage = _MemorySecureStorage();
  final apiClient = ApiClient(
    baseUrl: "https://api.ensom.test/v1",
    secureStorage: storage,
    httpClient: httpClient,
  );
  final authService = _ConsentAuthService(apiClient: apiClient);
  final initialDraftClear = Completer<void>();
  var draftClearCount = 0;
  var shouldFailDraftCleanup = false;
  var fcmDisposeCount = 0;
  final notifier = AuthNotifier(
    authService: authService,
    secureStorage: storage,
    apiClient: apiClient,
    clearMapDraft: () async {
      draftClearCount++;
      if (!initialDraftClear.isCompleted) initialDraftClear.complete();
      if (shouldFailDraftCleanup) throw StateError("draft cleanup failed");
    },
    disposeFcm: () async {
      fcmDisposeCount++;
      await fcmDisposer?.call();
    },
  );

  // 생성 시 세션 없음 검사를 끝낸 뒤 실행 중 로그인 상태를 만든다.
  await initialDraftClear.future;
  await Future<void>.delayed(Duration.zero);
  draftClearCount = 0;
  shouldFailDraftCleanup = failDraftCleanup;
  storage
    ..accessTokenValue = "access-token"
    ..refreshTokenValue = "refresh-token"
    ..userIdValue = "user-1"
    ..failClearSession = failSessionCleanup;
  await notifier.loginWithEmail(
    email: "user@example.com",
    password: "password",
  );
  apiClient.setAuthExpiredHandler(notifier.onTerminalAuthExpired);

  return _Harness(
    apiClient: apiClient,
    notifier: notifier,
    storage: storage,
    getDraftClearCount: () => draftClearCount,
    getFcmDisposeCount: () => fcmDisposeCount,
  );
}

class _Harness {
  _Harness({
    required this.apiClient,
    required this.notifier,
    required this.storage,
    required int Function() getDraftClearCount,
    required int Function() getFcmDisposeCount,
  }) : _getDraftClearCount = getDraftClearCount,
       _getFcmDisposeCount = getFcmDisposeCount;

  final ApiClient apiClient;
  final AuthNotifier notifier;
  final _MemorySecureStorage storage;
  final int Function() _getDraftClearCount;
  final int Function() _getFcmDisposeCount;

  int get draftClearCount => _getDraftClearCount();
  int get fcmDisposeCount => _getFcmDisposeCount();

  void dispose() {
    apiClient.setAuthExpiredHandler(null);
    notifier.dispose();
  }
}

class _AuthenticatedAuthService extends AuthService {
  _AuthenticatedAuthService({required super.apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
    required int expectedGeneration,
    String? installationId,
  }) async {
    await _apiClient.saveSession(
      expectedGeneration: expectedGeneration,
      accessToken: "access-1",
      refreshToken: "refresh-1",
      userId: "user-1",
    );
    return const LoginResult(
      userId: "user-1",
      nickname: "tester",
      timezone: "Asia/Seoul",
      isNew: false,
      consentRequired: [],
    );
  }
}

class _ConsentAuthService extends AuthService {
  _ConsentAuthService({required super.apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
    required int expectedGeneration,
    String? installationId,
  }) async {
    await _apiClient.saveSession(
      expectedGeneration: expectedGeneration,
      accessToken: "access-1",
      refreshToken: "refresh-1",
      userId: "user-1",
    );
    return const LoginResult(
      userId: "user-1",
      nickname: "tester",
      timezone: "Asia/Seoul",
      isNew: false,
      consentRequired: ["terms"],
    );
  }
}

class _MemorySecureStorage extends SecureStorageService {
  String? accessTokenValue;
  String? refreshTokenValue;
  String? userIdValue;
  int clearSessionCount = 0;
  bool failClearSession = false;
  Completer<void>? sessionReadStarted;
  Completer<void>? sessionReadGate;
  Completer<void>? sessionSaveStarted;
  Completer<void>? sessionSaveGate;
  Object? saveSessionErrorAfterAccessToken;
  Completer<void>? accessUpdateStarted;
  Completer<void>? accessUpdateGate;
  Object? accessUpdateErrorAfterWrite;

  Future<String?> _readSessionValue(String? value) async {
    final gate = sessionReadGate;
    if (gate != null) {
      final started = sessionReadStarted;
      if (started != null && !started.isCompleted) started.complete();
      await gate.future;
    }
    return value;
  }

  @override
  Future<String?> get accessToken => _readSessionValue(accessTokenValue);

  @override
  Future<String?> get refreshToken => _readSessionValue(refreshTokenValue);

  @override
  Future<String?> get userId => _readSessionValue(userIdValue);

  @override
  Future<String> get installationId async => "installation-1";

  @override
  Future<bool> get hasSession async => accessTokenValue != null;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    final gate = sessionSaveGate;
    if (gate != null) {
      final started = sessionSaveStarted;
      if (started != null && !started.isCompleted) started.complete();
      await gate.future;
    }
    accessTokenValue = accessToken;
    final partialWriteError = saveSessionErrorAfterAccessToken;
    if (partialWriteError != null) throw partialWriteError;
    refreshTokenValue = refreshToken;
    userIdValue = userId;
  }

  @override
  Future<void> clearSession() async {
    clearSessionCount++;
    if (failClearSession) throw StateError("session cleanup failed");
    accessTokenValue = null;
    refreshTokenValue = null;
    userIdValue = null;
  }

  @override
  Future<void> updateAccessToken(String accessToken) async {
    accessTokenValue = accessToken;
    final started = accessUpdateStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = accessUpdateGate;
    if (gate != null) await gate.future;
    final partialWriteError = accessUpdateErrorAfterWrite;
    if (partialWriteError != null) throw partialWriteError;
  }
}
