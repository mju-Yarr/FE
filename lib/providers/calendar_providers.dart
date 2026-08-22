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

final eventsInRangeProvider = FutureProvider.autoDispose
    .family<List<Event>, EventRange>((ref, range) async {
      final repo = ref.watch(ensomRepositoryProvider);
      return repo.fetchEvents(from: range.from, to: range.to);
    });

/// S-11 — 보이는 기간의 미해결 분류 질문. 캘린더 화면이 이 범위를 정한다.
final pendingReviewsProvider = FutureProvider.autoDispose
    .family<List<PendingEventReview>, EventRange>((ref, range) async {
      final repo = ref.watch(ensomRepositoryProvider);
      return repo.fetchPendingReviews(from: range.from, to: range.to);
    });

final weeklySummaryProvider = FutureProvider.autoDispose
    .family<WeeklySummary, DateTime>((ref, date) async {
      final repo = ref.watch(ensomRepositoryProvider);
      return repo.fetchWeeklySummary(DateFormat("yyyy-MM-dd").format(date));
    });
