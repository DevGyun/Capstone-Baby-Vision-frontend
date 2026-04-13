import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConfig {
  // 💡 메인 API 서버 주소 (FastAPI)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://211.243.47.179:8000'; // 웹에서는 ngrok 주소로 대체됩니다.
    } else if (Platform.isAndroid) {
      // 안드로이드 에뮬레이터에서 호스트(내 컴퓨터)의 localhost에 접속하기 위한 주소입니다.
      return 'http://10.0.2.2:8000'; 
    } else {
      return 'http://211.243.47.179:8000'; 
    }
  }

  // 💡 실시간 로그/알림용 WebSocket 주소
  static String get wsUrl {
    if (kIsWeb) {
      return 'wss://211.243.47.179';
    } else if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8000';
    } else {
      return 'ws://211.243.47.179:8000';
    }
  }

  // 💡 WebRTC 송출용 주소 (MediaMTX)
  static String get webRtcUrl {
    if (kIsWeb) {
      return 'http://211.243.47.179:8554';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8554';
    } else {
      return 'http://211.243.47.179:8554';
    }
  }

  // 앱 내 영상 재생용 HLS 주소 (MediaMTX)
  // RTSP보다 플러터 앱에서 더 안정적으로 재생됩니다.
  static String get hlsUrl {
    if (kIsWeb) {
      return 'http://211.243.47.179:8888';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8888';
    } else {
      return 'http://211.243.47.179:8888';
    }
  }
}