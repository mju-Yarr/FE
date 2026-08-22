import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "../../../models/event.dart";
import "../../../models/pending_event_review.dart";
import "../../../network/api_client.dart";
import "../../../providers/calendar_providers.dart";
import "../../../repository/providers.dart";
import "../../../theme/ensom_colors.dart";
import "../../../widgets/ensom/ensom_error_banner.dart";
import "../../../widgets/ensom/ensom_pill_button.dart";

/// S-11 분류 확인 시트.
///
/// §3 — 세 선택지 모두 서버로 보낸다. "잘 모르겠어요"도 답변이다: 보내지 않으면
/// 질문이 미답변으로 남아 다음 목록에서 또 뜨고, 그건 §13 "재질문 금지" 위반이다.
/// 서버는 unknown을 받으면 질문만 닫고 장소 필요 여부는 그대로 둔다.
///
/// 시트를 그냥 닫으면(뒤로/스크림 탭) 아무것도 보내지 않고 미해결로 남는다 —
/// 이건 "답을 미룬 것"이지 "모른다고 답한 것"이 아니다.
Future<bool?> showClassificationReviewSheet(
  BuildContext context,
  PendingEventReview review,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ClassificationReviewSheet(review: review),
  );
}

class _ClassificationReviewSheet extends ConsumerStatefulWidget {
  const _ClassificationReviewSheet({required this.review});

  final PendingEventReview review;

  @override
  ConsumerState<_ClassificationReviewSheet> createState() =>
      _ClassificationReviewSheetState();
}

class _ClassificationReviewSheetState
    extends ConsumerState<_ClassificationReviewSheet> {
  bool _submitting = false;
  String? _error;

  static final _dateFmt = DateFormat("M월 d일 (E) HH:mm", "ko_KR");

  Future<void> _answer(ClassificationAnswer answer) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(ensomRepositoryProvider)
          .reviewEventClassification(
            widget.review.eventId,
            EventClassificationReview(
              questionType: widget.review.questionType,
              userAnswer: answer.wireValue,
            ),
            // 질문이 이미 닫혔거나 대상이 아니게 됐으면 서버가 409로 막는다.
            reviewId: widget.review.reviewId,
          );
      if (!mounted) return;
      ref.invalidate(pendingReviewsProvider);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (e.code) {
          "REVIEW_ALREADY_CLOSED" => "이미 답변한 질문이에요.",
          "REVIEW_STALE" => "이 일정은 더 이상 확인이 필요하지 않아요.",
          "REVIEW_NOT_FOUND" => "질문을 찾을 수 없어요.",
          "NETWORK_ERROR" => "네트워크에 연결할 수 없어요.",
          _ => e.message,
        };
      });
      // 닫힌 질문은 목록에서도 사라져야 한다.
      if (e.code == "REVIEW_ALREADY_CLOSED" || e.code == "REVIEW_STALE") {
        ref.invalidate(pendingReviewsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "이 일정, 이동이 필요한가요?",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -.3,
                color: EnsomColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              // 제목 원문은 서버가 24시간 뒤 폐기하므로 시각으로만 가리킨다.
              "${_dateFmt.format(widget.review.startsAt.toLocal())} 일정이에요.",
              style: const TextStyle(
                fontSize: 12.5,
                color: EnsomColors.inkMuted,
                height: 1.5,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              EnsomErrorBanner(title: _error!),
            ],
            const SizedBox(height: 18),
            EnsomPillButton(
              label: "네, 장소가 있어요",
              onPressed: _submitting
                  ? null
                  : () => _answer(ClassificationAnswer.offline),
            ),
            const SizedBox(height: 8),
            EnsomPillButton(
              label: "아니요, 온라인·재택이에요",
              variant: EnsomPillVariant.secondary,
              onPressed: _submitting
                  ? null
                  : () => _answer(ClassificationAnswer.online),
            ),
            const SizedBox(height: 4),
            EnsomPillButton(
              label: "잘 모르겠어요",
              variant: EnsomPillVariant.text,
              onPressed: _submitting
                  ? null
                  : () => _answer(ClassificationAnswer.unknown),
            ),
          ],
        ),
      ),
    );
  }
}
