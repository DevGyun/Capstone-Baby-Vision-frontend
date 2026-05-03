class AppConfig {
  static const String SERVER_IP = '115.23.243.116';

  static String get baseUrl => 'http://$SERVER_IP:8000';
  static String get wsUrl  => 'ws://$SERVER_IP:8000';
  static String get hlsUrl => 'http://$SERVER_IP:8888';
}
