import 'package:flutter/material.dart';

/// 그리는 중 / 편집 중인 다각형을 그리는 페인터.
///
/// 좌표 체계:
/// - [points]는 정규화 좌표 (0.0~1.0). 화면 크기에 무관.
/// - [size]는 캔버스의 실제 픽셀 크기. paint 시 곱해서 픽셀로 변환.
class PolygonEditorPainter extends CustomPainter {
  final List<Offset> normalizedPoints;
  final int? selectedIndex;
  final bool isCompleted;
  final String? label;

  /// 위험구역은 기존 zone_screen 컨벤션에 맞춰 orangeAccent.
  static const Color _dangerColor = Colors.orangeAccent;

  PolygonEditorPainter({
    required this.normalizedPoints,
    this.selectedIndex,
    this.isCompleted = false,
    this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (normalizedPoints.isEmpty) return;

    // 정규화 → 픽셀
    final pixel = normalizedPoints
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();

    final fillColor = _dangerColor.withOpacity(isCompleted ? 0.30 : 0.15);
    final strokeColor = _dangerColor;

    // 다각형 채우기 + 외곽선 (3개 이상)
    if (pixel.length >= 3) {
      final path = Path()..addPolygon(pixel, true);
      canvas.drawPath(path, Paint()..color = fillColor);
      canvas.drawPath(
        path,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // 완성된 다각형엔 라벨 표시
      if (isCompleted && label != null && label!.isNotEmpty) {
        _drawLabel(canvas, _centroid(pixel), label!);
      }
    } else if (pixel.length == 2) {
      // 점 2개면 선분만
      canvas.drawLine(
        pixel[0],
        pixel[1],
        Paint()
          ..color = strokeColor
          ..strokeWidth = 2.5,
      );
    }

    // 미완성 다각형의 마지막 점 → 첫 점 점선 미리보기 (3점 이상)
    if (!isCompleted && pixel.length >= 3) {
      _drawDashedLine(canvas, pixel.last, pixel.first, strokeColor);
    }

    // 점 핸들
    for (var i = 0; i < pixel.length; i++) {
      final isSel = i == selectedIndex;
      final r = isSel ? 13.0 : 10.0;
      // 외곽 (오렌지)
      canvas.drawCircle(pixel[i], r, Paint()..color = strokeColor);
      // 내부 흰
      canvas.drawCircle(pixel[i], r - 4, Paint()..color = Colors.white);
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
          fontWeight: FontWeight.bold,
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
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
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
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1.5;
    final total = (b - a).distance;
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
