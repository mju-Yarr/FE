import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";

enum EnsomPillVariant { primary, secondary, text }

/// 화면연결명세서 §9.3 "기본 버튼" 규격: 알약형(radius 999), 높이 50px,
/// 14px/700. 보조 버튼은 surface-2 배경, 텍스트 버튼은 배경 없이 밑줄.
/// 비활성 시 opacity .4 (Flutter의 disabled 처리가 그대로 이 역할을 한다).
class EnsomPillButton extends StatelessWidget {
  const EnsomPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EnsomPillVariant.primary,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final EnsomPillVariant variant;
  final Widget? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon!, const SizedBox(width: 9), Text(label)],
          );

    final button = switch (variant) {
      EnsomPillVariant.primary => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: EnsomColors.cta,
          foregroundColor: Colors.white,
          disabledBackgroundColor: EnsomColors.cta.withValues(alpha: .4),
          disabledForegroundColor: Colors.white.withValues(alpha: .8),
          minimumSize: const Size.fromHeight(50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: child,
      ),
      EnsomPillVariant.secondary => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: EnsomColors.surface2,
          foregroundColor: EnsomColors.ink,
          disabledBackgroundColor: EnsomColors.surface2,
          disabledForegroundColor: EnsomColors.ink.withValues(alpha: .4),
          minimumSize: const Size.fromHeight(50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: child,
      ),
      EnsomPillVariant.text => TextButton(
        style: TextButton.styleFrom(
          foregroundColor: EnsomColors.inkMuted,
          minimumSize: const Size.fromHeight(44),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
