import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 로그인 비즈니스 로직
  Future<void> login({
    required String email,
    required String password,
    required Function onSuccess,
    required Function(String errorMessage) onError,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      onError('이메일과 비밀번호를 모두 입력해주세요.');
      return;
    }

    _isLoading = true;
    notifyListeners(); // 화면에 로딩 상태 알림

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '69420',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        
        // 토큰 저장 및 유저 정보 요청 로직...
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('eyeCatchToken', token);
        
        final userResponse = await http.get(
          Uri.parse('${AppConfig.baseUrl}/users/me'),
          headers: {
            'Authorization': 'Bearer $token',
            // ✅ 수정 1: 두 번째 요청에도 ngrok 우회 헤더 추가
            'ngrok-skip-browser-warning': '69420',
          },
        );

        if (userResponse.statusCode == 200) {
          await prefs.setString('eyeCatchUser', userResponse.body);
          onSuccess(); // 로그인 성공 시 UI로 콜백 전달
        } else {
          onError('유저 정보를 불러올 수 없습니다.');
        }
      } else {
        final errorData = jsonDecode(response.body);
        onError(errorData['detail'] ?? '이메일 또는 비밀번호가 틀렸습니다.');
      }
    } catch (e, stackTrace) {
      // ✅ 수정 2: catch 블록에 디버깅용 에러 출력 추가
      print('🚨 로그인 통신 에러 발생: $e');
      print('🚨 스택 트레이스: $stackTrace');
      
      // 기존 에러 메시지
      onError('서버와 통신할 수 없습니다.\n인터넷 연결이나 서버 상태를 확인해주세요.');
    } finally {
      _isLoading = false;
      notifyListeners(); // 로딩 종료 상태 알림
    }
  }
}