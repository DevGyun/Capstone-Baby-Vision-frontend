import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 💡 카메라 데이터를 담기 위한 모델 클래스 추가
class CameraModel {
  final String id;
  final String name;
  final String url; // 스트리밍 URL
  final String? thumbnailUrl; // 썸네일 이미지 URL (선택)

  CameraModel({
    required this.id,
    required this.name,
    required this.url,
    this.thumbnailUrl,
  });
}

class CameraProvider with ChangeNotifier {
  String? _streamUrl;
  String? _cameraName;
  bool _isLoading = false;

  // 💡 기존 화면(메인 스크린 등)에서 요구하는 카메라 목록 상태 변수 추가
  List<CameraModel> _cameras = [];

  // 상태를 읽기 위한 getter
  String? get streamUrl => _streamUrl;
  String? get cameraName => _cameraName;
  bool get isLoading => _isLoading;
  List<CameraModel> get cameras => _cameras; // 💡 카메라 목록 getter 추가

  // TODO: 차훈님이 구축하신 백엔드 서버의 실제 IP 및 포트로 변경해야 합니다.
  final String _baseUrl = 'http://your-server-ip:port/api';

  /// 브릿지 ID와 카메라 이름을 서버로 전송하여 등록을 요청합니다.
  Future<bool> registerCamera(String name, String bridgeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/cameras'), // POST /cameras 엔드포인트
        headers: {
          'Content-Type': 'application/json',
          // 인증이 필요하다면 여기에 토큰 추가
          // 'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'name': name,
          'bridge_id': bridgeId,
        }),
      );

      // 서버 응답이 성공(200 OK 또는 201 Created)일 경우
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);

        // 서버 응답 규격에 맞게 파싱
        // 예: { "camera_id": "...", "name": "...", "stream_url": "rtsp://..." }
        _streamUrl = responseData['stream_url'];
        _cameraName = responseData['name'] ?? name;

        // 💡 성공적으로 등록되면 로컬 목록(_cameras)에도 반영
        _cameras.add(
          CameraModel(
            id: responseData['camera_id'] ?? DateTime.now().toString(), // 임시 ID 처리
            name: _cameraName!,
            url: _streamUrl ?? '',
          ),
        );

        _isLoading = false;
        notifyListeners();
        return true; // 등록 성공 반환 -> 화면에서 /live_stream으로 라우팅 처리
      } else {
        // 서버에서 에러 응답을 보낸 경우
        print('카메라 등록 실패: 상태 코드 ${response.statusCode}');
        print('응답 내용: ${response.body}');

        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (error) {
      // 네트워크 연결 실패 등 예외 발생 시
      print('카메라 등록 API 통신 에러: $error');

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 💡 [추가] 서버에서 전체 카메라 목록을 가져오는 함수 (메인 화면 등에서 호출)
  Future<void> fetchCameras() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/cameras'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        _cameras = responseData.map((data) => CameraModel(
          id: data['camera_id'].toString(),
          name: data['name'],
          url: data['stream_url'],
          thumbnailUrl: data['thumbnail_url'],
        )).toList();
      } else {
        print('카메라 목록 불러오기 실패: ${response.statusCode}');
      }
    } catch (error) {
      print('카메라 목록 불러오기 에러: $error');
      // 통신 전이거나 실패 시 임시 테스트 데이터 유지 (원하시면 지워도 됩니다)
      if (_cameras.isEmpty) {
        _cameras = [
          CameraModel(id: 'test_1', name: '거실 테스트 카메라', url: 'test_url_1'),
        ];
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  // 💡 [추가] 카메라를 삭제하는 함수
  Future<bool> removeCamera(String cameraId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/cameras/$cameraId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 서버 삭제 성공 시 로컬 목록에서도 제거
        _cameras.removeWhere((cam) => cam.id == cameraId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        print('카메라 삭제 실패: ${response.statusCode}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (error) {
      print('카메라 삭제 에러: $error');
      // API 연결 전 테스트용: 로컬에서만이라도 지우기
      _cameras.removeWhere((cam) => cam.id == cameraId);
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  /// 새로운 브릿지를 등록하거나 상태를 초기화할 때 사용합니다.
  void clearCameraData() {
    _streamUrl = null;
    _cameraName = null;
    // _cameras.clear(); // 원하시면 목록도 함께 초기화 가능
    notifyListeners();
  }
}