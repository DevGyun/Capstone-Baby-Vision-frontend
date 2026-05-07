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
  
  await NotificationService().init();

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
    // 💡 앱 최상단에 MultiProvider를 감싸줍니다.
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
    // 💡 테마 프로바이더의 상태를 실시간으로 감지합니다.
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

      // ── 새 디자인 시스템 적용 ──
      // 기존 ColorScheme.fromSeed + GoogleFonts 직접 호출 코드를
      // AppTheme.light() / AppTheme.dark()로 교체.
      // 시스템 자동 전환은 themeProvider.themeMode가 처리.
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