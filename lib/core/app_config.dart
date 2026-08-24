/// 빌드 시점 주입 값. 환경별로 바꿔야 하는 값은 --dart-define으로 덮어쓴다.
/// `flutter run --dart-define=KAKAO_NATIVE_APP_KEY=xxx --dart-define=KAKAO_REST_API_KEY=yyy`
library;

/// 카카오맵 SDK 네이티브 앱 키.
/// Native App Key는 Android/iOS 바이너리에 포함되는 공개 식별자이므로
/// Ensom 앱의 등록값을 기본값으로 둔다. 다른 카카오 앱을 사용하는 환경은
/// --dart-define=KAKAO_NATIVE_APP_KEY로 덮어쓸 수 있다.
const String kKakaoNativeAppKey = String.fromEnvironment(
  'KAKAO_NATIVE_APP_KEY',
  defaultValue: '51b8598283169d6ec85c8c934783c2da',
);

/// 카카오 로컬(키워드 검색) REST API 키. 지도 SDK 키와 별도 발급값이다
/// (카카오 개발자 콘솔의 같은 앱에서 "REST API 키"로 확인 가능).
/// 비어 있으면 목적지 키워드 검색이 지도를 눌러 좌표를 고르는 방식으로 저하 동작한다.
const String kKakaoRestApiKey = String.fromEnvironment(
  'KAKAO_REST_API_KEY',
  defaultValue: '',
);

/// Flutter Web의 Kakao Maps JavaScript SDK 키. 네이티브/REST 키와
/// 별도이며, 웹 빌드 시 동적으로 SDK script를 로드하는 데만 사용한다.
/// JavaScript App Key 역시 브라우저에 포함되는 공개 식별자이므로 Ensom
/// 웹 앱의 등록값을 기본값으로 둔다. 다른 카카오 앱을 사용하는 환경은
/// --dart-define=KAKAO_JAVASCRIPT_APP_KEY로 덮어쓸 수 있다.
const String kKakaoJavaScriptAppKey = String.fromEnvironment(
  'KAKAO_JAVASCRIPT_APP_KEY',
  defaultValue: 'a18e422a8a32a78ca9753aad386d26d0',
);

/// Google OAuth 클라이언트 ID. BE의 OAUTH_GOOGLE_CLIENT_ID와 같은
/// 이름을 사용하되, FE에는 공개 가능한 client ID만 빌드 시 주입한다.
/// 비어 있으면 구글 로그인 버튼이 숨겨진다.
///
/// OAuth client ID는 시크릿이 아니라 클라이언트 바이너리에 포함되도록
/// 설계된 공개 식별자다(Google 문서 기준. 짝을 이루는 client secret만
/// 서버에 보관한다) — 그래서 카카오 네이티브/JS 키와 같은 방식으로
/// Ensom 앱의 등록값을 기본값으로 둔다.
///
/// 이전엔 defaultValue가 빈 문자열이라 배포 스크립트가
/// --dart-define=OAUTH_GOOGLE_CLIENT_ID=...를 반드시 넘겨야 했는데,
/// 실제 배포 명령이 이름이 다른 --dart-define=GOOGLE_SERVER_CLIENT_ID=...
/// 를 넘기고 있어 매번 조용히 빈 문자열로 빌드됐다(dart-define은 이름이
/// 안 맞으면 오류 없이 defaultValue로 떨어진다) — 그 결과 구글
/// 로그인 버튼이 계속 숨겨져 있었다.
const String kGoogleServerClientId = String.fromEnvironment(
  'OAUTH_GOOGLE_CLIENT_ID',
  defaultValue:
      '496007970310-15p3l1gvka68ijtphubh889pvnk9crs7.apps.googleusercontent.com',
);

/// 백엔드 API base URL. 운영 도메인은 api.ensom.shop이며(구 api.ensom.app은
/// DNS 레코드가 없어 모든 호출이 해석 단계에서 실패했다, Issue #83),
/// 스테이징/로컬 전환을 위해 --dart-define=API_BASE_URL로 재정의할 수 있다.
/// 예: flutter run --dart-define=API_BASE_URL=https://staging.ensom.shop/v1
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.ensom.shop/v1',
);
