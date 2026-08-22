import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "../../models/notification.dart";
import "../../repository/providers.dart";
import "../../theme/ensom_colors.dart";

/// 알림 로그 — v6 프로토타입 기준 redesign
/// 디자인 기준: Ensom_프로토타입_v6_최종/02_홈·일정/ensom_push_notifications.html
final todayNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      final repo = ref.watch(ensomRepositoryProvider);
      return repo.fetchTodayNotifications();
    });

class NotificationLogScreen extends ConsumerWidget {
  const NotificationLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(todayNotificationsProvider);
    final timeFormat = DateFormat("a h:mm", "ko_KR");

    return Scaffold(
      backgroundColor: EnsomColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: notificationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(
                  child: Text(
                    "불러오지 못했어요",
                    style: TextStyle(color: EnsomColors.inkMuted),
                  ),
                ),
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            "오늘 발송된 알림이 없어요",
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: EnsomColors.ink,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "알림이 오면 여기에 표시돼요",
                            style: TextStyle(
                              fontSize: 12,
                              color: EnsomColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final sorted = [...notifications]
                    ..sort((a, b) {
                      if (a.sentAt == null) return 1;
                      if (b.sentAt == null) return -1;
                      return b.sentAt!.compareTo(a.sentAt!);
                    });
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) => _NotificationCard(
                      notification: sorted[index],
                      timeFormat: timeFormat,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: EnsomColors.surface2,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.chevron_left,
                size: 14,
                color: EnsomColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "오늘의 알림",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: EnsomColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notification Card (iOS 잠금화면 스타일) ───

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.timeFormat,
  });

  final AppNotification notification;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: EnsomColors.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 앱 아이콘
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: EnsomColors.lime,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.access_time,
              size: 15,
              color: EnsomColors.ink,
            ),
          ),
          const SizedBox(width: 10),
          // 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Ensom",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: EnsomColors.ink,
                      ),
                    ),
                    if (notification.sentAt != null)
                      Text(
                        timeFormat.format(notification.sentAt!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: EnsomColors.inkFaint,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notification.body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: EnsomColors.ink,
                    height: 1.4,
                  ),
                ),
                if (notification.triggerReason != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    notification.triggerReason!,
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
    );
  }
}
