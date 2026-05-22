class AppConfig {
  // ngrok URL — 매번 ngrok 재시작하면 바뀌어요
  static const String _apiBase = 'http://211.243.47.179:8000';

  static String get baseUrl => _apiBase;
}
