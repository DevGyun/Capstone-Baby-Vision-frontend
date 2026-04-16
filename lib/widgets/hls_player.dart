import 'package:flutter/material.dart';

// 💡 [핵심] 웹 브라우저 환경이면 web.dart를, 모바일 앱 환경이면 mobile.dart를 자동으로 불러옵니다!
import 'hls_player_mobile.dart' if (dart.library.html) 'hls_player_web.dart';

class HlsPlayer extends StatelessWidget {
  final String streamUrl;

  const HlsPlayer({super.key, required this.streamUrl});

  @override
  Widget build(BuildContext context) {
    // 1. 긴 주소에서 끝부분 카메라 ID만 깔끔하게 추출
    String cleanStreamId = streamUrl.split('/').last.trim();
    
    // 2. 플랫폼에 맞는 플레이어 위젯 반환 (각 파일에 구현된 함수가 호출됨)
    return getPlatformPlayer(cleanStreamId);
  }
}