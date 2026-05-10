import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';

// 백엔드 응답 구조에 맞게 정의
class CameraModel {
  final int id;
  final String name;
  final String hlsUrl;
  final String streamUrl;
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

  /// 일부 필드만 바꿔서 새 인스턴스 만들기.
  /// 토글 같은 부분 업데이트에 사용.
  CameraModel copyWith({
    String? name,
    String? hlsUrl,
    String? streamUrl,
    bool? isActive,
    bool? isConnected,
  }) {
    return CameraModel(
      id: id,
      name: name ?? this.name,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      isActive: isActive ?? this.isActive,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class CameraProvider with ChangeNotifier {
  bool _isLoading = false;
  List<CameraModel> _cameras = [];
  String? _lastErrorMessage;

  bool get isLoading => _isLoading;
  List<CameraModel> get cameras => _cameras;
  String? get lastErrorMessage => _lastErrorMessage;

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

  // ── 페어링 ──
  Future<bool> pairCamera({
    required String pairingCode,
    required String name,
  }) async {
    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.request(
        'POST', '/bridges/pair',
        body: {'pairing_code': pairingCode, 'name': name},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCameras();
        return true;
      }

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
      return false;
    } catch (e) {
      print('페어링 에러: $e');
      _lastErrorMessage = '서버와 통신할 수 없어요. 인터넷 연결을 확인해 주세요.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 카메라 목록 ──
  Future<void> fetchCameras() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.request('GET', '/cameras');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cameras = data.map((e) => CameraModel.fromJson(e)).toList();
      } else {
        print('카메라 목록 불러오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('카메라 목록 에러: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 카메라 삭제 ──
  Future<bool> removeCamera(int cameraId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiClient.request('DELETE', '/cameras/$cameraId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _cameras.removeWhere((c) => c.id == cameraId);
        return true;
      }
      print('카메라 삭제 실패: ${response.statusCode}');
      return false;
    } catch (e) {
      print('카메라 삭제 에러: $e');
      _cameras.removeWhere((c) => c.id == cameraId);
      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 카메라 모니터링 켜기/끄기 ──
  /// PATCH /cameras/{id} 로 is_active 토글.
  /// is_active=false 면 Vision 서비스가 분석 대상에서 제외함.
  /// 낙관적 업데이트: UI를 먼저 바꾸고 서버 실패 시 롤백.
  Future<bool> setCameraActive(int cameraId, bool isActive) async {
    final idx = _cameras.indexWhere((c) => c.id == cameraId);
    if (idx == -1) return false;

    final original = _cameras[idx];
    _cameras[idx] = original.copyWith(isActive: isActive);
    notifyListeners();

    try {
      final response = await ApiClient.request(
        'PATCH',
        '/cameras/$cameraId',
        body: {'is_active': isActive},
      );

      if (response.statusCode == 200) {
        // 서버가 돌려준 최신 상태로 다시 동기화
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            _cameras[idx] = CameraModel.fromJson(data);
            notifyListeners();
          }
        } catch (_) {
          // 파싱 실패해도 낙관적 업데이트 결과는 유지
        }
        return true;
      }

      // 실패 → 롤백
      _cameras[idx] = original;
      notifyListeners();
      print('카메라 활성 토글 실패: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      _cameras[idx] = original;
      notifyListeners();
      print('카메라 활성 토글 에러: $e');
      return false;
    }
  }
}