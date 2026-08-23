import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../models/environment_data.dart";
import "../../../providers/environment_provider.dart";
import "../../../theme/ensom_colors.dart";

/// 홈 화면 인라인 날씨/환경 카드.
/// 접힌 상태에서 온도·하늘·PM10 뱃지를 한 줄로 보여주고,
/// 탭하면 확장해 PM25·자외선 정보를 추가로 표시한다.
/// 에러 시 아무것도 렌더링하지 않는다 (graceful degradation).
class WeatherWidget extends ConsumerStatefulWidget {
  const WeatherWidget({super.key});

  @override
  ConsumerState<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends ConsumerState<WeatherWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final envAsync = ref.watch(environmentProvider);

    return envAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        return _buildCard(data);
      },
    );
  }

  Widget _buildCard(EnvironmentData data) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
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
                "현재 위치",
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
              // 확장 상태: PM25 + UV
              if (_expanded) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: EnsomColors.hairline),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.pm25Grade != null)
                      _GradeBadge(label: "초미세", grade: data.pm25Grade!),
                    if (data.pm25Grade != null) const SizedBox(height: 6),
                    if (data.uvIndex != null) ...[
                      Text(
                        "자외선 ${data.uvIndex}",
                        style: const TextStyle(
                          fontSize: 13,
                          color: EnsomColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.label, required this.grade});

  final String label;
  final String grade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _gradeColor(grade).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "$label $grade",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _gradeColor(grade),
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case "좋음":
        return EnsomColors.dataGood;
      case "보통":
        return EnsomColors.dataModerate;
      case "나쁨":
        return EnsomColors.dataWarning;
      case "매우나쁨":
        return EnsomColors.dataSevere;
      default:
        return EnsomColors.inkMuted;
    }
  }
}
