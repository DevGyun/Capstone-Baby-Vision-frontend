import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

// 화면들
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';

// 프로바이더들
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/log_provider.dart';
import 'providers/camera_provider.dart';

// 서비스들
import 'services/notification_service.dart';

// 디자인 시스템
import 'theme/app_theme.dart';

// 설정
import 'config.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 시작 시 access token이 정말 유효한지 검증.
/// 만료됐다면 refresh token으로 새로 받기까지 시도.
/// 모두 실패하면 토큰 정리하고 false 반환.
///
/// 정책:
/// - 200 → 통과, 사용자 정보 캐시
/// - 401 → refresh 시도
/// - 4xx (그 외) → 토큰 자체가 잘못된 것이므로 로그아웃
/// - 5xx / 네트워크 에러 → 서버 문제이므로 통과 (캐시된 사용자 정보로 진행)
Future<bool> _hasValidSession() async {
  final prefs = await SharedPreferences.getInstance();

  // 사용자가 자동 로그인을 껐다면 무조건 로그인 화면으로
  final autoLoginEnabled = prefs.getBool('autoLoginEnabled') ?? true;
  if (!autoLoginEnabled) return false;

  final token = prefs.getString('eyeCatchToken');
  if (token == null || token.isEmpty) return false;

  try {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': '69420',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      await prefs.setString('eyeCatchUser', response.body);
      return true;
    }

    if (response.statusCode == 401) {
      return await _tryRefresh();
    }

    // 4xx (인증 외) — 토큰이나 요청이 잘못됐을 가능성. 안전하게 로그아웃.
    if (response.statusCode >= 400 && response.statusCode < 500) {
      await _clearTokens();
      return false;
    }

    // 5xx — 서버 문제, 사용자 잘못 아님. 캐시로 진행.
    return true;
  } catch (e) {
    // 네트워크 단절 등 — 오프라인일 수도 있으니 사용자 강제 로그아웃 X
    debugPrint('세션 검증 중 네트워크 에러: $e');
    return true;
  }
}

Future<bool> _tryRefresh() async {
  final prefs = await SharedPreferences.getInstance();
  final refresh = prefs.getString('eyeCatchRefreshToken');
  if (refresh == null || refresh.isEmpty) {
    await _clearTokens();
    return false;
  }

  try {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/users/refresh'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': '69420',
      },
      body: jsonEncode({'refresh_token': refresh}),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await prefs.setString('eyeCatchToken', data['access_token']);
      await prefs.setString('eyeCatchRefreshToken', data['refresh_token']);
      return true;
    }
  } catch (e) {
    debugPrint('Refresh 토큰 검증 에러: $e');
  }

  // refresh도 실패 → 깔끔하게 정리
  await _clearTokens();
  return false;
}

Future<void> _clearTokens() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('eyeCatchToken');
  await prefs.remove('eyeCatchRefreshToken');
  await prefs.remove('eyeCatchUser');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init();
  await NotificationService().requestPermissions();

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  String initialRoute = '/onboarding';
  if (hasSeenOnboarding) {
    final isValid = await _hasValidSession();
    initialRoute = isValid ? '/main' : '/login';
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => CameraProvider()),
      ],
      child: EyeCatchApp(initialRoute: initialRoute),
    ),
  );
  // 앱 시작 후 첫 프레임 그려진 다음, 종료 상태 알림 탭이었다면 라우팅 보정
  NotificationService().handleLaunchPayload();
}

class EyeCatchApp extends StatelessWidget {
  final String initialRoute;
  const EyeCatchApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Eye Catch',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),

      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.themeMode,

      initialRoute: initialRoute,
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}
