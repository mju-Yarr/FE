import "package:flutter/material.dart";
import "../theme/ensom_colors.dart";

/// 코치마크 스팟 정의.
class _CoachmarkSpot {
  const _CoachmarkSpot({
    required this.center,
    required this.radius,
    required this.tooltip,
    required this.tooltipAlignment,
  });

  final Offset center;
  final double radius;
  final String tooltip;
  final Alignment tooltipAlignment;
}

/// 홈 화면 최초 진입 시 표시되는 코치마크 오버레이.
/// 최대 2개의 스팟을 반투명 배경 위에 원형 컷아웃으로 강조하고,
/// 각 스팟 옆에 툴팁 버블을 보여준다.
///
/// 탭하면(어디든) 또는 "확인" 버튼을 누르면 닫힌다.
class CoachmarkOverlay extends StatefulWidget {
  const CoachmarkOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<CoachmarkOverlay> createState() => _CoachmarkOverlayState();
}

class _CoachmarkOverlayState extends State<CoachmarkOverlay> {
  int _currentSpot = 0;

  List<_CoachmarkSpot> _buildSpots(Size screenSize) {
    return [
      // Spot 1: 알림 벨 아이콘 (AppBar 우측 상단)
      _CoachmarkSpot(
        center: Offset(screenSize.width - 40, kToolbarHeight + 12),
        radius: 28,
        tooltip: "오늘의 알림을 확인하세요",
        tooltipAlignment: Alignment.centerLeft,
      ),
      // Spot 2: 플랜 카드 영역 (화면 중앙)
      _CoachmarkSpot(
        center: Offset(screenSize.width / 2, screenSize.height * 0.45),
        radius: 60,
        tooltip: "일정 카드를 탭해서 상세를 확인하세요",
        tooltipAlignment: Alignment.center,
      ),
    ];
  }

  void _next() {
    if (_currentSpot < 1) {
      setState(() => _currentSpot = 1);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final spots = _buildSpots(screenSize);
    final spot = spots[_currentSpot];

    return GestureDetector(
      onTap: _next,
      child: Stack(
        children: [
          // 반투명 배경 + 원형 컷아웃
          CustomPaint(
            size: screenSize,
            painter: _SpotlightPainter(
              center: spot.center,
              radius: spot.radius,
            ),
          ),
          // 툴팁 버블
          Positioned(
            left: _tooltipLeft(spot, screenSize),
            top: _tooltipTop(spot),
            child: Container(
              constraints: BoxConstraints(maxWidth: screenSize.width * 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: EnsomColors.canvas,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: EnsomColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                spot.tooltip,
                style: const TextStyle(
                  color: EnsomColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // 확인 버튼
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: EnsomColors.lime,
                  foregroundColor: EnsomColors.limeInk,
                ),
                child: Text(_currentSpot < 1 ? "다음" : "확인"),
              ),
            ),
          ),
          // 인디케이터
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentSpot
                        ? EnsomColors.lime
                        : EnsomColors.inkMuted.withValues(alpha: 0.4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  double _tooltipLeft(_CoachmarkSpot spot, Size screenSize) {
    if (spot.tooltipAlignment == Alignment.centerLeft) {
      // 벨 아이콘 좌측에 배치
      return spot.center.dx - screenSize.width * 0.65;
    }
    return screenSize.width * 0.15;
  }

  double _tooltipTop(_CoachmarkSpot spot) {
    return spot.center.dy + spot.radius + 16;
  }
}

/// 반투명 배경에 원형 구멍을 뚫는 페인터.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = EnsomColors.scrim;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      center != oldDelegate.center || radius != oldDelegate.radius;
}
