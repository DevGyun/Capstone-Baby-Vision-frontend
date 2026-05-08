import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

// 화면들
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';

// 프로바이더들 (상태 관리)
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/log_provider.dart';
import 'providers/camera_provider.dart';

// 서비스들
import 'services/notification_service.dart';

// 디자인 시스템
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ 1. 알림 서비스 초기화
  await NotificationService().init();
  
  // ✅ 2. 안드로이드 13+ 및 iOS 알림 권한 팝업 강제 요청 (추가된 부분!)
  await NotificationService().requestPermissions();

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
  final String? token = prefs.getString('eyeCatchToken');
  
  String initialRoute = '/onboarding';
  if (hasSeenOnboarding) {
    if (token != null && token.isNotEmpty) {
      initialRoute = '/main';
    } else {
      initialRoute = '/login';
    }
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
}

class EyeCatchApp extends StatelessWidget {
  final String initialRoute;
  const EyeCatchApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
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