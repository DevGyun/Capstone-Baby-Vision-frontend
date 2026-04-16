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

          // 💡 하드코딩 제거: 주소에 경로(/)가 포함되어 있거나 전체 URL 형태면 외부 스트림으로 판단
          bool isExternalStream = streamUrl.startsWith('http') && Uri.parse(streamUrl).path.length > 1;

          if (isExternalStream) {
            debugPrint('외부 스트림(HLS 서버) 주소 확인됨. 로컬 기기 셋업 생략.');
            await fetchCameras(); 
            return 'success';
          }

          // 로컬 카메라 기기(IP만 입력한 경우) 셋업 로직
          String cameraLocalIp = streamUrl;
          if (streamUrl.contains('://')) {
            cameraLocalIp = Uri.parse(streamUrl).host;
          }

          final localResponse = await http.post(
            Uri.parse('http://$cameraLocalIp:5000/setup-stream'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'server_url': serverStreamUrl}),
          ).timeout(const Duration(seconds: 5)); 
          
          if(localResponse.statusCode != 200) throw Exception('기기 응답 오류');

          await fetchCameras(); 
          return 'success';

        } catch (e) {
          await fetchCameras();
          return '백엔드 등록 성공. 단, 카메라 기기($streamUrl) 연결 확인 필요.';
        }
      }
      return '서버 등록 실패';
    } catch (e) {
      return '네트워크 에러 발생';
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