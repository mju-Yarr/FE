import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../../models/environment_data.dart";
import "../../../providers/environment_provider.dart";
import "../../../theme/ensom_colors.dart";

/// 홈 화면 인라인 날씨/환경 카드 (ensom_prototype.html `.weather`).
/// 목업처럼 탭하면 날씨 상세 화면(`/weather`)으로 이동한다 — 이전엔
/// 로컬 상태로 카드 안에서 PM25·자외선만 펼쳐 보여줬는데, 그건 목업의
/// `openWeather()`(전체화면 상세 패널 이동)와 다른 동작이라 "날씨를
/// 눌러도 상세 페이지가 안 뜬다"는 문제로 이어졌다.
/// 에러 시 아무것도 렌더링하지 않는다 (graceful degradation).
class WeatherWidget extends ConsumerWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envAsync = ref.watch(environmentProvider);

    return envAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        return _buildCard(context, data);
      },
    );
  }

  Widget _buildCard(BuildContext context, EnvironmentData data) {
    return GestureDetector(
      onTap: () => context.push("/weather"),
      child: Container(
        width: 108,
        decoration: BoxDecoration(
          color: EnsomColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "대표 장소",
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: EnsomColors.inkMuted,
                ),
              ),
              if (data.temperature != null)
                Text(
                  "${data.temperature}°",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: EnsomColors.ink,
                  ),
                ),
              Text(
                data.sky ?? "날씨 정보",
                style: const TextStyle(
                  fontSize: 9,
                  height: 1.3,
                  color: EnsomColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
