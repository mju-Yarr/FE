import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "../models/calendar_connection.dart";
import "../models/event.dart";
import "../models/pending_event_review.dart";
import "../models/weekly_summary.dart";
import "../repository/providers.dart";

/// S-41 캘린더 연동 관리. 연결마다 소스 목록이 함께 온다.
final calendarConnectionsProvider =
    FutureProvider.autoDispose<List<CalendarConnection>>((ref) async {
      final repo = ref.watch(ensomRepositoryProvider);
      return repo.fetchCalendarConnections();
    });

class EventRange {
  const EventRange({required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is EventRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// `GET /events`·`GET /events/reviews/pending` 둘 다 서버가 `[from, to)`
/// 범위를 최대 31일까지만 허용한다(BE `EventService.list()`/
/// `listPendingReviews()`, 초과 시 422 VALIDATION_ERROR). 캘린더 화면은
/// 앞뒤 한 달까지 미리 불러오는 3개월 범위를 요청하므로 항상 이 제한을
/// 넘는다 — 여기서 30일 단위(하루 여유를 둬 DST 등으로 실제 instant
/// 길이가 31일을 살짝 넘는 경우까지 안전)로 쪼개 병렬 요청한 뒤 병합한다.
/// 화면 쪽은 원하는 범위를 그대로 넘기면 되고 31일 제한은 신경 쓸 필요가
/// 없다 — (PR #3 리뷰에서 지적된 주간 뷰 경계·검색 범위 축소·DST 회귀를
/// 모두 여기서 해소한다.)
const _maxSafeRangeDays = 30;

List<EventRange> _splitIntoSafeChunks(EventRange range) {
  final chunks = <EventRange>[];
  var start = range.from;
  while (start.isBefore(range.to)) {
    final end = start.add(const Duration(days: _maxSafeRangeDays));
    chunks.add(
      EventRange(from: start, to: end.isBefore(range.to) ? end : range.to),
    );
    start = end;
  }
  return chunks;
}

final eventsInRangeProvider = FutureProvider.autoDispose
    .family<List<Event>, EventRange>((ref, range) async {
      final repo = ref.watch(ensomRepositoryProvider);
      final chunks = _splitIntoSafeChunks(range);
      final results = await Future.wait(
        chunks.map((c) => repo.fetchEvents(from: c.from, to: c.to)),
      );
      final events = results.expand((e) => e).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return events;
    });

/// S-11 — 보이는 기간의 미해결 분류 질문. 캘린더 화면이 이 범위를 정한다.
final pendingReviewsProvider = FutureProvider.autoDispose
    .family<List<PendingEventReview>, EventRange>((ref, range) async {
      final repo = ref.watch(ensomRepositoryProvider);
      final chunks = _splitIntoSafeChunks(range);
      final results = await Future.wait(
        chunks.map((c) => repo.fetchPendingReviews(from: c.from, to: c.to)),
      );
      final reviews = results.expand((r) => r).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return reviews;
    });

final weeklySummaryProvider = FutureProvider.autoDispose
    .family<WeeklySummary, DateTime>((ref, date) async {
      final repo = ref.watch(ensomRepositoryProvider);
      return repo.fetchWeeklySummary(DateFormat("yyyy-MM-dd").format(date));
    });
