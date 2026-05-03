import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

// 백엔드 GET /alerts 응답에 맞춰 정의
// 응답 예: {id, message, is_read, sent_at, zone_name, confidence, detected_at}
class IncidentLog {
  final int id;
  final String message;
  final bool isRead;
  final DateTime sentAt;
  final String? zoneName;
  final double? confidence;
  final DateTime? detectedAt;

  IncidentLog({
    required this.id,
    required this.message,
    required this.isRead,
    required this.sentAt,
    this.zoneName,
    this.confidence,
    this.detectedAt,
  });

  factory IncidentLog.fromJson(Map<String, dynamic> json) {
    return IncidentLog(
      id:         json['id'],
      message:    json['message'] ?? '',
      isRead:     json['is_read'] ?? false,
      sentAt:     DateTime.parse(json['sent_at']).toLocal(),
      zoneName:   json['zone_name'],
      confidence: (json['confidence'] as num?)?.toDouble(),
      detectedAt: json['detected_at'] != null
                  ? DateTime.parse(json['detected_at']).toLocal()
                  : null,
    );
  }

  // ── UI 호환용 getter (history/main/details 화면에서 사용) ─
  String get title       => zoneName != null ? '$zoneName 감지' : '위험 감지';
  String get description => message;
  String get time        => _timeAgo(sentAt);
  IconData get icon      => Icons.warning_amber_rounded;
  Color get iconColor    => Colors.redAccent;
  bool get isAlert       => true;
  String get imageUrl    => 'assets/images/1babyscreen.png';

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours   < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

class LogProvider extends ChangeNotifier {
  List<IncidentLog> _logs = [];
  bool _isLoading = false;

  List<IncidentLog> get logs => _logs;
  bool get isLoading => _isLoading;

  Future<Map<String, String>?> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');
    if (token == null) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': '69420',
    };
  }

  // ── 알림 목록 조회 ── GET /alerts
  Future<void> fetchAlerts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final headers = await _authHeaders();
      if (headers == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/alerts'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        _logs = data.map((e) => IncidentLog.fromJson(e)).toList();
      } else {
        print('알림 목록 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('알림 목록 에러: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── 읽음 처리 ── PATCH /alerts/{id}/read
  Future<void> markAsRead(int alertId) async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return;

      final response = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/alerts/$alertId/read'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        await fetchAlerts(); // 목록 다시 받아오기
      }
    } catch (e) {
      print('읽음 처리 에러: $e');
    }
  }

  // 로컬 푸시 도착 시 즉시 추가용 (서버 동기화는 fetchAlerts로)
  void addLog(IncidentLog newLog) {
    _logs.insert(0, newLog);
    notifyListeners();
  }
}
