import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";

/// 화면연결명세서 §11 — 로딩은 스켈레톤으로 표시한다. 스피너는 스플래시
/// 워드마크 링에만 허용된다. 무지개색 shimmer 대신 surface-2 ↔ surface-neutral
/// 사이를 오가는 낮은 대비 펄스만 쓴다(§9.2 팔레트 밖 색 금지).
class EnsomSkeleton extends StatefulWidget {
  const EnsomSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  /// 텍스트 한 줄 자리. [widthFactor]로 줄 길이를 다르게 줘서 실제 문단처럼 보인다.
  const EnsomSkeleton.line({Key? key, double height = 12, double? width})
    : this(
        key: key,
        width: width ?? double.infinity,
        height: height,
        radius: 6,
      );

  /// 카드 한 장 자리. §9.3 카드 radius 18에 맞춘다.
  const EnsomSkeleton.card({Key? key, double height = 120})
    : this(key: key, width: double.infinity, height: height, radius: 18);

  final double width;
  final double height;
  final double radius;

  @override
  State<EnsomSkeleton> createState() => _EnsomSkeletonState();
}

class _EnsomSkeletonState extends State<EnsomSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            EnsomColors.surface2,
            EnsomColors.surfaceNeutral,
            _controller.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// 목록형 화면의 로딩 자리. 카드 [count]장을 [gap] 간격으로 쌓는다.
class EnsomSkeletonList extends StatelessWidget {
  const EnsomSkeletonList({
    super.key,
    this.count = 3,
    this.itemHeight = 120,
    this.gap = 12,
  });

  final int count;
  final double itemHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(height: gap),
          EnsomSkeleton.card(height: itemHeight),
        ],
      ],
    );
  }
}
