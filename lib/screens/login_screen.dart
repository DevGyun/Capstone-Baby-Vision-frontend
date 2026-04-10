import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_error_dialog.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // UI단에서는 함수 호출과 에러 핸들링만 담당합니다.
  void _attemptLogin() {
    // 키보드 내리기
    FocusScope.of(context).unfocus();

    context.read<AuthProvider>().login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      onSuccess: () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      },
      onError: (errorMessage) {
        if (!mounted) return;
        // 새로 만든 에러 위젯(다시 시도 버튼 포함) 호출
        CustomErrorDialog.show(
          context, 
          errorMessage,
          onRetry: () => _attemptLogin(), // 실패 시 다시 시도
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Provider로부터 로딩 상태를 실시간으로 구독
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.visibility, color: Colors.blueAccent, size: 48),
              const SizedBox(height: 16),
              const Text('Eye Catch', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('우리아이 안심 모니터링', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 48),
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '이메일 주소',
                  prefixIcon: Icon(Icons.email_outlined, color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  prefixIcon: Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _attemptLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2),
                        )
                      : const Text('로그인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // 커스텀 트랜지션 적용 (Slide & Fade)
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const SignupScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0); // 우측에서 시작
                        const end = Offset.zero;        // 제자리
                        const curve = Curves.easeInOutQuart; // 부드러운 가감속 커브

                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                          position: offsetAnimation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 500), // 전환 속도 조절
                    ),
                  );
                },
                child: Text(
                  '계정이 없으신가요? 회원가입',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}