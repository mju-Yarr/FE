import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../models/prep_item.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_chip.dart";
import "../../widgets/ensom/ensom_error_banner.dart";
import "../../widgets/ensom/ensom_pill_button.dart";

/// PRD §11.3 "준비 시간 및 맞춤 준비 항목 입력 화면" 반영.
/// 맞춤 준비 항목은 별도 온보딩 단계가 아니라 이 화면 안의 한 섹션이다
/// — API 명세 §6에서 이미 확정한 원칙, 화면 분리 금지.
///
/// ensom_onboarding_flow.html STEP 2의 qlabel/sub/chiprow 시각 언어를
/// 반영했다. "시간이 필요한 루틴"(timed_routine) 섹션은 목업엔 없지만
/// 실제 API(§6.1 PrepKind.routine)가 지원하는 기능이라 같은 톤으로
/// 유지했다.
///
/// 이 화면에서 처리하는 API 호출:
///   1. PATCH /me/settings { initialPrepMinutes } — §4.1
///   2. POST /prep-items (선택된 빠른 추가 + 직접 입력 + 시간 루틴) — §6.1
class PrepTimeEntryScreen extends ConsumerStatefulWidget {
  const PrepTimeEntryScreen({super.key, this.isOnboarding = true});

  /// 온보딩 흐름(ONB-03)인지, 설정의 준비 시간 편집(/profile/prep)인지 구분한다.
  /// 온보딩이면 저장 후 다음 단계(places)로 진행하고, 설정 편집이면 저장 후
  /// 이전 화면으로 pop한다(온보딩 마커를 되감지 않는다).
  final bool isOnboarding;

  @override
  ConsumerState<PrepTimeEntryScreen> createState() =>
      _PrepTimeEntryScreenState();
}

// ─── 빠른 추가 항목 (carry/consume/purchase) ────────────────────────

class _QuickAddItem {
  _QuickAddItem({
    required this.label,
    required this.kind,
    this.sensitive = false,
  });

  final String label;
  final PrepKind kind;
  final bool sensitive;
  bool selected = false;
}

// ─── 시간 소요 루틴 항목 (timed_routine) ────────────────────────────

class _RoutineItem {
  _RoutineItem({required this.label, required this.minutes});

  final String label;
  int minutes;
  bool selected = false;
}

// ─── 화면 상태 ──────────────────────────────────────────────────────

class _PrepTimeEntryScreenState extends ConsumerState<PrepTimeEntryScreen> {
  // ── 준비 시간 프리셋 ──────────────────────────────────────────────
  static const _presets = [10, 20, 30, 45, 60];
  int? _selectedPreset;
  bool _unknownSelected = false;

  // ── 빠른 추가 칩 (carry/consume/purchase) ─────────────────────────
  // 민감 항목(복용약)은 추천 칩에 노출하지 않음 (TR-10 추천 경계)
  final List<_QuickAddItem> _quickItems = [
    _QuickAddItem(label: "영양제", kind: PrepKind.consume),
    _QuickAddItem(label: "물·텀블러", kind: PrepKind.carry),
    _QuickAddItem(label: "선크림", kind: PrepKind.carry),
    _QuickAddItem(label: "마스크", kind: PrepKind.carry),
    _QuickAddItem(label: "우산", kind: PrepKind.carry),
    _QuickAddItem(label: "보조배터리", kind: PrepKind.carry),
    _QuickAddItem(label: "커피·차·간식", kind: PrepKind.purchase),
  ];

  // ── 시간 소요 루틴 칩 (timed_routine) ─────────────────────────────
  // PRD §11.3: "렌즈, 화장, 식사, 반려동물 돌보기"
  // 시간이 필요한 루틴 → 설정한 분만큼 준비 시간에 합산됨
  final List<_RoutineItem> _routineItems = [
    _RoutineItem(label: "렌즈 착용", minutes: 5),
    _RoutineItem(label: "화장·스킨케어", minutes: 15),
    _RoutineItem(label: "식사", minutes: 15),
    _RoutineItem(label: "샤워", minutes: 15),
    _RoutineItem(label: "반려동물 돌보기", minutes: 10),
  ];

  // ── 직접 입력 ─────────────────────────────────────────────────────
  final _customItemController = TextEditingController();
  final _customRoutineController = TextEditingController();
  int _customRoutineMinutes = 10;
  bool _customItemFieldOpen = false;
  bool _customRoutineFieldOpen = false;

  // 직접 추가로 "확정"된 커스텀 항목들. "추가" 버튼이 여기에 append하고,
  // 요약·제출은 컨트롤러의 임시 텍스트가 아니라 이 리스트만 읽는다.
  // 그래서 필드를 접거나 여러 개를 추가해도 화면과 제출이 일치한다.
  final List<String> _customItems = [];
  final List<_RoutineItem> _customRoutines = [];

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _customItemController.dispose();
    _customRoutineController.dispose();
    super.dispose();
  }

  // ── 준비 시간 선택 ────────────────────────────────────────────────

  void _selectPreset(int minutes) {
    setState(() {
      _selectedPreset = minutes;
      _unknownSelected = false;
    });
  }

  void _selectUnknown() {
    setState(() {
      _unknownSelected = true;
      _selectedPreset = null;
    });
  }

  // ── 커스텀 항목 확정 ──────────────────────────────────────────────

  void _addCustomItem() {
    final text = _customItemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _customItems.add(text);
      _customItemController.clear();
    });
  }

  void _removeCustomItem(int index) {
    setState(() => _customItems.removeAt(index));
  }

  void _addCustomRoutine() {
    final text = _customRoutineController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _customRoutines.add(
        _RoutineItem(label: text, minutes: _customRoutineMinutes)
          ..selected = true,
      );
      _customRoutineController.clear();
      _customRoutineMinutes = 10;
    });
  }

  void _removeCustomRoutine(int index) {
    setState(() => _customRoutines.removeAt(index));
  }

  // ── 제출 ──────────────────────────────────────────────────────────

  bool get _canSubmit => _selectedPreset != null || _unknownSelected;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(ensomRepositoryProvider);

      // 1. PATCH /me/settings — 준비 시간 시드 저장
      //    "잘 모르겠어요"는 null 전송 (§4.1: initialPrepMinutes는 null 허용)
      await repo.updateSettings({
        "initialPrepMinutes": _unknownSelected ? null : _selectedPreset,
      });

      // 2~5. POST /prep-items — 부분 실패 허용
      //    settings 저장은 성공했으므로 prep-items 중 일부가 실패해도
      //    성공한 건은 유지하고 실패 건수를 사용자에게 안내한다.
      final itemsToCreate = <PrepItem>[];

      // 선택된 빠른 추가 항목
      for (final item in _quickItems.where((i) => i.selected)) {
        itemsToCreate.add(
          PrepItem(
            id: "",
            label: item.label,
            kind: item.kind,
            sensitive: item.sensitive,
            fromChip: true,
          ),
        );
      }

      // 선택된 시간 소요 루틴
      for (final routine in _routineItems.where((r) => r.selected)) {
        itemsToCreate.add(
          PrepItem(
            id: "",
            label: routine.label,
            kind: PrepKind.routine,
            extraMin: routine.minutes,
            fromChip: true,
          ),
        );
      }

      // 직접 입력해 확정한 일반 항목들(여러 개 가능)
      for (final label in _customItems) {
        itemsToCreate.add(
          PrepItem(id: "", label: label, kind: PrepKind.carry, fromChip: false),
        );
      }

      // 직접 입력해 확정한 루틴들(여러 개 가능)
      for (final routine in _customRoutines) {
        itemsToCreate.add(
          PrepItem(
            id: "",
            label: routine.label,
            kind: PrepKind.routine,
            extraMin: routine.minutes,
            fromChip: false,
          ),
        );
      }

      // 순차 호출 — 부분 실패 추적
      int successCount = 0;
      int failCount = 0;
      for (final item in itemsToCreate) {
        try {
          await repo.createPrepItem(item);
          successCount++;
        } catch (_) {
          failCount++;
        }
      }

      if (!mounted) return;

      if (failCount > 0 && successCount == 0) {
        // 전부 실패
        setState(() => _error = "준비 항목 저장에 실패했어요. 네트워크를 확인하고 다시 시도해주세요.");
        return;
      }

      if (failCount > 0) {
        // 부분 실패 — 안내 후 진행 허용
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "$successCount개 저장됨 · $failCount개 실패 — 설정에서 다시 추가할 수 있어요.",
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (!mounted) return;

      // 온보딩이면 다음 단계로 진행, 설정 편집이면 온보딩 마커를 건드리지
      // 않고 이전 화면으로 돌아간다(완료된 온보딩이 되감기지 않도록).
      if (widget.isOnboarding) {
        await ref
            .read(authNotifierProvider.notifier)
            .advanceOnboarding("places");
        if (mounted) context.go("/onboarding/places");
      } else {
        context.pop();
      }
    } on ApiException catch (e) {
      // settings PATCH 자체가 실패한 경우
      setState(() {
        if (e.isNetworkError) {
          _error = "네트워크에 연결할 수 없어요. 잠시 후 다시 시도해주세요.";
        } else {
          _error = e.message;
        }
      });
    } catch (_) {
      setState(() => _error = "저장에 실패했어요. 다시 시도해주세요.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skip() async {
    // 맞춤 항목은 선택 사항 — 건너뛰어도 온보딩 완료를 막지 않음 (PRD §11.3)
    if (widget.isOnboarding) {
      await ref.read(authNotifierProvider.notifier).advanceOnboarding("places");
      if (mounted) context.go("/onboarding/places");
    } else {
      context.pop();
    }
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 0),
              child: Row(
                children: [
                  // 설정 편집(/profile/prep) 진입 시 뒤로가기 제공 — dev의
                  // AppBar back 버튼이 수제 헤더로 바뀌며 사라진 탈출구 복원.
                  if (!widget.isOnboarding)
                    IconButton(
                      onPressed: _submitting ? null : () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: EnsomColors.ink,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      tooltip: "뒤로",
                    ),
                  const Expanded(
                    child: Text(
                      "준비 시간",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                        color: EnsomColors.ink,
                      ),
                    ),
                  ),
                  if (widget.isOnboarding)
                    TextButton(
                      onPressed: _submitting ? null : _skip,
                      child: const Text(
                        "나중에 설정할게요",
                        style: TextStyle(
                          fontSize: 12,
                          color: EnsomColors.inkMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                children: [
                  // ── 섹션 1: 준비 시간 ─────────────────────────────────
                  const _SectionLabel(
                    "평소 외출 준비에 얼마나 걸리나요?",
                    "정확하지 않아도 괜찮아요. 실제 기록을 바탕으로 계속 조정할게요.",
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 8,
                    children: [
                      for (final minutes in _presets)
                        EnsomChip(
                          label: "$minutes분",
                          selected: _selectedPreset == minutes,
                          onTap: () => _selectPreset(minutes),
                        ),
                      EnsomChip(
                        label: "잘 모르겠어요",
                        selected: _unknownSelected,
                        onTap: _selectUnknown,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── 섹션 2: 빠른 추가 (챙기기/사용/구매) ──────────────
                  const _SectionLabel(
                    "외출 전에 자주 챙기는 것이 있나요?",
                    "선택한 항목은 준비 체크리스트에 자동 반영됩니다.",
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 7,
                    runSpacing: 8,
                    children: [
                      for (final item in _quickItems)
                        EnsomChip(
                          label: item.label,
                          selected: item.selected,
                          onTap: () =>
                              setState(() => item.selected = !item.selected),
                        ),
                      EnsomChip(
                        label: "+ 직접 추가",
                        selected: false,
                        dashed: true,
                        onTap: () => setState(() {
                          _customItemFieldOpen = !_customItemFieldOpen;
                          // 접으면 = 취소로 간주. 남은 텍스트가 제출되지 않도록
                          // 컨트롤러를 비운다.
                          if (!_customItemFieldOpen) {
                            _customItemController.clear();
                          }
                        }),
                      ),
                    ],
                  ),
                  if (_customItemFieldOpen) ...[
                    const SizedBox(height: 10),
                    _InlineAddField(
                      controller: _customItemController,
                      hintText: "예: 지갑, 이어폰",
                      onSubmit: _addCustomItem,
                    ),
                  ],
                  if (_customItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _customItems.length; i++)
                          _RemovableChip(
                            label: _customItems[i],
                            onRemove: () => _removeCustomItem(i),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── 섹션 3: 시간 소요 루틴 (timed_routine) ────────────
                  const _SectionLabel(
                    "시간이 필요한 루틴이 있나요?",
                    "선택한 루틴 시간이 준비 시작 시각에 반영됩니다.",
                  ),
                  const SizedBox(height: 12),
                  for (final routine in _routineItems)
                    _RoutineRow(
                      routine: routine,
                      onToggle: (v) => setState(() => routine.selected = v),
                      onMinutesChanged: (m) =>
                          setState(() => routine.minutes = m),
                    ),
                  const SizedBox(height: 6),
                  if (!_customRoutineFieldOpen)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: EnsomChip(
                        label: "+ 직접 추가",
                        selected: false,
                        dashed: true,
                        onTap: () =>
                            setState(() => _customRoutineFieldOpen = true),
                      ),
                    )
                  else
                    _InlineRoutineAddField(
                      controller: _customRoutineController,
                      minutes: _customRoutineMinutes,
                      onMinutesChanged: (m) =>
                          setState(() => _customRoutineMinutes = m),
                      onAdd: _addCustomRoutine,
                      onClose: () => setState(() {
                        _customRoutineFieldOpen = false;
                        _customRoutineController.clear();
                        _customRoutineMinutes = 10;
                      }),
                    ),
                  if (_customRoutines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _customRoutines.length; i++)
                          _RemovableChip(
                            label:
                                "${_customRoutines[i].label} · ${_customRoutines[i].minutes}분",
                            onRemove: () => _removeCustomRoutine(i),
                          ),
                      ],
                    ),
                  ],

                  // ── 합산 미리보기 ─────────────────────────────────────
                  _RoutineSummary(
                    prepMinutes: _selectedPreset,
                    routineItems: _routineItems,
                    customRoutines: _customRoutines,
                  ),

                  // ── 에러 메시지 ───────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    EnsomErrorBanner(title: _error!),
                  ],

                  const SizedBox(height: 24),

                  // ── 제출 버튼 ─────────────────────────────────────────
                  EnsomPillButton(
                    label: _submitting
                        ? "저장 중..."
                        : (widget.isOnboarding ? "다음으로" : "저장"),
                    onPressed: (_canSubmit && !_submitting) ? _submit : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -.2,
            color: EnsomColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: EnsomColors.inkMuted,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// 빠른 추가 입력 필드 — 텍스트 + "추가" 버튼. 버튼은 실제로 커스텀 항목을
/// 확정(append)한다.
class _InlineAddField extends StatelessWidget {
  const _InlineAddField({
    required this.controller,
    required this.hintText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: EnsomColors.surface1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EnsomColors.hairline, width: 1.4),
            ),
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmit(),
              style: const TextStyle(fontSize: 13, color: EnsomColors.ink),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                isCollapsed: true,
                hintStyle: const TextStyle(color: EnsomColors.inkFaint),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: EnsomColors.cta,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onSubmit,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                "추가",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineRoutineAddField extends StatelessWidget {
  const _InlineRoutineAddField({
    required this.controller,
    required this.minutes,
    required this.onMinutesChanged,
    required this.onAdd,
    required this.onClose,
  });

  final TextEditingController controller;
  final int minutes;
  final ValueChanged<int> onMinutesChanged;
  final VoidCallback onAdd;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: EnsomColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EnsomColors.hairline, width: 1.4),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onAdd(),
                  style: const TextStyle(fontSize: 13, color: EnsomColors.ink),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "예: 스트레칭",
                    isCollapsed: true,
                    hintStyle: TextStyle(color: EnsomColors.inkFaint),
                  ),
                ),
              ),
              _MinuteStepper(minutes: minutes, onChanged: onMinutesChanged),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: onClose,
              child: const Text(
                "닫기",
                style: TextStyle(fontSize: 12, color: EnsomColors.inkMuted),
              ),
            ),
            const Spacer(),
            Material(
              color: EnsomColors.cta,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    "추가",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 확정된 커스텀 항목을 보여주고 삭제(×)할 수 있는 칩.
class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EnsomColors.cta,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(left: 13, right: 6, top: 7, bottom: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinuteStepper extends StatelessWidget {
  const _MinuteStepper({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onTap: minutes > 5 ? () => onChanged(minutes - 5) : null,
        ),
        SizedBox(
          width: 38,
          child: Text(
            "$minutes분",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: EnsomColors.ink,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          onTap: minutes < 60 ? () => onChanged(minutes + 5) : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EnsomColors.surface2,
      shape: const CircleBorder(),
      child: InkWell(
        // onTap이 null이어도 빈 콜백을 주어 제스처를 흡수한다. 상/하한에서
        // 버튼을 눌러도 조상(있다면)으로 탭이 전달되지 않는다.
        onTap: onTap ?? () {},
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(
            icon,
            size: 14,
            color: onTap == null ? EnsomColors.inkFaint : EnsomColors.ink,
          ),
        ),
      ),
    );
  }
}

// ─── 루틴 항목 행 ────────────────────────────────────────────────────

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.onToggle,
    required this.onMinutesChanged,
  });

  final _RoutineItem routine;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onMinutesChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // 토글 InkWell은 체크박스+라벨 영역까지만. 스테퍼는 이 밖에 두어
          // 분 라벨·비활성 버튼 탭이 조상 InkWell로 전달돼 체크가 풀리는 것을
          // 막는다.
          Expanded(
            child: InkWell(
              onTap: () => onToggle(!routine.selected),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                child: Row(
                  children: [
                    _RoutineCheckbox(checked: routine.selected),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        routine.label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: EnsomColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (routine.selected)
            _MinuteStepper(
              minutes: routine.minutes,
              onChanged: onMinutesChanged,
            ),
        ],
      ),
    );
  }
}

class _RoutineCheckbox extends StatelessWidget {
  const _RoutineCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? EnsomColors.cta : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: checked ? EnsomColors.cta : EnsomColors.hairline,
          width: 1.6,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : null,
    );
  }
}

// ─── 합산 미리보기 ───────────────────────────────────────────────────

class _RoutineSummary extends StatelessWidget {
  const _RoutineSummary({
    required this.prepMinutes,
    required this.routineItems,
    required this.customRoutines,
  });

  final int? prepMinutes;
  final List<_RoutineItem> routineItems;
  final List<_RoutineItem> customRoutines;

  @override
  Widget build(BuildContext context) {
    final selectedRoutines = routineItems.where((r) => r.selected);
    final routineTotal =
        selectedRoutines.fold<int>(0, (sum, r) => sum + r.minutes) +
        customRoutines.fold<int>(0, (sum, r) => sum + r.minutes);

    if (prepMinutes == null && routineTotal == 0) {
      return const SizedBox.shrink();
    }

    final totalMin = (prepMinutes ?? 0) + routineTotal;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "예상 준비 시간 미리보기",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 9),
          if (prepMinutes != null)
            Text(
              "기본 준비: $prepMinutes분",
              style: const TextStyle(
                fontSize: 12.5,
                color: EnsomColors.inkMuted,
              ),
            ),
          if (routineTotal > 0) ...[
            Text(
              "루틴 합산: $routineTotal분",
              style: const TextStyle(
                fontSize: 12.5,
                color: EnsomColors.inkMuted,
              ),
            ),
            for (final r in selectedRoutines)
              Text(
                "  · ${r.label}: ${r.minutes}분",
                style: const TextStyle(
                  fontSize: 11.5,
                  color: EnsomColors.inkFaint,
                ),
              ),
            for (final r in customRoutines)
              Text(
                "  · ${r.label}: ${r.minutes}분",
                style: const TextStyle(
                  fontSize: 11.5,
                  color: EnsomColors.inkFaint,
                ),
              ),
          ],
          const Divider(height: 20, color: EnsomColors.hairline),
          Text(
            "총 약 $totalMin분",
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -.3,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "실제 이동 시간과 여유 시간은 일정별로 따로 계산됩니다.",
            style: TextStyle(fontSize: 10.5, color: EnsomColors.inkFaint),
          ),
        ],
      ),
    );
  }
}
