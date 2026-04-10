import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'; // kIsWeb을 사용하기 위해 필요

class AppConfig {
  // 환경에 따라 자동으로 서버 주소를 할당합니다. (포트 번호는 실제 백엔드에 맞게 수정하세요)
  static String get baseUrl {
    if (kIsWeb) {
      // 1. 웹 브라우저 환경
      return 'http://localhost:8000'; 
    } 
    // 웹이 아닌 네이티브(모바일) 환경일 때만 Platform 검사
    else if (Platform.isAndroid) {
      // 2. 안드로이드 에뮬레이터 환경
      return 'http://10.0.2.2:8000'; 
    } else {
      // 3. iOS 시뮬레이터 (localhost 사용 가능) 또는 기타 환경
      return 'http://localhost:8000'; 
    }
  }
  // 웹소켓 서버의 기본 주소 (알림 기능 등에 사용 시)
  static String get wsUrl {
    if (kIsWeb) {
      return 'ws://localhost:8000';
    } else if (Platform.isAndroid) {
      return 'ws://10.0.2.2:8000';
    } else {
      return 'ws://localhost:8000';
    }
  }
}