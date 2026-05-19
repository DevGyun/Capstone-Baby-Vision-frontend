import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/alert_seen_storage.dart';
import '../services/notification_service.dart';

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
  bool _pushEnabled = true;
  set pushEnabled(bool value) => _pushEnabled = value;
  List<IncidentLog> get logs => _logs;
  bool get isLoading => _isLoading;

  // _authHeaders() 메서드 삭제

Future<void> fetchAlerts() async {
  _isLoading = true;
  notifyListeners();
  try {
    final response = await ApiClient.request('GET', '/alerts');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      final newLogs = data.map((e) => IncidentLog.fromJson(e)).toList();

      // 새로 들어온 알림 중 푸시 띄울 것들 찾기
      await _maybePushNewAlerts(newLogs);

      _logs = newLogs;
    } else {
      debugPrint('알림 목록 실패: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('알림 목록 에러: $e');
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

/// 새 알림 발견 시 로컬 푸시 발행.
///
/// 규칙:
/// - 첫 실행이면 푸시 안 띄움 (과거 알림 폭탄 방지)
/// - 이미 푸시한 ID는 다시 안 띄움
/// - 사용자가 알림 끄면 안 띄움
/// - 한 폴링 사이클에 5개 넘게 새로 들어오면 첫 1개만 띄우고
///   "외 N건"으로 합침 (스팸 방지)
Future<void> _maybePushNewAlerts(List<IncidentLog> latestLogs) async {
  if (latestLogs.isEmpty) return;

  // 첫 실행 — 기존 알림 다 마킹만 하고 끝
  final initialized = await AlertSeenStorage.isInitialized();
  if (!initialized) {
    await AlertSeenStorage.markInitialized(
      latestLogs.map((l) => l.id).toList(),
    );
    return;
  }

  if (!_pushEnabled) return;

  // 푸시 띄울 후보들 — 아직 안 본 알림만
  final List<IncidentLog> fresh = [];
  for (final log in latestLogs) {
    if (!await AlertSeenStorage.hasSeen(log.id)) {
      fresh.add(log);
    }
  }
  if (fresh.isEmpty) return;

  // 너무 많으면 한 번에 합쳐서 표시
  if (fresh.length == 1) {
    final log = fresh.first;
    await NotificationService().showUrgentNotification(
      title: '🚨 ${log.title}',
      body: log.description.isEmpty
          ? '카메라에서 위험이 감지됐어요'
          : log.description,
    );
  } else {
    // 가장 최근 + "외 N건"
    final newest = fresh.first; // fetchAlerts가 sent_at desc로 옴
    await NotificationService().showUrgentNotification(
      title: '🚨 새 알림 ${fresh.length}건',
      body: '${newest.title} 외 ${fresh.length - 1}건',
    );
  }

  // 모두 본 것으로 마킹
  for (final log in fresh) {
    await AlertSeenStorage.markSeen(log.id);
  }
}

  Future<void> markAsRead(int alertId) async {
    try {
      final response = await ApiClient.request('PATCH', '/alerts/$alertId/read');
      if (response.statusCode == 200) {
        await fetchAlerts();
      }
    } catch (e) {
      debugPrint('읽음 처리 에러: $e');
    }
  }
  /// 로그아웃 시 호출 — 푸시 추적 상태 초기화
Future<void> clearSeenAlerts() async {
  await AlertSeenStorage.clear();
}
/// 단일 알림 삭제. 낙관적 UI — 화면에서 먼저 빼고, 실패 시 되돌림.
Future<bool> deleteAlert(int alertId) async {
  final original = List<IncidentLog>.from(_logs);
  _logs.removeWhere((l) => l.id == alertId);
  notifyListeners();

  try {
    final response = await ApiClient.request('DELETE', '/alerts/$alertId');
    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    }
    _logs = original;
    notifyListeners();
    return false;
  } catch (e) {
    debugPrint('알림 삭제 에러: $e');
    _logs = original;
    notifyListeners();
    return false;
  }
}

/// 여러 알림 일괄 삭제. 성공한 갯수 반환.
Future<int> deleteAlerts(List<int> alertIds) async {
  if (alertIds.isEmpty) return 0;

  final original = List<IncidentLog>.from(_logs);
  final idSet = alertIds.toSet();
  _logs.removeWhere((l) => idSet.contains(l.id));
  notifyListeners();

  try {
    final response = await ApiClient.request(
      'POST',
      '/alerts/bulk-delete',
      body: {'alert_ids': alertIds},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['deleted_count'] as int?) ?? 0;
    }
    _logs = original;
    notifyListeners();
    return 0;
  } catch (e) {
    debugPrint('알림 일괄 삭제 에러: $e');
    _logs = original;
    notifyListeners();
    return 0;
  }
}

/// 전체 삭제.
Future<bool> clearAllAlerts() async {
  final original = List<IncidentLog>.from(_logs);
  _logs.clear();
  notifyListeners();

  try {
    final response = await ApiClient.request('DELETE', '/alerts');
    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    }
    _logs = original;
    notifyListeners();
    return false;
  } catch (e) {
    debugPrint('알림 전체 삭제 에러: $e');
    _logs = original;
    notifyListeners();
    return false;
  }
}
}
