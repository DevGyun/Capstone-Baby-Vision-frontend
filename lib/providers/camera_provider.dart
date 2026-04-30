import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CameraProvider with ChangeNotifier {
  String? _streamUrl;
  String? _cameraName;
  bool _isLoading = false;

  // 상태를 읽기 위한 getter
  String? get streamUrl => _streamUrl;
  String? get cameraName => _cameraName;
  bool get isLoading => _isLoading;

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

  /// 새로운 브릿지를 등록하거나 상태를 초기화할 때 사용합니다.
  void clearCameraData() {
    _streamUrl = null;
    _cameraName = null;
    notifyListeners();
  }
}