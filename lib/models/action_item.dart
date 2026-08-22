import 'package:freezed_annotation/freezed_annotation.dart';

part 'action_item.freezed.dart';
part 'action_item.g.dart';

@freezed
abstract class ActionItem with _$ActionItem {
  const factory ActionItem({
    required String id,
    required String category, // sleep|hydration|move|focus|meal
    required String ladderKey,
    required int difficulty, // 1~5
    required int estMinutes,
    required String title,
    String? description,
  }) = _ActionItem;

  factory ActionItem.fromJson(Map<String, dynamic> json) =>
      _$ActionItemFromJson(json);
}
