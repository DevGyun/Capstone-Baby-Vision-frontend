import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class CameraProvider extends ChangeNotifier {
  List<dynamic> _cameras = [];
  List<dynamic> get cameras => _cameras;

  // 카메라 추가 (POST /cameras)
  Future<bool> addCamera(String name, String streamUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');

    try {
      // 1. 기존 기능 유지: 백엔드로 name과 stream_url 전송
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name, 'stream_url': streamUrl}), 
      );
      
      if (response.statusCode == 200) {
        
        // 💡 [여기서부터 새로 추가된 부분] : 같은 와이파이 기기로 주소 쏴주기
        try {
          // 1) 백엔드 응답에서 서버가 만들어준 고유 스트림 주소를 추출합니다.
          final responseData = jsonDecode(response.body);
          final serverStreamUrl = responseData['stream_url'] ?? '';

          // 2) 사용자가 앱에 입력한 주소(예: rtsp://192.168.0.55/stream)에서 IP(192.168.0.55)만 빼냅니다.
          String cameraLocalIp = streamUrl;
          if (streamUrl.contains('://')) {
            cameraLocalIp = Uri.parse(streamUrl).host;
          }

          // 3) 카메라 기기(내부 IP)에 서버 스트림 주소를 전달합니다.
          // (주의: 포트 5000과 /setup-stream은 하드웨어/파이썬 담당자와 협의해 맞추시면 됩니다!)
          await http.post(
            Uri.parse('http://$cameraLocalIp:5000/setup-stream'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'server_url': serverStreamUrl // 카메라가 송출해야 할 메인 서버 주소
            }),
          ).timeout(const Duration(seconds: 5)); // 무한 로딩 방지용 5초 타임아웃
          
          debugPrint('로컬 카메라 기기로 주소 전송 성공!');
        } catch (localError) {
          debugPrint('로컬 카메라 통신 에러 (백엔드 등록은 성공함): $localError');
          // 내부망 연결이 불안정해도 서버 등록은 되었으므로 아래 과정(fetchCameras)은 정상 진행시킵니다.
        }
        // 💡 [추가된 부분 끝]

        await fetchCameras(); 
        return true;
      }
    } catch (e) {
      debugPrint('카메라 추가 에러: $e');
    }
    return false;
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
}