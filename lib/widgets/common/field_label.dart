import 'package:flutter/material.dart';

/// 입력 필드 위의 작은 라벨 텍스트.
///
/// 일반적으로 다음과 같이 사용:
/// ```dart
/// FieldLabel('이메일'),
/// const SizedBox(height: 8),
/// TextField(...),
/// ```
///
/// 배경이 어두운 화면(예: 카메라 추가)에서는 [onDarkBackground]를 true로:
/// ```dart
/// FieldLabel('Wi-Fi 이름', onDarkBackground: true),
/// ```
class FieldLabel extends StatelessWidget {
  final String text;

  /// 검은 배경 위에 올릴 때 true. 기본 false면 테마 색 따라감.
  final bool onDarkBackground;

  const FieldLabel(
    this.text, {
    super.key,
    this.onDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    if (onDarkBackground) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}