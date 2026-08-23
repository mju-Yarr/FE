import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../../models/execution.dart";
import "../../../repository/providers.dart";
import "../../../theme/ensom_colors.dart";
import "../../../widgets/ensom/ensom_chip.dart";
import "../../../widgets/ensom/ensom_pill_button.dart";

/// REPORT-01 / S-44. 도착 처리 이후("도착 → 결과 확정" 루프의 마지막 조각) 도착
/// 결과를 보여주고 짧은 사후 평가를 받는다. 도착 처리(지오펜스·수동
/// 버튼) 로직과는 별도 위젯으로 분리해서 결합도를 낮췄다. 홈 카드와
/// 일정 상세(S-12) 결과 섹션 양쪽에서 그대로 재사용한다.
class ArrivalResultCard extends ConsumerStatefulWidget {
  const ArrivalResultCard({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<ArrivalResultCard> createState() => _ArrivalResultCardState();
}

class _ArrivalResultCardState extends ConsumerState<ArrivalResultCard> {
  EventExecution? _execution;
  bool _loading = true;
  bool _submitted = false;
  bool _submitting = false;
  PrepTimingAssessment? _prepTiming;
  RushAssessment? _rush;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final execution = await ref
          .read(ensomRepositoryProvider)
          .fetchExecution(widget.eventId);
      if (mounted) setState(() => _execution = execution);
    } catch (_) {
      // 실행 결과를 못 가져와도 카드만 조용히 생략한다 (홈 흐름은 막지 않는다).
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final prepTiming = _prepTiming;
    final rush = _rush;
    final execution = _execution;
    if (prepTiming == null || rush == null || execution == null) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(ensomRepositoryProvider)
          .submitFeedback(
            widget.eventId,
            prepTimingAssessment: prepTiming,
            arrivalResult: execution.arrivalResult,
            rushAssessment: rush,
          );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("저장하지 못했어요. 다시 시도해주세요.")));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _arrivalResultLabel(ArrivalResult result) {
    switch (result) {
      case ArrivalResult.early:
        return "여유 있게 도착했어요.";
      case ArrivalResult.onTime:
        return "제시간에 도착했어요.";
      case ArrivalResult.rushed:
        return "조금 서둘러 도착했어요.";
      case ArrivalResult.late_:
        return "예정보다 늦게 도착했어요.";
      case ArrivalResult.unknown:
        return "도착 결과를 확인했어요.";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _execution == null) {
      return const SizedBox.shrink();
    }
    final execution = _execution!;

    // 명세 S-44: 사후 평가 폼은 "판정이 애매할 때만" 등장한다.
    // 정시 도착이나 원인이 명확한 지각에는 섹션 자체가 없다.
    // WIS 밴드는 숫자를 강조하지 않는다 — rushLoadScore는 표시하지 않는다.
    final needsEvaluation = execution.arrivalResult == ArrivalResult.unknown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "결과",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -.2,
            color: EnsomColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: _badgeColor(execution.arrivalResult),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _badgeLabel(execution.arrivalResult),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color:
                  execution.arrivalResult == ArrivalResult.early ||
                      execution.arrivalResult == ArrivalResult.onTime
                  ? EnsomColors.limeInk
                  : EnsomColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _arrivalResultLabel(execution.arrivalResult),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.55,
            color: EnsomColors.inkMuted,
          ),
        ),
        if (_submitted) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: EnsomColors.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              "응답 감사해요.",
              style: TextStyle(fontSize: 12.5, color: EnsomColors.inkMuted),
            ),
          ),
        ],
        if (needsEvaluation && !_submitted) ...[
          const SizedBox(height: 20),
          const Divider(height: 1, color: EnsomColors.hairline),
          const SizedBox(height: 18),
          const Text(
            "무엇 때문에 늦어졌을까요?",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EnsomChip(
                label: "너무 일렀어요",
                selected: _prepTiming == PrepTimingAssessment.tooEarly,
                onTap: () =>
                    setState(() => _prepTiming = PrepTimingAssessment.tooEarly),
              ),
              EnsomChip(
                label: "적절했어요",
                selected: _prepTiming == PrepTimingAssessment.appropriate,
                onTap: () => setState(
                  () => _prepTiming = PrepTimingAssessment.appropriate,
                ),
              ),
              EnsomChip(
                label: "촉박했어요",
                selected: _prepTiming == PrepTimingAssessment.tooLate,
                onTap: () =>
                    setState(() => _prepTiming = PrepTimingAssessment.tooLate),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "도착할 때는 어땠나요?",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: EnsomColors.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EnsomChip(
                label: "여유로웠어요",
                selected: _rush == RushAssessment.notRushed,
                onTap: () => setState(() => _rush = RushAssessment.notRushed),
              ),
              EnsomChip(
                label: "서둘렀어요",
                selected: _rush == RushAssessment.rushed,
                onTap: () => setState(() => _rush = RushAssessment.rushed),
              ),
            ],
          ),
          const SizedBox(height: 14),
          EnsomPillButton(
            label: _submitting ? "저장 중..." : "저장",
            onPressed: (_prepTiming != null && _rush != null && !_submitting)
                ? _submit
                : null,
          ),
        ],
      ],
    );
  }

  String _badgeLabel(ArrivalResult result) {
    switch (result) {
      case ArrivalResult.early:
      case ArrivalResult.onTime:
        return "정시 도착";
      case ArrivalResult.rushed:
        return "촉박";
      case ArrivalResult.late_:
      case ArrivalResult.unknown:
        return "지각";
    }
  }

  Color _badgeColor(ArrivalResult result) {
    switch (result) {
      case ArrivalResult.early:
      case ArrivalResult.onTime:
        return EnsomColors.limeSoft;
      case ArrivalResult.rushed:
        return EnsomColors.caution;
      case ArrivalResult.late_:
      case ArrivalResult.unknown:
        return EnsomColors.surface2;
    }
  }
}
