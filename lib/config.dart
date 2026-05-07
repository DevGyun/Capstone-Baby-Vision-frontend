class AppConfig {
  static const String SERVER_IP = 'localhost'; // 실제 서버 IP로 변경 필요

  static String get baseUrl => 'http://$SERVER_IP:8000';
  static String get wsUrl  => 'ws://$SERVER_IP:8000';
  static String get hlsUrl => 'http://$SERVER_IP:8888';
}
