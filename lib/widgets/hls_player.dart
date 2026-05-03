import 'package:flutter/material.dart';

// 웹/모바일 자동 분기
import 'hls_player_mobile.dart' if (dart.library.html) 'hls_player_web.dart';

class HlsPlayer extends StatelessWidget {
  // 백엔드의 hls_url 그대로: http://host:8888/{uuid}/index.m3u8
  final String streamUrl;

  const HlsPlayer({super.key, required this.streamUrl});

  @override
  Widget build(BuildContext context) {
    if (streamUrl.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('스트림 URL이 비어있습니다.', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    return getPlatformPlayer(streamUrl);
  }
}
