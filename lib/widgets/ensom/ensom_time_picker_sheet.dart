import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";
import "ensom_pill_button.dart";

/// ensom_pickers.html "시간 선택기" 반영 — 시/분 휠 + 오전·오후
/// 세그먼트 바텀시트. 목업은 수동 스크롤+스냅 JS를 쓰지만, 여기서는
/// 같은 느낌을 내는 Flutter 기본 위젯인 `ListWheelScrollView`로
/// 구현했다(휠 스냅·중앙 강조가 이미 내장돼 있어 더 자연스럽다).
class EnsomTimePickerSheet {
  static Future<TimeOfDay?> show(
    BuildContext context, {
    required TimeOfDay initial,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: EnsomColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _TimePickerSheetBody(initial: initial),
    );
  }
}

class _TimePickerSheetBody extends StatefulWidget {
  const _TimePickerSheetBody({required this.initial});

  final TimeOfDay initial;

  @override
  State<_TimePickerSheetBody> createState() => _TimePickerSheetBodyState();
}

class _TimePickerSheetBodyState extends State<_TimePickerSheetBody> {
  late bool _isPm = widget.initial.hour >= 12;
  late int _hour12 = () {
    final h = widget.initial.hour % 12;
    return h == 0 ? 12 : h;
  }();
  late int _minute = widget.initial.minute;

  late final _hourController = FixedExtentScrollController(
    initialItem: _hour12 - 1,
  );
  late final _minuteController = FixedExtentScrollController(
    initialItem: _minute,
  );

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _confirm() {
    var hour24 = _hour12 % 12;
    if (_isPm) hour24 += 12;
    Navigator.pop(context, TimeOfDay(hour: hour24, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: EnsomColors.surfaceNeutral,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "시작 시각",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: EnsomColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Wheel(
                      controller: _hourController,
                      itemCount: 12,
                      labelBuilder: (i) => "${i + 1}",
                      onChanged: (i) => setState(() => _hour12 = i + 1),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        ":",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: EnsomColors.inkFaint,
                        ),
                      ),
                    ),
                    _Wheel(
                      controller: _minuteController,
                      itemCount: 60,
                      labelBuilder: (i) => i.toString().padLeft(2, "0"),
                      onChanged: (i) => setState(() => _minute = i),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: EnsomColors.surface2,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AmPmSegment(
                    label: "오전",
                    selected: !_isPm,
                    onTap: () => setState(() => _isPm = false),
                  ),
                ),
                Expanded(
                  child: _AmPmSegment(
                    label: "오후",
                    selected: _isPm,
                    onTap: () => setState(() => _isPm = true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EnsomPillButton(label: "확인", onPressed: _confirm),
        ],
      ),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late int _selectedIndex = widget.controller.initialItem;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 170,
      child: ListWheelScrollView.useDelegate(
        controller: widget.controller,
        itemExtent: 34,
        perspective: 0.003,
        diameterRatio: 1.6,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          setState(() => _selectedIndex = index);
          widget.onChanged(index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.itemCount,
          builder: (context, index) {
            final selected = index == _selectedIndex;
            return Center(
              child: Text(
                widget.labelBuilder(index),
                style: TextStyle(
                  fontSize: selected ? 19 : 17,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? EnsomColors.ink : EnsomColors.inkFaint,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmPmSegment extends StatelessWidget {
  const _AmPmSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? EnsomColors.cta : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : EnsomColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
