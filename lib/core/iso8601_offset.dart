/// API 명세 §1.5 TR-02는 오프셋 포함 ISO-8601을 요구하고 "Z만 오면 422"라고
/// 적혀 있다(이 422가 실제로 재현된 적은 없음 — PR #3에서 POST /events 바디는
/// Z suffix로도 201이 확인됨). 명세를 따라 "+00:00" 오프셋을 명시해 보낸다.
String iso8601WithOffset(DateTime dt) {
  final utc = dt.toUtc();
  final y = utc.year.toString().padLeft(4, "0");
  final mo = utc.month.toString().padLeft(2, "0");
  final d = utc.day.toString().padLeft(2, "0");
  final h = utc.hour.toString().padLeft(2, "0");
  final mi = utc.minute.toString().padLeft(2, "0");
  final s = utc.second.toString().padLeft(2, "0");
  final ms = utc.millisecond.toString().padLeft(3, "0");
  return "$y-$mo-${d}T$h:$mi:$s.${ms}+00:00";
}
