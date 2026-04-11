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
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        // 💡 백엔드로 name과 stream_url을 모두 보냄
        body: jsonEncode({'name': name, 'stream_url': streamUrl}), 
      );
      
      if (response.statusCode == 200) {
        await fetchCameras(); 
        return true;
      }
    } catch (e) {
      debugPrint('카메라 추가 에러: $e');
    }
    return false;
  }

  // 카메라 목록 가져오기 (GET /cameras)
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
      print('목록 로드 에러: $e');
    }
  }
}