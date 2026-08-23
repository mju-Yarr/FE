# Ensom API 명세서

| 항목 | 내용 |
|---|---|
| 문서 버전 | v5.1 |
| 작성일 | 2026-08-20 |
| 근거 문서 | **PRD v0.4.3** (최상위) · **ERD v3.1** · **TRD v4.0** |
| 스택 | Flutter · **Java 21 · Spring Boot 4.1.0** · PostgreSQL 16 |
| 외부 연동 | **ODsay 대중교통 API · 카카오맵 SDK · 기상청 · 에어코리아 · Google (OAuth · Calendar)** |
| 인증 | **이메일 계정 · Google 계정** 2종 |
| 필드 표기 | 요청·응답 **camelCase** · DB는 snake_case (ERD) |

**이 문서의 위치** — TRD §12가 정의한 엔드포인트 목록과 공통 규약을 뼈대로, ERD의 테이블·컬럼명과 PRD의 요구사항 ID를 결합해 요청/응답 바디까지 구현 가능한 수준으로 채운 것입니다. **TRD §12를 대체**하며, 설계 근거(계산 파이프라인·상태 기계·트랜잭션 경계)는 TRD 본문을 참조합니다.

| 문서 | 이 API 명세에 기여한 것 |
|---|---|
| **PRD v0.4.3** | 기능 요구사항 ID(AUTH/ONB/CAL/PLAN/MAP/NOTI/WELL/MODEL/REPORT/SET/DATA), 문구·의료 경계 원칙, 성공 지표 |
| **ERD v3.1** | 테이블·컬럼명, 제약(UNIQUE/CHECK), 삭제·보존 정책 |
| **TRD v4.0** | 엔드포인트 목록, 상태 기계, 멱등성·트랜잭션 규약, 파라미터(부록 A), 확정 결정 D1~D17, 기술 요구사항 TR-01~13 |

---

## 1. 공통 규약

### 1.1 Base URL

```
https://api.ensom.shop/v1
```

### 1.2 인증

- `Authorization: Bearer <accessToken>` — 전 엔드포인트 필수 (`/auth/*` 제외)
- access JWT 1시간 · refresh 30일 (기기별, `PUSH_DEVICE.installation_id`와 연결) — TRD §10.1
- 모든 자원은 토큰의 `userId`로 **행 수준 필터링**. 타 사용자 자원 접근은 `404` (존재 여부 비노출) — PRD §23.4
- **비회원·게스트 모드 없음** (AUTH-01, PRD §10.1)

### 1.3 공통 헤더

| 헤더 | 용도 |
|---|---|
| `Authorization` | Bearer 토큰 |
| `Idempotency-Key` | 모든 POST/PUT/PATCH 필수. 24시간 내 동일 키 → 이전 응답 재생 (TRD §12.3) |
| `X-App-Version` | 최소 지원 버전 미만이면 `426` |
| `Accept-Language` | 알림·카드 문구 로컬라이즈 |

### 1.4 공통 응답 포맷

```json
// 성공
{ "data": { }, "meta": { "requestId": "req_123", "serverTime": "2026-08-17T09:00:00+09:00" } }

// 실패
{ "error": { "code": "EVENT_NOT_FOUND", "retryable": false, "message": "string" } }
```

### 1.5 시간 표현 (TR-02)

- 저장은 전부 `timestamptz`(UTC). 일정 시각은 BE의 `Instant` 계약에 따라
  ISO-8601 UTC(`Z`) 또는 명시적 오프셋 값을 받으며, 응답은 UTC(`Z`)로
  정규화될 수 있습니다. 오프셋이 없는 로컬 시각 문자열은 요청에서 거부합니다(`422`).
- 일정은 `USERS.timezone`(IANA, 예 `Asia/Seoul`)을 함께 반환
- 종일 일정은 계획 대상에서 제외. 사용자가 시각을 지정하면 편입
- 클라이언트가 보내는 `deviceTs`는 기기 시각이며, 서버 수신 시각과 **±120초**를 넘게 차이 나면 `clockSkew` 플래그가 붙어 개인화 학습에서 제외됨 (§13)

### 1.6 멱등성 — 두 층위 (TR-03)

| 층위 | 수단 | 막는 것 |
|---|---|---|
| HTTP | `Idempotency-Key` 헤더 | **같은 요청**의 재전송 (네트워크 재시도) |
| 도메인 | 바디의 `clientEventId` (UUID) | **다른 요청에 실려 온 같은 사건** (오프라인 큐 재전송) |

둘 다 필요합니다. 도메인 층은 `EVENT_ACTION_LOG.client_event_id` UNIQUE로 강제하며, 중복은 오류가 아니라 `duplicated: true`를 담은 **정상 응답**입니다.

### 1.7 페이로드 한계

행동 이벤트 배치 최대 100건 · 요청 본문 1MB.

---

## 2. 인증 · 기기 · 동의 (AUTH-01~04)

인증 수단은 **이메일 계정**과 **Google 계정** 2종입니다. 비회원·게스트 모드는 없습니다.

| Method | Path | 설명 | 요구사항 |
|---|---|---|---|
| POST | `/auth/email/signup` | 이메일 계정 가입 | AUTH-01/02 |
| POST | `/auth/email/login` | 이메일 로그인 | AUTH-02 |
| POST | `/auth/email/verify` | 이메일 인증 완료 | AUTH-02 |
| POST | `/auth/email/verify/resend` | 인증 메일 재발송 | AUTH-02 |
| POST | `/auth/password/reset-request` | 재설정 메일 요청 | AUTH-02 |
| POST | `/auth/password/reset-confirm` | 재설정 완료 | AUTH-02 |
| PATCH | `/me/password` | 비밀번호 설정·변경 | AUTH-02 |
| POST | `/auth/login` | Google 로그인 | AUTH-01/02 |
| POST | `/auth/refresh` | 세션 갱신 | AUTH-03 |
| POST | `/auth/logout` | 로그아웃 | AUTH-04 |
| POST | `/push-devices` | FCM 토큰 등록·갱신 | AUTH-02 |
| DELETE | `/push-devices/{installationId}` | 토큰 해지 | AUTH-04 |
| GET / POST | `/consents` | 약관 동의 조회·기록 | AUTH-01 |
| PATCH | `/me/nickname` | 닉네임 변경 | AUTH-02 |
| GET | `/auth/check-nickname` | 닉네임 중복확인 | AUTH-02 |
| POST | `/me/email/change-request` | 이메일 변경 요청 | AUTH-02 |
| POST | `/me/email/change-confirm` | 이메일 변경 확정 | AUTH-02 |
| GET | `/me/providers` | 로그인 수단 목록 | AUTH-02 |
| POST | `/me/providers` | 로그인 수단 연결 | AUTH-02 |
| DELETE | `/me/providers/{id}` | 로그인 수단 해제 | AUTH-02 |
| GET | `/me/sessions` | 세션(로그인 기록) 목록 | AUTH-03 |
| DELETE | `/me/sessions/{id}` | 개별 세션 무효화 | AUTH-03 |
| DELETE | `/me/sessions` | 전체 세션 무효화(현재 제외) | AUTH-03 |
| GET | `/me/bookmarks` | 북마크 목록 | MAP-01 |
| POST | `/me/bookmarks` | 북마크 추가 | MAP-01 |
| DELETE | `/me/bookmarks/{id}` | 북마크 삭제 | MAP-01 |
| DELETE | `/me/action-logs` | 행동 기록 일괄 삭제 | DATA-01 |

### 2.1 POST /auth/email/signup

```json
// Request
{ "email": "user@example.com", "password": "string", "nickname": "민형",
  "timezone": "Asia/Seoul", "installationId": "uuid" }

// Response 201
{
  "data": {
    "user": { "userId": "uuid", "email": "user@example.com", "emailVerified": false },
    "verificationSent": true
  }
}
```

- 비밀번호는 **Argon2id**로 해시해 `USER_CREDENTIAL`에 저장합니다. 최소 10자, 이메일 로컬파트·서비스명 포함 금지, 유출 사전 상위 목록 차단
- `USER_IDENTITY`에 `(provider='email', providerUid=정규화된 이메일)` 행을 만듭니다
- **가입 시점에는 토큰을 발급하지 않습니다.** 이메일 인증 후 로그인해야 세션이 생깁니다
- 이미 Google로 가입된 이메일이면 `409 EMAIL_ALREADY_LINKED`를 반환하고, 클라이언트는 *"이미 Google로 가입된 이메일입니다. Google로 로그인한 뒤 비밀번호를 설정해 주세요"* 로 안내합니다 — 여기서 새 계정을 만들면 같은 사람의 데이터가 둘로 갈라집니다

### 2.2 POST /auth/email/login

```json
// Request
{ "email": "user@example.com", "password": "string", "installationId": "uuid" }

// Response 200
{
  "data": {
    "accessToken": "jwt", "refreshToken": "opaque", "expiresIn": 3600,
    "user": { "userId": "uuid", "nickname": "민형", "timezone": "Asia/Seoul", "isNew": false },
    "emailVerificationRequired": false,
    "consentRequired": []
  }
}
```

| 실패 | 응답 |
|---|---|
| 이메일 없음 · 비밀번호 불일치 | `401 AUTH_INVALID_CREDENTIALS` — **둘을 구분하지 않습니다** |
| 연속 5회 실패 후 | `423 ACCOUNT_LOCKED` + `retryAfterSec` |
| 이메일 미인증 | `200` + `emailVerificationRequired: true` — 로그인은 되지만 핵심 API가 막힙니다 |

> **TR-14 · 인증 응답은 계정의 존재를 노출하지 않습니다.** 존재하지 않는 계정에도 더미 해시 검증을 수행해 응답 시간 차이로도 구분되지 않게 합니다.

### 2.3 이메일 인증

```json
// POST /auth/email/verify
{ "token": "원문 토큰" }
// Response 200 → 이후 로그인부터 emailVerificationRequired: false

// POST /auth/email/verify/resend
{ "email": "user@example.com" }
// Response 200 — 계정 유무와 무관하게 항상 200 (TR-14)
```

- 토큰 수명 **24시간**, 단회용. 서버는 `AUTH_TOKEN.token_hash`(SHA-256)만 저장하고 **원문은 메일로만** 보냅니다
- 재발송은 **60초 쿨다운**. 새 토큰 발급 시 같은 목적의 미사용 토큰을 전부 소비 처리합니다
- 미인증 상태에서 핵심 API 호출 시 `403 EMAIL_VERIFICATION_REQUIRED`

### 2.4 비밀번호 재설정 · 변경

```json
// POST /auth/password/reset-request
{ "email": "user@example.com" }
// Response 200 — 계정 유무와 무관하게 항상 200 (TR-14)

// POST /auth/password/reset-confirm
{ "token": "원문 토큰", "newPassword": "string" }

// PATCH /me/password  — 로그인 상태
{ "currentPassword": "string", "newPassword": "string" }
// Google 로만 가입한 계정이 비밀번호를 처음 설정할 때는 currentPassword 를 생략한다
```

- 재설정 토큰 수명 **30분**, 단회용
- **재설정·변경 완료 시 해당 사용자의 모든 refresh 토큰을 폐기**합니다. 탈취된 세션이 살아남지 않게 하기 위함입니다
- `PATCH /me/password`로 Google 전용 계정에 비밀번호를 추가하면 `USER_IDENTITY`에 `email` identity가 함께 생성됩니다

### 2.5 POST /auth/login (Google)

```json
// Request
{ "provider": "google", "idToken": "string", "installationId": "uuid" }

// Response 200 — §2.2와 동일 형태
```

- 서버는 Google 공개키로 `idToken`을 검증한 뒤 `USER_IDENTITY (provider, providerUid)` UNIQUE 기준으로 계정을 확정합니다 — ERD `uq_identity_provider`
- `provider`는 **`google`만** 허용합니다
- **계정 연결:** `users.email`이 일치하는 기존 계정이 있으면 새 계정을 만들지 않고 그 계정에 `google` identity를 추가하며, `emailVerifiedAt`을 채웁니다 — Google이 이메일 소유를 증명하기 때문입니다
- Google 로그인은 항상 `emailVerificationRequired: false`입니다

### 2.6 POST /auth/refresh · /auth/logout

```json
// refresh Request
{ "refreshToken": "opaque" }
```

- **오프라인과 인증 실패를 구분합니다.** 네트워크 오류(`retryable: true`)면 클라이언트는 로그인 화면으로 보내지 않고 재시도합니다 — 지하철에서 토큰 갱신 실패로 로그아웃시키면 안 됩니다
- 로그아웃 시 서버는 refresh를 폐기하고 `PUSH_DEVICE.token_status`를 비활성화합니다. **서버 데이터는 유지**됩니다

### 2.7 POST /push-devices

```json
// Request
{ "installationId": "uuid", "currentToken": "fcm-token", "platform": "ios" }
// Response 200
{ "data": { "pushDeviceId": "uuid", "tokenStatus": "active" } }
```

- `installationId`가 UNIQUE(ERD)이므로 **재설치 전까지 같은 기기는 한 행을 갱신**합니다
- FCM 토큰은 앱 재실행마다 갱신될 수 있으므로 **로그인 응답에 묻히면 갱신 경로가 없습니다.** 별도 엔드포인트가 필요한 이유입니다
- 호출 시점: 로그인 직후 + 토큰 갱신 콜백 발생 시

### 2.8 GET · POST /consents

```json
// POST Request
{
  "consents": [
    { "consentType": "terms",    "policyVersion": "v3", "action": "agreed", "isRequired": true },
    { "consentType": "privacy",  "policyVersion": "v2", "action": "agreed", "isRequired": true },
    { "consentType": "marketing","policyVersion": "v1", "action": "revoked","isRequired": false }
  ],
  "idempotencyKey": "uuid"
}
```

- `consentType`: `terms` \| `privacy` \| `location` \| `marketing`
- `USER_CONSENT.idempotency_key`가 UNIQUE(ERD)인 것은 **전용 쓰기 경로를 전제한 설계**입니다. 동의 화면을 두 번 제출해도 이력이 중복되지 않습니다
- 동의 이력은 **탈퇴 후에도 법정 기간 보존**됩니다 (§16)
- `action: "revoked"`도 기록입니다 — 삭제가 아니라 새 행 추가

### 2.9 가입 흐름 요약

```
이메일 경로   signup → (메일) verify → login → consents → 온보딩
Google 경로   login  → consents → 온보딩
              ← 이메일 인증 단계가 없다. Google 이 소유를 증명한다

두 경로 모두 consentRequired 가 빈 배열이 될 때까지 홈 진입을 막는다 (PRD §11.2)
```

> **iOS 출시 시 확인:** Google 로그인(제3자 로그인 서비스)을 제공하므로 App Store 심사에서 Apple 로그인 병행을 요구받을 수 있습니다. 요구받으면 `provider`에 `apple`을 추가하며, **스키마와 API 계약은 바뀌지 않습니다** (TRD §10.5).

---

## 3. 부트스트랩

| Method | Path | 설명 |
|---|---|---|
| GET | `/me/bootstrap` | 앱 진입 시 1회. 홈 렌더에 필요한 전부 |

```json
{
  "data": {
    "user": { "userId": "uuid", "nickname": "민형", "timezone": "Asia/Seoul", "accountStatus": "active" },
    "settings": { "initialPrepMinutes": 30, "arrivalBufferMinutes": 10, "notificationSensitivity": "normal",
                  "personalizationEnabled": true, "autoManageEnabled": true,
                  "wellnessEventEnabled": true, "lockscreenHideSensitive": true },
    "permissions": [ { "permissionType": "calendar", "status": "granted" } ],
    "wellnessPrefs": [ { "wellnessTopic": "uv", "isEnabled": true, "remindIntervalMinutes": 120, "dailyEventCap": 1 } ],
    "places": [],
    "prepRules": [],
    "nextEvent": { "eventId": "uuid", "startsAt": "…" },
    "todayPlan": { },
    "engineConfig": { "calcVersion": "3.1.0", "weightVersion": "w1" }
  }
}
```

`engineConfig`를 내려보내는 이유는 **모든 상수가 원격 설정**이기 때문입니다(TR-06). 클라이언트는 이 값이 배포 없이 바뀔 수 있음을 전제하고, 캐시한 계산 결과를 버전이 바뀌면 무효화합니다.

---

## 4. 사용자 설정 · 권한 · 웰니스 선호

| Method | Path | 설명 | 요구사항 |
|---|---|---|---|
| GET / PATCH | `/me/settings` | 준비 시간 시드·도착 여유·알림 민감도·잠금화면 | SET-03 |
| GET / PATCH | `/me/permissions` | 캘린더·위치·알림·백그라운드 위치 권한 상태 | SET-03 |
| GET / PATCH | `/me/wellness-prefs` | 항목별 on/off · 재알림 주기 · 일일 상한 | WELL-06 |

### 4.1 PATCH /me/settings

```json
{
  "initialPrepMinutes": 30,
  "arrivalBufferMinutes": 10,
  "notificationSensitivity": "normal",
  "personalizationEnabled": true,
  "autoManageEnabled": true,
  "wellnessEventEnabled": true,
  "lockscreenHideSensitive": true
}
```

- **`initialPrepMinutes`는 `null` 허용**입니다 — 온보딩의 "잘 모르겠어요"(PRD §11.3). 이 경우 서버는 `SEED_FALLBACK_MIN`(30)을 시드로 쓰고 계획 응답의 `degraded`에 `seed_missing`을 남깁니다 (TRD 부록 A.1)
- 자기보고 시드값이며 **계산에 그대로 쓰이지 않습니다** (PLAN-01, 절대 원칙 2)

### 4.2 PATCH /me/wellness-prefs (WELL-06)

```json
{
  "prefs": [
    { "wellnessTopic": "uv",        "isEnabled": true,  "remindIntervalMinutes": 120, "dailyEventCap": 1 },
    { "wellnessTopic": "pm",        "isEnabled": true,  "remindIntervalMinutes": null, "dailyEventCap": 1 },
    { "wellnessTopic": "hydration", "isEnabled": false, "remindIntervalMinutes": null, "dailyEventCap": 1 }
  ]
}
```

| 필드 | 설명 |
|---|---|
| `wellnessTopic` | `uv` \| `pm` \| `temp` \| `rain` \| `hydration` — ERD 복합 PK `(userId, wellnessTopic)` |
| `remindIntervalMinutes` | **사용자가 직접 설정.** 서비스는 재도포 주기를 판단하지 않습니다 (PRD §14.7, 절대 원칙 3) |
| `dailyEventCap` | 항목별 **하루** 상한. 기본 1. 일정당 상한(§12.3)과 **별개** |

### 4.3 권한 요청 순서 (PRD §11.4)

클라이언트는 아래 순서로 개별 호출합니다. 한 번에 요청하지 않습니다.

```
로그인·약관        → 첫 실행 (회원 전용이므로 유일한 선행 조건)
캘린더            → 연동 진입 시
위치("사용 중")    → 첫 목적지 입력 시
알림              → 첫 계획 생성 후
위치("항상")       → 자동 출발·도착 확인을 켤 때 별도 화면에서 명시 동의
웰니스 이벤트 알림  → 관심 항목 설정에서 별도 토글 (기본 시간 알림과 분리)
```

거부 후 재안내는 기능 진입점에서 **1회만**.

---

## 5. 장소 (SET-01)

| Method | Path | 설명 |
|---|---|---|
| GET / POST | `/places` | 목록 · 생성 |
| PATCH / DELETE | `/places/{placeId}` | 수정 · 삭제 |

```json
// POST Request
{ "placeType": "home", "placeName": "집", "address": "서울시 …",
  "lat": 37.5, "lng": 127.0, "isPrimary": true }
```

- 좌표는 애플리케이션 레벨 AES-GCM 암호화 (TRD §14.3)
- `DELETE`는 **소프트 삭제**(`deleted_at`) — 과거 계획의 `originSnapshot*`은 이미 스냅샷이라 영향받지 않습니다

---

## 6. 맞춤 준비 규칙 (ONB-01 · SET-02 · PLAN-05)

> **v3.0에서 가장 크게 바뀐 절입니다.** 평면 구조(`kind` enum)를 폐기하고 **ERD v3 `USER_PREP_RULE`의 2축 구조**를 씁니다. PRD §11.3의 분류("반복 준비물 / 개인 기호 품목 / 시간 소요 루틴 / 민감 항목" × "챙기기 / 사용·섭취하기 / 구매하기 / 시간이 필요한 루틴")와 정확히 일치합니다.

| Method | Path | 설명 |
|---|---|---|
| GET / POST | `/prep-items` | 목록 · 생성 |
| PATCH / DELETE | `/prep-items/{prepRuleId}` | 수정 · 삭제(소프트) |

### 6.1 POST /prep-items

```json
{
  "ruleName": "영양제",
  "ruleCategory": "supplement",
  "actionType": "consume",
  "ruleTiming": "pre_departure",
  "defaultMinutes": null,
  "applyEventKind": null,
  "applyTimeBand": null,
  "applyPlaceId": null,
  "applyWeather": null,
  "isRequired": false,
  "isSensitive": false,
  "fromChip": true
}
```

| 필드 | 값 | 설명 |
|---|---|---|
| `ruleCategory` | `supplement` \| `medication` \| `personal_item` \| `routine` \| `general_item` | **구분** 축 |
| `actionType` | `carry` \| `consume` \| `purchase` \| `timed_routine` | **동작** 축 |
| `ruleTiming` | `pre_departure` \| `post_arrival` | 후자는 시간 계산에서 제외, 사후 카드에만 노출 |
| `defaultMinutes` | int \| null | **`timed_routine`일 때만 값 존재** — ERD `ck_prep_minutes`가 DB에서 강제 |
| `apply*` | null 또는 조건값 | **MVP는 전부 null(무조건 적용)만 지원.** 조건부 자동 적용은 P1 (PRD §25.2) |
| `isSensitive` | bool | true면 잠금화면·푸시에서 일반화 문구로 치환 (TR-10) |
| `fromChip` | bool | 추천 칩 선택 여부. 요청 검증에 쓰이고 `user_prep_rule.from_chip`에 **저장**됩니다 — PRD §24.2의 설정률·전환율 지표 원천 |

### 6.2 서버 검증 규칙

```
① defaultMinutes  actionType='timed_routine' ⟺ defaultMinutes IS NOT NULL
                  위반 → 422 VALIDATION_ERROR (ERD ck_prep_minutes 와 동일 규칙)

② 민감 항목 추천 금지 (TR-10 · PRD §1.1 위험 12)
                  fromChip=true ∧ isSensitive=true → 422 SENSITIVE_CHIP_REJECTED
                  담배·주류 등 민감·규제 품목은 추천 칩에 애초에 없으므로
                  이 조합은 클라이언트 오류로 간주한다

③ medication      ruleCategory='medication' → isSensitive 를 true 로 강제 세팅
```

> **온보딩 통합 (PRD §11.3):** 이 화면은 별도 온보딩 단계가 아니라 **준비 시간 입력 화면 내부 섹션**입니다. `PATCH /me/settings`(준비시간)와 `POST /prep-items`(맞춤 항목)는 같은 화면 제출 흐름에서 순차 호출되며, 항목 등록은 **선택 사항**이라 건너뛰어도 온보딩 완료를 막지 않습니다 (PRD 위험 11).

> **앱이 판단하지 않는 것 (절대 원칙 3 · TR-05):** 서버는 영양제·복용약·기호 품목의 **섭취 필요성·용량·효능·건강 영향을 판단하지 않습니다.** `USER_PREP_RULE`에 성분·용량·효능 필드가 없어 **판단할 데이터 자체가 없습니다.** 사용자가 등록한 항목을 일정 맥락에 맞춰 기억하고 확인하는 역할만 합니다.

---
## 7. 캘린더 연동 (CAL-02)

> **경로 갱신 (Issue #53):** BE 실제 구현은 Google 전용 단일 경로입니다.
> 이전 명세의 `/calendar/connections` (다중 provider 전제)는 폐기하고
> 아래 BE 실제 경로로 정렬합니다.

| Method | Path | 설명 |
|---|---|---|
| POST | `/calendar/google/connect` | Google 캘린더 연결 (body: `{ authCode }`) |
| DELETE | `/calendar/google` | Google 캘린더 연결 해제 |
| GET | `/calendar/google/status` | 연결 상태 조회 |
| POST | `/calendar/sync` | 수동 동기화 |

### 7.1 POST /calendar/google/connect

```json
// Request
{ "authCode": "google-server-auth-code" }

// Response 200
{
  "data": {
    "connected": true,
    "externalAccountId": "user@gmail.com",
    "connectedAt": "2026-08-10T…"
  }
}
```

Google serverAuthCode를 서버가 교환해 refresh token을 확보합니다.
FE는 캘린더 연동 전용 GoogleSignIn 인스턴스(`calendar.readonly` scope)에서
`serverAuthCode`를 획득해 전달합니다.

### 7.1.1 GET /calendar/google/status

```json
// Response 200
{
  "data": {
    "connected": true,
    "externalAccountId": "user@gmail.com",
    "connectedAt": "2026-08-10T09:00:00+09:00"
  }
}
```

- 미연결 상태는 `connected: false`이며 `externalAccountId`, `connectedAt`은 `null`입니다.
- `CalendarSyncScreen`은 bootstrap permission을 연결 여부로 추정하지 않고 이 endpoint를 사용합니다.

### 7.1.2 DELETE /calendar/google

연결 해제. 서버는 저장된 refresh token을 즉시 폐기합니다.

### 7.2 동기화 규약

- **읽기 전용.** Google Calendar. 로그인 IdP와 OAuth 동의 화면을 통합합니다
- 5~15분 폴링 + 수동 동기화. `externalEventId` + etag 기준 증분 반영
- 중복 방지: ERD `uq_event_external (calendar_source_id, external_event_id)`
- **`attendees`·`description`은 파싱 단계에서 폐기** — 저장 컬럼 자체가 없습니다 (절대 원칙 8)
- **제목도 저장하지 않습니다** — §8.3
- `refreshToken`은 `bytea refresh_token_enc`로 암호화 저장. 연결 해제 시 즉시 폐기
- 사용자가 지정한 `locationState`는 **동기화가 덮어쓰지 않습니다** (절대 원칙 5, TRD §13.1)

---

## 8. 일정 (CAL-01 · 03 · 04 · 05)

| Method | Path | 설명 |
|---|---|---|
| GET | `/events?from=&to=` | 기간 목록 + 계획 요약 |
| GET | `/events/next` | 다음 일정 + 활성 계획 |
| POST | `/events` | 생성 |
| GET / PATCH / DELETE | `/events/{eventId}` | 조회 · 수정 · 삭제 |
| POST | `/events/{eventId}/review` | 분류 확인 응답 |

### 8.1 POST /events

```json
{
  "startsAt": "2026-08-20T14:00:00+09:00",
  "endsAt": "2026-08-20T15:00:00+09:00",
  "locationState": "required_resolved",
  "destinationName": "강남역",
  "destinationLat": 37.498,
  "destinationLng": 127.027,
  "meetingUrl": null,
  "eventKind": "meeting",
  "sourceType": "map_search",
  "anchorMode": "arrive_by",
  "originPlaceId": "uuid",
  "selectedRouteOptionId": "uuid",
  "displayLabel": "강남역 미팅",
  "writeToCalendarSourceId": "uuid"
}
```

| 필드 | 값 | 설명 |
|---|---|---|
| `locationState` | `required_resolved` \| `required_missing` \| `not_required` \| `undecided` | 사용자 지정값이 **항상** 자동 분류보다 우선 (CAL-03, 절대 원칙 5) |
| `sourceType` | `internal` \| `external` \| `map_search` | |
| `anchorMode` | `arrive_by`(기본) \| `depart_at` | Plan Engine의 역산 방향 결정 (TRD §5.3) |
| `originPlaceId` · `selectedRouteOptionId` | uuid | `map_search` 저장 시 동봉 (CAL-05) |
| `displayLabel` · `writeToCalendarSourceId` | string · uuid | 표시명 처리 — §8.3 |
| `endsAt` | ISO-8601 instant, nullable | 생략 가능. 없으면 종료 시각 없는 일정으로 저장되고 응답은 `null` |

`anchorMode`는 API 전용 필드입니다. ERD `PLAN_REVISION`에는 이 값 대신 계산 결과가 남으므로, 서버는 계획 생성 시점에만 사용합니다.

### 8.2 응답과 계획 자동 생성

```json
{
  "data": {
    "eventId": "uuid",
    "displayName": "강남역 미팅",
    "startsAt": "2026-08-20T14:00:00+09:00",
    "timezone": "Asia/Seoul",
    "locationState": "required_resolved",
    "status": "planned",
    "autoManageExcluded": false,
    "plan": { "planId": "uuid", "revisionNo": 1, "…": "§9 참조" }
  }
}
```

`locationState`가 `required_resolved`면 **저장과 동시에 계획이 생성**되어 응답에 동봉됩니다 (PRD §12.5 "최종 일정 시각을 기준으로 준비와 웰니스 계획을 생성"). `not_required`면 `plan`은 `null`입니다.

### 8.3 표시명 처리 규약

`EVENT`는 외부 캘린더 제목 원문을 보관하지 않습니다(절대 원칙 8). 대신 **사용자가 입력·승인한 표시명만** `EVENT.display_label`에 저장합니다.

```
요청  displayLabel              사용자가 입력한 표시명 (nullable)
      writeToCalendarSourceId   외부 캘린더에도 기록할지 (nullable, isWritable=true 인 것만)

서버 동작
  displayLabel 이 있으면          → EVENT.display_label 에 저장
  writeToCalendarSourceId 지정 시 → 외부 캘린더에도 같은 제목으로 기록
  외부 동기화로 들어온 제목        → 분류 입력으로만 쓰고 즉시 폐기. display_label 에 넣지 않는다

응답  displayName   항상 채워진다. 해석 순서:
                    displayLabel → destinationName → "오후 2시 일정"
```

두 대상은 다릅니다. 절대 원칙 8이 막으려는 것은 **사용자가 통제하지 않은 외부 원문의 축적**이지, 사용자가 직접 붙인 이름이 아닙니다. 내부 생성 일정(`sourceType='internal'`)은 외부 캘린더가 없으므로 `displayLabel`이 유일한 이름입니다.

클라이언트는 **`displayName` 하나만 읽으면 됩니다.**

### 8.4 POST /events/{eventId}/review (CAL-04)

```json
// Request
{ "questionType": "is_online", "userAnswer": "offline" }
// Response
{ "data": { "eventId": "uuid", "locationState": "required_missing", "reviewClosed": true } }
```

- `classificationConfidence < 0.70`(TRD 부록 A `CLASSIFY_MIN_CONF`)일 때만 클라이언트가 이 질문을 노출합니다
- **일정 제목은 영구 저장되지 않습니다.** 분류 시점에만 `EVENT_CLASSIFICATION_REVIEW.title_snapshot`에 담기고, **응답 트랜잭션 안에서 즉시 NULL 처리**됩니다 (ERD `ck_title_purged`)
- 미응답 24시간 경과 시 배치가 원문만 자동 폐기하고 질문은 유지합니다 (TR-12). 사용자가 나중에 답해도 장소 필요 여부만 확정하면 되므로 제목이 필요 없습니다

---

## 9. 계획 (PLAN-01~05)

| Method | Path | 설명 |
|---|---|---|
| GET | `/plans/{planId}` | 계획 상세 |
| GET | `/events/{eventId}/plans/latest` | 활성 리비전 (`planStatus='active'`) |
| POST | `/events/{eventId}/plan/recalculate` | 강제 재계산 |
| PATCH | `/plans/{planId}` | 사용자 직접 수정 (출발지·시각) |

### 9.1 GET /plans/{planId}

```json
{
  "data": {
    "planId": "uuid",
    "eventId": "uuid",
    "revisionNo": 3,
    "calcVersion": "3.1.0",
    "planStatus": "active",
    "eventStatus": "notified",
    "feasible": true,
    "predictionConfidence": "high",

    "prepStartAt":         "2026-08-16T12:25:00+09:00",
    "recommendedDepartAt": "2026-08-16T13:10:00+09:00",
    "targetArriveAt":      "2026-08-16T13:50:00+09:00",

    "breakdown": {
      "estimatedPrepMinutes":   35,
      "extraPrepMinutes":        5,
      "personalRoutineMinutes": 10,
      "travelMinutes":          42,
      "trafficBufferMinutes":    7,
      "arrivalBufferMinutes":   10
    },

    "reasons": [
      { "field": "estimatedPrepMinutes", "source": "estimate", "adjusted": true,
        "text": "최근 8회 기록 기준, 초기 설정보다 +5분", "sampleCount": 8 },
      { "field": "personalRoutineMinutes", "source": "prepRule", "adjusted": false,
        "text": "렌즈·화장 (등록한 루틴)" },
      { "field": "travelMinutes", "source": "routeProvider", "adjusted": false,
        "text": "외부 지도 API 기준" },
      { "field": "extraPrepMinutes", "source": "environment", "adjusted": false,
        "text": "출발 시간 강수 확률 70%" }
    ],

    "checklist": [
      { "planPrepItemId": "uuid", "itemName": "영양제", "actionType": "consume",
        "sourceType": "rule", "completionStatus": "pending", "isSensitive": false,
        "appliedMinutes": 0 },
      { "planPrepItemId": "uuid", "itemName": "선크림", "actionType": "carry",
        "sourceType": "rule", "completionStatus": "pending", "isSensitive": false,
        "appliedMinutes": 0, "reason": "자외선 높음 · 야외 45분" },
      { "planPrepItemId": "uuid", "itemName": "렌즈·화장", "actionType": "timed_routine",
        "sourceType": "rule", "completionStatus": "pending", "isSensitive": false,
        "appliedMinutes": 10 }
    ],

    "wellnessActions": [
      { "wellnessActionId": "uuid", "wellnessTopic": "uv", "actionCode": "sunscreen",
        "actionLabel": "출발 전 선크림 확인", "displayRank": 1,
        "reasonSnapshot": "자외선 높음 · 예상 야외 이동 45분", "completionStatus": "proposed" },
      { "wellnessActionId": "uuid", "wellnessTopic": "hydration", "actionCode": "hydration",
        "actionLabel": "물 챙기기", "displayRank": 2,
        "reasonSnapshot": "체감온도 31℃", "completionStatus": "proposed" }
    ],

    "wellness": {
      "wisScore": 72, "wisBand": "high", "weightVersion": "w1",
      "eventArmed": true
    },

    "context": {
      "uvIndex": 8, "pm10": 45, "pm25": 22,
      "feelsLike": 31.2, "precipitationProb": 70,
      "estimatedOutdoorMinutes": 45,
      "weatherProvider": "kma", "airProvider": "airkorea",
      "observedAt": "2026-08-16T12:00:00+09:00"
    },

    "selectedRouteOptionId": "uuid",
    "degraded": []
  }
}
```

### 9.2 응답 필드 규약

| 규약 | 내용 |
|---|---|
| **`planStatus` ≠ `eventStatus`** | `planStatus`는 리비전 관리(`active`/`superseded`), `eventStatus`는 일정 생명주기(`planned`→`notified`→`preparing`→`enroute`→`arrived`→`closed`). **다른 축입니다** (TRD §4.3) |
| **`breakdown`은 정규 필드** | ERD `PLAN_REVISION`의 분해 컬럼과 1:1. JSONB가 아니므로 조인 없이 나옵니다 |
| **`reasons`·`checklist`·`wellnessActions`는 정렬하지 않음** | `source`·`sourceType`·`displayRank` 태그만 실어 보내고 화면 순서는 클라이언트가 정합니다 — 시점별 우선순위(준비 전·출발 임박·이동 중)가 다르고, 그 판단은 화면 맥락을 아는 쪽이 합니다 |
| **`checklist`와 `wellnessActions`는 별도 배열** | ERD상 `PLAN_PREP_ITEM`과 `PLAN_WELLNESS_ACTION`은 다른 테이블이고 응답 기록 경로도 다릅니다(§12.2) |
| **`isSensitive: true`** | 잠금화면·푸시에서 `NOTIFICATION.body_masked`의 일반화 문구로 치환 (TR-10) |
| **`degraded`** | 외부 API 실패 등으로 저하된 항목 목록. 빈 배열이면 정상 |

`degraded` 값 예시: `route_stale`(마지막 성공 경로 재사용) · `env_unavailable`(웰니스 생략) · `seed_missing`(시드 없어 기본값 사용) · `walk_speed_default`.

### 9.3 계산 파이프라인 (참고 — TRD §5.3)

```
① targetArriveAt        = event.startsAt − arrivalBufferMinutes
② recommendedDepartAt   = targetArriveAt − travelMinutes − trafficBufferMinutes
③ prepStartAt           = recommendedDepartAt
                            − estimatedPrepMinutes      (USER_PREP_ESTIMATE)
                            − extraPrepMinutes          (환경 가산)
                            − personalRoutineMinutes    (Σ timed_routine)
④ 제약 해결 → 충돌 시 feasible=false (제약을 깨지 않는다, TR-04)
⑤ 체크리스트 초안 생성

anchorMode='depart_at' 이면 ②를 고정하고 ①을 정방향 계산한다.
```

**체크리스트 병합 (PLAN-05):** 사용자 등록 항목과 웰니스 제안이 같은 대상이면(예: 둘 다 선크림) `PLAN_PREP_ITEM` 1건으로 합치고 `sourceType='rule'`을 유지한 채 근거만 웰니스 것을 붙입니다. 노출 상한은 맞춤 3개 + 웰니스 3개(ERD `ck_wellness_rank`가 후자를 DB에서 강제).

### 9.4 POST /events/{eventId}/plan/recalculate

```json
// Request
{ "reason": "user_request" }
// Response — 변화가 없으면 기존 리비전을 그대로 반환
{ "data": { "revisionNo": 3, "changed": false, "…": "§9.1" } }
```

- 입력이 동일하면(`inputHash` 일치) 새 리비전을 만들지 않고 `changed: false`로 반환합니다 — 외부 API 호출 0회 (TRD §5.5)
- 재계산 결과가 출발 시각을 **2분 미만** 바꾸면 리비전조차 만들지 않습니다 (TRD §8.3)

### 9.5 PATCH /plans/{planId} (PLAN-04)

```json
{ "originPlaceId": "uuid", "prepStartAt": "2026-08-16T12:10:00+09:00" }
```

사용자 수정은 **새 리비전을 만듭니다.** 이전 리비전은 `planStatus='superseded'`로 남아 감사·재현이 가능합니다.

---

## 10. 경로 (MAP-01~04)

| Method | Path | 설명 |
|---|---|---|
| GET | `/plans/{planId}/routes` | 경로 후보 3종 |
| POST | `/plans/{planId}/routes/select` | 선택 (재계산 동반) |
| GET | `/routes/search` | 계획 없이 검색 (지도 화면 · CAL-05 진입점) |

### 10.1 GET /plans/{planId}/routes

```json
{
  "data": [
    { "routeOptionId": "uuid", "routeRank": 1, "routeType": "fastest",
      "totalMinutes": 42, "walkMinutes": 11, "transferCount": 1,
      "departAt": "2026-08-16T13:10:00+09:00", "arriveAt": "2026-08-16T13:52:00+09:00" },
    { "routeOptionId": "uuid", "routeRank": 2, "routeType": "least_walk",
      "totalMinutes": 47, "walkMinutes": 4, "transferCount": 2,
      "departAt": "…", "arriveAt": "…" },
    { "routeOptionId": "uuid", "routeRank": 3, "routeType": "least_transfer",
      "totalMinutes": 51, "walkMinutes": 9, "transferCount": 0,
      "departAt": "…", "arriveAt": "…" }
  ]
}
```

- **단위는 분**입니다 (ERD `ROUTE_OPTION.total_minutes` / `walk_minutes`). v3.0의 초 단위 표기는 폐기했습니다
- MVP는 이 3종만 제공합니다. 고급 시각화·환경 레이어는 응답에 **없습니다** (절대 원칙 7, MAP-04)
- `routePayload`(폴리라인 등)는 계획 단위로만 보관하며 목록 응답에 싣지 않습니다

> **`walkMinutes`가 웰니스 엔진의 핵심 입력입니다.** 도보 구간 합이 `PLAN_CONTEXT.estimated_outdoor_minutes`로 파생되어 WIS의 O항이 됩니다(§12.1). 다만 **지하 환승 통로를 야외로 계산하면 WIS가 과대평가**되므로, 서버는 ODsay `subPath`를 순회해 지상 도보만 집계합니다.
>
> ```
> trafficType = 3 (도보)                          → 야외 후보
>   직전·직후가 지하철(trafficType = 1) 이고
>   구간이 3분 미만                                → 환승 통로로 보고 제외
>   그 외                                          → estimatedOutdoorMinutes 에 가산
> 버스(trafficType = 2) 승하차 도보는 지상으로 간주
> ```
>
> 판별이 불가능한 구간은 **야외로 계산하지 않고** `degraded`에 남깁니다 — 과대평가가 과소평가보다 해롭습니다(불필요한 알림이 나갑니다).

### 10.2 POST /plans/{planId}/routes/select (MAP-04)

```json
// Request
{ "routeOptionId": "uuid" }
// Response — 재계산된 새 리비전
{ "data": { "revisionNo": 4, "recommendedDepartAt": "…", "…": "§9.1" } }
```

경로를 바꾸면 출발·도착 시각과 웰니스 점수가 함께 재계산됩니다.

### 10.3 GET /routes/search (CAL-05 진입점)

```
GET /routes/search?originPlaceId=&originLat=&originLng=
                  &destLat=&destLng=&destName=
                  &anchorMode=arrive_by&at=2026-08-20T14:00:00%2B09:00
```

지도 화면에서 일정 없이 검색할 때 씁니다. 응답은 §10.1과 동일한 형태이되 `routeOptionId`는 **임시 키**(TTL 30분)이며, `POST /events`에 `selectedRouteOptionId`로 전달하면 계획 생성 시점에 `ROUTE_OPTION` 행으로 확정됩니다. 지도 렌더는 카카오맵 SDK가 담당하고 경로 데이터는 이 엔드포인트만 사용합니다 — 두 제공자를 섞지 않습니다.

---
## 11. 알림 (NOTI-01~05)

| Method | Path | 설명 |
|---|---|---|
| GET | `/notifications/today` | 당일 알림 로그 (시간 + 웰니스 통합) |
| POST | `/notifications/{notificationId}/respond` | 알림 액션 응답 |

### 11.1 GET /notifications/today (NOTI-05)

```json
{
  "data": [
    { "notificationId": "uuid", "notificationCategory": "time", "notificationType": "relaxed",
      "slot": "A", "scheduledAt": "…", "sentAt": "2026-08-16T12:20:00+09:00",
      "deliveryStatus": "delivered",
      "body": "20분 뒤 준비를 시작할 예정입니다.",
      "triggerReason": "준비 시작 20분 전",
      "reaction": "prep_started" },

    { "notificationId": "uuid", "notificationCategory": "time", "notificationType": "disruption",
      "slot": "C", "sentAt": "2026-08-16T12:43:00+09:00",
      "body": "지하철 지연으로 출발 권장 시각이 7분 빨라졌습니다.",
      "triggerReason": "교통 지연 +8분",
      "reaction": null },

    { "notificationId": "uuid", "notificationCategory": "wellness", "notificationType": "wellness_event",
      "slot": "W", "sentAt": "2026-08-16T14:30:00+09:00",
      "body": "야외 이동이 계속되고 있어요. 설정한 시간이 지났다면 선크림을 다시 확인해 보세요.",
      "triggerReason": "자외선 높음 · 설정 주기 120분 도달",
      "reaction": "completed" }
  ]
}
```

- `triggerReason`은 **알림 로그 표시 전용**입니다 (ERD `NOTIFICATION.trigger_reason`, PRD §10.2 "발생 이유")
- `notificationCategory`와 `notificationType`의 정합성은 ERD `ck_noti_category` CHECK가 강제합니다 — `wellness_event`는 반드시 `wellness` 카테고리
- **민감 준비 항목은 `body_masked`의 일반화 문구로 저장·노출**됩니다 (TR-10)

### 11.2 알림 예산 (TRD §8.1 · 절대 원칙 6)

| 슬롯 | 카테고리 | `notificationType` | 예산 |
|---|---|---|---|
| **A** | time | `relaxed` 여유 | 일정당 1 |
| **B** | time | `critical` 극한 | 일정당 1 |
| **C** | time | `disruption` 돌발 | 일정당 1 — **최신 1건만 유지(교체)** |
| **W** | wellness | `wellness_event` | 일정당 1(`sequenceNo`) **＋ 항목별 일일 상한**(`dailyEventCap`) |

```
실질 변화 판정 (TRD §8.3)
  Δ < 2분        리비전조차 만들지 않음
  2 ≤ Δ < 5분    리비전 갱신 · 홈 반영 · 푸시 없음 (로그에만)
  Δ ≥ 5분        돌발 슬롯 사용

즉시 알림 예외  feasible true→false · 경로 수단 변경 · 강수 none→heavy
상태 입력 시    남은 슬롯 전부 소각
자동 보정으로 준비 시각이 당겨진 사실 자체는 푸시하지 않는다 — 홈·로그에서만 확인
```

### 11.3 멱등성

```
dedupKey = sha1(eventId + ":" + slot + ":" + revisionNo)
collapseKey = eventId + ":" + slot      // FCM. 트레이에 항상 최신 1건만
```

`NOTIFICATION.dedup_key` UNIQUE 제약으로 중복 발송을 **구조적으로** 차단합니다. 발송 순서는 아웃박스입니다 — INSERT → 커밋 → FCM 전송 → `sentAt` 갱신. INSERT 실패는 "이미 발송됨"이므로 스킵하고, FCM 실패는 행은 있고 `sentAt`이 NULL이므로 재시도 대상이 됩니다.

### 11.4 POST /notifications/{notificationId}/respond

```json
// 시간 알림
{ "action": "prep_started", "clientEventId": "uuid", "deviceTs": "…" }
// → EVENT_ACTION_LOG 로 기록 (§13)

// 웰니스 이벤트 알림
{ "action": "completed", "userRating": "useful", "clientEventId": "uuid" }
// action: completed | snoozed | stop_today | ignored
// → WELLNESS_EVENT_SCHEDULE.response_action / user_rating 갱신
```

**같은 엔드포인트지만 기록되는 테이블이 다릅니다.** 서버가 `notificationCategory`로 분기합니다.

### 11.5 로컬 알림 이중화 (TR-07)

FCM은 전송 시각을 보장하지 않으므로, 클라이언트가 **준비 시작·출발 임박 2건을 로컬 알림으로 미리 예약**하고 서버 푸시가 먼저 오면 로컬을 취소합니다.

```
클라이언트는 계획 응답의 prepStartAt / recommendedDepartAt 만으로 로컬 예약을 구성한다.
중복 방지 키: dedupKey 를 로컬 알림 식별자로 그대로 사용
서버 ack 엔드포인트는 두지 않는다 — 로컬 알림은 클라이언트 내부 관심사이며,
  실제 행동은 §13의 액션 기록으로 이미 서버에 도달한다
```

> ack 엔드포인트를 두지 않는 이유는, 오프라인에서 로컬 알림이 떴을 때 ack만 큐에 쌓이고 정작 행동 기록과 순서가 어긋나기 때문입니다. 사용자가 실제로 무엇을 했는지는 §13의 액션 기록이 이미 담고 있으므로 별도 신호가 필요 없습니다.

---

## 12. 웰니스 (WELL-01~06)

### 12.1 점수 — 계획 응답에 포함

별도 점수 조회 엔드포인트를 두지 않습니다. WIS는 항상 계획과 함께 조회됩니다(§9.1의 `wellness`·`context`).

```
WIS = min(100, 100 × (0.35·U + 0.25·P + 0.20·T + 0.20·O) × M)
```

| 항 | 원천 | 정규화 |
|---|---|---|
| U | 자외선지수 (`PLAN_CONTEXT.uv_index`) | 0→0 · 6→0.6 · 8→0.8 · 11+→1.0 |
| P | 대기질 (`pm10`/`pm25`) | 좋음 0 · 보통 0.25 · 나쁨 0.7 · 매우나쁨 1.0 |
| T | 체감온도·강수 (`feels_like`/`precipitation_prob`) | 쾌적(5~28℃) 0 → 폭염·한파 1.0 |
| O | 야외 노출 (`estimated_outdoor_minutes`) | `min(1, 분/120)` — 상한 120분 |
| M | 관심 항목 보정 (`USER_WELLNESS_PREF`) | 1.0 ~ 1.25 |

| `wisBand` | `wisScore` | 동작 |
|---|---|---|
| `low` | 0~39 | 일정 상세에만 표시. 푸시 없음 |
| `mid` | 40~69 | 외출 전 준비 카드에 행동 1~2개 |
| `high` | 70~100 | 행동 제안 + 동의 시 웰니스 이벤트 알림 후보 생성 |

밴드와 점수의 정합성은 ERD `ck_wis_band` CHECK가 강제합니다. 가중치·구간은 **원격 설정**이며 `weightVersion`으로 버전을 남깁니다(TR-06) — 값이 바뀌어도 **API 계약은 그대로**입니다. 가중치를 바꿔도 과거 계획을 소급 재계산하지 않고 버전별로 분리 집계합니다.

> **WIS는 의료 위험도나 피부 상태 점수가 아니라 알림 우선순위 값입니다** (PRD §8.7, ERD `score_purpose='priority_only'`, 절대 원칙 3).

### 12.2 행동 응답 기록 — 두 경로

| Method | Path | 대상 테이블 | 요구사항 |
|---|---|---|---|
| POST | `/plans/{planId}/prep-items/{planPrepItemId}/resolve` | `PLAN_PREP_ITEM.completion_status` | PLAN-05 |
| POST | `/plans/{planId}/wellness-actions/{wellnessActionId}/resolve` | `PLAN_WELLNESS_ACTION.completion_status` | WELL-03, REPORT-02 |

```json
// 준비 항목
{ "completionStatus": "completed", "clientEventId": "uuid" }   // pending | completed

// 웰니스 행동
{ "completionStatus": "completed", "clientEventId": "uuid" }   // proposed | completed | dismissed
```

**두 경로를 분리한 이유:** ERD상 다른 테이블이고 상태 enum도 다릅니다(`pending|completed` vs `proposed|completed|dismissed`). 지표 산출의 분모도 달라집니다 — 맞춤 항목 체크 완료율과 웰니스 행동 완료율은 PRD §24.4에서 별개 지표입니다.

### 12.3 웰니스 이벤트 발사 조건 — 6중 게이트 (TR-11)

전부 AND입니다. 하나라도 실패하면 알림이 생성되지 않습니다.

| # | 게이트 | 근거 |
|---|---|---|
| 1 | `USER_SETTING.wellnessEventEnabled` ∧ `USER_WELLNESS_PREF.isEnabled` | 사용자 동의. **둘 다 기본값 false — opt-in** |
| 2 | `wisScore ≥ 70` (`WELLNESS_EVENT_MIN`) | PRD §14.3 구간표 |
| 3 | 야외 노출이 계속 진행 중 (실내 전환 추정 시 취소) | PRD §12.7 |
| 4 | `remindIntervalMinutes` 도달 — **사용자가 설정한 값** | PRD §14.7 |
| 5 | 같은 일정·같은 `actionCode`에 `completed`/`stop_today` 없음 | ERD `uq_wellness_event_once` |
| 6 | **`dailyEventCap` 미소진** (항목별 하루 상한, 기본 1) | ERD `USER_WELLNESS_PREF.daily_event_cap` |

**5번과 6번은 다른 상한입니다.** 5번은 일정당(`sequenceNo`), 6번은 하루당. 야외 일정이 하루 3건이어도 같은 항목으로 3번 알리지 않습니다.

```
취소   WELLNESS_EVENT_SCHEDULE.cancelled_at + cancel_reason
       (indoor | plan_changed | user_completed)
백오프 stop_today  → 당일 해당 actionCode 전체 중단
       ignored 2회 연속 → dailyEventCap 을 0 으로. 설정에서 다시 켤 수 있다 (PRD §14.7)
집계   항목별 해제율 ≥ 30% 또는 userRating='not_relevant' ≥ 25%
       → 해당 actionCode 의 WIS 임계를 70 → 85 로 자동 상향 (원격 설정)
스냅샷 interval_minutes_snapshot 에 발사 시점 사용자 설정을 복사 (사후 분석용)
```

> **의료·소비 판단 경계 (절대 원칙 3 · TR-05 · TR-09):** 서버는 SPF·피부 타입·제품 성능·복용량·효능을 **절대 판단하지 않습니다.** 알림 문구는 사전 승인된 템플릿(PRD 부록 B.4)에서만 나오며, **자유 생성 LLM을 이 경로에 쓰지 않습니다.** 템플릿 외 문자열이 렌더 경로에 유입되는지는 CI가 검사합니다(TRD §17.5).

### 12.4 일일 마무리 카드 (WELL-05)

| Method | Path | 설명 |
|---|---|---|
| GET | `/summary/daily?date=` | 하루 요약 카드 |
| POST | `/summary/daily/{summaryId}/viewed` | 조회 기록 (지표) |

```json
{
  "data": {
    "summaryId": "uuid",
    "summaryDate": "2026-08-16",
    "eventCount": 3,
    "totalOutdoorMinutes": 43,
    "outdoorSource": "estimated",
    "dwlBand": "mid",
    "dwlScore": 58,
    "cardScenario": "exposure",
    "message": "자외선이 높은 시간대의 예상 야외 이동이 길었어요. 지금은 수분을 보충하고 편안하게 쉬어주세요.",
    "isViewed": false
  }
}
```

```
DWL = 0.6 × (일정별 WIS의 야외시간 가중평균) + 0.4 × (일정별 RLS 평균)
cardScenario 우선순위: rushed > density > exposure > stable > default
```

- **`dwlBand`만 노출합니다.** `dwlScore`는 응답에 포함하되 클라이언트는 표시하지 않습니다 — 점수 노출은 건강 점수로 오해될 여지를 만듭니다(절대 원칙 3). 내부 분석·A/B 용도로만 씁니다
- `outdoorSource`: `estimated`(계획 기준) \| `observed`(실측). PRD §14.5가 요구하는 **"예상/계획 기준" 표기의 근거**입니다 — 추정치를 관측치처럼 보여주지 않습니다
- 관리 일정 0건이면 카드를 생성하지 않습니다(`404`). **숫자를 지어내지 않습니다**
- 민감 준비 항목·복용약은 요약 생성 입력에서 **원천 배제** (PRD §14.8, TR-10 집계 경계)
- 렌더된 문장은 `card_message_snapshot`에 보존됩니다 — 사후에 "어떤 문구가 실제로 나갔는지" 확인할 수 있어야 콘텐츠 검토가 성립합니다

---

## 13. 행동 기록 (REPORT-01)

| Method | Path | 설명 |
|---|---|---|
| POST | `/plans/{planId}/actions` | **행동 이벤트 배치.** 오프라인 큐의 최종 도착지 |

```json
// Request — 배치 최대 100건
{
  "actions": [
    { "actionType": "prep_started", "actionSource": "user",
      "deviceTs": "2026-08-16T12:31:00+09:00", "clientEventId": "uuid" },
    { "actionType": "departed", "actionSource": "geo",
      "deviceTs": "2026-08-16T13:14:00+09:00", "clientEventId": "uuid",
      "confidence": 0.78 }
  ]
}

// Response — 갱신된 계획을 함께 반환
{
  "data": {
    "accepted": 2,
    "duplicated": 0,
    "eventStatus": "enroute",
    "plan": { "revisionNo": 4, "…": "§9.1" }
  }
}
```

| 필드 | 값 |
|---|---|
| `actionType` | `prep_started` \| `snoozed` \| `departed` \| `item_checked` \| `excluded` — ERD `EVENT_ACTION_LOG.action_type` |
| `actionSource` | `user` \| `geo` \| `system` |
| `clientEventId` | UUID. `(userId, clientEventId)` UNIQUE로 오프라인 재전송 흡수 (TR-03) |

**v3.0에서 잘못 포함됐던 것들**

| v3.0의 `type` | 실제 위치 |
|---|---|
| `arrived` | **`EVENT_EXECUTION.actual_arrived_at`** — §14.1로 기록 |
| `wellness_done` / `wellness_later` / `wellness_stop` | **`WELLNESS_EVENT_SCHEDULE.response_action`** — §11.4로 기록 |
| `checklist_done` | `item_checked`로 표기하고 §12.2가 상태를 갱신 |
| `plan_edited` | `PATCH /plans/{id}`(§9.5)가 리비전을 남기므로 별도 액션 불필요 |

**규약**

- 응답에 **갱신된 계획을 동봉**해 왕복을 줄입니다. 지하에서 재연결된 순간의 요청이 한 번에 끝나야 합니다
- `duplicated`는 오류가 아니라 정상 결과입니다 (TR-03)
- **지오펜스 판정도 이 엔드포인트로 들어옵니다**(`actionSource: "geo"`). **좌표는 전송하지 않고** 판정 결과(`actionType`, `confidence`)만 보냅니다 (절대 원칙 8)
- 서버는 `deviceTs`와 수신 시각 차이가 ±120초를 넘으면 `clockSkew` 플래그를 붙여 **개인화 학습에서 제외**합니다 (TR-02)

---

## 14. 결과 · 피드백 · 지연 사유 (REPORT-01)

| Method | Path | 설명 | 요구사항 |
|---|---|---|---|
| GET | `/events/{eventId}/execution` | 실행 결과 조회 | REPORT-01 |
| POST | `/events/{eventId}/feedback` | 사후 평가 | REPORT-01 |

### 14.1 GET /events/{eventId}/execution

```json
{
  "data": {
    "eventId": "uuid",
    "finalPlanId": "uuid",
    "actualPrepStartedAt": "2026-08-16T12:31:00+09:00",
    "actualDepartedAt":    "2026-08-16T13:14:00+09:00",
    "actualArrivedAt":     "2026-08-16T13:55:00+09:00",
    "arrivalResult": "on_time",
    "resultSource": "geo",
    "actualOutdoorMinutes": 47,
    "rushLoadScore": 22,
    "delayReasons": [
      { "reasonCode": "prep_late", "reasonSource": "inferred", "confidence": 0.72 }
    ]
  }
}
```

- `arrivalResult`: `early` \| `on_time` \| `rushed` \| `late` \| `unknown` — ERD
- `rushLoadScore`는 **운영 지표 전용**입니다. 사용자의 스트레스나 정신건강을 측정하지 않습니다 (PRD §14.4, 절대 원칙 3)
- `delayReasons`는 복수 기록 가능합니다(ERD 복합 PK). 보정은 `confidence` 최고값 하나만 라우팅합니다 (TR-06)

### 14.2 POST /events/{eventId}/feedback

```json
{
  "prepTimingAssessment": "too_early",
  "arrivalResult": "on_time",
  "rushAssessment": "not_rushed"
}
```

| 필드 | 값 | 쓰임 |
|---|---|---|
| `prepTimingAssessment` | `too_early` \| `appropriate` \| `too_late` \| `unknown` | 알림 시점 보정 (TRD §6.2) |
| `rushAssessment` | 사용자 촉박 자기평가 | **북극성 지표의 입력** (PRD §24.1·§24.3) |

- `EVENT_FEEDBACK`은 `event_id` PK이므로 **일정당 1건**입니다. 재제출은 갱신입니다
- **판단 데이터가 충분하면 이 UI를 띄우지 않습니다.** 지오펜스 `confidence ≥ 0.6`이면 도착이 이미 확정되었으므로 질문은 보완 수단일 뿐입니다 (PRD §12.10)

---

## 15. 개인화 (MODEL-01 · 02)

| Method | Path | 설명 |
|---|---|---|
| GET | `/me/personalization` | 현재 추정값 조회 |
| POST | `/me/personalization/revert` | 직전 보정 되돌리기 + 표본 영구 제외 |
| DELETE | `/me/personalization` | 초기화 (행동 로그는 유지) |

### 15.1 GET /me/personalization

```json
{
  "data": {
    "estimates": [
      { "scopeType": "global", "scopeValue": null, "estimatedMinutes": 35,
        "sampleCount": 8, "confidence": 0.71, "modelVersion": "m1",
        "adjustmentReason": "저녁 약속에서 평균 12분 늦게 출발",
        "validFrom": "2026-08-10T…" }
    ],
    "trafficBufferMinutes": 7,
    "notificationLeadMinutes": 20
  }
}
```

- `scopeType`: `global` \| `event_kind` \| `weather` \| `origin_place` \| `time_band` — MODEL-02를 ERD가 이미 수용합니다. **MVP는 `global`만 사용**합니다
- 조회 우선순위(좁은 것부터): `(eventKind, timeBand)` → `eventKind` → `weather` → `originPlace` → `global`
- `adjustmentReason`은 PRD §8.5가 요구하는 "왜 보정됐는지" 문장이며 `user_prep_estimate.adjustment_reason`에 저장됩니다

### 15.2 원인 분리 보정 (TR-06)

```
P_new = (1 − α)·P_old + α·D_actual                α = 0.30
arrivalResult ∈ {late, rushed}  → α ×1.5     실패가 더 강한 신호
arrivalResult = 'early'         → α ×0.7     줄이는 방향은 신중히
가드레일  P ∈ [10분, 시드×2] · 1회 변화 ≤ 15분
콜드 스타트  sampleCount < 3 → 시드 유지. 첫 명확한 실패만 1회 보정(상한 20분)

손잡이 라우팅 — 하나의 관측은 하나만 조정한다
  prep_overrun → estimatedMinutes      prep_late  → notificationLeadMinutes
  depart_late  → notificationLeadMinutes   traffic → trafficBufferMinutes
  external     → 학습 제외
```

교통 지연으로 늦은 날에 "개인 준비 시간"이 늘어나는 **오귀속을 막는 것**이 이 설계의 목적입니다. 클라이언트는 `reasons[].source`(`estimate`/`prepRule`/`routeProvider`/`environment`)로 어떤 값이 어떤 근거로 조정됐는지 항상 구분해 받습니다.

### 15.3 POST /me/personalization/revert

```json
{ "eventId": "uuid" }
```

값 복원에 그치지 않고 **해당 표본을 학습에서 영구 제외**합니다. 그러지 않으면 다음 틱에서 같은 보정이 재발하고 사용자는 무시당했다고 느낍니다. 되돌림률은 가드레일 지표입니다 (PRD §24.6).

---

## 16. 계정 관리 (S-16 · S-25~S-31 · S-14E)

08.20 화면연결 명세에서 추가된 계정·북마크·행동 기록 관련 API입니다.

### 16.1 닉네임 변경·중복확인

```json
// PATCH /me/nickname
{ "nickname": "새닉네임" }
// Response 200
{ "data": { "nickname": "새닉네임" } }

// GET /auth/check-nickname?value=테스트
// Response 200
{ "data": { "available": true } }
```

- 닉네임 2~12자, 특수문자(`!@#$%^&*`) 불가
- 중복확인은 인증 없이 호출 가능 (`/auth/*` 허용)

### 16.2 이메일 변경

```json
// POST /me/email/change-request
{ "newEmail": "new@example.com", "password": "현재비밀번호" }
// Response 202 — 새 이메일로 인증 토큰 발송

// POST /me/email/change-confirm
{ "token": "원문 토큰" }
// Response 204 — User.email + UserIdentity.providerUid 갱신
```

- 현재 비밀번호 검증 후 발송 (Google 전용 계정은 호출 불가)
- 기존 이메일은 인증 완료 전까지 유지
- 토큰 30분 TTL, SHA-256 해시 저장

### 16.3 로그인 수단 관리

```json
// GET /me/providers
// Response 200
{ "data": [{ "identityId": "uuid", "provider": "email", "linkedAt": "2026-..." }, ...] }

// POST /me/providers
{ "provider": "google", "providerToken": "Google idToken" }
// Response 201

// DELETE /me/providers/{identityId}
// Response 204
```

- active identity가 1개만 남으면 해제 거부 (`400 LAST_PROVIDER`)
- Google 연결 시 idToken 검증으로 providerUid 추출

### 16.4 세션(로그인 기록) 관리

```json
// GET /me/sessions
// Response 200
{ "data": [{ "refreshTokenId": "uuid", "issuedAt": "2026-...", "isCurrent": true }, ...] }

// DELETE /me/sessions/{id}
// Response 204

// DELETE /me/sessions   — 현재 기기 제외 전체 무효화
// Response 204
```

- `isCurrent`는 요청의 Bearer 토큰에서 추출
- 현재 기기 세션은 삭제 불가 (`400 CANNOT_REVOKE_CURRENT`)

### 16.5 북마크

```json
// GET /me/bookmarks(?folder=자주가는곳)
// Response 200
{ "data": [{ "bookmarkId": "uuid", "placeName": "강남역", "lat": 37.4979, "lng": 127.0276, "folder": "자주가는곳", "createdAt": "2026-..." }] }

// POST /me/bookmarks
{ "placeName": "강남역", "lat": 37.4979, "lng": 127.0276, "folder": "자주가는곳" }
// Response 201

// DELETE /me/bookmarks/{bookmarkId}
// Response 204
```

- `folder`는 선택. null이면 기본 폴더
- UserPlace(주요 장소)와 별개 도메인

### 16.6 행동 기록 삭제

```json
// DELETE /me/action-logs
// Response 204
```

- 사용자 소유 `EVENT_ACTION_LOG` 전체 삭제
- `USER_PREP_ESTIMATE`(개인화 모델)는 유지 — 개인화 초기화는 `DELETE /me/personalization` (§15.3)

---

## 17. 데이터 삭제 · 계정 수명주기 (DATA-01 · 02 · AUTH-04)

| 전이 | API | 처리 |
|---|---|---|
| **로그아웃** | `POST /auth/logout` | 서버: refresh 폐기 · `PUSH_DEVICE` 비활성. **데이터 유지**<br>클라이언트: 토큰·민감 캐시·예약 로컬 알림 소거 |
| **개인화 초기화** | `DELETE /me/personalization` | `USER_PREP_ESTIMATE` 무효화 + `USER_WELLNESS_PREF` 초기화. **`EVENT_ACTION_LOG`는 유지** — 다시 켤 수 있어야 하므로 |
| **탈퇴** | `DELETE /me` | `USERS.accountStatus='withdrawn'` + `withdrawnAt` 기록 후 **CASCADE 하드 삭제**. `USER_CREDENTIAL`·`AUTH_TOKEN`·`USER_IDENTITY`도 함께 삭제 |

```json
// DELETE /me 응답
{
  "data": {
    "deleted": ["events", "plans", "prepRules", "places", "calendarConnections",
                "pushDevices", "actionLogs", "prepEstimates", "wellnessPrefs",
                "identities", "credential", "authTokens"],
    "retained": ["consentHistory"],
    "retentionReason": "법정 보존 의무"
  }
}
```

- **동기 하드 삭제.** 실패 시 전체 롤백 — 부분 삭제 상태를 만들지 않습니다 (TRD §13.1)
- `USER_CONSENT`만 잔존합니다 (감사 추적, ERD §5)
- 재가입 시 이전 개인화 데이터는 **복구하지 않습니다** (PRD §11.5)
- **하드 삭제입니다.** 익명화 배치를 두지 않습니다 — 회원 전용 + 재가입 복구 없음 정책과 일관되며, 익명화 잔여 데이터는 관리 비용만 남깁니다

---

## 17. 데이터 모델 요약 — ERD v3 정식 표기

| API 리소스 | ERD v3 테이블 | 핵심 필드 |
|---|---|---|
| User | `users` + `user_identity` | accountStatus, timezone, email(UNIQUE), emailVerifiedAt / provider(`email`\|`google`), providerUid |
| **Credential** | **`user_credential`** | passwordHash(Argon2id), passwordAlgo, failedAttempts, lockedUntil |
| **AuthToken** | **`auth_token`** | purpose(`email_verify`\|`password_reset`), tokenHash(SHA-256), expiresAt, consumedAt |
| Setting | `user_setting` | initialPrepMinutes(nullable), arrivalBufferMinutes, wellnessEventEnabled, lockscreenHideSensitive |
| WellnessPref | `user_wellness_pref` | wellnessTopic(PK), isEnabled, remindIntervalMinutes, **dailyEventCap** |
| Place | `user_place` | placeType, lat/lng(암호화), isPrimary, deletedAt |
| **PrepRule** | **`user_prep_rule`** | **ruleName, ruleCategory × actionType, ruleTiming, defaultMinutes, isSensitive, fromChip** |
| EventPrepItem | `event_prep_item` | itemName, actionType, estimatedMinutes |
| **PlanPrepItem** | **`plan_prep_item`** | itemNameSnapshot, appliedMinutes, sourceType, completionStatus |
| CalendarConnection | `calendar_connection` + `calendar_source` | provider, refreshTokenEnc / externalCalendarId, isWritable |
| Event | `event` | startsAt, **locationState**, destinationName, **displayLabel**, sourceType, eventKind, status |
| ClassificationReview | `event_classification_review` | questionType, classificationConfidence, titleSnapshot(즉시 폐기) |
| Plan | `plan_revision` | revisionNo, prepStartAt/recommendedDepartAt/targetArriveAt, **분해 5필드**, planStatus, calcVersion, nextEvalAt, inputHash |
| PlanContext | `plan_context` | uvIndex, pm10/25, feelsLike, **estimatedOutdoorMinutes**, provider, observedAt |
| **WellnessScore** | **`plan_wellness_score`** | uvLoad/pmLoad/thermalLoad/outdoorLoad, wisScore, wisBand, weightVersion |
| **WellnessAction** | **`plan_wellness_action`** | actionCode, displayRank(1~3), reasonSnapshot, completionStatus |
| **WellnessEvent** | **`wellness_event_schedule`** | actionCode, intervalMinutesSnapshot, responseAction, userRating, sequenceNo |
| RouteOption | `route_option` | routeRank, routeType, **totalMinutes / walkMinutes**, transferCount |
| Notification | `notification` | notificationCategory, notificationType, triggerReason, bodyMasked, **dedupKey(UNIQUE)** |
| **ActionLog** | **`event_action_log`** | actionType, actionSource, actionAt, **clientEventId(UNIQUE)** |
| Execution | `event_execution` | actualPrep/Departed/ArrivedAt, arrivalResult, rushLoadScore |
| DelayReason | `event_delay_reason` | reasonCode(복합 PK), reasonSource, confidence |
| Feedback | `event_feedback` | prepTimingAssessment, rushAssessment |
| **DailySummary** | **`daily_wellness_summary`** | dwlScore, dwlBand, cardScenario, cardMessageSnapshot, isViewed |
| **PrepEstimate** | **`user_prep_estimate`** | **scopeType, scopeValue, estimatedMinutes, sampleCount, confidence, modelVersion, adjustmentReason** |
| Consent | `user_consent` | consentType, policyVersion, action, idempotencyKey(UNIQUE) |
| PushDevice | `push_device` | installationId(UNIQUE), currentToken, tokenStatus, platform |

---

## 18. 에러 코드

**공통**

`INVALID_ARGUMENT` · `VALIDATION_ERROR` · `UNAUTHORIZED` · `FORBIDDEN` · `NOT_FOUND` · `CONFLICT` · `RATE_LIMITED` · `INTERNAL_ERROR` · `APP_VERSION_UNSUPPORTED`(426)

**도메인**

| 코드 | 상황 | `retryable` |
|---|---|---|
| `AUTH_INVALID_CREDENTIALS` | 이메일 없음 또는 비밀번호 불일치 — **구분하지 않음**(TR-14) | false |
| `ACCOUNT_LOCKED` | 연속 실패로 잠금(423). `retryAfterSec` 동반 | **true** |
| `EMAIL_ALREADY_LINKED` | 이미 Google로 가입된 이메일로 가입 시도(409) | false |
| `EMAIL_VERIFICATION_REQUIRED` | 이메일 미인증 상태로 핵심 API 호출(403) | false |
| `AUTH_TOKEN_INVALID` | 인증·재설정 토큰이 만료·소비·위조 | false |
| `WEAK_PASSWORD` | 비밀번호 정책 미달 | false |
| `CONSENT_REQUIRED` | 필수 약관 미동의 상태로 핵심 API 호출 | false |
| `EVENT_NOT_FOUND` | 없거나 타 사용자 자원 | false |
| `EVENT_CLASSIFICATION_UNCERTAIN` | 분류 신뢰도 미달 — 확인 필요 | false |
| `PLAN_INFEASIBLE` | 지금 출발해도 늦음 (`feasible=false`) | false |
| `LOCATION_REQUIRED` | `locationState=required_missing`인데 계획 요청 | false |
| `ROUTE_PROVIDER_UNAVAILABLE` | 경로 API 실패 | **true** |
| `WELLNESS_DATA_UNAVAILABLE` | 환경 API 실패 → 웰니스만 생략 | **true** |
| `PERMISSION_REQUIRED` | 위치·알림 권한 없이 해당 기능 호출 | false |
| `SENSITIVE_CHIP_REJECTED` | 민감 항목을 추천 칩으로 등록 시도 (§6.2) | false |
| `PREP_MINUTES_RULE_VIOLATION` | `timed_routine`이 아닌데 `defaultMinutes` 지정 | false |
| `SUMMARY_NOT_GENERATED` | 관리 일정 0건이라 일일 카드 없음 (404) | false |

> **저하 응답은 에러가 아닙니다.** 경로·환경 API가 실패해도 계획 응답은 `200`으로 나가고 `degraded` 배열에 사유가 담깁니다 (PRD §23.2 "일부 실패해도 앱 전체가 중단되지 않는다"의 API 표현). 위 `retryable: true` 코드는 **해당 데이터만 조회하는 엔드포인트**에서만 나옵니다.

---

## 19. 스키마 델타 (ERD v3 → v3.1)

본 명세가 전제하는 컬럼 추가입니다. Flyway 마이그레이션은 백엔드B가 작성하며, **M0 스키마에 전부 포함**됩니다.

```sql
ALTER TABLE plan_revision  ADD COLUMN next_eval_at timestamptz;   -- 재평가 큐
ALTER TABLE plan_revision  ADD COLUMN input_hash   text;          -- 재계산 조기 종료
CREATE INDEX plan_due ON plan_revision (next_eval_at)
  WHERE next_eval_at IS NOT NULL AND plan_status = 'active';

ALTER TABLE notification   ADD COLUMN dedup_key text;             -- 중복 발송 차단
ALTER TABLE notification   ADD CONSTRAINT uq_notification_dedup UNIQUE (dedup_key);

ALTER TABLE event          ADD COLUMN display_label text;         -- 표시명 (§8.3)
ALTER TABLE user_prep_rule ADD COLUMN from_chip boolean NOT NULL DEFAULT false;
ALTER TABLE user_prep_estimate ADD COLUMN adjustment_reason text;

-- 이메일 계정 인증 (§2)
ALTER TABLE users ADD COLUMN email_verified_at timestamptz;
ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE (email);

CREATE TABLE user_credential (
  user_id             uuid PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  password_hash       text NOT NULL,
  password_algo       text NOT NULL DEFAULT 'argon2id',
  password_updated_at timestamptz NOT NULL DEFAULT now(),
  failed_attempts     smallint NOT NULL DEFAULT 0,
  locked_until        timestamptz
);

CREATE TABLE auth_token (
  token_id    uuid PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  purpose     text NOT NULL,
  token_hash  text NOT NULL,
  expires_at  timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_auth_token_hash ON auth_token (token_hash);
CREATE INDEX auth_token_live ON auth_token (user_id, purpose) WHERE consumed_at IS NULL;

CREATE TABLE engine_config (                                      -- 원격 설정 (TR-06)
  config_key   text PRIMARY KEY,
  config_value jsonb NOT NULL,
  version      text NOT NULL,
  updated_at   timestamptz NOT NULL DEFAULT now(),
  updated_by   text
);
```

---

## 20. 요구사항 추적

| PRD ID | 엔드포인트 |
|---|---|
| AUTH-01~04 | §2 전체 — 이메일 §2.1~2.4 · Google §2.5 · 세션 §2.6 |
| ONB-01 | §4.1 `/me/settings` + §6 `/prep-items` (같은 화면 흐름) |
| CAL-01 | §8 `/events` CRUD |
| CAL-02 | §7 `/calendar/*` |
| CAL-03 | §8.1 `locationState` (사용자 지정 우선) |
| CAL-04 | §8.4 `/events/{id}/review` |
| CAL-05 | §10.3 `/routes/search` → §8.1 `POST /events` |
| PLAN-01 | §4.1 `initialPrepMinutes` |
| PLAN-02/03 | §9.1 `breakdown` + `reasons` |
| PLAN-04 | §9.4 recalculate · §9.5 PATCH |
| PLAN-05 | §6 규칙 · §9.1 `checklist` · §12.2 resolve |
| MAP-01~04 | §10 전체 |
| NOTI-01~03 | §11.1~11.3 슬롯 A/B/C |
| NOTI-04 | §12.3 6중 게이트 · §11.4 respond |
| NOTI-05 | §11.1 `/notifications/today` |
| WELL-01 | §9.1 `context` |
| WELL-02 | §12.1 WIS |
| WELL-03 | §9.1 `wellnessActions` · §12.2 |
| WELL-04 | §12.3 |
| WELL-05 | §12.4 `/summary/daily` |
| WELL-06 | §4.2 `/me/wellness-prefs` |
| MODEL-01/02 | §15 전체 |
| REPORT-01 | §13 actions · §14 execution·feedback |
| REPORT-02 | §12.2 웰니스 resolve |
| SET-01 | §5 `/places` |
| SET-02 | §6 `/prep-items` |
| SET-03 | §4 settings·permissions·wellness-prefs |
| DATA-01 | §16 `DELETE /me` |
| DATA-02 | §16 `DELETE /me/personalization` |

---

*Ensom API 명세서 v5.0 · 상위 문서 PRD v0.4.3 · 참조 ERD v3.1 · TRD v4.0 · 2026-08-17*
*늦지 않게, 서두르지 않게.*
