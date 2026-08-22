import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";

/// 목업 `.errbanner` — 폼 검증 요약 배너. 빨강 대신 caution(amber)
/// 왼쪽 바로만 오류를 표시한다(§9.2 "색으로만 상태를 구분하지 않는다"는
/// 원칙은 지키되, 텍스트 자체가 오류 내용을 이미 설명하므로 아이콘은
/// 생략했다).
class EnsomErrorBanner extends StatelessWidget {
  const EnsomErrorBanner({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      // stretch는 부모가 높이를 안 정해주면 무한 높이를 요구한다. ListView 같은
      // 스크롤 영역 안에 놓이면 그대로 레이아웃이 터지므로 텍스트 높이를 먼저
      // 재고 그 높이에 맞춰 왼쪽 바를 늘인다.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: EnsomColors.caution,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.2,
                      color: EnsomColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: EnsomColors.inkFaint,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
