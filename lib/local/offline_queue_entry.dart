import 'package:hive_ce/hive_ce.dart';

part 'offline_queue_entry.g.dart';

@HiveType(typeId: 0)
class OfflineQueueEntry extends HiveObject {
  @HiveField(0)
  String userId; // FK 아님, 값으로만

  @HiveField(1)
  String eventType;

  @HiveField(2)
  Map<String, dynamic> payload;

  @HiveField(3)
  DateTime queuedAt;

  OfflineQueueEntry({
    required this.userId,
    required this.eventType,
    required this.payload,
    required this.queuedAt,
  });
}
