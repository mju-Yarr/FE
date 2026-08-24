import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../models/environment_data.dart";
import "../../providers/environment_provider.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

/// ensom_prototype.html `#wxPanel`(날씨 상세)을 반영한다.
///
/// 목업은 위치명·최고/최저·강수확률·7일 예보까지 보여주지만, BE
/// `GET /environment/current`(EnvironmentResponse)는 temperature/sky/
/// pm10Grade/pm25Grade/uvIndex 5개 필드만 반환하고 예보 데이터 자체가
/// 없다(BE #226). 없는 값을 지어내는 대신 실제로 있는 값만으로 같은
/// 레이아웃(히어로 + 3항목 통계 카드)을 구성한다.
class WeatherDetailScreen extends ConsumerWidget {
  const WeatherDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final envAsync = ref.watch(environmentProvider);

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "날씨"),
      body: SafeArea(
        top: false,
        child: envAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "날씨 정보를 불러오지 못했어요.",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: EnsomColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => ref.invalidate(environmentProvider),
                    child: const Text("다시 시도"),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            if (data == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    "자주 가는 장소를 등록하면 날씨 정보를 보여드려요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: EnsomColors.inkMuted),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
              children: [
                _WeatherHero(data: data),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: "자외선",
                        value: data.uvIndex != null
                            ? "지수 ${data.uvIndex}"
                            : "정보 없음",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: "미세먼지",
                        value: data.pm10Grade ?? "정보 없음",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: "초미세먼지",
                        value: data.pm25Grade ?? "정보 없음",
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: EnsomColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    "대표 장소 기준 날씨·대기질 정보예요. 실제 준비 계획은 일정 시각과 이동 경로를 함께 반영해 계산돼요.",
                    style: TextStyle(
                      fontSize: 11,
                      color: EnsomColors.inkMuted,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeatherHero extends StatelessWidget {
  const _WeatherHero({required this.data});

  final EnvironmentData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const Text(
            "대표 장소",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: EnsomColors.inkMuted,
            ),
          ),
          if (data.temperature != null)
            Text(
              "${data.temperature}°",
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                height: 1.05,
                letterSpacing: -1.5,
                color: EnsomColors.ink,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              data.sky ?? "날씨 정보 없음",
              style: const TextStyle(
                fontSize: 12.5,
                color: EnsomColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              // inkFaint(#6F7269)는 surface2(#EEF0EA) 위에서 대비 4.27:1로
              // WCAG AA 본문 기준(4.5:1) 미달이라 inkMuted(5.15:1)를 쓴다.
              color: EnsomColors.inkMuted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: EnsomColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
