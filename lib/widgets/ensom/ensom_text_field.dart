import "package:flutter/material.dart";
import "../../theme/ensom_colors.dart";

enum EnsomFieldTone { neutral, ok, bad }

/// 화면연결명세서 §9.3 입력 필드 규격: 라벨(11px/600, inkMuted)이 위,
/// 인풋은 hairline 테두리(1.4px)·radius 12, 포커스 시 cta 테두리.
/// 도움말은 상태별 색(중립/성공-limeInk/실패-caution)로 표시한다.
class EnsomTextField extends StatelessWidget {
  const EnsomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.helperText,
    this.helperTone = EnsomFieldTone.neutral,
    this.autofocus = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? helperText;
  final EnsomFieldTone helperTone;
  final bool autofocus;
  final bool enabled;

  Color get _helperColor => switch (helperTone) {
    EnsomFieldTone.neutral => EnsomColors.inkFaint,
    EnsomFieldTone.ok => EnsomColors.limeInk,
    EnsomFieldTone.bad => EnsomColors.caution,
  };

  @override
  Widget build(BuildContext context) {
    final borderColor = helperTone == EnsomFieldTone.bad
        ? EnsomColors.caution
        : EnsomColors.hairline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: EnsomColors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          enabled: enabled,
          style: const TextStyle(fontSize: 13, color: EnsomColors.ink),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: EnsomColors.surface1,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1.4),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EnsomColors.cta, width: 1.4),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 5),
          Text(
            helperText!,
            style: TextStyle(fontSize: 10.5, color: _helperColor, height: 1.4),
          ),
        ],
      ],
    );
  }
}
