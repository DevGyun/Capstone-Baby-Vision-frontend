import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // (Firebase 등 초기화 코드는 필요 시 주석 해제)
  // await Firebase.initializeApp();

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003d9b), brightness: Brightness.light),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF60a5fa), brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(ThemeData.dark().textTheme),
      ),
      // 💡 Provider가 관리하는 테마 모드를 적용합니다.
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