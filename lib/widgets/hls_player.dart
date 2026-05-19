import 'package:flutter/material.dart';

// 웹/모바일 자동 분기
import 'hls_player_mobile.dart';

class HlsPlayer extends StatelessWidget {
  final String streamUrl;
  final VoidCallback? onConnected;
  final VoidCallback? onRetry;

  /// true면 연결 직후 라이브 엣지로 점프.
  /// HLS는 기본적으로 5~10초 뒤처져 재생되니, "지금 이 순간" 프레임이
  /// 필요한 캡처용일 때 켜세요. 실시간 화면처럼 부드러운 재생이 필요한
  /// 곳에선 false(기본값) 유지.
  final bool seekToLiveOnConnect;

  const HlsPlayer({
    super.key,
    required this.streamUrl,
    this.onConnected,
    this.onRetry,
    this.seekToLiveOnConnect = false,
  });

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
    return getPlatformPlayer(
      streamUrl,
      onConnected: onConnected,
      onRetry: onRetry,
      seekToLiveOnConnect: seekToLiveOnConnect,
    );
  }
}
