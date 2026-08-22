import "package:flutter/material.dart";
import "ensom_colors.dart";

/// 화면연결명세서 §9 공통 컴포넌트 규격을 ThemeData 기본값으로 고정한다.
/// 화면마다 카드 radius·시트 스크림을 다시 적어 넣지 않게 하는 것이 목적이다.
/// 색 토큰 자체는 [EnsomColors]가 단일 출처다.
ThemeData buildEnsomTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: EnsomColors.cta,
      brightness: Brightness.light,
      primary: EnsomColors.cta,
      secondary: EnsomColors.lime,
      surface: EnsomColors.surface1,
      // §9.2 빨강 금지 — 오류색도 caution(앰버)로 고정한다.
      error: EnsomColors.caution,
    ),
    scaffoldBackgroundColor: EnsomColors.canvas,
    dividerColor: EnsomColors.hairline,
    // §9.3 상단 바 — 흰색, 높이 40px, surfaceTint 제거
    appBarTheme: const AppBarTheme(
      backgroundColor: EnsomColors.canvas,
      foregroundColor: EnsomColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 40,
      centerTitle: false,
    ),
    // §9.3 카드 — radius 18, hairline 1px 테두리
    cardTheme: CardThemeData(
      color: EnsomColors.surface1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: EnsomColors.hairline),
      ),
    ),
    // §9.3 시트 — 상단만 radius 26, 스크림 rgba(20,21,15,.45)
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: EnsomColors.surface1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalBarrierColor: Color(0x7314150F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    // §9.3 다이얼로그 — 중앙 팝업, radius 22
    dialogTheme: DialogThemeData(
      backgroundColor: EnsomColors.surface1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    // §9.3 토스트 — cta 배경, 하단에서 올라옴
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: EnsomColors.cta,
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),
    // §9.4 터치 타겟 최소 44×44
    materialTapTargetSize: MaterialTapTargetSize.padded,
    useMaterial3: true,
  );
}
