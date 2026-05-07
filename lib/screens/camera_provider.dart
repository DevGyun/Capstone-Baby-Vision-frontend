import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

// 백엔드 응답 구조에 맞게 정의
// GET /cameras 응답: {id, name, stream_url, is_active, is_connected, hls_url}
class CameraModel {
  final int id;
  final String name;
  final String hlsUrl;      // HLS 플레이어용 (http://host:8888/uuid/index.m3u8)
  final String streamUrl;   // RTSP 원본 URL
  final bool isActive;
  final bool isConnected;

  CameraModel({
    required this.id,
    required this.name,
    required this.hlsUrl,
    required this.streamUrl,
    required this.isActive,
    required this.isConnected,
  });

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      id:          json['id'],
      name:        json['name'] ?? '알 수 없는 카메라',
      hlsUrl:      json['hls_url'] ?? '',
      streamUrl:   json['stream_url'] ?? '',
      isActive:    json['is_active'] ?? true,
      isConnected: json['is_connected'] ?? false,
    );
  }
}

class CameraProvider with ChangeNotifier {
  bool _isLoading = false;
  List<CameraModel> _cameras = [];

  /// 마지막 통신 실패의 사용자 친화적 메시지.
  /// 페어링 등에서 백엔드 detail을 SnackBar로 노출할 때 사용.
  String? _lastErrorMessage;

  bool get isLoading => _isLoading;
  List<CameraModel> get cameras => _cameras;
  String? get lastErrorMessage => _lastErrorMessage;

  // ── 공통 헬퍼 ──────────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('eyeCatchToken');
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': '69420',
  };

  /// FastAPI 에러 응답 `{"detail": "..."}` 또는 `{"detail": [{"msg": "..."}]}` 파싱.
  String? _extractDetail(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) {
            return first['msg'] as String;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ── 카메라 등록 (구버전 — 페어링 없이 이름만으로 빈 카메라 생성) ──
  // POST /cameras  {name}
  // ⚠️ 이 메서드는 진짜 라즈베리파이와 연결되지 않은 빈 카메라를 만듭니다.
  // 영상 스트리밍은 안 됩니다. 새 등록은 [pairCamera]를 사용하세요.
  // 다른 화면에서 호출하지 않는다면 안전하게 제거 가능합니다.
  Future<bool> registerCamera(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: _headers(token),
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCameras();
        return true;
      } else {
        print('카메라 등록 실패: ${response.statusCode} ${response.body}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('카메라 등록 에러: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── 카메라 페어링 등록 (신규) ──
  // POST /bridges/pair  {pairing_code, name}
  // 라즈베리파이가 부팅 시 발급받은 6자리 코드를 사용해 사용자 계정에 카메라를 연결.
  Future<bool> pairCamera({
    required String pairingCode,
    required String name,
  }) async {
    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _lastErrorMessage = '로그인이 필요해요. 다시 로그인 후 시도해 주세요.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/bridges/pair'),
        headers: _headers(token),
        body: json.encode({
          'pairing_code': pairingCode,
          'name': name,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 등록 성공 후 목록 새로고침 (fetchCameras가 _isLoading false로 만듦)
        await fetchCameras();
        return true;
      }

      // 상태 코드별 사용자 메시지
      final detail = _extractDetail(response);
      switch (response.statusCode) {
        case 400:
          _lastErrorMessage = detail ?? '입력값이 올바르지 않아요.';
          break;
        case 401:
        case 403:
          _lastErrorMessage = '로그인이 필요해요. 다시 로그인 후 시도해 주세요.';
          break;
        case 404:
          _lastErrorMessage = detail ?? '잘못되거나 만료된 페어링 코드예요. 카메라에서 새 코드를 확인해 주세요.';
          break;
        case 422:
          _lastErrorMessage = detail ?? '코드는 6자리 숫자여야 해요.';
          break;
        case 503:
          _lastErrorMessage = '서버가 잠시 바빠요. 잠시 후 다시 시도해 주세요.';
          break;
        default:
          _lastErrorMessage = detail ?? '페어링에 실패했어요. (${response.statusCode})';
      }

      print('페어링 실패: ${response.statusCode} ${response.body}');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('페어링 에러: $e');
      _lastErrorMessage = '서버와 통신할 수 없어요. 인터넷 연결을 확인해 주세요.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── 카메라 목록 조회 ── GET /cameras
  Future<void> fetchCameras() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cameras = data.map((e) => CameraModel.fromJson(e)).toList();
      } else {
        print('카메라 목록 불러오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('카메라 목록 에러: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── 카메라 삭제 ── DELETE /cameras/{id}
  Future<bool> removeCamera(int cameraId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/cameras/$cameraId'),
        headers: _headers(token),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _cameras.removeWhere((c) => c.id == cameraId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        print('카메라 삭제 실패: ${response.statusCode}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('카메라 삭제 에러: $e');
      // 네트워크 오류 시에도 로컬에서는 제거 (UX)
      _cameras.removeWhere((c) => c.id == cameraId);
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }
}
