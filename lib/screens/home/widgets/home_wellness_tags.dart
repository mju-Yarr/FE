import "package:flutter/material.dart";
import "../../../models/plan.dart";
import "../../../theme/ensom_colors.dart";

/// ensom_prototype.html 홈 화면의 "환경 웰니스" `.wtags` — 상세 화면
/// (WellnessActionsSection, ensom_detail.html `.wrow`)의 체크박스+
/// 완료/넘어갈게요 행 대신, 홈은 "{행동} · {이유}" 한 줄짜리 라임 태그로
/// 보여준다. 탭하면 바로 완료 처리한다(한 화면에서 훑고 끝낼 수 있게).
class HomeWellnessTags extends StatelessWidget {
  const HomeWellnessTags({super.key, required this.actions, required this.onResolve});

  final List<WellnessAction> actions;
  final void Function(
    WellnessAction action,
    WellnessActionCompletionStatus status,
  )
  onResolve;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            "환경 웰니스",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: EnsomColors.inkFaint,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final action in actions)
              _WellnessTag(action: action, onResolve: onResolve),
          ],
        ),
      ],
    );
  }
}

class _WellnessTag extends StatelessWidget {
  const _WellnessTag({required this.action, required this.onResolve});

  final WellnessAction action;
  final void Function(
    WellnessAction action,
    WellnessActionCompletionStatus status,
  )
  onResolve;

  @override
  Widget build(BuildContext context) {
    final resolved =
        action.completionStatus != WellnessActionCompletionStatus.proposed;
    final label = action.reasonSnapshot != null
        ? "${action.actionLabel} · ${action.reasonSnapshot}"
        : action.actionLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: resolved
          ? null
          : () => onResolve(action, WellnessActionCompletionStatus.completed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: resolved ? EnsomColors.surface2 : EnsomColors.limeSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: resolved ? EnsomColors.inkFaint : EnsomColors.limeInk,
            decoration:
                action.completionStatus ==
                    WellnessActionCompletionStatus.completed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
      ),
    );
  }
}
