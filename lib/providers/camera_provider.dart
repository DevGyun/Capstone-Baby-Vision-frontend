import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

// 백엔드 응답 구조에 맞게 정의
// GET /cameras 응답: {id, name, stream_url, is_active, is_connected, hls_url}
class CameraModel {
  final int id;
  final String name;
  final String hlsUrl;      // HLS 플레이어용 (http://host:8888/uuid/index.m3u8)
  final String streamUrl;   // RTSP 원본 URL
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
}

class CameraProvider with ChangeNotifier {
  bool _isLoading = false;
  List<CameraModel> _cameras = [];

  bool get isLoading => _isLoading;
  List<CameraModel> get cameras => _cameras;

  // ── 공통 헬퍼 ──────────────────────────────────────────────
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('eyeCatchToken');
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'ngrok-skip-browser-warning': '69420',
  };

  // ── 카메라 등록 ── POST /cameras  {name}
  Future<bool> registerCamera(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: _headers(token),
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 등록 성공 후 목록 새로고침
        await fetchCameras();
        return true;
      } else {
        print('카메라 등록 실패: ${response.statusCode} ${response.body}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('카메라 등록 에러: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── 카메라 목록 조회 ── GET /cameras
  Future<void> fetchCameras() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/cameras'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cameras = data.map((e) => CameraModel.fromJson(e)).toList();
      } else {
        print('카메라 목록 불러오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('카메라 목록 에러: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── 카메라 삭제 ── DELETE /cameras/{id}
  Future<bool> removeCamera(int cameraId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/cameras/$cameraId'),
        headers: _headers(token),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _cameras.removeWhere((c) => c.id == cameraId);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        print('카메라 삭제 실패: ${response.statusCode}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('카메라 삭제 에러: $e');
      // 네트워크 오류 시에도 로컬에서는 제거 (UX)
      _cameras.removeWhere((c) => c.id == cameraId);
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }
}
