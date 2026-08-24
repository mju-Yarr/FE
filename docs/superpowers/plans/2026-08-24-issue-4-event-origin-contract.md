# 이슈 #4 일정 계약 및 기본 출발지 수정 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 일정 기능에서 BE `anchorMode` 응답을 정확히 해석하고, 일반 물리 일정 생성 시 등록된 기본 출발지를 전달해 초기 플랜 생성을 복구한다.

**Architecture:** 이벤트 응답 호환성은 모든 응답 경로가 공유하는 `Event.fromJson` 경계에서 해결한다. 기본 출발지 선택은 `EventFormScreen`의 저장 오케스트레이션에 작고 테스트 가능한 지연 조회 함수로 두며, repository/API 계약은 기존 인터페이스를 재사용한다.

**Tech Stack:** Flutter, Dart 3.11, Freezed/json_serializable, Riverpod, flutter_test, http MockClient

## Global Constraints

- 기준 브랜치는 최신 `origin/main`이며 설계 기준 리비전은 `935cb41`이다.
- 신규 화면, API, provider, 의존성을 추가하지 않는다.
- `anchorMode`를 표준 응답 키로 우선하고 기존 `anchor` 키 호환성을 유지한다.
- 온라인·미정·지도 초안 일정은 `fetchPlaces()`를 호출하지 않는다.
- 장소 목록이 비었거나 조회가 실패해도 일정 생성은 계속한다.
- PR #18의 `dwlBand: unknown` 처리와 PR #3의 시간 직렬화는 변경하지 않는다.
- PR 제목과 본문은 한국어로 작성하고 본문에 `Closes #4`를 포함한다.

---

### Task 1: EventResponse `anchorMode` 호환 파싱

**Files:**
- Create: `test/event_response_contract_test.dart`
- Modify: `lib/models/event.dart:69`

**Interfaces:**
- Consumes: BE `EventResponse`의 `anchorMode: "arrive_by" | "depart_at"` 및 legacy `anchor` 키
- Produces: `Event.fromJson(Map<String, dynamic>) -> Event`에서 `Event.anchor`가 올바르게 설정되는 중앙 호환 경계

- [ ] **Step 1: 실제 역직렬화를 사용하는 실패 테스트 작성**

```dart
import "package:ensom/models/event.dart";
import "package:flutter_test/flutter_test.dart";

Map<String, dynamic> _eventJson({
  String? anchorMode,
  String? anchor,
}) => {
  "eventId": "event-1",
  "displayName": "회의",
  "startsAt": "2026-08-24T09:00:00Z",
  "locationState": "not_required",
  if (anchorMode != null) "anchorMode": anchorMode,
  if (anchor != null) "anchor": anchor,
};

void main() {
  test("표준 anchorMode의 depart_at을 출발 기준으로 파싱한다", () {
    final event = Event.fromJson(_eventJson(anchorMode: "depart_at"));
    expect(event.anchor, EventAnchor.departAt);
  });

  test("legacy anchor 응답도 계속 파싱한다", () {
    final event = Event.fromJson(_eventJson(anchor: "depart_at"));
    expect(event.anchor, EventAnchor.departAt);
  });

  test("두 키가 함께 오면 표준 anchorMode를 우선한다", () {
    final event = Event.fromJson(
      _eventJson(anchorMode: "depart_at", anchor: "arrive_by"),
    );
    expect(event.anchor, EventAnchor.departAt);
  });

  test("두 키가 모두 없으면 기존 도착 기준 기본값을 유지한다", () {
    final event = Event.fromJson(_eventJson());
    expect(event.anchor, EventAnchor.arriveBy);
  });
}
```

- [ ] **Step 2: RED 확인**

Run: `flutter test --no-pub test/event_response_contract_test.dart`

Expected: 첫 번째와 세 번째 테스트가 `Expected: EventAnchor.departAt / Actual: EventAnchor.arriveBy`로 실패하고 legacy/default 테스트는 통과한다.

- [ ] **Step 3: 모델 경계에서 표준 키를 정규화하는 최소 구현**

```dart
factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson({
  ...json,
  if (json["anchorMode"] != null) "anchor": json["anchorMode"],
});
```

이 구현은 생성 코드를 수정하지 않고 `toJson()`의 기존 `anchor` 출력도 보존한다.

- [ ] **Step 4: GREEN 확인**

Run: `flutter test --no-pub test/event_response_contract_test.dart`

Expected: 4/4 PASS.

- [ ] **Step 5: 변경 범위를 커밋**

```bash
git add lib/models/event.dart test/event_response_contract_test.dart
git commit -m "fix: 백엔드 일정 anchorMode 응답 파싱"
```

---

### Task 2: 일반 물리 일정의 기본 출발지 연결

**Files:**
- Create: `test/event_origin_resolution_test.dart`
- Modify: `lib/screens/calendar/event_form_screen.dart:245-309`
- Modify: `test/be_contract_alignment_test.dart:170-213`

**Interfaces:**
- Consumes: `EnsomRepository.fetchPlaces()`, 최종 `LocationState`, 지도 초안 존재 여부와 초안 `originPlaceId`
- Produces: `Future<String?> resolveEventOriginPlaceId(...)`와 `createEvent(originPlaceId:)` 호출

- [ ] **Step 1: 기본 출발지 선택의 실패 테스트 작성**

`test/event_origin_resolution_test.dart`에 `EnsomRepository`를 구현하는 `_OriginRepo`를 만들고 `fetchPlacesCalls`, `places`, `fetchError`를 관측한다. 다른 메서드는 기존 테스트 패턴대로 `noSuchMethod`에서 `UnimplementedError`를 던진다.

```dart
class _OriginRepo implements EnsomRepository {
  _OriginRepo(this.places, {this.fetchError});

  final List<Place> places;
  final Object? fetchError;
  int fetchPlacesCalls = 0;

  @override
  Future<List<Place>> fetchPlaces() async {
    fetchPlacesCalls++;
    if (fetchError != null) throw fetchError!;
    return places;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
```

다음 실제 입력과 리터럴 기대값을 각각 검증한다.

```dart
test("일반 물리 일정은 primary 장소를 우선한다", () async {
  final repo = _OriginRepo(const [
    Place(placeId: "first", placeType: "work", placeName: "회사", address: "서울", lat: 37.1, lng: 127.1),
    Place(placeId: "primary", placeType: "home", placeName: "집", address: "서울", lat: 37.2, lng: 127.2, isPrimary: true),
  ]);

  final result = await resolveEventOriginPlaceId(
    repository: repo,
    locationState: LocationState.requiredResolved,
    hasMapDraft: false,
  );

  expect(result, "primary");
  expect(repo.fetchPlacesCalls, 1);
});
```

추가 테스트는 다음 행렬을 그대로 구현한다.

| 입력 | 기대 ID | `fetchPlacesCalls` |
|---|---:|---:|
| 일반 물리, primary 없음, `[first, second]` | `first` | 1 |
| 일반 물리, 빈 목록 | `null` | 1 |
| 일반 물리, 조회 예외 | `null` | 1 |
| `notRequired`, 일반 폼 | `null` | 0 |
| `undecided`, 일반 폼 | `null` | 0 |
| 지도 초안, `draftOriginPlaceId: "draft"` | `draft` | 0 |
| 지도 초안, origin 없음 | `null` | 0 |

- [ ] **Step 2: RED 확인**

Run: `flutter test --no-pub test/event_origin_resolution_test.dart`

Expected: `resolveEventOriginPlaceId`가 정의되지 않아 컴파일 실패한다. 테스트 코드의 오타가 아니라 요구 인터페이스 부재로 인한 실패인지 확인한다.

- [ ] **Step 3: 최소 출발지 resolver 구현**

`EventFormScreen` 선언 앞에 아래 함수를 추가한다.

```dart
@visibleForTesting
Future<String?> resolveEventOriginPlaceId({
  required EnsomRepository repository,
  required LocationState locationState,
  required bool hasMapDraft,
  String? draftOriginPlaceId,
}) async {
  if (hasMapDraft) return draftOriginPlaceId;
  if (locationState != LocationState.requiredResolved) return null;

  try {
    final places = await repository.fetchPlaces();
    if (places.isEmpty) return null;
    return places
        .firstWhere((place) => place.isPrimary, orElse: () => places.first)
        .placeId;
  } catch (error, stackTrace) {
    debugPrint("[event-create] 기본 출발지 조회 실패: $error\n$stackTrace");
    return null;
  }
}
```

`event_form_screen.dart`에 `EnsomRepository` import를 추가한다.

- [ ] **Step 4: resolver GREEN 확인**

Run: `flutter test --no-pub test/event_origin_resolution_test.dart`

Expected: 8/8 PASS.

- [ ] **Step 5: 저장 흐름에 resolver 연결**

`_save()`에서 최종 `Event`를 만든 다음 repository를 한 번 읽고 resolver 결과를 전달한다.

```dart
final repository = ref.read(ensomRepositoryProvider);
final originPlaceId = await resolveEventOriginPlaceId(
  repository: repository,
  locationState: event.locationState,
  hasMapDraft: draft != null,
  draftOriginPlaceId: draft?.originPlaceId,
);
final created = await repository.createEvent(
  event,
  originPlaceId: originPlaceId,
  selectedRouteOptionId: draft?.selectedRoute.routeOptionId,
  writeToCalendarSourceId: _writeToCalendarSourceId,
);
```

- [ ] **Step 6: POST `/events` wire 계약 보강**

`test/be_contract_alignment_test.dart`의 기존 이벤트 생성 테스트에서 `originPlaceId: "place-1"`을 전달하고 다음 리터럴 assertion을 추가한다.

```dart
expect(body["originPlaceId"], "place-1");
```

이 단계는 이미 구현된 repository 직렬화 경계를 보존하는 characterization assertion이며 새 production 동작을 요구하지 않는다.

- [ ] **Step 7: 관련 테스트 GREEN 확인**

Run: `flutter test --no-pub test/event_origin_resolution_test.dart test/be_contract_alignment_test.dart test/event_response_contract_test.dart`

Expected: 모든 테스트 PASS.

- [ ] **Step 8: 변경 범위를 커밋**

```bash
git add lib/screens/calendar/event_form_screen.dart test/event_origin_resolution_test.dart test/be_contract_alignment_test.dart
git commit -m "fix: 일반 일정에 기본 출발지 전달"
```

---

### Task 3: 전체 검증과 한국어 PR 작성

**Files:**
- Modify: `tasks/todo.md` (로컬 작업 기록이며 PR 커밋에서 제외)

**Interfaces:**
- Consumes: Task 1~2의 커밋과 이슈 #4 DoD
- Produces: 검증 근거, 독립 리뷰 결과, 한국어 PR

- [ ] **Step 1: 전체 테스트 실행**

Run: `flutter test --no-pub`

Expected: 0 failures.

- [ ] **Step 2: 정적 분석 실행**

Run: `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`

Expected: 컴파일 오류 0건이며 변경 파일에 신규 warning/error가 없다. 기존 lint는 개수와 종류를 PR에 명시한다.

- [ ] **Step 3: 웹 릴리스 빌드 실행**

Run: `flutter build web --release --no-pub`

Expected: exit code 0.

- [ ] **Step 4: diff 무결성과 변경 범위 확인**

Run: `git diff --check origin/main...HEAD && git status --short && git diff --stat origin/main...HEAD`

Expected: whitespace 오류가 없고 `tasks/`는 커밋되지 않으며 설계·계획·두 수정·테스트만 포함된다.

- [ ] **Step 5: 독립 코드 리뷰**

`requesting-code-review` 템플릿으로 reviewer 서브에이전트에 `origin/main`부터 `HEAD`까지 검토를 요청한다. Critical/Important finding은 수정하고 관련 검증을 다시 실행한다.

- [ ] **Step 6: 작업 기록 완료**

`tasks/todo.md`의 Issue #4 체크리스트를 모두 체크하고 Review에 테스트 수, analyze 결과, build 결과, reviewer 결과, 커밋 SHA와 PR URL을 기록한다. `tasks/`는 `git add`하지 않는다.

- [ ] **Step 7: 전용 브랜치 push 및 한국어 PR 생성**

PR 제목:

```text
fix: 일정 응답 계약과 기본 출발지 연결 오류 수정
```

PR 본문은 최근 PR #18/#19의 한국어 양식을 따라 다음 섹션을 사용한다.

```markdown
## 🐣 변경 요약

## 🌈 PR 요약

## 🐤 반영 브랜치

## 🐥 테스트 결과

## 👾 참고 사항

## 👀 추가 설명

Closes #4
```

본문에는 `anchorMode` 호환 파싱, 일반 물리 일정의 primary/첫 장소 선택, 온라인·지도 초안 조회 생략, 빈 목록·조회 실패 폴백, 실제 검증 수치를 한국어로 기록한다.
