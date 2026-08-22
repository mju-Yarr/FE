import "package:flutter/material.dart";
import "../theme/ensom_colors.dart";

/// PICK-01~03 공용 피커 시트 — v6 프로토타입 기준 redesign
/// 디자인 기준: Ensom_프로토타입_v6_최종/06_공통·P1/ensom_pickers.html

/// PICK-01: 날짜 선택 → DateTime 반환
Future<DateTime?> showDatePickerSheet(
  BuildContext context, {
  DateTime? initial,
}) {
  return showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime.now().subtract(const Duration(days: 30)),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
}

/// PICK-02: 시간 선택 → TimeOfDay 반환
Future<TimeOfDay?> showTimePickerSheet(
  BuildContext context, {
  TimeOfDay? initial,
}) {
  return showTimePicker(
    context: context,
    initialTime: initial ?? TimeOfDay.now(),
  );
}

/// PICK-03: 소요시간 선택 바텀시트 → int(분) 반환
Future<int?> showDurationPickerSheet(
  BuildContext context, {
  int initialMinutes = 30,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DurationPickerSheet(initialMinutes: initialMinutes),
  );
}

class _DurationPickerSheet extends StatefulWidget {
  const _DurationPickerSheet({required this.initialMinutes});
  final int initialMinutes;

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  late int _minutes;
  static const _quickOptions = [10, 15, 20, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EnsomColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: EnsomColors.surfaceNeutral,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 14),
          // 제목
          const Text(
            "소요 시간",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          // 칩 선택
          Wrap(
            spacing: 7,
            runSpacing: 9,
            children: _quickOptions.map((min) {
              final isSelected = _minutes == min;
              return GestureDetector(
                onTap: () => setState(() => _minutes = min),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? EnsomColors.cta : EnsomColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$min분",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : EnsomColors.ink,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // +/- 조절
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleButton(
                icon: Icons.remove,
                enabled: _minutes > 5,
                onTap: () => setState(() => _minutes -= 5),
              ),
              const SizedBox(width: 20),
              Text(
                "$_minutes분",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(width: 20),
              _CircleButton(
                icon: Icons.add,
                enabled: _minutes < 180,
                onTap: () => setState(() => _minutes += 5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 확인 버튼
          GestureDetector(
            onTap: () => Navigator.pop(context, _minutes),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: EnsomColors.cta,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: const Text(
                "확인",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: EnsomColors.surface2,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: enabled ? EnsomColors.ink : EnsomColors.inkFaint,
        ),
      ),
    );
  }
}
