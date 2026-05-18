import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/common.dart';
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
  bool _obscurePassword = true;
  bool _autoLogin = true; // 기본 켜짐

  @override
  void initState() {
    super.initState();
    _loadAutoLoginPref();
    _loadSavedEmail();
  }

  /// 사용자가 이전에 자동 로그인을 끄셨다면 그 설정 유지
  Future<void> _loadAutoLoginPref() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('autoLoginEnabled');
    if (saved != null && mounted) {
      setState(() => _autoLogin = saved);
    }
  }

  /// 마지막으로 로그인한 이메일은 미리 채워둠
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('lastEmail');
    if (email != null && email.isNotEmpty && mounted) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveAutoLoginPref(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoLoginEnabled', enabled);
  }

  void _attemptLogin() {
    FocusScope.of(context).unfocus();

    context.read<AuthProvider>().login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          onSuccess: () async {
            if (!mounted) return;

            // 이메일 + 자동 로그인 설정 저장
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('lastEmail', _emailController.text.trim());
            await _saveAutoLoginPref(_autoLogin);

            // 자동 로그인 끈 경우 토큰 안 저장
            if (!_autoLogin) {
              await prefs.remove('eyeCatchRefreshToken');
            }

            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/main');
          },
          onError: (errorMessage) {
            if (!mounted) return;
            CustomErrorDialog.show(
              context,
              errorMessage,
              onRetry: _attemptLogin,
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl + AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft(context),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.visibility_rounded,
                  color: AppColors.accent,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'Eye Catch에\n오신 걸 환영해요',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                '아이의 안전을 늘 함께 지켜볼게요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),

              const SizedBox(height: AppSpacing.xl + AppSpacing.sm),

              const FieldLabel('이메일'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              const FieldLabel('비밀번호'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _attemptLogin(),
                decoration: InputDecoration(
                  hintText: '비밀번호를 입력해 주세요',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 자동 로그인 체크박스
              InkWell(
                onTap: () => setState(() => _autoLogin = !_autoLogin),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _autoLogin
                              ? AppColors.accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _autoLogin
                                ? AppColors.accent
                                : cs.outline,
                            width: 1.5,
                          ),
                        ),
                        child: _autoLogin
                            ? const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.sm + 2),
                      Text(
                        '자동 로그인 유지',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: '다음에 앱 열 때 로그인 화면을 건너뜁니다',
                        child: Icon(
                          Icons.help_outline,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              SoftButton(
                label: isLoading ? '로그인 중...' : '로그인',
                isLoading: isLoading,
                onPressed: _attemptLogin,
              ),

              const SizedBox(height: AppSpacing.lg),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, animation, __) => const SignupScreen(),
                      transitionsBuilder: (_, animation, __, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOutQuart;
                        final tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        return SlideTransition(
                          position: animation.drive(tween),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 500),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.md,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: '계정이 없으신가요?  ',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const TextSpan(
                            text: '회원가입',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}