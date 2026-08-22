import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:permission_handler/permission_handler.dart";
import "../theme/ensom_colors.dart";

enum DegradedPermissionType { notification, location, calendar }

/// S-35 권한 거부 안내 + S-36 OS 설정 안내.
/// 닫으면 현재 위젯 생명주기 동안 다시 노출하지 않는다.
class PermissionDegradedBanner extends StatefulWidget {
  const PermissionDegradedBanner({
    super.key,
    required this.type,
    this.deniedOverride,
  });

  final DegradedPermissionType type;
  final bool? deniedOverride;

  @override
  State<PermissionDegradedBanner> createState() =>
      _PermissionDegradedBannerState();
}

class _PermissionDegradedBannerState extends State<PermissionDegradedBanner>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _denied = false;
  bool _dismissed = false;

  Permission? get _permission => switch (widget.type) {
    DegradedPermissionType.notification => Permission.notification,
    DegradedPermissionType.location => Permission.location,
    DegradedPermissionType.calendar => null,
  };

  String get _title => switch (widget.type) {
    DegradedPermissionType.notification => "알림이 꺼져 있어요",
    DegradedPermissionType.location => "위치 권한이 꺼져 있어요",
    DegradedPermissionType.calendar => "캘린더 연동이 꺼져 있어요",
  };

  String get _description => switch (widget.type) {
    DegradedPermissionType.notification => "홈 카드에서 준비·출발 시각을 직접 확인할 수 있어요.",
    DegradedPermissionType.location => "출발했어요 버튼과 도착 확인으로 계속 이용할 수 있어요.",
    DegradedPermissionType.calendar => "일정 만들기 버튼으로 직접 일정을 추가할 수 있어요.",
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant PermissionDegradedBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deniedOverride != widget.deniedOverride) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (widget.deniedOverride != null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _denied = widget.deniedOverride!;
      });
      return;
    }

    final permission = _permission;
    if (permission == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final status = await permission.status;
    if (!mounted) return;
    final isDenied =
        status.isDenied || status.isPermanentlyDenied || status.isRestricted;
    setState(() {
      _loading = false;
      _denied = isDenied;
      // 설정에서 돌아온 뒤 권한이 허용되었으면 배너 자동 닫기
      if (!isDenied) _dismissed = true;
    });
  }

  Future<void> _showSettingsGuide() async {
    if (widget.type == DegradedPermissionType.calendar) {
      await context.push("/calendar/connections");
      return;
    }

    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("시스템 설정에서 권한 켜기"),
        content: Text(
          "설정에서 Ensom을 선택한 뒤 $_title 항목을 허용해주세요. 권한을 켜지 않아도 앱은 계속 사용할 수 있어요.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("지금은 괜찮아요"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("설정 열기"),
          ),
        ],
      ),
    );
    if (open == true) await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_denied || _dismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: EnsomColors.caution, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: EnsomColors.caution),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _description,
                  style: const TextStyle(
                    color: EnsomColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
                TextButton(
                  onPressed: _showSettingsGuide,
                  child: Text(
                    widget.type == DegradedPermissionType.calendar
                        ? "연동 관리"
                        : "설정에서 켜기",
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: "이번 세션에서 닫기",
            onPressed: () => setState(() => _dismissed = true),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
