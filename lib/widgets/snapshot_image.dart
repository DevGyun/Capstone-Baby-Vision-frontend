import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 위험 감지 스냅샷 이미지.
///
/// 백엔드 GET /alerts/snapshots/{filename} 은 Bearer 토큰이 필요해서
/// Image.network에 Authorization 헤더를 붙여야 해요.
/// URL이 없거나(아직 스냅샷 미저장) 로딩 실패 시 placeholder 에셋으로 폴백.
class SnapshotImage extends StatefulWidget {
  final String? snapshotUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String fallbackAsset;
  final Color? color;
  final BlendMode? colorBlendMode;

  const SnapshotImage({
    super.key,
    required this.snapshotUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackAsset = 'assets/images/1babyscreen.png',
    this.color,
    this.colorBlendMode,
  });

  @override
  State<SnapshotImage> createState() => _SnapshotImageState();
}

class _SnapshotImageState extends State<SnapshotImage> {
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Future<void> _loadHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken') ?? '';
    if (!mounted) return;
    setState(() {
      _headers = {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': '69420',
      };
    });
  }

  Widget _fallback() => Image.asset(
        widget.fallbackAsset,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
      );

  @override
  Widget build(BuildContext context) {
    final url = widget.snapshotUrl;

    // 스냅샷 없음(예전 알림 등) or 토큰 헤더 준비 전 → placeholder
    if (url == null || url.isEmpty || _headers == null) {
      return _fallback();
    }

    return Image.network(
      url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      headers: _headers,
      errorBuilder: (_, __, ___) => _fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _fallback();
      },
    );
  }
}