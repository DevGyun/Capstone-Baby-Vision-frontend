import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 사용자 이름 첫 글자로 만드는 컬러풀한 이니셜 아바타.
///
/// 이름이 비어있으면 사람 아이콘을 보여줘요.
/// 같은 이름은 항상 같은 색이 나오도록 해시 기반 컬러링.
class InitialAvatar extends StatelessWidget {
  final String? name;
  final double radius;
  final double? fontSize;

  const InitialAvatar({
    super.key,
    required this.name,
    this.radius = 24,
    this.fontSize,
  });

  String get _initial {
    final n = name?.trim();
    if (n == null || n.isEmpty) return '';
    return n.characters.first.toUpperCase();
  }

  Color _bgColor(BuildContext context) {
    final n = name?.trim();
    if (n == null || n.isEmpty) {
      return Theme.of(context).colorScheme.surfaceContainerHigh;
    }
    // 이름의 hashCode로 팔레트에서 색 선택 (같은 이름 = 같은 색)
    final palette = [
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      const Color(0xFF8B5CF6), // 보라
      const Color(0xFFEC4899), // 핑크
      const Color(0xFF14B8A6), // 청록
      const Color(0xFFF97316), // 주황
    ];
    final idx = n.hashCode.abs() % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = _initial;
    final bg = _bgColor(context);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: initial.isEmpty
          ? Icon(
              Icons.person_outline,
              size: radius * 0.9,
              color: cs.onSurfaceVariant,
            )
          : Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize ?? radius * 0.85,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
    );
  }
}