import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";

/// PRF-07 알림 설정 — v6 프로토타입 기준 redesign
/// 디자인 기준: Ensom_프로토타입_v6_최종/05_설정/ensom_profile.html (v-noti)
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _loading = true;
  String _sensitivity = "normal"; // low, normal, high
  bool _timeNotification = true;
  bool _trafficNotification = true;
  bool _wellnessNotification = false;
  bool _lockscreenHide = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<Map<String, dynamic>>("/me/settings");
      if (mounted) {
        setState(() {
          _sensitivity = data["notificationSensitivity"] ?? "normal";
          _lockscreenHide = data["lockscreenHideSensitive"] ?? true;
          _wellnessNotification = data["wellnessEventEnabled"] ?? false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() => _saving = true);
    final fullBody = {
      "initialPrepMinutes": null,
      "arrivalBufferMinutes": 10,
      "notificationSensitivity": _sensitivity,
      "personalizationEnabled": true,
      "autoManageEnabled": true,
      "wellnessEventEnabled": _wellnessNotification,
      "lockscreenHideSensitive": _lockscreenHide,
      ...patch,
    };
    try {
      final api = ref.read(apiClientProvider);
      await api.patch("/me/settings", body: fullBody);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("설정 저장에 실패했어요.")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: EnsomColors.canvas,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // 알림 민감도 세그먼트
                  const _SectionLabel("알림 민감도"),
                  _SegmentedControl(
                    selected: _sensitivity,
                    options: const [
                      ("low", "적게"),
                      ("normal", "보통"),
                      ("high", "자주"),
                    ],
                    onChanged: (v) {
                      setState(() => _sensitivity = v);
                      _save({"notificationSensitivity": v});
                    },
                  ),

                  const _Divider(),

                  // 일정별 알림 토글
                  const _SectionLabel("일정별 알림"),
                  _ToggleRow(
                    title: "시간 알림",
                    value: _timeNotification,
                    onChanged: (v) => setState(() => _timeNotification = v),
                  ),
                  _ToggleRow(
                    title: "교통 지연 알림",
                    value: _trafficNotification,
                    onChanged: (v) => setState(() => _trafficNotification = v),
                  ),
                  _ToggleRow(
                    title: "웰니스 알림",
                    value: _wellnessNotification,
                    onChanged: (v) {
                      setState(() => _wellnessNotification = v);
                      _save({"wellnessEventEnabled": v});
                    },
                  ),

                  const _Divider(),

                  // 잠금화면 표시
                  const _SectionLabel("잠금화면 표시"),
                  _ToggleRow(
                    title: "잠금화면에서 민감한 정보 숨기기",
                    subtitle: "복용약 등 민감 항목은 잠금화면에서 일반화되어 표시돼요",
                    value: _lockscreenHide,
                    onChanged: (v) {
                      setState(() => _lockscreenHide = v);
                      _save({"lockscreenHideSensitive": v});
                    },
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _BackButton(onTap: () => context.pop()),
          const SizedBox(width: 10),
          Text(
            "알림",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: EnsomColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Components ───

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: EnsomColors.surface2,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.chevron_left, size: 14, color: EnsomColors.ink),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: EnsomColors.inkFaint,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 22),
      color: EnsomColors.hairline,
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String selected;
  final List<(String value, String label)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt.$1 == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? EnsomColors.cta : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : EnsomColors.inkMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: EnsomColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11, color: EnsomColors.inkFaint),
                  ),
                ],
              ],
            ),
          ),
          _EnsomToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _EnsomToggle extends StatelessWidget {
  const _EnsomToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 25,
        decoration: BoxDecoration(
          color: value ? EnsomColors.cta : EnsomColors.surfaceNeutral,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2.5),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? EnsomColors.lime : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
