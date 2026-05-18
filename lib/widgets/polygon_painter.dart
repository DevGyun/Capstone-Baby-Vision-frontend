import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 그리는 중 / 편집 중인 다각형 페인터.
///
/// 좌표 체계:
/// - [normalizedPoints]는 정규화 좌표 (0.0~1.0). 화면 크기 무관.
/// - paint 시 캔버스 size에 곱해 픽셀 좌표로 변환.
class PolygonEditorPainter extends CustomPainter {
  final List<Offset> normalizedPoints;
  final int? selectedIndex;
  final bool isCompleted;
  final String? label;

  /// 색상은 디자인 시스템의 액센트(테라코타) 사용.
  final Color strokeColor;
  final Color fillColor;

  PolygonEditorPainter({
    required this.normalizedPoints,
    this.selectedIndex,
    this.isCompleted = false,
    this.label,
    Color? strokeColor,
    Color? fillColor,
  })  : strokeColor = strokeColor ?? AppColors.warning,
        fillColor = fillColor ??
            AppColors.warning.withValues(alpha:isCompleted ? 0.20 : 0.10);

  @override
  void paint(Canvas canvas, Size size) {
    if (normalizedPoints.isEmpty) return;

    // 정규화 → 픽셀
    final pixel = normalizedPoints
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    // 다각형 채우기 + 외곽선 (3개 이상)
    if (pixel.length >= 3) {
      final path = Path()..addPolygon(pixel, true);

      canvas.drawPath(path, Paint()..color = fillColor);

      canvas.drawPath(
        path,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );

      if (isCompleted && label != null && label!.isNotEmpty) {
        _drawLabel(canvas, _centroid(pixel), label!);
      }
    } else if (pixel.length == 2) {
      canvas.drawLine(
        pixel[0],
        pixel[1],
        Paint()
          ..color = strokeColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // 미완성 다각형: 마지막 점 → 첫 점 점선 미리보기 (3점 이상)
    if (!isCompleted && pixel.length >= 3) {
      _drawDashedLine(canvas, pixel.last, pixel.first, strokeColor);
    }

    // 점 핸들
    for (var i = 0; i < pixel.length; i++) {
      final isSel = i == selectedIndex;
      final r = isSel ? 13.0 : 10.0;

      // 외곽 (액센트)
      canvas.drawCircle(pixel[i], r, Paint()..color = strokeColor);
      // 내부 흰색
      canvas.drawCircle(
        pixel[i],
        r - 4,
        Paint()..color = Colors.white,
      );
      // 점 번호
      _drawNumber(canvas, pixel[i], '${i + 1}', strokeColor);
    }
  }

  void _drawNumber(Canvas canvas, Offset center, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: const ['Noto Sans KR'],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawLabel(Canvas canvas, Offset center, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          shadows: [
            Shadow(blurRadius: 6, color: Colors.black87),
            Shadow(blurRadius: 12, color: Colors.black54),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Color color) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    final paint = Paint()
      ..color = color.withValues(alpha:0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    double drawn = 0;
    while (drawn < total) {
      final next = (drawn + dashLen).clamp(0.0, total);
      canvas.drawLine(a + dir * drawn, a + dir * next, paint);
      drawn = next + gapLen;
    }
  }

  Offset _centroid(List<Offset> pts) {
    double cx = 0, cy = 0;
    for (final p in pts) {
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / pts.length, cy / pts.length);
  }

  @override
  bool shouldRepaint(covariant PolygonEditorPainter oldDelegate) {
    return oldDelegate.normalizedPoints != normalizedPoints ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.label != label;
  }
}