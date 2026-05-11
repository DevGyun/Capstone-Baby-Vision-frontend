import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../main.dart';   // appNavigatorKey

/// 401 만나면 한 번 refresh 시도하고 재요청.
/// 그래도 실패하면 토큰 지우고 로그인 화면으로.
class ApiClient {
  static Future<Map<String, String>> _baseHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': '69420',
    };
  }

  /// 핵심: 401 시 자동 refresh
  static Future<bool> _tryRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('eyeCatchRefreshToken');
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final r = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '69420',
        },
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        await prefs.setString('eyeCatchToken', d['access_token']);
        await prefs.setString('eyeCatchRefreshToken', d['refresh_token']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('eyeCatchToken');
    await prefs.remove('eyeCatchRefreshToken');
    await prefs.remove('eyeCatchUser');
    appNavigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (_) => false);
  }
Future<bool> registerCameraPairing(String code) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/bridges/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      // 성공(200) 시 true 반환
      if (response.statusCode == 200) {
        return true;
      } else {
        print('페어링 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('서버 통신 에러: $e');
      throw Exception('서버 페어링 실패');
    }
  }
  /// GET / POST / PATCH / PUT / DELETE 공통 래퍼
  static Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> doCall() async {
      final headers = await _baseHeaders();
      final uri = Uri.parse('${AppConfig.baseUrl}$path');
      switch (method) {
        case 'GET':
          return http.get(uri, headers: headers);
        case 'POST':
          return http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
        case 'PATCH':
          return http.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
        case 'PUT':
          return http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
        case 'DELETE':
  return http.delete(
    uri,
    headers: headers,
    body: body == null ? null : jsonEncode(body),
  );
        default:
          throw ArgumentError('지원하지 않는 method: $method');
      }
    }

    var resp = await doCall();
    if (resp.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        resp = await doCall();      // 한 번 재시도
      } else {
        await _forceLogout();        // 강제 로그아웃
      }
    }
    return resp;
  }
}
