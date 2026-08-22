import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/logout_helper.dart";
import "../../providers/auth_providers.dart";
import "../../providers/system_state_provider.dart";
import "../../screens/system/system_screens.dart";

/// 화면연결명세서 §11 "전체 실패 — 전면 화면" 배선.
/// [systemStateProvider]에 전면 차단이 걸리면 앱 전체를 SYS-01~04로 덮는다.
/// 부분 실패는 여기로 오지 않는다(§1.5) — 각 화면의 인라인 배너가 담당한다.
class EnsomSystemGate extends ConsumerWidget {
  const EnsomSystemGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final block = ref.watch(systemStateProvider).block;
    if (block == null) return child;

    final notifier = ref.read(systemStateProvider.notifier);
    return switch (block) {
      SystemBlock.network => NetworkErrorScreen(onRetry: notifier.clearBlock),
      SystemBlock.sessionExpired => SessionExpiredScreen(
        onLogin: () async {
          await clearLocalCaches(ref);
          ref.read(authNotifierProvider.notifier).logout();
          notifier.clearBlock();
        },
      ),
      SystemBlock.maintenance => MaintenanceScreen(
        message: ref.watch(systemStateProvider).maintenanceMessage,
      ),
      // 스토어 URL이 아직 정해지지 않아 이동 동작을 붙이지 않는다. 버튼 없이
      // 안내만 보여주고, URL이 정해지면 onUpdate를 채운다.
      SystemBlock.updateRequired => const ForceUpdateScreen(),
    };
  }
}
