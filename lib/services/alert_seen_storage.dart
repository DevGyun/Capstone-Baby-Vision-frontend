import 'package:shared_preferences/shared_preferences.dart';

/// 이미 푸시를 띄운 알림 ID들을 기억하는 저장소.
///
/// 폴링은 30초마다 같은 알림을 다시 가져와요.
/// 같은 알림에 매번 푸시를 띄우면 곤란하니, "이미 푸시한 ID"를 기록.
///
/// 첫 실행 시점에는 기존 알림 전부를 "본 것"으로 간주해야 해요.
/// 안 그러면 앱 처음 켰을 때 과거 알림 100개가 한꺼번에 푸시로 쏟아져요.
class AlertSeenStorage {
  static const String _seenKey = 'alert_seen_ids';
  static const String _initializedKey = 'alert_seen_initialized';
  static const int _maxStored = 200; // 너무 많으면 오래된 것부터 잘림

  /// 첫 실행 여부 확인 — 첫 실행이면 푸시를 띄우지 않고 마킹만 함
  static Future<bool> isInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_initializedKey) ?? false;
  }

  /// 첫 실행 시 호출 — 현재 알림 목록을 "이미 본 것"으로 마킹
  static Future<void> markInitialized(List<int> currentIds) async {
    final prefs = await SharedPreferences.getInstance();
    final stringIds = currentIds.map((id) => id.toString()).toList();
    await prefs.setStringList(_seenKey, stringIds);
    await prefs.setBool(_initializedKey, true);
  }

  /// 이미 푸시 띄운 알림인가?
  static Future<bool> hasSeen(int alertId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? [];
    return seen.contains(alertId.toString());
  }

  /// 푸시 띄운 후 호출 — "이미 본 것"으로 마킹
  static Future<void> markSeen(int alertId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? [];
    final idStr = alertId.toString();
    if (seen.contains(idStr)) return;

    seen.add(idStr);

    // 너무 많이 쌓이면 오래된 것부터 제거 (단순히 앞에서 자름)
    if (seen.length > _maxStored) {
      seen.removeRange(0, seen.length - _maxStored);
    }
    await prefs.setStringList(_seenKey, seen);
  }

  /// 로그아웃 시 초기화
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey);
    await prefs.remove(_initializedKey);
  }
}