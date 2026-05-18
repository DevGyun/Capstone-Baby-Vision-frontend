import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 위험구역의 클라이언트-사이드 설정 저장소.
///
/// 백엔드 스키마에 dangerLevel/objectDetection 필드가 없어서,
/// 사용자가 설정한 값을 기기 안에 저장해요.
/// 추후 백엔드에 필드가 추가되면 이 클래스를 제거하고 서버로 옮기면 됨.
///
/// 저장 형식: SharedPreferences key "zone_settings"
/// {
///   `"<zone_id>"`: {"dangerLevel": 2, "objectDetection": true},
///   `"<zone_id>"`: {...},
/// }
class ZoneSettingsStorage {
  static const String _key = 'zone_settings';

  /// 모든 zone 설정을 한 번에 읽기.
  static Future<Map<int, ZoneLocalSettings>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((idStr, value) {
        final id = int.parse(idStr);
        final map = value as Map<String, dynamic>;
        return MapEntry(id, ZoneLocalSettings.fromJson(map));
      });
    } catch (_) {
      return {};
    }
  }

  /// 특정 zone의 설정 저장.
  static Future<void> save(int zoneId, ZoneLocalSettings settings) async {
    final all = await loadAll();
    all[zoneId] = settings;
    await _writeAll(all);
  }

  /// zone이 삭제됐을 때 호출 — 관련 설정도 같이 정리.
  static Future<void> remove(int zoneId) async {
    final all = await loadAll();
    if (all.remove(zoneId) != null) {
      await _writeAll(all);
    }
  }

  static Future<void> _writeAll(Map<int, ZoneLocalSettings> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      all.map((id, s) => MapEntry(id.toString(), s.toJson())),
    );
    await prefs.setString(_key, encoded);
  }
}

class ZoneLocalSettings {
  final int dangerLevel;        // 0=낮음, 1=중간, 2=높음
  final bool objectDetection;

  const ZoneLocalSettings({
    this.dangerLevel = 2,
    this.objectDetection = true,
  });

  Map<String, dynamic> toJson() => {
        'dangerLevel': dangerLevel,
        'objectDetection': objectDetection,
      };

  factory ZoneLocalSettings.fromJson(Map<String, dynamic> json) {
    return ZoneLocalSettings(
      dangerLevel: (json['dangerLevel'] as int?) ?? 2,
      objectDetection: (json['objectDetection'] as bool?) ?? true,
    );
  }
}