import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";
import "ensom_pill_button.dart";

/// ensom_pickers.html "날짜 선택기" 반영 — 월 이동 화살표 + 달력
/// 그리드 바텀시트. 오늘은 라임 채움, 선택한 날은 딥차콜 채움.
class EnsomDatePickerSheet {
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initial,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: EnsomColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _DatePickerSheetBody(initial: initial),
    );
  }
}

class _DatePickerSheetBody extends StatefulWidget {
  const _DatePickerSheetBody({required this.initial});

  final DateTime initial;

  @override
  State<_DatePickerSheetBody> createState() => _DatePickerSheetBodyState();
}

class _DatePickerSheetBodyState extends State<_DatePickerSheetBody> {
  static const _dow = ["일", "월", "화", "수", "목", "금", "토"];

  late DateTime _focusedMonth = DateTime(
    widget.initial.year,
    widget.initial.month,
    1,
  );
  late DateTime _selected = DateTime(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
  );

  void _shiftMonth(int delta) {
    setState(
      () => _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
        1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final leading = monthStart.weekday % 7;
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final gridStart = monthStart.subtract(Duration(days: leading));
    final cellCount = ((leading + daysInMonth) / 7).ceil() * 7;

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
            "날짜 선택",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(
                icon: Icons.chevron_left,
                onTap: () => _shiftMonth(-1),
              ),
              Text(
                "${_focusedMonth.year}년 ${_focusedMonth.month}월",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: EnsomColors.ink,
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right,
                onTap: () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _dow
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: EnsomColors.inkFaint,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              mainAxisExtent: 34,
            ),
            itemBuilder: (context, i) {
              final date = gridStart.add(Duration(days: i));
              final inMonth = date.month == _focusedMonth.month;
              if (!inMonth) {
                return Center(
                  child: Text(
                    "${date.day}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.inkFaint.withValues(alpha: .4),
                    ),
                  ),
                );
              }
              final isToday = date == todayOnly;
              final isSelected = date == _selected;
              return Center(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = date),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? EnsomColors.cta
                          : (isToday ? EnsomColors.lime : Colors.transparent),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "${date.day}",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: (isSelected || isToday)
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected ? Colors.white : EnsomColors.ink,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          EnsomPillButton(
            label: "확인",
            onPressed: () => Navigator.pop(context, _selected),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EnsomColors.surface2,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 14, color: EnsomColors.ink),
        ),
      ),
    );
  }
}
