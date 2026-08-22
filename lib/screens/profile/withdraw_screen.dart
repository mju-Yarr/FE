import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_sign_in/google_sign_in.dart";
import "../../core/logout_helper.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";

/// PRF-04 회원 탈퇴 2단계
/// 기존 account_screen.dart에서 분리.
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  int _step = 1;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원 탈퇴")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _step == 1 ? _buildStep1() : _buildStep2(),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §3 S-14F 탈퇴 영역에는 강조색을 쓰지 않는다. §12 느낌표·경고 아이콘도
        // 쓰지 않는다 — 문구만으로 충분히 무겁다.
        const Icon(
          Icons.person_remove_outlined,
          size: 40,
          color: EnsomColors.inkMuted,
        ),
        const SizedBox(height: 16),
        Text("정말 탈퇴하시겠어요?", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text("탈퇴하면 다음 데이터가 모두 삭제되며 복구할 수 없어요."),
        const SizedBox(height: 12),
        const Text("• 일정과 준비 계획"),
        const Text("• 맞춤 준비 항목과 개인화 기록"),
        const Text("• 웰니스 설정과 행동 기록"),
        const SizedBox(height: 8),
        const Text(
          "동의 이력만 법적 의무에 따라 보존됩니다.",
          style: TextStyle(color: EnsomColors.inkMuted, fontSize: 12),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("취소"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EnsomColors.surface2,
                  foregroundColor: EnsomColors.ink,
                  elevation: 0,
                ),
                child: const Text("탈퇴할게요"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("마지막 확인", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Text("본인 확인을 위해 다시 한번 로그인해주세요."),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _processing ? null : _withdraw,
            icon: _processing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_remove_outlined, size: 17),
            label: Text(_processing ? "처리 중..." : "탈퇴 확인"),
            style: ElevatedButton.styleFrom(
              backgroundColor: EnsomColors.surface2,
              foregroundColor: EnsomColors.ink,
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _withdraw() async {
    setState(() => _processing = true);
    try {
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("본인 확인이 필요해요.")));
          setState(() => _processing = false);
        }
        return;
      }

      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete("/me");
      await clearLocalCaches(ref);
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("탈퇴가 완료됐어요."),
            content: const Text("그동안 이용해주셔서 고마워요."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(authNotifierProvider.notifier).logout();
                },
                child: const Text("확인"),
              ),
            ],
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _processing = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("본인 확인에 실패했어요. 다시 시도해주세요.")),
        );
        setState(() => _processing = false);
      }
    }
  }
}
