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

  // 💡 [핵심 추가] 비밀번호 변경 시 API가 '현재 비밀번호'를 요구하므로 임시 저장할 변수
  String? _tempCurrentPassword;

  String get profileName => _profileName;
  String get profileEmail => _profileEmail;
  bool get isAlertOn => _isAlertOn;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    loadSettings();
  }

  // 내부 저장소에서 사용자 정보 및 세팅 불러오기
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
          'ngrok-skip-browser-warning': '69420',
        },
        // 검증을 위해 기존처럼 로그인 API 활용
        body: jsonEncode({'email': _profileEmail, 'password': password}),
      );

      if (response.statusCode == 200) {
        _tempCurrentPassword = password; // 💡 검증 통과 시 비밀번호를 잠시 기억해 둠 (수정 시 사용)
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

    if (newName.isEmpty && newPassword.isEmpty) {
      onError('변경된 내용이 없습니다.');
      return false;
    }

    _isLoading = true;
    notifyListeners();
    bool isSuccess = true;

    try {
      // 1. 이름 변경 (PATCH /users/me) - 이름이 바뀌었을 때만 따로 요청
      if (newName.isNotEmpty && newName != _profileName) {
        final nameResponse = await http.patch(
          Uri.parse('${AppConfig.baseUrl}/users/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': '69420',
          },
          body: jsonEncode({'name': newName}),
        );

        if (nameResponse.statusCode == 200) {
          // 이름 수정 성공 시 로컬 기기 데이터도 업데이트
          final userDataString = prefs.getString('eyeCatchUser');
          if (userDataString != null) {
            final userData = jsonDecode(userDataString) as Map<String, dynamic>;
            userData['name'] = newName;
            await prefs.setString('eyeCatchUser', jsonEncode(userData));
            _profileName = newName;
          }
        } else {
          onError('이름 변경에 실패했습니다.');
          isSuccess = false;
        }
      }

      // 2. 비밀번호 변경 (PATCH /users/me/password) - 새 비밀번호가 입력됐을 때 따로 요청
      if (newPassword.isNotEmpty && isSuccess) {
        if (_tempCurrentPassword == null) {
          onError('인증이 만료되었습니다. 다시 비밀번호를 확인해주세요.');
          isSuccess = false;
        } else {
          final passResponse = await http.patch(
            Uri.parse('${AppConfig.baseUrl}/users/me/password'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'ngrok-skip-browser-warning': '69420',
            },
            // 💡 백엔드 스키마가 요구하는 2개의 값 모두 전송
            body: jsonEncode({
              'current_password': _tempCurrentPassword,
              'new_password': newPassword
            }),
          );

          if (passResponse.statusCode != 200) {
            final errorData = jsonDecode(passResponse.body);
            onError(errorData['detail'] ?? '비밀번호 변경에 실패했습니다. (8자리 이상 입력)');
            isSuccess = false;
          }
        }
      }
    } catch (e) {
      onError('서버와의 통신에 실패했습니다.');
      isSuccess = false;
    } finally {
      _isLoading = false;
      // 처리가 끝나면 보안을 위해 임시 저장한 비밀번호를 메모리에서 즉시 폐기
      _tempCurrentPassword = null;
      notifyListeners();
    }

    return isSuccess;
  }
}