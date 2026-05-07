import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 칩 스타일 톤.
enum SoftChipTone { neutral, accent, success, warning, danger, dark }

/// 작은 배지/태그/라벨용 칩.
/// 주황 LIVE 배지, 카메라 이름 칩, 알림 카운트 등에 사용.
///
/// 사용 예:
/// ```dart
/// SoftChip(label: 'LIVE', tone: SoftChipTone.accent, leadingDot: true)
/// SoftChip(label: '온라인 2대', tone: SoftChipTone.success)
/// SoftChip(label: '주방', icon: Icons.warning_amber_rounded)
/// ```
class SoftChip extends StatelessWidget {
  final String label;
  final SoftChipTone tone;
  final IconData? icon;

  /// true면 라벨 앞에 작은 점 표시 (LIVE 배지 등).
  final bool leadingDot;

  /// true면 점이 펄스 (LIVE 등).
  final bool pulseDot;

  const SoftChip({
    super.key,
    required this.label,
    this.tone = SoftChipTone.neutral,
    this.icon,
    this.leadingDot = false,
    this.pulseDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDot) ...[
            _Dot(color: colors.foreground, pulse: pulseDot),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 13, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _ChipColors _resolveColors(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (tone) {
      case SoftChipTone.neutral:
        return _ChipColors(
          background: cs.surfaceContainerHigh,
          foreground: cs.onSurfaceVariant,
        );
      case SoftChipTone.accent:
        return _ChipColors(
          background: AppColors.accent.withOpacity(isDark ? 0.18 : 0.12),
          foreground: AppColors.accent,
        );
      case SoftChipTone.success:
        return _ChipColors(
          background: AppColors.success.withOpacity(isDark ? 0.16 : 0.10),
          foreground: AppColors.success,
        );
      case SoftChipTone.warning:
        return _ChipColors(
          background: AppColors.warning.withOpacity(isDark ? 0.16 : 0.10),
          foreground: AppColors.warning,
        );
      case SoftChipTone.danger:
        return _ChipColors(
          background: AppColors.danger.withOpacity(isDark ? 0.16 : 0.10),
          foreground: AppColors.danger,
        );
      case SoftChipTone.dark:
        // 영상 위에 얹는 칩 (LIVE 등) — 영상이 밝든 어둡든 잘 보이게
        return _ChipColors(
          background: Colors.black.withOpacity(0.55),
          foreground: Colors.white,
        );
    }
  }
}

class _ChipColors {
  final Color background;
  final Color foreground;
  _ChipColors({required this.background, required this.foreground});
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, required this.pulse});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_controller.value * 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
