import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/plan.dart";
import "../network/api_client.dart";
import "../providers/auth_providers.dart";
import "../providers/home_providers.dart";
import "../theme/ensom_colors.dart";
import "ensom/route_option_card.dart";

/// RTE-01 경로 변경 후보 시트
/// 호출: DTL-01 경로 [변경] 버튼
/// BE: GET /plans/{planId}/routes, POST /plans/{planId}/routes/select
///
/// 사용법:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (_) => RouteChangeSheet(planId: plan.planId, eventId: eventId),
/// );
/// ```
class RouteChangeSheet extends ConsumerStatefulWidget {
  const RouteChangeSheet({
    super.key,
    required this.planId,
    required this.eventId,
  });

  final String planId;
  final String eventId;

  @override
  ConsumerState<RouteChangeSheet> createState() => _RouteChangeSheetState();
}

class _RouteChangeSheetState extends ConsumerState<RouteChangeSheet> {
  List<RouteOption>? _options;
  bool _loading = true;
  String? _error;
  String? _selectedId;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final options = await ref.read(
        routeOptionsProvider(widget.planId).future,
      );
      if (mounted) {
        setState(() {
          _options = options;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "경로를 불러오지 못했어요.";
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectRoute(String routeOptionId) async {
    setState(() {
      _selecting = true;
      _selectedId = routeOptionId;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        "/plans/${widget.planId}/routes/select",
        body: {"routeOptionId": routeOptionId},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("경로를 변경했어요.")));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _selecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: EnsomColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "경로 변경",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -.2,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: EnsomColors.inkMuted),
                ),
              ),
            )
          else if (_options == null || _options!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "대안 경로가 없어요.",
                  style: TextStyle(color: EnsomColors.inkMuted),
                ),
              ),
            )
          else
            for (final opt in _options!) ...[
              EnsomRouteOptionCard(
                option: opt,
                selected: _selectedId == opt.routeOptionId,
                onSelect: _selecting
                    ? null
                    : () => _selectRoute(opt.routeOptionId),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
