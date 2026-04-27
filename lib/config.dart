import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConfig {
  // 💡 방금 찾은 내 PC의 IPv4 주소로 변경하세요!
  static const String SERVER_IP = '192.168.0.15'; 

  static String get baseUrl {
    return 'http://$SERVER_IP:8000'; 
  }

  static String get wsUrl {
    return 'ws://$SERVER_IP:8000';
  }

  static String get hlsUrl {
    return 'http://$SERVER_IP:8888';
  }
}