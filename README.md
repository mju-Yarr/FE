# Ensom FE

## 실행

### 1. Firebase 설정 파일 (필수 — Git 미추적)

`google-services.json`과 `GoogleService-Info.plist`는 API 키를 포함하므로 Git에 기록하지 않습니다.
빌드 전에 아래 경로에 직접 배치해야 합니다.

```
android/app/google-services.json      ← Android
ios/Runner/GoogleService-Info.plist    ← iOS
```

**파일 획득 방법:**
- 팀 Slack `#fe-secrets` 채널에서 다운로드
- 또는 Firebase 콘솔 → 프로젝트 설정 → 앱 추가에서 직접 발급

**파일이 없으면:**
- `flutter build apk`는 Google Services Gradle 플러그인 오류로 실패합니다
- `flutter run` (debug)은 `Firebase.initializeApp()` try-catch로 FCM만 비활성, 앱은 시작됨

### 2. 카카오 지도 설정

```bash
flutter run \
  --dart-define=KAKAO_REST_API_KEY=yyy
```

- `KAKAO_NATIVE_APP_KEY`: Ensom 네이티브 앱 키가 코드 기본값으로 등록되어
  있어 일반 Android/iOS 실행에는 별도 주입이 필요하지 않습니다. 다른 카카오
  앱을 사용하는 빌드에서만 `--dart-define=KAKAO_NATIVE_APP_KEY=...`로 덮어씁니다.
- `KAKAO_REST_API_KEY`: 같은 콘솔의 REST API 키 (목적지 키워드 검색)
- REST API 키가 비어 있어도 지도는 표시되지만 장소 키워드 검색은 저하 동작합니다.

카카오 개발자 콘솔의 Android 플랫폼 등록값은 다음과 일치해야 합니다.

- 패키지명: `com.ensom.app.ensom`
- 키 해시: `DcHKO2R5DcV/BvOjZNCtuTl/Lbk=`

키 해시는 앱에 전달하는 런타임 설정이 아니라 카카오 서버가 APK 서명을
검증하기 위한 콘솔 등록값입니다. 서명 인증서를 변경하면 새 키 해시도 콘솔에
추가해야 합니다.

### 3. Google OAuth (선택)

```bash
flutter run \
  --dart-define=OAUTH_GOOGLE_CLIENT_ID=xxx
```

- 비어 있으면 Google 로그인 버튼이 숨겨지고 이메일 로그인만 노출

### 전체 실행 예시

```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.ensom.shop/v1 \
  --dart-define=KAKAO_REST_API_KEY=yyy \
  --dart-define=KAKAO_JAVASCRIPT_APP_KEY=www \
  --dart-define=OAUTH_GOOGLE_CLIENT_ID=zzz
```

키 이름은 `lib/core/app_config.dart`의 `String.fromEnvironment`와 정확히
같아야 합니다. Google client ID는 BE의 `OAUTH_GOOGLE_CLIENT_ID`와 이름을
맞췄습니다(FE에는 공개 가능한 client ID만 주입).

## CI 빌드 시 Firebase 설정 주입

```yaml
# GitHub Actions 예시
- name: Decode google-services.json
  run: echo "${{ secrets.GOOGLE_SERVICES_JSON_BASE64 }}" | base64 -d > android/app/google-services.json

- name: Build APK
  run: flutter build apk --debug
```

시크릿 `GOOGLE_SERVICES_JSON_BASE64`는 `base64 -w0 android/app/google-services.json`으로 생성합니다.

## 빌드 검증

```bash
# 분석 (error 0이면 통과)
flutter analyze --no-fatal-infos --no-fatal-warnings

# 테스트
flutter test

# APK 빌드 (google-services.json 필요)
flutter build apk --debug

# 웹 릴리스 빌드
flutter build web --release --pwa-strategy=none --no-wasm-dry-run \
  --dart-define=API_BASE_URL=https://api.ensom.shop/v1 \
  --dart-define=OAUTH_GOOGLE_CLIENT_ID=zzz \
  --dart-define=KAKAO_REST_API_KEY=yyy \
  --dart-define=KAKAO_JAVASCRIPT_APP_KEY=www \
  --dart-define=KAKAO_NATIVE_APP_KEY=xxx
```

두 플래그 모두 의도가 있으니 빼지 마세요.

`--no-wasm-dry-run`은 wasm 호환성 사전 검사를 끕니다(`flutter build web --help`가
"Disable to suppress warnings"로 안내하는 용도). 이 앱은 JS로 빌드해 Firebase
Hosting에 올리므로 wasm은 대상이 아닌데, 검사를 켜 두면 의존 패키지
`kakao_map_sdk`(1.2.6, 현재 최신) 내부의 static interop 경고가 매 빌드마다 수십
줄씩 나옵니다. 우리 코드로는 고칠 수 없고 산출물에도 영향이 없습니다. 이 패키지가
wasm을 지원하면 플래그를 빼고 `--wasm` 전환을 검토할 수 있습니다.

`--pwa-strategy=none`은 deprecated 경고가 뜨지만 **아직 실제로 동작합니다.**
붙이면 `flutter_service_worker.js`가 0바이트로 비고, 빼면 784바이트짜리 실제
service worker가 생성돼 캐싱 동작이 달라집니다. 배포 후 구버전이 캐시에 남는 것을
막으려면 유지해야 합니다. Flutter가 이 옵션을 제거하면(flutter/flutter#156910)
service worker를 비우는 다른 방법을 찾아야 합니다.
