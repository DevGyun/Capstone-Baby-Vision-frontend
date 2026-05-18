import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 버튼 스타일 variant.
/// - [SoftButtonVariant.primary]: 메인 CTA (테라코타 채움)
/// - [SoftButtonVariant.secondary]: 보조 액션 (외곽선만)
/// - [SoftButtonVariant.tonal]: 톤다운 액션 (살짝 채워진 회색)
/// - [SoftButtonVariant.danger]: 삭제 등 위험 액션 (빨강)
enum SoftButtonVariant { primary, secondary, tonal, danger }

/// 눌림 애니메이션 + 통일된 디자인 시스템을 따르는 버튼.
///
/// 사용 예:
/// ```dart
/// SoftButton(
///   label: '카메라 등록',
///   icon: Icons.add,
///   onPressed: () => doSomething(),
/// )
///
/// SoftButton(
///   label: '취소',
///   variant: SoftButtonVariant.secondary,
///   onPressed: () => Navigator.pop(context),
/// )
///
/// SoftButton(
///   label: '저장 중...',
///   isLoading: true,
///   onPressed: null,
/// )
/// ```
class SoftButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SoftButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;

  /// 버튼 높이. 기본 52 (디자인 시스템 값).
  final double height;

  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = SoftButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.height = 52,
  });

  @override
  State<SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<SoftButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = _resolveStyle(colorScheme);

    final child = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        height: widget.height,
        width: widget.fullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: _enabled ? style.background : style.disabledBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: style.border != null
              ? Border.all(
                  color: _enabled ? style.border! : style.disabledBorder!,
                  width: 1,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      _enabled ? style.foreground : style.disabledForeground,
                    ),
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  size: 18,
                  color: _enabled ? style.foreground : style.disabledForeground,
                ),
              if (widget.icon != null || widget.isLoading)
                const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _enabled ? style.foreground : style.disabledForeground,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!_enabled) return child;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  _ButtonStyle _resolveStyle(ColorScheme cs) {
    switch (widget.variant) {
      case SoftButtonVariant.primary:
        return _ButtonStyle(
          background: cs.primary,
          foreground: cs.onPrimary,
          border: null,
          disabledBackground: cs.surfaceContainerHigh,
          disabledForeground: cs.onSurfaceVariant.withValues(alpha:0.5),
          disabledBorder: null,
        );
      case SoftButtonVariant.secondary:
        return _ButtonStyle(
          background: Colors.transparent,
          foreground: cs.onSurface,
          border: cs.outline,
          disabledBackground: Colors.transparent,
          disabledForeground: cs.onSurfaceVariant.withValues(alpha:0.4),
          disabledBorder: cs.outlineVariant,
        );
      case SoftButtonVariant.tonal:
        return _ButtonStyle(
          background: cs.surfaceContainerHigh,
          foreground: cs.onSurface,
          border: null,
          disabledBackground: cs.surfaceContainer,
          disabledForeground: cs.onSurfaceVariant.withValues(alpha:0.5),
          disabledBorder: null,
        );
      case SoftButtonVariant.danger:
        return _ButtonStyle(
          background: AppColors.danger.withValues(alpha:
              Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.10),
          foreground: AppColors.danger,
          border: AppColors.danger.withValues(alpha:0.3),
          disabledBackground: cs.surfaceContainerHigh,
          disabledForeground: cs.onSurfaceVariant.withValues(alpha:0.5),
          disabledBorder: cs.outlineVariant,
        );
    }
  }
}

class _ButtonStyle {
  final Color background;
  final Color foreground;
  final Color? border;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color? disabledBorder;

  _ButtonStyle({
    required this.background,
    required this.foreground,
    required this.border,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.disabledBorder,
  });
}
