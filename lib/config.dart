class AppConfig {
  // ngrok URL — 매번 ngrok 재시작하면 바뀌어요
  static const String _apiBase = 'https://madeleine-coaxial-tyron.ngrok-free.dev';
  static const String _hlsBase = 'http://220.78.207.37:8888'; // HLS는 별도

  static String get baseUrl => _apiBase;
  static String get hlsUrl => _hlsBase;
}