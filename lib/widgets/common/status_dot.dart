import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 카메라 / 시스템 연결 상태 점.
///
/// - [StatusDotKind.online]: 녹색 (펄스 애니메이션 옵션)
/// - [StatusDotKind.offline]: 회색
/// - [StatusDotKind.warning]: 앰버
/// - [StatusDotKind.alert]: 빨강 (펄스 애니메이션 옵션)
enum StatusDotKind { online, offline, warning, alert }

class StatusDot extends StatefulWidget {
  final StatusDotKind kind;
  final double size;

  /// true면 부드럽게 펄스 (LIVE 인디케이터 같은 곳).
  /// 정적인 표시 (썸네일 우상단 점)에서는 false.
  final bool pulse;

  const StatusDot({
    super.key,
    required this.kind,
    this.size = 8,
    this.pulse = false,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _color() {
    switch (widget.kind) {
      case StatusDotKind.online:
        return AppColors.success;
      case StatusDotKind.offline:
        return Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:0.6);
      case StatusDotKind.warning:
        return AppColors.warning;
      case StatusDotKind.alert:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    if (!widget.pulse) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha:_controller.value * 0.5),
                blurRadius: 8,
                spreadRadius: 1.5,
              ),
            ],
          ),
        );
      },
    );
  }
}
