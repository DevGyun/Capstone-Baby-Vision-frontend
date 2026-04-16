import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class CameraProvider extends ChangeNotifier {
  List<dynamic> _cameras = [];
  List<dynamic> get cameras => _cameras;

 // 카메라 추가 (POST /cameras) - name만 전달받도록 수정
  Future<String> addCamera(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name}), // body에서 stream_url 제거
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 백엔드 등록 성공 시, 복잡한 로컬 기기 연동 과정 없이 바로 목록 새로고침
        await fetchCameras(); 
        return 'success';
      }
      return '서버 등록 실패: 상태 코드 ${response.statusCode}';
    } catch (e) {
      return '네트워크 에러 발생: $e';
    }
  }

  // 카메라 목록 가져오기 (기존 유지)
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
  
  // 카메라 삭제 (기존 유지)
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