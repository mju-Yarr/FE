import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/environment_data.dart";
import "../network/api_client.dart";
import "auth_providers.dart";

/// 홈 화면 날씨/대기질 위젯용 FutureProvider. BE `GET /environment/current`
/// (BE #226)를 호출한다. 위치는 서버가 사용자의 대표 장소로 잡으므로
/// 클라이언트가 좌표를 보내지 않는다.
///
/// 대표 장소를 아직 등록하지 않았으면 404가 오는데, 이건 오류 상태가 아니라
/// "보여줄 게 없는" 상태라 null로 바꾼다. WeatherWidget은 null이면 비노출된다.
final environmentProvider = FutureProvider.autoDispose<EnvironmentData?>((
  ref,
) async {
  try {
    final json = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>("/environment/current");
    return EnvironmentData.fromJson(json);
  } on ApiException {
    return null;
  }
});
