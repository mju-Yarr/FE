import "package:flutter_riverpod/legacy.dart";
import "../network/api_client.dart";

/// 화면연결명세서 §11 전면 차단 4종.
enum SystemBlock { network, sessionExpired, maintenance, updateRequired }

class SystemState {
  const SystemState({
    this.block,
    this.maintenanceMessage,
    this.dismissedBanners = const {},
  });

  /// null이면 정상. 값이 있으면 해당 전면 화면으로 앱 전체를 덮는다.
  final SystemBlock? block;

  /// 점검 안내 문구. 서버가 주지 않으면 null로 두고 지어내지 않는다.
  final String? maintenanceMessage;

  /// §11 "배너 닫기 — 사용자가 닫으면 그 세션 동안 다시 띄우지 않는다".
  /// 앱 프로세스가 살아 있는 동안만 유지되므로 영속 저장하지 않는다.
  final Set<String> dismissedBanners;

  SystemState copyWith({
    SystemBlock? block,
    String? maintenanceMessage,
    Set<String>? dismissedBanners,
    bool clearBlock = false,
  }) => SystemState(
    block: clearBlock ? null : (block ?? this.block),
    maintenanceMessage: clearBlock
        ? null
        : (maintenanceMessage ?? this.maintenanceMessage),
    dismissedBanners: dismissedBanners ?? this.dismissedBanners,
  );
}

/// §1.5의 핵심 규칙 — "네트워크 자체가 없음"과 "일부 요청 실패"는 다르게
/// 처리한다. 이 notifier는 **전면 차단만** 담당한다. 경로 조회·캘린더 동기화
/// 같은 부분 실패는 여기로 보내지 말고 화면 안 인라인 배너로 처리한다.
class SystemStateNotifier extends StateNotifier<SystemState> {
  SystemStateNotifier() : super(const SystemState());

  /// 앱 전체를 못 쓰게 만드는 실패만 전달한다. 어떤 실패가 전면인지는
  /// 호출부가 판단한다 — 같은 NETWORK_ERROR라도 세션 검사 실패는 전면이고
  /// 경로 조회 실패는 배너다.
  void reportGlobalFailure(ApiException error) {
    final block = switch (error) {
      _ when error.statusCode == 503 => SystemBlock.maintenance,
      _ when error.statusCode == 426 => SystemBlock.updateRequired,
      _ when error.isNetworkError => SystemBlock.network,
      _ when error.isAuthExpired => SystemBlock.sessionExpired,
      _ => null,
    };
    if (block == null) return;
    state = state.copyWith(
      block: block,
      maintenanceMessage: block == SystemBlock.maintenance
          ? error.message
          : null,
    );
  }

  /// 재시도가 성공했거나 연결이 돌아왔을 때 차단을 푼다.
  void clearBlock() => state = state.copyWith(clearBlock: true);

  void dismissBanner(String key) {
    if (state.dismissedBanners.contains(key)) return;
    state = state.copyWith(dismissedBanners: {...state.dismissedBanners, key});
  }

  bool isBannerDismissed(String key) => state.dismissedBanners.contains(key);
}

final systemStateProvider =
    StateNotifierProvider<SystemStateNotifier, SystemState>(
      (ref) => SystemStateNotifier(),
    );
