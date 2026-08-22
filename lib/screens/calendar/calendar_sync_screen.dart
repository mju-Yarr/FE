import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/app_config.dart";
import "../../core/google_auth_helper.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../providers/bootstrap_provider.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_error_banner.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "widgets/calendar_source_section.dart";

/// S-41 캘린더 연동 관리.
/// Google OAuth에서 받은 serverAuthCode를 BE 계약에 맞춰 전달한다.
class CalendarSyncScreen extends ConsumerStatefulWidget {
  const CalendarSyncScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  ConsumerState<CalendarSyncScreen> createState() => _CalendarSyncScreenState();
}

class _CalendarSyncScreenState extends ConsumerState<CalendarSyncScreen> {
  bool _connected = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConnectionStatus();
  }

  Future<void> _loadConnectionStatus() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>("/calendar/google/status");
      if (!mounted) return;
      setState(() => _connected = data["connected"] == true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isNetworkError
            ? "캘린더 연결 상태를 확인하지 못했어요. 네트워크를 확인해주세요."
            : "캘린더 연결 상태를 확인하지 못했어요.";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    if (kGoogleServerClientId.isEmpty) {
      setState(() => _error = "Google 서버 클라이언트 설정이 없어 지금은 연동할 수 없어요.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authCode = await GoogleAuthHelper.instance.signInForCalendar();
      if (authCode == null) return;

      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            "/calendar/google/connect",
            body: {"authCode": authCode},
          );

      if (!mounted) return;
      setState(() => _connected = true);
      ref.invalidate(bootstrapProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("캘린더를 연동했어요.")));

      if (widget.isOnboarding) {
        // §4.1 캘린더 다음은 위치 프라이밍이다. 프라이밍 3종은 서버에
        // permissions 한 단계로만 기록한다.
        await ref
            .read(authNotifierProvider.notifier)
            .advanceOnboarding("permissions");
        if (mounted) context.go("/onboarding/priming/location");
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isNetworkError
            ? "네트워크에 연결할 수 없어요. 잠시 후 다시 시도해주세요."
            : "캘린더를 연동하지 못했어요. 다시 시도해주세요.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Google 인증 정보를 가져오지 못했어요. 다시 시도해주세요.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("캘린더 연결을 해제할까요?"),
        content: const Text("연동된 일정이 더 이상 자동으로 가져와지지 않아요."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("연결 해제"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .delete<Map<String, dynamic>>("/calendar/google");
      if (!mounted) return;
      setState(() => _connected = false);
      ref.invalidate(bootstrapProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("캘린더 연결을 해제했어요.")));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isNetworkError
            ? "네트워크에 연결할 수 없어요. 잠시 후 다시 시도해주세요."
            : "연결을 해제하지 못했어요. 다시 시도해주세요.";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithoutCalendar() async {
    await ref
        .read(authNotifierProvider.notifier)
        .advanceOnboarding("permissions");
    if (mounted) context.go("/onboarding/priming/location");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: AppBar(
        backgroundColor: EnsomColors.canvas,
        surfaceTintColor: EnsomColors.canvas,
        elevation: 0,
        automaticallyImplyLeading: !widget.isOnboarding,
        title: const Text(
          "캘린더 연동",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EnsomColors.ink,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        children: [
          if (widget.isOnboarding) ...[
            Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: const BoxDecoration(
                color: EnsomColors.surface2,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 26,
                color: EnsomColors.ink,
              ),
            ),
            const Text(
              "다음 일정과 장소를\n자동으로 인식하려면",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -.3,
                height: 1.35,
                color: EnsomColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "캘린더를 연동하면 일정마다 시간과 장소를 다시 입력하지 않아도, 언제부터 준비를 시작해야 하는지 자동으로 알려드려요.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: EnsomColors.inkMuted,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: EnsomColors.surface2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_connected) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: EnsomColors.limeInk,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "캘린더를 연동했어요",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: EnsomColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 26),
                    child: Text(
                      "Google 캘린더",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: EnsomColors.inkMuted,
                      ),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: EnsomColors.surface1,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: EnsomColors.ink,
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Google 캘린더",
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: EnsomColors.ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "연동 안 됨",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: EnsomColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  EnsomErrorBanner(title: _error!),
                ],
                const SizedBox(height: 14),
                EnsomPillButton(
                  label: _connected
                      ? "연결 해제"
                      : (_loading ? "연결 중..." : "캘린더 연동하기"),
                  variant: _connected
                      ? EnsomPillVariant.secondary
                      : EnsomPillVariant.primary,
                  onPressed: _loading
                      ? null
                      : (_connected ? _disconnect : _connect),
                ),
              ],
            ),
          ),
          // 연결된 계정의 캘린더별 설정. 온보딩 중에는 연결 여부만 묻고
          // 세부 설정은 나중에 설정에서 하게 둔다.
          if (!widget.isOnboarding && _connected) const CalendarSourceSection(),
          if (!widget.isOnboarding) ...[
            const SizedBox(height: 16),
            const Text(
              "캘린더를 연동하면 다음 일정과 장소를 자동으로 인식해요. 별도로 일정을 입력하지 않아도 준비 계획을 세워드려요.",
              style: TextStyle(
                fontSize: 12,
                color: EnsomColors.inkFaint,
                height: 1.6,
              ),
            ),
          ],
          if (widget.isOnboarding) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _loading ? null : _continueWithoutCalendar,
                child: const Text(
                  "나중에 할게요",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: EnsomColors.inkMuted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
