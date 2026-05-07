import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 로딩 시 콘텐츠 자리에 표시되는 회색 박스. 부드러운 shimmer 애니메이션.
///
/// 사용 예 (단일 박스):
/// ```dart
/// const SkeletonBox(width: 200, height: 16)
/// const SkeletonBox.circle(size: 40)
/// ```
///
/// 사용 예 (조합 — 카드 한 장 모양):
/// ```dart
/// SoftCard(
///   child: Column(
///     children: [
///       SkeletonBox(width: double.infinity, height: 180),
///       const SizedBox(height: 12),
///       SkeletonBox(width: 120, height: 14),
///     ],
///   ),
/// )
/// ```
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  final bool isCircle;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadius.sm,
  }) : isCircle = false;

  const SkeletonBox.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        radius = 0,
        isCircle = true;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = isDark
        ? cs.surfaceContainerHigh
        : cs.surfaceContainerHighest;
    final highlight = isDark
        ? cs.surfaceContainerHighest
        : cs.surfaceContainer;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, _controller.value),
            borderRadius: widget.isCircle
                ? null
                : BorderRadius.circular(widget.radius),
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
          ),
        );
      },
    );
  }
}

/// 카메라 카드 / 알림 아이템 / 위험구역 등 자주 쓰이는 스켈레톤 조합.
class SkeletonPresets {
  SkeletonPresets._();

  /// 라이브 카메라 카드 스켈레톤 (16:9 + 텍스트 한 줄).
  static Widget cameraCard() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonBox(
                width: double.infinity,
                height: double.infinity,
                radius: AppRadius.lg,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            const SkeletonBox(width: 120, height: 13),
          ],
        ),
      );

  /// 리스트 아이템 (아이콘 + 제목 + 부제목).
  static Widget listItem() => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox.circle(size: 36),
            const SizedBox(width: AppSpacing.md - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 13),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 140, height: 11),
                ],
              ),
            ),
          ],
        ),
      );

  /// 카메라 썸네일 한 줄 (3개).
  static Widget thumbnailRow() => Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: SkeletonBox(
                  width: double.infinity,
                  height: double.infinity,
                  radius: AppRadius.md,
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      );
}
