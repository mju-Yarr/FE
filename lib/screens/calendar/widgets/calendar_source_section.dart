import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "../../../models/calendar_connection.dart";
import "../../../network/api_client.dart";
import "../../../providers/calendar_providers.dart";
import "../../../repository/providers.dart";
import "../../../theme/ensom_colors.dart";
import "../../../widgets/ensom/ensom_error_banner.dart";
import "../../../widgets/ensom/ensom_skeleton.dart";
import "../../../widgets/ensom/ensom_toggle.dart";

/// S-41 캘린더 연동 관리의 소스 목록.
///
/// 연결된 계정마다 어떤 캘린더를 가져올지(syncEnabled), 일정을 어디에 기록할지
/// (defaultSource) 고른다. 쓰기 불가 소스는 기본 기록 캘린더가 될 수 없다 —
/// 서버가 CALENDAR_SOURCE_NOT_WRITABLE로 막는다.
class CalendarSourceSection extends ConsumerStatefulWidget {
  const CalendarSourceSection({super.key});

  @override
  ConsumerState<CalendarSourceSection> createState() =>
      _CalendarSourceSectionState();
}

class _CalendarSourceSectionState extends ConsumerState<CalendarSourceSection> {
  /// 요청 중인 소스. 같은 행을 연타해 요청이 겹치지 않게 한다.
  final _pending = <String>{};
  String? _error;

  static final _syncedFmt = DateFormat("M월 d일 HH:mm", "ko_KR");

  Future<void> _run(String sourceId, Future<void> Function() action) async {
    if (_pending.contains(sourceId)) return;
    setState(() {
      _pending.add(sourceId);
      _error = null;
    });
    try {
      await action();
      // 기본 캘린더를 바꾸면 다른 소스의 defaultSource도 함께 내려간다.
      // 개별 응답만 반영하면 화면에 기본이 둘로 보이므로 목록을 다시 읽는다.
      ref.invalidate(calendarConnectionsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.code) {
          "CALENDAR_SOURCE_NOT_WRITABLE" => "이 캘린더에는 일정을 기록할 수 없어요.",
          "CALENDAR_SOURCE_NOT_FOUND" => "캘린더를 찾을 수 없어요. 목록을 새로고침해 주세요.",
          "NETWORK_ERROR" => "네트워크에 연결할 수 없어요.",
          _ => e.message,
        };
      });
    } finally {
      if (mounted) setState(() => _pending.remove(sourceId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionsAsync = ref.watch(calendarConnectionsProvider);

    return connectionsAsync.when(
      // §11 로딩은 스켈레톤.
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: EnsomSkeletonList(count: 2, itemHeight: 96),
      ),
      // 연결 목록을 못 읽어도 위쪽 연결/해제는 계속 쓸 수 있어야 한다.
      // 전면으로 막지 않고 배너로만 알린다(§1.5).
      error: (err, st) => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: EnsomErrorBanner(title: "연동한 캘린더 목록을 불러오지 못했어요."),
      ),
      data: (connections) {
        if (connections.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            const Text(
              "가져올 캘린더",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -.2,
                color: EnsomColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "켜 둔 캘린더의 일정만 가져와요. 기록할 캘린더는 하나만 고를 수 있어요.",
              style: TextStyle(
                fontSize: 11.5,
                color: EnsomColors.inkFaint,
                height: 1.5,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              EnsomErrorBanner(title: _error!),
            ],
            for (final connection in connections) ...[
              const SizedBox(height: 12),
              _ConnectionCard(
                connection: connection,
                syncedLabel: connection.lastSyncedAt == null
                    // 한 번도 동기화하지 않은 것과 방금 한 것을 구분한다.
                    ? "아직 동기화하지 않았어요"
                    : "마지막 동기화 ${_syncedFmt.format(connection.lastSyncedAt!.toLocal())}",
                pending: _pending,
                onToggleSync: (source, enabled) => _run(
                  source.calendarSourceId,
                  () => ref
                      .read(ensomRepositoryProvider)
                      .setCalendarSourceSync(source.calendarSourceId, enabled),
                ),
                onSelectDefault: (source) => _run(
                  source.calendarSourceId,
                  () => ref
                      .read(ensomRepositoryProvider)
                      .setDefaultCalendarSource(source.calendarSourceId),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.syncedLabel,
    required this.pending,
    required this.onToggleSync,
    required this.onSelectDefault,
  });

  final CalendarConnection connection;
  final String syncedLabel;
  final Set<String> pending;
  final void Function(CalendarSource source, bool enabled) onToggleSync;
  final void Function(CalendarSource source) onSelectDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EnsomColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            connection.externalAccountId.isEmpty
                ? connection.provider
                : connection.externalAccountId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            syncedLabel,
            style: const TextStyle(fontSize: 11, color: EnsomColors.inkFaint),
          ),
          if (connection.sources.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              "가져올 수 있는 캘린더가 아직 없어요. 동기화하면 목록이 채워져요.",
              style: TextStyle(fontSize: 11.5, color: EnsomColors.inkMuted),
            ),
          ],
          for (final source in connection.sources) ...[
            const Divider(height: 20, color: EnsomColors.hairline),
            _SourceRow(
              source: source,
              busy: pending.contains(source.calendarSourceId),
              onToggleSync: (enabled) => onToggleSync(source, enabled),
              onSelectDefault: () => onSelectDefault(source),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.busy,
    required this.onToggleSync,
    required this.onSelectDefault,
  });

  final CalendarSource source;
  final bool busy;
  final ValueChanged<bool> onToggleSync;
  final VoidCallback onSelectDefault;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                source.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: EnsomColors.ink),
              ),
            ),
            // 요청 중 연타는 _run의 pending 집합이 걸러낸다.
            EnsomToggle(value: source.syncEnabled, onChanged: onToggleSync),
          ],
        ),
        const SizedBox(height: 6),
        if (source.writable)
          _DefaultChoice(
            selected: source.defaultSource,
            busy: busy,
            onTap: onSelectDefault,
          )
        else
          // 읽기 전용 캘린더는 기록 대상이 될 수 없다. 버튼을 숨기는 대신
          // 이유를 적는다(§8 "무엇을 더 해야 하는지 알 수 있어야 한다").
          const Text(
            "읽기 전용이라 일정을 기록할 수 없어요",
            style: TextStyle(fontSize: 11, color: EnsomColors.inkFaint),
          ),
      ],
    );
  }
}

class _DefaultChoice extends StatelessWidget {
  const _DefaultChoice({
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      // §9.2 상태를 색으로만 구분하지 않는다 — 아이콘과 텍스트를 함께 둔다.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: EnsomColors.limeSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 12, color: EnsomColors.limeInk),
            SizedBox(width: 4),
            Text(
              "여기에 기록해요",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: EnsomColors.limeInk,
              ),
            ),
          ],
        ),
      );
    }
    return TextButton(
      onPressed: busy ? null : onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        alignment: Alignment.centerLeft,
        foregroundColor: EnsomColors.inkMuted,
        textStyle: const TextStyle(
          fontSize: 11.5,
          decoration: TextDecoration.underline,
        ),
      ),
      child: const Text("여기에 기록하기"),
    );
  }
}
