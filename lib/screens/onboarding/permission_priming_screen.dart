import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";

/// ONB-07/08/08b 권한 프라이밍 공용 화면
/// PRD §11.4: "왜 필요한지" 설명 후 OS 권한 다이얼로그 트리거.
/// [나중에]는 항상 허용 (거부 후 재안내는 기능 진입점에서 1회만).
///
/// ensom_permission.html의 `.primewrap`(아이콘 원 + 헤드라인 + 설명 +
/// 안내 카드 + 버튼 2개) 레이아웃을 반영한다.
///
/// 사용법:
/// ```dart
/// PermissionPrimingScreen(
///   type: PermissionPrimingType.notification,
///   onAllow: () => requestPermission(),
///   onSkip: () => context.go("/next"),
/// )
/// ```
enum PermissionPrimingType { notification, location, calendar }

class PermissionPrimingScreen extends StatelessWidget {
  const PermissionPrimingScreen({
    super.key,
    required this.type,
    required this.onAllow,
    required this.onSkip,
  });

  final PermissionPrimingType type;
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  String get _title {
    switch (type) {
      case PermissionPrimingType.notification:
        return "알림을 보내도 될까요?";
      case PermissionPrimingType.location:
        return "위치 정보를 사용해도 될까요?";
      case PermissionPrimingType.calendar:
        return "캘린더를 연동할까요?";
    }
  }

  String get _description {
    switch (type) {
      case PermissionPrimingType.notification:
        return "준비 시작과 출발 시각을 놓치지 않도록\n시간에 맞춰 알려드려요.";
      case PermissionPrimingType.location:
        return "출발과 도착을 자동으로 감지해서\n더 정확한 시간 계획을 세울 수 있어요.";
      case PermissionPrimingType.calendar:
        return "다음 일정과 장소를 자동으로 인식해서\n따로 입력하지 않아도 준비 계획을 세워드려요.";
    }
  }

  String get _infoNote {
    switch (type) {
      case PermissionPrimingType.notification:
        return "필요한 순간에만 보내드려요 — 일정당 최대 3번이에요.";
      case PermissionPrimingType.location:
        return "위치 정보는 준비·이동 시간 계산에만 사용되고 암호화되어 저장돼요.";
      case PermissionPrimingType.calendar:
        return "일정의 시간과 장소만 읽어와요 — 참석자·본문 내용은 저장하지 않아요.";
    }
  }

  IconData get _icon {
    switch (type) {
      case PermissionPrimingType.notification:
        return Icons.notifications_outlined;
      case PermissionPrimingType.location:
        return Icons.location_on_outlined;
      case PermissionPrimingType.calendar:
        return Icons.calendar_today_outlined;
    }
  }

  String get _allowLabel {
    switch (type) {
      case PermissionPrimingType.notification:
        return "알림 켜기";
      case PermissionPrimingType.location:
        return "위치 허용";
      case PermissionPrimingType.calendar:
        return "캘린더 연동하기";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: EnsomColors.surface2,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(_icon, size: 28, color: EnsomColors.inkFaint),
              ),
              const SizedBox(height: 18),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                  height: 1.35,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                _description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: EnsomColors.inkMuted,
                  height: 1.6,
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: EnsomColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _infoNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: EnsomColors.inkMuted,
                    height: 1.55,
                  ),
                ),
              ),
              const Spacer(flex: 3),
              EnsomPillButton(label: _allowLabel, onPressed: onAllow),
              const SizedBox(height: 4),
              EnsomPillButton(
                label: "나중에",
                variant: EnsomPillVariant.text,
                onPressed: onSkip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
