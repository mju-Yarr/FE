import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "../../theme/ensom_colors.dart";

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

const _faqs = [
  _Faq(
    "로그인이 안 돼요",
    "네트워크 연결을 먼저 확인해 주세요. 연결에 문제가 없는데도 로그인이 되지 않으면 아래 문의하기로 알려주세요.",
  ),
  _Faq(
    "캘린더 일정이 안 보여요",
    "설정 > 권한에서 캘린더 연동 상태를 확인해 주세요. 연동된 계정에서 개별 캘린더가 꺼져 있을 수도 있어요.",
  ),
  _Faq(
    "준비 시간이 실제와 안 맞아요",
    "Ensom은 실제 준비·이동 기록을 바탕으로 준비 시간을 계속 조정해요. 설정 > 개인화에서 학습된 값을 확인하고 되돌릴 수 있어요.",
  ),
  _Faq("알림이 오지 않아요", "설정 > 권한에서 알림 허용 상태를, 설정 > 알림에서 알림 민감도와 일정별 알림을 확인해 주세요."),
];

const _supportEmail = "support@ensom.app";

/// 고객지원 화면. ensom_auth.html 목업 "화면6"을 반영한다.
/// 문의 메일 발송은 url_launcher 의존성을 새로 들이지 않기 위해,
/// 버튼을 누르면 주소를 클립보드에 복사하고 안내 스낵바를 띄운다.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  int? _openIndex;

  Future<void> _copyEmail() async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("$_supportEmail 주소를 복사했어요")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: AppBar(
        backgroundColor: EnsomColors.canvas,
        surfaceTintColor: EnsomColors.canvas,
        elevation: 0,
        title: const Text(
          "고객지원",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EnsomColors.ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
        children: [
          const Text(
            "자주 묻는 질문",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: EnsomColors.inkFaint,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _faqs.length; i++)
            _FaqTile(
              faq: _faqs[i],
              open: _openIndex == i,
              onTap: () =>
                  setState(() => _openIndex = _openIndex == i ? null : i),
            ),
          const Divider(height: 33, color: EnsomColors.hairline),
          const Text(
            "문의하기",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: EnsomColors.inkFaint,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: EnsomColors.surface2,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline,
                  size: 16,
                  color: EnsomColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _supportEmail,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.2,
                      color: EnsomColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "보통 1~2 영업일 안에 답변드려요",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: EnsomColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "앱 버전 1.0.0 (1)",
            style: TextStyle(fontSize: 10.5, color: EnsomColors.inkFaint),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _copyEmail,
              style: FilledButton.styleFrom(
                backgroundColor: EnsomColors.surface2,
                foregroundColor: EnsomColors.ink,
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                elevation: 0,
              ),
              child: const Text("문의 메일 보내기"),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq, required this.open, required this.onTap});

  final _Faq faq;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EnsomColors.hairline)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        faq.question,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.2,
                          color: EnsomColors.ink,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? .25 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: EnsomColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    faq.answer,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: EnsomColors.inkMuted,
                      height: 1.75,
                      letterSpacing: -.2,
                    ),
                  ),
                ),
                crossFadeState: open
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
