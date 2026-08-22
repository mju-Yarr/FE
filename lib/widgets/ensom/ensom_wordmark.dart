import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";

/// "ENS(O)M" 워드마크. 목업(ensom_priming_splash.html / ensom_auth.html /
/// ensom_prototype.html)의 워드마크를 그대로 옮긴 것 — O 자리의 링이
/// 스플래시에서는 로딩 인디케이터를 겸한다(§1.1 "별도 로딩 인디케이터를
/// 두지 않는다").
class EnsomWordmark extends StatefulWidget {
  const EnsomWordmark({
    super.key,
    this.fontSize = 40,
    this.color = EnsomColors.ink,
    this.animate = false,
  });

  final double fontSize;
  final Color color;

  /// true면 링이 1.05초 주기로 회전한다(스플래시 전용).
  /// false면 정지된 상태로 그린다(로그인 화면 상단 워드마크 등).
  final bool animate;

  @override
  State<EnsomWordmark> createState() => _EnsomWordmarkState();
}

class _EnsomWordmarkState extends State<EnsomWordmark>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1050),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.fontSize * 0.82;
    final ring = SizedBox(
      width: ringSize,
      height: ringSize,
      child: _controller == null
          ? CustomPaint(painter: _RingPainter(0, widget.color))
          : AnimatedBuilder(
              animation: _controller!,
              builder: (context, _) => CustomPaint(
                painter: _RingPainter(_controller!.value, widget.color),
              ),
            ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "ENS",
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: widget.fontSize * 0.075,
            color: widget.color,
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ring,
        ),
        Text(
          "M",
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: widget.fontSize * 0.075,
            color: widget.color,
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// 트랙(잉크 18%) + arc(잉크 100%, 68% 둘레) 링. progress(0~1)가 arc의
/// 회전 각도를 결정한다 — 목업의 `stroke-dasharray:47 22` 비율과 동일.
class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - size.width * 0.11;
    final strokeWidth = size.width * 0.22;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const sweepFraction = 47 / (47 + 22); // dasharray 47 22
    final startAngle = -1.5708 + progress * 6.28319; // -90deg + spin
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      6.28319 * sweepFraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
