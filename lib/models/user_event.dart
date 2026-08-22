import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_event.freezed.dart';
part 'user_event.g.dart';

@freezed
abstract class UserEvent with _$UserEvent {
  const factory UserEvent({
    String? title, // 저장 여부 미결(Q-004) — 화면엔 일단 노출하되 서버 정책 확정 전까지 주의
    required DateTime startsAt,
    required DateTime endsAt,
    String? placeText, // 좌표 아님, 문자열
  }) = _UserEvent;

  factory UserEvent.fromJson(Map<String, dynamic> json) =>
      _$UserEventFromJson(json);
}
