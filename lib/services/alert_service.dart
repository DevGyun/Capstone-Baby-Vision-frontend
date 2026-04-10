import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AlertService {
  static String get baseUrl => AppConfig.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> fetchAlerts() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/alerts'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw Exception('알림을 불러오는데 실패했습니다: ${response.statusCode}');
  }

  static Future<void> markAlertAsRead(int alertId) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/alerts/$alertId/read'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('읽음 처리에 실패했습니다: ${response.statusCode}');
    }
  }

  static Future<void> triggerTestAlert() async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$baseUrl/alerts/test'),
      headers: headers,
      body: jsonEncode({'message': '테스트 위험 감지 알림입니다.', 'zone': '침대 주변'}),
    );
  }
}
