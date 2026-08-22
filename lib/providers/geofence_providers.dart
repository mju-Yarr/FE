import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../services/geofence_manager.dart";
import "home_providers.dart";

/// 앱 전체에서 하나만 있어야 하는 지오펜스 매니저(TR-08 "활성 계획 1건").
final geofenceManagerProvider = Provider<GeofenceManager>((ref) {
  return GeofenceManager(ref);
});

/// main.dart의 MaterialApp.router builder에 항상 붙여 두는 보이지 않는
/// 위젯. 다음 일정·계획이 바뀔 때마다 GeofenceManager에 동기화를
/// 트리거한다(활성 창 진입 시 리전 등록, 종료 시 해제).
///
/// syncActivePlan()은 planId가 같으면 바로 반환하는 멱등 연산이라
/// build()에서 매번 호출해도 안전하다 -- WidgetRef.listen은 위젯
/// build 안에서 fireImmediately를 지원하지 않아(Riverpod 3), watch로
/// 얻은 최신 값을 build 안에서 직접 동기화하는 방식을 쓴다.
class GeofenceSync extends ConsumerWidget {
  const GeofenceSync({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(nextEventProvider);
    // Riverpod 3의 AsyncValue.value는 이전 데이터 없이 에러 상태면 그
    // 자리에서 예외를 다시 던진다 — build() 안에서 무조건 .value를
    // 읽으면 /events/next가 401 등으로 실패할 때 이 보이지 않는
    // 위젯이 화면 전체를 깨뜨릴 수 있다. hasValue로 먼저 가드한다.
    final event = eventAsync.hasValue ? eventAsync.value : null;

    if (event == null) {
      if (eventAsync.hasValue) ref.read(geofenceManagerProvider).clear();
      return const SizedBox.shrink();
    }

    final planAsync = ref.watch(planControllerProvider(event.eventId));
    planAsync.whenData(
      (plan) => ref.read(geofenceManagerProvider).syncActivePlan(event, plan),
    );

    return const SizedBox.shrink();
  }
}
