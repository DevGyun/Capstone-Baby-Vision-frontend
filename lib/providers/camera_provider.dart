import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class CameraProvider extends ChangeNotifier {
  List<dynamic> _cameras = [];
  List<dynamic> get cameras => _cameras;

  // 카메라 추가 (POST /cameras)
  Future<String> addCamera(String name, String streamUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name, 'stream_url': streamUrl}),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          final serverStreamUrl = responseData['stream_url'] ?? '';

          String cameraLocalIp = streamUrl;
          if (streamUrl.contains('://')) {
            cameraLocalIp = Uri.parse(streamUrl).host;
          }

          // 👇👇👇 추가할 부분: 입력 주소가 이미 HLS 서버 주소인 경우 로컬 기기 셋업을 우회합니다. 👇👇👇
          if (cameraLocalIp == '211.243.47.179' || streamUrl.contains('8888')) {
            debugPrint('이미 스트리밍 중인 주소 확인됨. 로컬 기기 셋업 생략.');
            await fetchCameras(); 
            return 'success';
          }

          // 💡 타임아웃 처리는 잘 되어있으나, 에러 시 밖으로 던지게 수정
          final localResponse = await http.post(
            Uri.parse('http://$cameraLocalIp:5000/setup-stream'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'server_url': serverStreamUrl}),
          ).timeout(const Duration(seconds: 5)); 
          
          if(localResponse.statusCode != 200) {
            throw Exception('카메라 기기 응답 오류');
          }

          debugPrint('로컬 카메라 기기로 주소 전송 성공!');
          await fetchCameras(); 
          return 'success';

        } catch (localError) {
          debugPrint('로컬 카메라 통신 에러: $localError');
          await fetchCameras(); // 백엔드 등록은 됐으니 목록은 갱신
          return '백엔드 등록은 성공했으나, 카메라 기기($streamUrl)와 통신할 수 없습니다. 기기 전원을 확인하세요.';
        }
      }
      return '서버에 카메라를 등록하는데 실패했습니다. (상태코드: ${response.statusCode})';
    } catch (e) {
      debugPrint('카메라 추가 네트워크 에러: $e');
      return '서버와의 네트워크 연결에 실패했습니다.';
    }
  }

  // 카메라 목록 가져오기 (기존 기능 그대로)
  Future<void> fetchCameras() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _cameras = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('목록 로드 에러: $e');
    }
  }
  Future<bool> removeCamera(String cameraId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/cameras/$cameraId'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 서버 삭제 성공 시 로컬 목록에서도 제거
        _cameras.removeWhere((cam) => cam['id'].toString() == cameraId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('카메라 삭제 에러: $e');
    }
    return false;
  }
}