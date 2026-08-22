import 'package:freezed_annotation/freezed_annotation.dart';

part 'prep_item.freezed.dart';

/// 챙기기 / 사용·섭취하기 / 구매하기 / 시간이 필요한 루틴 (PRD §11.3, ERD prep_kind).
enum PrepKind { carry, consume, purchase, routine }

/// 맞춤 준비 항목. 준비시간 화면 안의 한 섹션에서 등록되며
/// 별도 온보딩 단계로 분리하지 않는다 (PRD §11.3).
///
/// fromJson/toJson 모두 수동 구현 — json_serializable codegen에 의존하지 않는다.
/// BE 응답 필드명(prepRuleId/ruleName/actionType 등)과
/// FE 필드명(id/label/kind 등) 양쪽 모두 대응한다.
@freezed
abstract class PrepItem with _$PrepItem {
  const factory PrepItem({
    required String id,
    required String label,
    required PrepKind kind,
    @Default(0) int extraMin,
    @Default(false) bool sensitive,
    @Default(false) bool fromChip,
    @Default(true) bool active,
  }) = _PrepItem;

  const PrepItem._();

  /// BE/FE 양쪽 필드명 모두 파싱 가능.
  factory PrepItem.fromJson(Map<String, dynamic> json) {
    return PrepItem(
      id: (json['id'] ?? json['prepRuleId'] ?? '') as String,
      label: (json['label'] ?? json['ruleName'] ?? '') as String,
      kind: _parseKind(json['kind'] ?? json['actionType']),
      extraMin: (json['extraMin'] ?? json['defaultMinutes'] ?? 0) as int,
      sensitive: (json['sensitive'] ?? json['isSensitive'] ?? false) as bool,
      fromChip: (json['fromChip'] ?? false) as bool,
      active: (json['active'] ?? json['isActive'] ?? true) as bool,
    );
  }

  /// FE → BE 요청 시 직렬화. FE 내부 필드명으로 보낸다.
  /// (ApiEnsomRepository._prepItemToRequestBody()가 API 명세 필드명으로
  /// 별도 변환하므로, 여기서는 FE 모델 그대로 직렬화.)
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.name,
    'extraMin': extraMin,
    'sensitive': sensitive,
    'fromChip': fromChip,
    'active': active,
  };

  /// 서버 검증 규칙과 동일한 클라이언트측 가드.
  bool get isInvalidChipCombination => fromChip && sensitive;
}

/// BE의 actionType 값(CARRY/CONSUME/PURCHASE/TIMED_ROUTINE 또는
/// carry/consume/purchase/timed_routine) 모두 파싱 가능.
PrepKind _parseKind(dynamic value) {
  if (value == null) return PrepKind.carry;
  final s = value.toString().toLowerCase();
  switch (s) {
    case 'carry':
      return PrepKind.carry;
    case 'consume':
      return PrepKind.consume;
    case 'purchase':
      return PrepKind.purchase;
    case 'routine':
    case 'timed_routine':
      return PrepKind.routine;
    default:
      return PrepKind.carry;
  }
}

/// 추천 칩 목록. 민감·규제 품목(담배·주류·복용약 등)은 여기 포함하지 않는다.
const List<Map<String, dynamic>> kPrepItemQuickAddChips = [
  {'label': '영양제', 'kind': PrepKind.consume},
  {'label': '물·텀블러', 'kind': PrepKind.carry},
  {'label': '선크림', 'kind': PrepKind.carry},
  {'label': '마스크', 'kind': PrepKind.carry},
  {'label': '우산', 'kind': PrepKind.carry},
  {'label': '보조배터리', 'kind': PrepKind.carry},
  {'label': '커피·차·간식', 'kind': PrepKind.purchase},
];
