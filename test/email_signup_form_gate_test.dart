import "package:ensom/core/auth_service.dart";
import "package:ensom/network/api_client.dart";
import "package:ensom/providers/auth_providers.dart";
import "package:ensom/screens/onboarding/email_signup_screen.dart";
import "package:ensom/widgets/ensom/ensom_pill_button.dart";
import "package:ensom/widgets/ensom/ensom_text_field.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";

/// 명세 §8 S-16 폼 게이트 — 이름·닉네임·이메일·비밀번호·비밀번호 확인 전부 입력
/// AND 비밀번호 8자 이상 + 영문·숫자 AND 확인 일치 AND 필수 약관 AND 이메일 인증.
/// 조건 하나라도 빠지면 "회원가입" 버튼이 비활성이어야 한다.
class _FakeAuthService implements AuthService {
  int sendCount = 0;
  int confirmCount = 0;

  @override
  Future<VerificationChallenge> sendVerificationCode(String email) async {
    sendCount++;
    return VerificationChallenge(
      challengeId: "challenge-1",
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );
  }

  @override
  Future<VerificationTicket> confirmVerificationCode({
    required String email,
    required String code,
  }) async {
    confirmCount++;
    if (code != "123456") {
      throw ApiException(
        code: "INVALID_VERIFICATION_CODE",
        message: "인증 코드가 유효하지 않거나 만료되었습니다.",
      );
    }
    return VerificationTicket(
      ticket: "ticket-1",
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _pump(WidgetTester tester, _FakeAuthService auth) async {
  tester.view.physicalSize = const Size(834, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: "/signup",
    routes: [
      GoRoute(path: "/signup", builder: (c, s) => const EmailSignupScreen()),
      GoRoute(path: "/terms/:key", builder: (c, s) => const SizedBox.shrink()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

bool _signupDisabled(WidgetTester tester) {
  final button = tester.widget<EnsomPillButton>(
    find.widgetWithText(EnsomPillButton, "회원가입"),
  );
  return button.onPressed == null;
}

/// EnsomTextField는 라벨을 TextField 바깥의 형제 Text로 그린다.
Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  await tester.enterText(
    find.descendant(
      of: find.widgetWithText(EnsomTextField, label),
      matching: find.byType(TextField),
    ),
    value,
  );
  await tester.pump();
}

/// 인증을 제외한 나머지 조건을 모두 채운다.
Future<void> _fillEverythingButVerification(WidgetTester tester) async {
  await _enterField(tester, "이름", "김민현");
  await _enterField(tester, "닉네임", "minhyun");
  await _enterField(tester, "이메일", "test@example.com");
  await _enterField(tester, "비밀번호", "password123");
  await _enterField(tester, "비밀번호 확인", "password123");
  for (final label in [
    "[필수] 이용약관 동의",
    "[필수] 개인정보 처리방침 동의",
    "[필수] 위치기반 서비스 이용약관 동의",
  ]) {
    await tester.tap(find.text(label));
    await tester.pump();
  }
}

Future<void> _verifyEmail(WidgetTester tester, String code) async {
  await tester.tap(find.widgetWithText(EnsomPillButton, "인증 요청"));
  await tester.pumpAndSettle();
  await _enterField(tester, "인증 코드 6자리", code);
  await tester.tap(find.widgetWithText(EnsomPillButton, "확인"));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("빈 폼에서는 회원가입 버튼이 비활성이다", (tester) async {
    await _pump(tester, _FakeAuthService());
    expect(_signupDisabled(tester), isTrue);
  });

  testWidgets("이메일 인증만 빠져도 회원가입 버튼이 비활성이다", (tester) async {
    await _pump(tester, _FakeAuthService());
    await _fillEverythingButVerification(tester);
    expect(_signupDisabled(tester), isTrue);
  });

  testWidgets("모든 조건을 채우면 회원가입 버튼이 활성화된다", (tester) async {
    await _pump(tester, _FakeAuthService());
    await _fillEverythingButVerification(tester);
    await _verifyEmail(tester, "123456");

    expect(find.text("이메일 인증 완료"), findsOneWidget);
    expect(_signupDisabled(tester), isFalse);
  });

  testWidgets("필수 약관 하나를 빼면 다시 비활성이 된다", (tester) async {
    await _pump(tester, _FakeAuthService());
    await _fillEverythingButVerification(tester);
    await _verifyEmail(tester, "123456");
    expect(_signupDisabled(tester), isFalse);

    await tester.tap(find.text("[필수] 위치기반 서비스 이용약관 동의"));
    await tester.pump();
    expect(_signupDisabled(tester), isTrue);
  });

  testWidgets("비밀번호 확인이 다르면 비활성이다", (tester) async {
    await _pump(tester, _FakeAuthService());
    await _fillEverythingButVerification(tester);
    await _verifyEmail(tester, "123456");
    await _enterField(tester, "비밀번호 확인", "password124");

    expect(find.text("비밀번호가 일치하지 않아요."), findsOneWidget);
    expect(_signupDisabled(tester), isTrue);
  });

  testWidgets("숫자 없는 비밀번호는 규칙 체크를 통과하지 못한다", (tester) async {
    await _pump(tester, _FakeAuthService());
    await _fillEverythingButVerification(tester);
    await _verifyEmail(tester, "123456");
    await _enterField(tester, "비밀번호", "passwordonly");
    await _enterField(tester, "비밀번호 확인", "passwordonly");

    expect(_signupDisabled(tester), isTrue);
  });

  testWidgets("틀린 코드는 인증되지 않고 안내를 보여준다", (tester) async {
    await _pump(tester, _FakeAuthService());
    await _fillEverythingButVerification(tester);
    await _verifyEmail(tester, "000000");

    expect(find.text("인증 코드가 맞지 않거나 만료됐어요."), findsOneWidget);
    expect(find.text("이메일 인증 완료"), findsNothing);
    expect(_signupDisabled(tester), isTrue);
  });

  testWidgets("인증 후 이메일을 바꾸면 인증이 무효가 된다", (tester) async {
    await _pump(tester, _FakeAuthService());
    await _fillEverythingButVerification(tester);
    await _verifyEmail(tester, "123456");
    expect(_signupDisabled(tester), isFalse);

    await _enterField(tester, "이메일", "other@example.com");

    expect(find.text("이메일 인증 완료"), findsNothing);
    expect(_signupDisabled(tester), isTrue);
  });
}
