import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class SettingsProvider extends ChangeNotifier {
  String _profileName = '보호자';
  String _profileEmail = 'parent@eyecatch.ai';
  bool _isAlertOn = true;
  bool _isLoading = false;

  String get profileName => _profileName;
  String get profileEmail => _profileEmail;
  bool get isAlertOn => _isAlertOn;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    loadSettings();
  }

  // 내부 저장소에서 사용자 정보 및 세팅 불러오기 (초기값 연동 완벽함)
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('eyeCatchUser');
    
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      _profileName = userData['name'] ?? '보호자';
      _profileEmail = userData['email'] ?? 'parent@eyecatch.ai';
    }
    _isAlertOn = prefs.getBool('isAlertOn') ?? true;
    notifyListeners();
  }

  // 알림 토글 스위치 변경
  Future<void> toggleAlert(bool value) async {
    _isAlertOn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAlertOn', value);
    notifyListeners();
  }

  // 로그아웃 (토큰 및 데이터 삭제)
  Future<void> logout(Function onSuccess) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('eyeCatchToken');
    await prefs.remove('eyeCatchUser');
    onSuccess();
  }

  // 비밀번호 확인 (정보 수정 전 단계)
  Future<bool> verifyPassword(String password, Function(String) onError) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '69420', // ✅ ngrok 우회 헤더 추가
        },
        body: jsonEncode({'email': _profileEmail, 'password': password}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        onError('비밀번호가 일치하지 않습니다.');
        return false;
      }
    } catch (e) {
      onError('서버와 연결할 수 없습니다.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 프로필 업데이트 (이름 및 비밀번호 변경)
  Future<bool> updateProfile(String newName, String newPassword, Function(String) onError) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');
    
    if (token == null) {
      onError('로그인 정보가 없습니다.');
      return false;
    }

    final Map<String, dynamic> updateData = {};
    if (newName.isNotEmpty) updateData['name'] = newName;
    if (newPassword.isNotEmpty) updateData['password'] = newPassword;

    if (updateData.isEmpty) {
      onError('변경된 내용이 없습니다.');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420', // ✅ ngrok 우회 헤더 추가
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        // 로컬 데이터도 갱신
        if (newName.isNotEmpty) {
          final userDataString = prefs.getString('eyeCatchUser');
          if (userDataString != null) {
            final userData = jsonDecode(userDataString) as Map<String, dynamic>;
            userData['name'] = newName; // 새 이름으로 덮어쓰기
            await prefs.setString('eyeCatchUser', jsonEncode(userData));
            _profileName = newName;
          }
        }
        return true;
      } else {
        onError('정보 수정에 실패했습니다.');
        return false;
      }
    } catch (e) {
      onError('서버와의 통신에 실패했습니다.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}