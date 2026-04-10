import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000'; 
    else if (Platform.isAndroid) return 'http://10.0.2.2:8000'; 
    else return 'http://localhost:8000'; 
  }

  static String get wsUrl {
    if (kIsWeb) return 'ws://localhost:8000';
    else if (Platform.isAndroid) return 'ws://10.0.2.2:8000';
    else return 'ws://localhost:8000';
  }

  // 💡 새롭게 추가할 부분: RTSP 스트리밍 서버 주소
  static String get rtspUrl {
    if (kIsWeb) {
      return 'rtsp://localhost:8554';
    } else if (Platform.isAndroid) {
      return 'rtsp://10.0.2.2:8554';
    } else {
      return 'rtsp://localhost:8554';
    }
  }
}