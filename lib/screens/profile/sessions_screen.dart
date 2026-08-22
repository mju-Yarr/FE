import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_pill_button.dart";

/// S-29 로그인 기록 (세션 관리)
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<Map<String, dynamic>>? _sessions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<List<dynamic>>("/me/sessions");
      if (mounted) {
        setState(() {
          _sessions = data.map((e) => e as Map<String, dynamic>).toList();
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.isNetworkError ? "네트워크에 연결할 수 없어요. 다시 시도해주세요." : e.message;
        });
      }
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete<Map<String, dynamic>>("/me/sessions/$sessionId");
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteAllSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("다른 기기에서 로그아웃할까요?"),
        // Issue #52: 명세상 현재 기기는 제외 — 다른 기기 세션만 종료
        content: const Text("현재 기기를 제외한 모든 세션이 종료돼요."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: EnsomColors.caution),
            child: const Text("다른 기기 로그아웃"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = ref.read(apiClientProvider);
      // DELETE /me/sessions는 현재 기기를 제외한 세션만 종료한다.
      // 따라서 로컬 소거·로그아웃 없이 세션 목록만 새로고침한다.
      await api.delete<Map<String, dynamic>>("/me/sessions");
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("다른 기기에서 로그아웃했어요.")));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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
          "로그인 기록",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EnsomColors.ink,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _deleteAllSessions,
            child: const Text(
              "전체 로그아웃",
              style: TextStyle(
                fontSize: 12.5,
                color: EnsomColors.caution,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: EnsomColors.inkMuted),
              ),
              const SizedBox(height: 16),
              EnsomPillButton(label: "다시 시도", expand: false, onPressed: _load),
            ],
          ),
        ),
      );
    }

    final sessions = _sessions ?? [];
    if (sessions.isEmpty) {
      return const Center(
        child: Text(
          "세션 정보가 없어요.",
          style: TextStyle(color: EnsomColors.inkMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final id = session["refreshTokenId"]?.toString() ?? "";
        final isCurrent = session["isCurrent"] == true;
        final deviceName = session["platform"]?.toString() ?? "알 수 없는 기기";
        final lastActive = session["issuedAt"]?.toString() ?? "";

        return Dismissible(
          key: Key(id),
          direction: isCurrent
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 9),
            decoration: BoxDecoration(
              color: EnsomColors.caution,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.logout, color: Colors.white, size: 18),
          ),
          confirmDismiss: (_) async => !isCurrent,
          onDismissed: (_) => _deleteSession(id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: EnsomColors.surface1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: EnsomColors.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: EnsomColors.surface2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrent ? Icons.phone_android : Icons.devices_other,
                    size: 15,
                    color: EnsomColors.inkMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              deviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: EnsomColors.ink,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: EnsomColors.limeSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                "현재 기기",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: EnsomColors.limeInk,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (lastActive.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          lastActive,
                          style: const TextStyle(
                            fontSize: 11,
                            color: EnsomColors.inkFaint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
