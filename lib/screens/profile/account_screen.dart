import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/logout_helper.dart";
import "../../providers/auth_providers.dart";
import "../../providers/bootstrap_provider.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

/// PRF-02 계정 정보. ensom_profile.html "1. 계정 정보" 화면을 반영 —
/// 아바타+이름+이메일+가입일 카드, 로그아웃, danger-zone(회원 탈퇴).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final bootstrap = ref.watch(bootstrapProvider).value;
    final nickname = bootstrap?.user.nickname ?? "";
    final initial = nickname.isNotEmpty ? nickname.substring(0, 1) : "?";

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "계정"),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: EnsomColors.surface1,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: EnsomColors.hairline),
              ),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname.isNotEmpty ? "$nickname님" : "회원님",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: EnsomColors.ink,
                          ),
                        ),
                        if (authState.email != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            authState.email!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: EnsomColors.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _AccountRow(
              icon: Icons.lock_outline,
              label: "비밀번호 변경",
              onTap: () => context.push("/profile/change-password"),
            ),
            _AccountRow(
              icon: Icons.email_outlined,
              label: "이메일 변경",
              onTap: () => context.push("/profile/change-email"),
            ),
            _AccountRow(
              icon: Icons.vpn_key_outlined,
              label: "로그인 수단",
              onTap: () => context.push("/profile/providers"),
            ),
            // 로그인 기록은 MVP 범위에서 제외됐다(명세 §3 S-24 조건·예외, §14).
            // 화면(sessions_screen.dart)과 /profile/sessions 라우트, BE의
            // /me/sessions는 그대로 두고 진입만 막는다 — 범위에 들어오면
            // 이 행만 되살리면 된다.
            const Divider(height: 26, color: EnsomColors.hairline),
            _AccountRow(
              icon: Icons.logout,
              label: "로그아웃",
              onTap: () => showLogoutConfirmAndExecute(context, ref),
            ),
            Container(
              margin: const EdgeInsets.only(top: 22),
              padding: const EdgeInsets.only(top: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: EnsomColors.hairline)),
              ),
              child: _AccountRow(
                icon: Icons.person_off_outlined,
                label: "회원 탈퇴",
                muted: true,
                onTap: () => context.push("/profile/withdraw"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: muted ? EnsomColors.inkFaint : EnsomColors.inkMuted,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: muted ? EnsomColors.inkMuted : EnsomColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
