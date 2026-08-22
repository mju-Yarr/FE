import "dart:convert";
import "package:http/http.dart" as http;

/// 카카오 로컬(키워드 검색) REST API 결과 한 건.
/// kakao_map_sdk(지도 렌더링 전용)에는 검색 기능이 없어서 별도로 붙인다.
class KakaoSearchResult {
  const KakaoSearchResult({
    required this.name,
    required this.addressName,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String addressName;
  final double lat;
  final double lng;

  factory KakaoSearchResult.fromJson(Map<String, dynamic> json) {
    return KakaoSearchResult(
      name: json["place_name"] as String,
      addressName: (json["road_address_name"] as String?)?.isNotEmpty == true
          ? json["road_address_name"] as String
          : json["address_name"] as String,
      lat: double.parse(json["y"] as String),
      lng: double.parse(json["x"] as String),
    );
  }
}

class KakaoLocalSearchException implements Exception {
  const KakaoLocalSearchException({
    required this.statusCode,
    this.errorType,
    this.apiMessage,
  });

  factory KakaoLocalSearchException.fromResponse(http.Response response) {
    String? errorType;
    String? apiMessage;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      errorType = body["errorType"] as String?;
      apiMessage = body["message"] as String?;
    } catch (_) {
      // HTML 등 JSON이 아닌 오류 응답은 상태 코드만 사용한다.
    }
    return KakaoLocalSearchException(
      statusCode: response.statusCode,
      errorType: errorType,
      apiMessage: apiMessage,
    );
  }

  final int statusCode;
  final String? errorType;
  final String? apiMessage;

  bool get isMapAndLocalServiceDisabled =>
      statusCode == 403 &&
      errorType == "NotAuthorizedError" &&
      (apiMessage?.contains("disabled OPEN_MAP_AND_LOCAL") ?? false);

  String get userMessage => isMapAndLocalServiceDisabled
      ? "카카오 지도·장소 서비스가 비활성화되어 있어요. 관리자 설정 후 다시 시도해주세요."
      : "장소 검색을 사용할 수 없어요. 잠시 후 다시 시도해주세요.";
}

/// 목적지 키워드 검색. REST API 키가 비어 있으면 항상 빈 리스트를
/// 반환해서 호출부(map_screen.dart)가 지도를 눌러 좌표를 고르는
/// 방식으로 저하 동작하게 한다.
class KakaoLocalSearchService {
  KakaoLocalSearchService({required String restApiKey, http.Client? client})
    : _restApiKey = restApiKey,
      _http = client ?? http.Client();

  static const _endpoint =
      "https://dapi.kakao.com/v2/local/search/keyword.json";
  static const _coord2addressEndpoint =
      "https://dapi.kakao.com/v2/local/geo/coord2address.json";

  final String _restApiKey;
  final http.Client _http;

  bool get isAvailable => _restApiKey.isNotEmpty;

  Future<List<KakaoSearchResult>> search(String query) async {
    if (!isAvailable || query.trim().isEmpty) return const [];

    final uri = Uri.parse(_endpoint).replace(queryParameters: {"query": query});
    final response = await _http.get(
      uri,
      headers: {"Authorization": "KakaoAK $_restApiKey"},
    );

    if (response.statusCode != 200) {
      throw KakaoLocalSearchException.fromResponse(response);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = body["documents"] as List<dynamic>? ?? const [];
    return documents
        .map((e) => KakaoSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 좌표 → 주소 역지오코딩 (카카오 `coord2address`).
  ///
  /// 주요 장소 등록은 현재 위치 좌표로만 이뤄지는데 BE `POST /places`가
  /// `address`를 필수(`@NotBlank`, DB `not null`)로 받으므로, 좌표를 사람이
  /// 읽는 주소 문자열로 변환해 채워 보낸다.
  ///
  /// 도로명 주소를 우선하고 없으면 지번 주소를 쓴다. 키가 없거나 결과가
  /// 없으면 `null`을 반환해 호출부가 폴백을 결정하게 한다.
  Future<String?> coord2address(double lat, double lng) async {
    if (!isAvailable) return null;

    // 카카오 좌표계는 x=경도(lng), y=위도(lat) 순서다.
    final uri = Uri.parse(
      _coord2addressEndpoint,
    ).replace(queryParameters: {"x": "$lng", "y": "$lat"});
    final response = await _http.get(
      uri,
      headers: {"Authorization": "KakaoAK $_restApiKey"},
    );

    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = body["documents"] as List<dynamic>? ?? const [];
    if (documents.isEmpty) return null;

    final first = documents.first as Map<String, dynamic>;
    final road = first["road_address"] as Map<String, dynamic>?;
    final roadName = road?["address_name"] as String?;
    if (roadName != null && roadName.isNotEmpty) return roadName;

    final addr = first["address"] as Map<String, dynamic>?;
    final addrName = addr?["address_name"] as String?;
    if (addrName != null && addrName.isNotEmpty) return addrName;

    return null;
  }
}
