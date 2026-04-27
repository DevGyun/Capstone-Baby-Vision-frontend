import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class CameraProvider extends ChangeNotifier {
  List<dynamic> _cameras = [];
  List<dynamic> get cameras => _cameras;

  // [추가] 등록 대기 중인 브릿지 목록 상태 관리
  List<dynamic> _pendingBridges = [];
  List<dynamic> get pendingBridges => _pendingBridges;

  // [추가] 미등록 브릿지 목록 가져오기 (GET /bridges/pending)
  Future<void> fetchPendingBridges() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/bridges/pending'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _pendingBridges = jsonDecode(response.body);
        notifyListeners();
      } else {
        debugPrint('미등록 브릿지 목록 로드 실패: 상태 코드 ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('미등록 브릿지 목록 로드 에러: $e');
    }
  }

  // [수정] 카메라 추가 (POST /cameras) - name과 bridgeId 전달
  // 참고: 백엔드 DB 구조상 ID가 숫자일 확률이 높아 bridgeId를 int로 받도록 설정했습니다.
  Future<String> addCamera(String name, int bridgeId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'bridge_id': bridgeId, // [추가] 서버로 브릿지 ID 전달
        }), 
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 등록 성공 시 카메라 목록 새로고침
        await fetchCameras(); 
        // 등록된 브릿지가 대기 목록에서 빠지도록 대기 목록도 새로고침
        await fetchPendingBridges();
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