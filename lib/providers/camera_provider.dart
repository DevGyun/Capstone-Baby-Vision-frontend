import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';
import '../services/camera_snapshot_storage.dart';

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

  /// 방금 등록된 카메라 이름 — 메인 화면이 이걸 감지하고 환영 SnackBar 표시.
  /// SnackBar 표시 후엔 메인 화면이 [consumeJustPairedCameraName]으로 비움.
  String? _justPairedCameraName;

  bool get isLoading => _isLoading;
  List<CameraModel> get cameras => _cameras;
  String? get lastErrorMessage => _lastErrorMessage;
  String? get justPairedCameraName => _justPairedCameraName;

  /// 메인 화면이 환영 메시지를 표시한 후 호출 — 같은 이벤트가 두 번 안 뜨도록.
  void consumeJustPairedCameraName() {
    _justPairedCameraName = null;
  }

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
        // 메인 화면에서 환영 메시지 띄우도록 마킹
        _justPairedCameraName = name;
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
          _lastErrorMessage =
              detail ?? '잘못되거나 만료된 페어링 코드예요. 카메라에서 새 코드를 확인해 주세요.';
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

      debugPrint('페어링 실패: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('페어링 에러: $e');
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
        debugPrint('카메라 목록 불러오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('카메라 목록 에러: $e');
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
      // 스냅샷 캐시도 함께 정리
      await CameraSnapshotStorage.remove(cameraId);
      return true;
    }
      debugPrint('카메라 삭제 실패: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('카메라 삭제 에러: $e');
      _cameras.removeWhere((c) => c.id == cameraId);
      return true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── 카메라 모니터링 켜기/끄기 ──
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
        try {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            _cameras[idx] = CameraModel.fromJson(data);
            notifyListeners();
          }
        } catch (_) {}
        return true;
      }

      _cameras[idx] = original;
      notifyListeners();
      debugPrint('카메라 활성 토글 실패: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      _cameras[idx] = original;
      notifyListeners();
      debugPrint('카메라 활성 토글 에러: $e');
      return false;
    }
  }
}