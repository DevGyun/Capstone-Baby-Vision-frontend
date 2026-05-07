import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 모든 카드의 베이스 위젯.
/// 라이트/다크 모드에 자동 대응하고, 패딩·radius·border가 통일됨.
///
/// 사용 예:
/// ```dart
/// SoftCard(
///   child: Text('내용'),
/// )
///
/// SoftCard(
///   onTap: () => doSomething(),  // 탭 가능 (스플래시 효과 자동)
///   padding: const EdgeInsets.all(AppSpacing.lg),
///   child: ...,
/// )
/// ```
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  /// false면 외곽선 제거 (배경색만으로 구분).
  final bool bordered;

  /// 카드 색상 오버라이드. null이면 기본 surface 색.
  final Color? color;

  /// 강조 카드 (모서리 색이 살짝 강조됨, 활성 카메라 등에 사용).
  final bool emphasized;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.bordered = true,
    this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = color ?? colorScheme.surfaceContainerLow;

    final borderColor = emphasized
        ? colorScheme.primary
        : (bordered ? colorScheme.outlineVariant : Colors.transparent);
    final borderWidth = emphasized ? 1.5 : 0.5;

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            splashColor: colorScheme.primary.withOpacity(0.06),
            highlightColor: colorScheme.primary.withOpacity(0.03),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
