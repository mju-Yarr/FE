import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";
import "ensom_toggle.dart";

/// 목업 `.lrow` + `.toggle` — 제목(+설명) 행 전체를 탭해도 토글되는
/// 공용 설정 행. 알림/권한/웰니스 설정 화면이 공유한다.
class EnsomToggleRow extends StatelessWidget {
  const EnsomToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: EnsomColors.inkFaint,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            EnsomToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
