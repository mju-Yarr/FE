import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/auth_service.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "consent_detail_screen.dart";

/// S-02 약관 동의. PRD §11.2 "필수 약관 동의" / API 명세 §2.8 POST
/// /consents. consentRequired가 빈 배열이 될 때까지 홈 진입을 막는다.
///
/// ensom_auth.html 목업 "화면3"을 반영 — 전체 동의 카드와 개별 항목이
/// 양방향으로 연동된다(전체 동의를 누르면 4개 다 켜지고, 4개를 다
/// 수동으로 켜면 전체 동의도 자동으로 켜진다).
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentItem {
  _ConsentItem({
    required this.type,
    required this.name,
    required this.required,
  });

  final String type; // terms | privacy | location | marketing
  final String name;
  final bool required;
  bool agreed = false;
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  final List<_ConsentItem> _items = [
    _ConsentItem(type: "terms", name: "이용약관", required: true),
    _ConsentItem(type: "privacy", name: "개인정보 수집 및 이용 동의", required: true),
    _ConsentItem(type: "location", name: "위치기반 서비스 이용약관", required: true),
    _ConsentItem(type: "marketing", name: "마케팅 정보 수신 동의", required: false),
  ];

  bool get _allRequiredAgreed =>
      _items.where((i) => i.required).every((i) => i.agreed);

  bool get _allAgreed => _items.every((i) => i.agreed);

  void _toggleAll() {
    final next = !_allAgreed;
    setState(() {
      for (final item in _items) {
        item.agreed = next;
      }
    });
  }

  void _toggleItem(_ConsentItem item) {
    setState(() => item.agreed = !item.agreed);
  }

  bool _submitting = false;
  String? _error;

  /// 약관 동의 정책 버전. 실제 운영에서는 서버가 내려주는 최신 버전을
  /// bootstrap에서 받아 써야 하지만 MVP에서는 하드코딩.
  static const _policyVersion = "v1";

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);

      final consents = _items
          .map(
            (item) => ConsentEntry(
              consentType: item.type,
              policyVersion: _policyVersion,
              agreed: item.agreed,
            ),
          )
          .toList();

      await authService.submitConsents(consents);

      if (!mounted) return;

      // 약관 동의 완료 → AuthNotifier 상태 전이
      ref.read(authNotifierProvider.notifier).onConsentCompleted();

      // 온보딩 다음 단계(준비시간 입력)로 이동
      context.go("/onboarding/prep-time");
    } on ApiException catch (e) {
      setState(() {
        switch (e.code) {
          case "NETWORK_ERROR":
            _error = "네트워크에 연결할 수 없어요. 잠시 후 다시 시도해주세요.";
          default:
            _error = "동의 처리에 실패했어요. 다시 시도해주세요.";
        }
      });
    } catch (_) {
      setState(() => _error = "동의 처리에 실패했어요. 다시 시도해주세요.");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openDetail(_ConsentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ConsentDetailScreen(consentType: item.type, title: item.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: EnsomColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    const Text(
                      "서비스 이용을 위해\n약관에 동의해 주세요",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                        height: 1.35,
                        color: EnsomColors.ink,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Material(
                      color: EnsomColors.surface2,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _toggleAll,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 15,
                          ),
                          child: Row(
                            children: [
                              _Checkbox(checked: _allAgreed),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "전체 동의",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -.3,
                                        color: EnsomColors.ink,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      "선택 항목 동의를 포함합니다",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: EnsomColors.inkFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 29, color: EnsomColors.hairline),
                    for (final item in _items)
                      _ConsentRow(
                        item: item,
                        onToggle: () => _toggleItem(item),
                        onView: () => _openDetail(item),
                      ),
                    const SizedBox(height: 14),
                    const Text(
                      "필수 항목에 동의하셔야 서비스를 시작할 수 있어요. 선택 항목은 나중에 설정에서 바꿀 수 있습니다.",
                      style: TextStyle(
                        fontSize: 10.5,
                        color: EnsomColors.inkFaint,
                        height: 1.5,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: EnsomColors.caution,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                decoration: const BoxDecoration(
                  color: EnsomColors.surface1,
                  border: Border(top: BorderSide(color: EnsomColors.hairline)),
                ),
                child: EnsomPillButton(
                  label: _submitting ? "처리 중..." : "동의하고 시작하기",
                  onPressed: (_allRequiredAgreed && !_submitting)
                      ? _submit
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.item,
    required this.onToggle,
    required this.onView,
  });

  final _ConsentItem item;
  final VoidCallback onToggle;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _Checkbox(checked: item.agreed),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: EnsomColors.surface2,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.required ? "필수" : "선택",
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: EnsomColors.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.2,
                          color: EnsomColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onView,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 26,
                height: 26,
                child: Icon(
                  Icons.chevron_right,
                  size: 15,
                  color: EnsomColors.inkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? EnsomColors.cta : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked ? EnsomColors.cta : EnsomColors.hairline,
          width: 1.8,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
