import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:permission_handler/permission_handler.dart";
import "../../theme/ensom_colors.dart";

/// PRF-05 권한 관리 — v6 프로토타입 기준 redesign
/// 디자인 기준: Ensom_프로토타입_v6_최종/05_설정/ensom_profile.html (v-perm)
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  Map<Permission, PermissionStatus> _statuses = {};
  bool _alwaysLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final current = <Permission, PermissionStatus>{};
    for (final p in [
      Permission.notification,
      Permission.location,
      Permission.locationAlways,
    ]) {
      current[p] = await p.status;
    }
    if (mounted) {
      setState(() {
        _statuses = current;
        _alwaysLocation =
            current[Permission.locationAlways]?.isGranted ?? false;
      });
    }
  }

  String _pillText(PermissionStatus? status) {
    if (status == null) return "확인 중";
    if (status.isGranted) return "허용됨";
    if (status.isPermanentlyDenied) return "차단됨";
    return "허용 안 함";
  }

  bool _isGranted(PermissionStatus? status) => status?.isGranted ?? false;

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 16),
                  // 캘린더 연동
                  _PermissionCard(
                    title: "캘린더 연동",
                    pillText: "연동됨",
                    isGranted: true,
                    onTap: () => context.push("/calendar/connections"),
                  ),
                  const SizedBox(height: 10),
                  // 위치
                  _PermissionCard(
                    title: "위치",
                    pillText: _pillText(_statuses[Permission.location]),
                    isGranted: _isGranted(_statuses[Permission.location]),
                    onTap: openAppSettings,
                  ),
                  const SizedBox(height: 10),
                  // 알림
                  _PermissionCard(
                    title: "알림",
                    pillText: _pillText(_statuses[Permission.notification]),
                    isGranted: _isGranted(_statuses[Permission.notification]),
                    onTap: openAppSettings,
                  ),

                  // 구분선
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(top: 16),
                    color: EnsomColors.hairline,
                  ),

                  // 자동 출발·도착 확인 섹션
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Text(
                      "자동 출발 · 도착 확인",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: EnsomColors.inkFaint,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  _AlwaysLocationCard(
                    isEnabled: _alwaysLocation,
                    onChanged: (v) async {
                      if (v) {
                        await openAppSettings();
                      } else {
                        await openAppSettings();
                      }
                    },
                  ),

                  // 안내 카드
                  if (_alwaysLocation) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: EnsomColors.surface2,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        "위치 정보는 준비·이동 시간 계산에만 사용되고 암호화되어 저장돼요. 언제든 이 화면에서 다시 끌 수 있어요.",
                        style: TextStyle(
                          fontSize: 12,
                          color: EnsomColors.inkMuted,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
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
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: EnsomColors.surface2,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.chevron_left,
                size: 14,
                color: EnsomColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "권한",
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

// ─── Permission Card ───

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.title,
    required this.pillText,
    required this.isGranted,
    required this.onTap,
  });

  final String title;
  final String pillText;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: EnsomColors.surface1,
          border: Border.all(color: EnsomColors.hairline),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: EnsomColors.ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isGranted ? EnsomColors.limeSoft : EnsomColors.surface2,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                pillText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isGranted ? EnsomColors.limeInk : EnsomColors.inkMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 14,
              color: EnsomColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Always Location Card ───

class _AlwaysLocationCard extends StatelessWidget {
  const _AlwaysLocationCard({required this.isEnabled, required this.onChanged});

  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "항상 위치 허용",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: EnsomColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "앱을 쓰지 않을 때도 출발·도착을 자동으로 확인해요.",
                  style: TextStyle(
                    fontSize: 12,
                    color: EnsomColors.inkMuted,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => onChanged(!isEnabled),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42,
              height: 25,
              decoration: BoxDecoration(
                color: isEnabled ? EnsomColors.cta : EnsomColors.surfaceNeutral,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: isEnabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2.5),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isEnabled ? EnsomColors.lime : Colors.white,
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
          ),
        ],
      ),
    );
  }
}
