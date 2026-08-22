import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:google_sign_in/google_sign_in.dart";
import "../../core/app_config.dart";
import "../../network/api_client.dart";
import "../../providers/auth_providers.dart";
import "../../theme/ensom_colors.dart";
import "../../widgets/ensom/ensom_error_banner.dart";
import "../../widgets/ensom/ensom_pill_button.dart";
import "../../widgets/ensom/ensom_top_bar.dart";

/// S-27 로그인 수단 관리
class ProvidersScreen extends ConsumerStatefulWidget {
  const ProvidersScreen({super.key});

  @override
  ConsumerState<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  List<Map<String, dynamic>>? _providers;
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
      final data = await api.get<List<dynamic>>("/me/providers");
      if (mounted) {
        setState(() {
          _providers = data.map((e) => e as Map<String, dynamic>).toList();
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

  Future<void> _disconnect(String providerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("로그인 수단을 해제할까요?"),
        content: const Text("이 수단으로 더 이상 로그인할 수 없게 돼요."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: EnsomColors.caution),
            child: const Text("해제"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.delete<Map<String, dynamic>>("/me/providers/$providerId");
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _connectGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: kGoogleServerClientId.isEmpty
            ? null
            : kGoogleServerClientId,
        scopes: ["email"],
      );
      final account = await googleSignIn.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Google 인증에 실패했어요.")));
        }
        return;
      }

      final api = ref.read(apiClientProvider);
      await api.post<Map<String, dynamic>>(
        "/me/providers",
        body: {"provider": "google", "providerToken": idToken},
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google 로그인에 실패했어요. 다시 시도해주세요.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      appBar: const EnsomTopBar(title: "로그인 수단"),
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
              EnsomErrorBanner(title: _error!),
              const SizedBox(height: 16),
              EnsomPillButton(label: "다시 시도", expand: false, onPressed: _load),
            ],
          ),
        ),
      );
    }

    final providers = _providers ?? [];
    final isOnlyOne = providers.length <= 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        const Text(
          "계정에 연결된 로그인 방법이에요. 최소 한 개는 남겨두어야 해요.",
          style: TextStyle(
            fontSize: 11,
            color: EnsomColors.inkFaint,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        ...providers.map((p) {
          final id = p["identityId"]?.toString() ?? "";
          final type = p["provider"]?.toString() ?? "";
          final email = p["email"]?.toString() ?? "";
          return _ProviderRow(
            icon: _iconForProvider(type),
            label: _labelForProvider(type),
            sub: email.isNotEmpty ? email : null,
            locked: isOnlyOne,
            onDisconnect: isOnlyOne ? null : () => _disconnect(id),
          );
        }),
        if (isOnlyOne) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              "마지막 로그인 수단은 해제할 수 없어요. 다른 수단을 먼저 연결해주세요.",
              style: TextStyle(
                fontSize: 11,
                color: EnsomColors.inkFaint,
                height: 1.5,
              ),
            ),
          ),
        ],
        const Divider(height: 26, color: EnsomColors.hairline),
        InkWell(
          onTap: _connectGoogle,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            child: Row(
              children: [
                Icon(Icons.add, size: 18, color: EnsomColors.inkMuted),
                SizedBox(width: 13),
                Text(
                  "Google 계정 연결",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: EnsomColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconForProvider(String type) {
    switch (type.toUpperCase()) {
      case "GOOGLE":
        return Icons.g_mobiledata;
      case "EMAIL":
        return Icons.email_outlined;
      default:
        return Icons.account_circle_outlined;
    }
  }

  String _labelForProvider(String type) {
    switch (type.toUpperCase()) {
      case "GOOGLE":
        return "Google";
      case "EMAIL":
        return "이메일";
      default:
        return type;
    }
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.icon,
    required this.label,
    required this.locked,
    this.sub,
    this.onDisconnect,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final bool locked;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
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
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: EnsomColors.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: EnsomColors.limeSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              "연결됨",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: EnsomColors.limeInk,
              ),
            ),
          ),
          // §13 마지막 로그인 수단은 해제 버튼을 숨기지 않고 비활성으로 둔다.
          // 숨기면 왜 못 하는지 알 수 없다(§8).
          const SizedBox(width: 8),
          Opacity(
            opacity: locked ? .4 : 1,
            child: InkWell(
              onTap: locked ? null : onDisconnect,
              child: const Text(
                "해제",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: EnsomColors.inkMuted,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
