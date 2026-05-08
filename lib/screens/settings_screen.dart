import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? AppColors.danger : AppColors.success, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    void showPasswordCheckDialog() {
      final passwordController = TextEditingController();
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('비밀번호 확인'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('개인정보를 수정하려면 비밀번호를 다시 입력해주세요.', style: TextStyle(fontSize: 14)),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '현재 비밀번호',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text;
                if (password.isEmpty) return;
                
                final isSuccess = await settings.verifyPassword(
                  password, 
                  (errorMsg) => _showSnack(context, errorMsg, isError: true)
                );

                if (isSuccess && context.mounted) {
                  Navigator.pop(dialogContext);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditScreen()));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: settings.isLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('확인', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.home, color: AppColors.accent),
            SizedBox(width: AppSpacing.sm),
            Text('Eye Catch', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 섹션
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card(context),
              ),
              child: Column(
                children: [
                  const CircleAvatar(radius: 50, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1596131398991-b94f928d85a1?auto=format&fit=crop&q=80')),
                  const SizedBox(height: AppSpacing.md),
                  Text('${settings.profileName} 보호자님', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(settings.profileEmail, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.xl),
                  SoftButton(
                    label: '로그아웃',
                    icon: Icons.logout,
                    onPressed: () {
                      settings.logout(() {
                        _showSnack(context, '안전하게 로그아웃 되었습니다.');
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      });
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            Text('계정 관리', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            _buildListTile(context, '보호자 정보 수정', '비밀번호 및 이름 변경', Icons.person, onTap: showPasswordCheckDialog),
            
            const SizedBox(height: AppSpacing.lg),
            Text('기기 연동', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            _buildListTile(context, '브릿지 연동 토큰 복사', '카메라 기기 최초 설정 시 필요합니다', Icons.copy, onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('eyeCatchToken');
              if (token != null && token.isNotEmpty) {
                await Clipboard.setData(ClipboardData(text: token));
                if (context.mounted) _showSnack(context, '브릿지 연동 토큰이 클립보드에 복사되었습니다.');
              } else {
                if (context.mounted) _showSnack(context, '토큰을 찾을 수 없습니다. 다시 로그인해주세요.', isError: true);
              }
            }),

            const SizedBox(height: AppSpacing.lg),
            Text('환경 설정', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            _buildToggleTile(
              context, '아이 활동 알림', '위험 구역 접근 및 울음소리 감지 시 즉시 알림', Icons.notifications_active,
              settings.isAlertOn, (val) => context.read<SettingsProvider>().toggleAlert(val),
            ),
            _buildToggleTile(
              context, '야간 모드 (다크)', '어두운 방에서 모니터링 시 눈 보호', Icons.dark_mode,
              themeProvider.isDarkMode, (val) => context.read<ThemeProvider>().toggleTheme(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        trailing: Icon(icon, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildToggleTile(BuildContext context, String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        secondary: CircleAvatar(
          backgroundColor: value ? AppColors.accent.withOpacity(0.1) : cs.surfaceContainerHighest,
          child: Icon(icon, color: value ? AppColors.accent : cs.onSurfaceVariant, size: 20),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accent,
      ),
    );
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: context.read<SettingsProvider>().profileName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    Future<void> saveInfo() async {
      final isSuccess = await settings.updateProfile(
        _nameController.text.trim(),
        _passwordController.text.trim(),
        (errorMsg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg))),
      );

      if (isSuccess && context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('정보가 성공적으로 수정되었습니다.')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('보호자 정보 수정', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '이름 변경', border: OutlineInputBorder())),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '새 비밀번호', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: AppSpacing.xl),
            SoftButton(
              label: '저장하기',
              isLoading: settings.isLoading,
              onPressed: settings.isLoading ? () {} : saveInfo,
            ),
          ],
        ),
      ),
    );
  }
}