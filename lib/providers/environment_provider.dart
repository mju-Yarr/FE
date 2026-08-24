import "package:flutter_riverpod/flutter_riverpod.dart";
import "../models/environment_data.dart";
import "../network/api_client.dart";
import "auth_providers.dart";

/// 홈 화면 날씨/대기질 위젯용 FutureProvider. BE `GET /environment/current`
/// (BE #226)를 호출한다. 위치는 서버가 사용자의 대표 장소로 잡으므로
/// 클라이언트가 좌표를 보내지 않는다.
///
/// 대표 장소를 아직 등록하지 않았으면 `PRIMARY_PLACE_NOT_FOUND`(404)가
/// 오는데, 이건 오류 상태가 아니라 "보여줄 게 없는" 상태라 null로 바꾼다.
/// WeatherWidget은 null이면 비노출된다.
///
/// BE는 대표 장소는 있지만 환경 조회 자체가 실패한 경우도 같은 404
/// 상태코드로 `ENVIRONMENT_UNAVAILABLE`을 응답한다(EnvironmentController) —
/// 상태코드만으로는 두 경우를 구분할 수 없어 반드시 `error.code`로
/// 분기해야 한다. 이 경우와 그 밖의 네트워크/서버 오류는 null로 숨기지
/// 않고 그대로 던져서 화면이 재시도 가능한 오류 상태를 보여주게 한다.
final environmentProvider = FutureProvider.autoDispose<EnvironmentData?>((
  ref,
) => fetchEnvironment(ref.read(apiClientProvider)));

/// provider 본체를 분리해 둔다 — `FutureProvider.autoDispose`는 구독자가
/// 없으면 응답 도착 전에 dispose될 수 있어 단위 테스트에서 Riverpod
/// 스케줄러 타이밍에 영향을 받는다. 이 함수는 `ApiClient`만 있으면 되므로
/// ProviderContainer 없이 직접 호출해 검증할 수 있다.
Future<EnvironmentData?> fetchEnvironment(ApiClient client) async {
  try {
    final json = await client.get<Map<String, dynamic>>("/environment/current");
    return EnvironmentData.fromJson(json);
  } on ApiException catch (e) {
    if (e.code == "PRIMARY_PLACE_NOT_FOUND") return null;
    rethrow;
  }
}
