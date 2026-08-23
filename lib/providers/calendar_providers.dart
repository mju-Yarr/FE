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

/// 청크 중 일부만 실패해도(일시적 네트워크 오류 등) 전체 화면을 에러로
/// 만들지 않는다 — 성공한 청크만 모아서 반환하고, **전부** 실패했을 때만
/// (원래 단일 요청이었을 때와 동일하게) 에러를 전파한다.
Future<List<T>> _fetchChunksResilient<T>(
  List<Future<List<T>>> futures,
) async {
  final settled = await Future.wait(
    futures.map(
      (f) => f.then<Object?>((v) => v).catchError((Object e) => e),
    ),
  );
  final oks = <List<T>>[];
  Object? firstError;
  for (final r in settled) {
    if (r is List<T>) {
      oks.add(r);
    } else {
      firstError ??= r;
    }
  }
  if (oks.isEmpty && firstError != null) {
    throw firstError;
  }
  return oks.expand((e) => e).toList();
}

final eventsInRangeProvider = FutureProvider.autoDispose
    .family<List<Event>, EventRange>((ref, range) async {
      final repo = ref.watch(ensomRepositoryProvider);
      final chunks = _splitIntoSafeChunks(range);
      final events = await _fetchChunksResilient(
        chunks.map((c) => repo.fetchEvents(from: c.from, to: c.to)).toList(),
      );
      // 청크는 [from, to) 반개구간으로 인접·비중첩이라(BE
      // EventRepository: `startsAt >= :from AND startsAt < :to`로 확인)
      // 원칙적으로 중복이 없지만, eventId 기준으로 한 번 더 방어한다.
      final seen = <String>{};
      final deduped = [
        for (final e in events)
          if (seen.add(e.eventId)) e,
      ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return deduped;
    });

/// S-11 — 보이는 기간의 미해결 분류 질문. 캘린더 화면이 이 범위를 정한다.
final pendingReviewsProvider = FutureProvider.autoDispose
    .family<List<PendingEventReview>, EventRange>((ref, range) async {
      final repo = ref.watch(ensomRepositoryProvider);
      final chunks = _splitIntoSafeChunks(range);
      final reviews = await _fetchChunksResilient(
        chunks
            .map((c) => repo.fetchPendingReviews(from: c.from, to: c.to))
            .toList(),
      );
      final seen = <String>{};
      final deduped = [
        for (final r in reviews)
          if (seen.add(r.reviewId)) r,
      ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return deduped;
    });

final weeklySummaryProvider = FutureProvider.autoDispose
    .family<WeeklySummary, DateTime>((ref, date) async {
      final repo = ref.watch(ensomRepositoryProvider);
      return repo.fetchWeeklySummary(DateFormat("yyyy-MM-dd").format(date));
    });
