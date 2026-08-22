import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";

/// 목업 `.topbar` — 다크 앱바 대신 라이트 배경 위 원형 뒤로가기 버튼 +
/// 제목. 인증/온보딩 서브 화면들이 공통으로 쓴다.
class EnsomTopBar extends StatelessWidget implements PreferredSizeWidget {
  const EnsomTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final VoidCallback? onBack;

  /// 우측 액션. 없으면 기존과 동일하게 제목만 남는다.
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Material(
                color: EnsomColors.surface2,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 14,
                      color: EnsomColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                    color: EnsomColors.ink,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
