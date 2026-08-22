import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_error_banner.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_text_field.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

/// S-26 이메일 변경. ensom_account.html "v2 이메일 변경" 반영.
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post<Map<String, dynamic>>(
        "/me/email/change-request",
        body: {
          "newEmail": _emailCtrl.text.trim(),
          "password": _passwordCtrl.text,
        },
      );
      if (mounted) {
        setState(() {
          _submitting = false;
          _sent = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.isNetworkError ? "네트워크에 연결할 수 없어요. 다시 시도해주세요." : e.message;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = ref.watch(authNotifierProvider).email;

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "이메일 변경"),
      body: SafeArea(
        top: false,
        child: _sent ? _buildSentState() : _buildFormState(currentEmail),
      ),
    );
  }

  Widget _buildFormState(String? currentEmail) {
    final canSubmit =
        !_submitting &&
        _emailCtrl.text.trim().isNotEmpty &&
        _passwordCtrl.text.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            children: [
              if (currentEmail != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: EnsomColors.surface2,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "현재 이메일",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: EnsomColors.inkFaint,
                          letterSpacing: .3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: EnsomColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              EnsomTextField(
                label: "새 이메일",
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              EnsomTextField(
                label: "비밀번호 확인",
                controller: _passwordCtrl,
                obscureText: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: EnsomColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "새 이메일로 인증 메일을 보내드려요. 인증을 완료해야 변경이 적용돼요.",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: EnsomColors.inkMuted,
                    height: 1.5,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                EnsomErrorBanner(title: _error!),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: const BoxDecoration(
            color: EnsomColors.surface1,
            border: Border(top: BorderSide(color: EnsomColors.hairline)),
          ),
          child: EnsomPillButton(
            label: _submitting ? "보내는 중..." : "인증 메일 보내기",
            onPressed: canSubmit ? _submit : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSentState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 18),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: EnsomColors.surface2,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 26,
              color: EnsomColors.inkMuted,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "인증 메일을 보냈어요",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 9),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                color: EnsomColors.inkMuted,
                height: 1.6,
              ),
              children: [
                TextSpan(
                  text: _emailCtrl.text.trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: EnsomColors.ink,
                  ),
                ),
                const TextSpan(text: " 로\n보낸 메일에서 인증을 완료해 주세요."),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "인증 전까지는 기존 이메일로 로그인해요",
            style: TextStyle(fontSize: 10.5, color: EnsomColors.inkFaint),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: const Text(
              "다시 보내기",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 4),
          EnsomPillButton(
            label: "돌아가기",
            variant: EnsomPillVariant.secondary,
            onPressed: () => setState(() => _sent = false),
          ),
        ],
      ),
    );
  }
}
