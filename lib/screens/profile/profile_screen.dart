import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../providers/auth_providers.dart";
import "../../providers/bootstrap_provider.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_wordmark.dart";

/// PRF-01 프로필 메인 리스트
/// 화면설계서: 계정→PRF-02, 권한→PRF-05, 준비설정→PRF-06,
///           알림→PRF-07, 개인화→PRF-08, 데이터→PRF-09
///
/// ensom_profile.html의 프로필 메인 리스트 레이아웃(아바타+이름+이메일
/// 헤더, 섹션 라벨 + 아이콘 행)을 반영한다. 로그아웃은 목업처럼
/// "계정" 하위 화면으로 옮기고(이미 account_screen.dart에 있음) 이
/// 메인 리스트에서는 뺐다 — 중복 진입점을 두지 않기 위해서다.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final bootstrap = ref.watch(bootstrapProvider).value;
    final nickname = bootstrap?.user.nickname ?? "";
    final grantedCount = bootstrap?.permissions
        .where((p) => p.status == "granted")
        .length;

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            const EnsomWordmark(fontSize: 15),
            const SizedBox(height: 18),
            _ProfileHeader(nickname: nickname, email: authState.email),
            const SizedBox(height: 8),
            _ProfileSection(
              title: "계정",
              items: [
                _ProfileItem(
                  icon: Icons.person_outline,
                  label: "로그인 계정 정보",
                  onTap: () => context.push("/profile/account"),
                ),
              ],
            ),
            _ProfileSection(
              title: "권한 · 설정",
              items: [
                _ProfileItem(
                  icon: Icons.shield_outlined,
                  label: "권한 관리",
                  valuePill: grantedCount != null ? "$grantedCount건 허용" : null,
                  onTap: () => context.push("/profile/permissions"),
                ),
                _ProfileItem(
                  icon: Icons.schedule_outlined,
                  label: "준비 설정",
                  onTap: () => context.push("/profile/prep"),
                ),
                _ProfileItem(
                  icon: Icons.notifications_outlined,
                  label: "알림",
                  onTap: () => context.push("/profile/notifications"),
                ),
                _ProfileItem(
                  icon: Icons.spa_outlined,
                  label: "웰니스",
                  onTap: () => context.push("/settings/wellness-prefs"),
                ),
              ],
            ),
            _ProfileSection(
              title: "기록",
              items: [
                _ProfileItem(
                  icon: Icons.bar_chart_outlined,
                  label: "주간 리포트",
                  subtitle: "준비·도착 흐름과 환경 노출 요약",
                  onTap: () => context.push("/calendar/weekly-report"),
                ),
              ],
            ),
            _ProfileSection(
              title: "개인화 · 데이터",
              items: [
                _ProfileItem(
                  icon: Icons.auto_graph,
                  label: "개인화",
                  onTap: () => context.push("/profile/personalization"),
                ),
                _ProfileItem(
                  icon: Icons.storage_outlined,
                  label: "데이터",
                  onTap: () => context.push("/profile/data"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.nickname, required this.email});

  final String nickname;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final initial = nickname.isNotEmpty ? nickname.substring(0, 1) : "?";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: EnsomColors.surface2,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: EnsomColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nickname.isNotEmpty ? "$nickname님" : "회원님",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.2,
                  color: EnsomColors.ink,
                ),
              ),
              if (email != null) ...[
                const SizedBox(height: 2),
                Text(
                  email!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: EnsomColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.items});

  final String title;
  final List<_ProfileItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 4),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: EnsomColors.inkFaint,
              letterSpacing: .4,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.valuePill,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String? valuePill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: EnsomColors.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: EnsomColors.inkMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EnsomColors.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (valuePill != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: EnsomColors.limeSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  valuePill!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: EnsomColors.limeInk,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right,
              size: 15,
              color: EnsomColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}
