import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart'; // AppConfig.baseUrl 사용

class CameraProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _cameras = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get cameras => _cameras;
  bool get isLoading => _isLoading;

  // 카메라 목록 불러오기 (GET /cameras)
  Future<void> fetchCameras() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('eyeCatchToken') ?? '';

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _cameras = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('카메라 목록을 불러오는 데 실패했습니다: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 카메라 추가하기 (POST /cameras)
  Future<bool> addCamera(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('eyeCatchToken') ?? '';

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': name}),
      );

      if (response.statusCode == 200) {
        // 성공적으로 추가되면 목록을 다시 불러와 화면을 갱신합니다.
        await fetchCameras();
        return true;
      }
    } catch (e) {
      debugPrint('카메라 추가에 실패했습니다: $e');
    }
    return false;
  }
}