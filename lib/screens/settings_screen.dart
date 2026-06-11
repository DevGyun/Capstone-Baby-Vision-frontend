import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/common.dart';
import 'add_camera_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showSnack(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color: isError ? AppColors.danger : AppColors.success,
                size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: AppSpacing.sm),
              Text('회원 탈퇴'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '탈퇴하시면 아래 데이터가 영구 삭제되며 복구가 불가능해요.\n\n'
                '• 등록된 모든 카메라\n'
                '• 위험 구역 설정\n'
                '• 알림 내역\n\n'
                '계속하시려면 비밀번호를 입력해 주세요.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '현재 비밀번호',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            Consumer<SettingsProvider>(
              builder: (_, settings, __) => ElevatedButton(
                onPressed: settings.isLoading
                    ? null
                    : () async {
                        await context.read<SettingsProvider>().deleteAccount(
                              password: passwordController.text,
                              onSuccess: () {
                                Navigator.pop(dialogContext);
                                Navigator.pushNamedAndRemoveUntil(
                                    context, '/login', (_) => false);
                                _showSnack(context,
                                    '계정이 삭제됐어요. 그동안 이용해 주셔서 감사합니다');
                              },
                              onError: (msg) => _showSnack(dialogContext, msg,
                                  isError: true),
                            );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: settings.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('탈퇴하기',
                        style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // watch로 SettingsProvider를 구독 — 이름 바뀌면 즉시 리빌드
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
              const Text('개인정보를 수정하려면 비밀번호를 다시 입력해주세요.',
                  style: TextStyle(fontSize: 14)),
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
                    (errorMsg) =>
                        _showSnack(context, errorMsg, isError: true));

                if (isSuccess && context.mounted) {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileEditScreen()));
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: settings.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
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
            Text('Eye Catch',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
  padding: EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg,
    120 + MediaQuery.of(context).padding.bottom, // 플로팅 네비 + 시스템 네비
  ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 섹션 — 이니셜 아바타로 교체
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card(context),
              ),
              child: Column(
                children: [
                  InitialAvatar(name: settings.profileName, radius: 50),
                  const SizedBox(height: AppSpacing.md),
                  Text('${settings.profileName} 보호자님',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(settings.profileEmail,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.xl),
                  SoftButton(
                    label: '로그아웃',
                    icon: Icons.logout,
                    onPressed: () {
                      settings.logout(() {
                        _showSnack(context, '안전하게 로그아웃 되었습니다.');
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (route) => false);
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('계정 관리',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            _buildListTile(context, '보호자 정보 수정', '비밀번호 및 이름 변경', Icons.person,
                onTap: showPasswordCheckDialog),
            _buildListTile(
              context,
              '회원 탈퇴',
              '계정과 연결된 모든 데이터가 영구 삭제돼요',
              Icons.no_accounts_outlined,
              isDanger: true,
              onTap: () => _showDeleteAccountDialog(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('기기 연동',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            _buildListTile(
              context,
              '카메라 추가하기',
              '주변 카메라를 블루투스로 자동으로 찾아 연결해요',  // ← 이렇게 변경
              Icons.add_a_photo_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddCameraScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('환경 설정',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            _buildToggleTile(
              context,
              '아이 활동 알림',
              '위험 구역 접근시 즉시 알림',
              Icons.notifications_active,
              settings.isAlertOn,
              (val) => context.read<SettingsProvider>().toggleAlert(val),
            ),
            _buildThemeTile(context, themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
    bool isDanger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = isDanger ? AppColors.danger : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: accentColor,
          ),
        ),
        subtitle: Text(subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        trailing: Icon(icon, color: accentColor ?? cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildToggleTile(BuildContext context, String title, String subtitle,
      IconData icon, bool value, ValueChanged<bool> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: SwitchListTile(
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        secondary: CircleAvatar(
          backgroundColor: value
              ? AppColors.accent.withValues(alpha:0.1)
              : cs.surfaceContainerHighest,
          child: Icon(icon,
              color: value ? AppColors.accent : cs.onSurfaceVariant,
              size: 20),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.accent,
      ),
    );
  }
}
/// 라이트/다크/시스템 3-way 선택 타일.
Widget _buildThemeTile(
    BuildContext context, ThemeProvider themeProvider) {
  final cs = Theme.of(context).colorScheme;
  final pref = themeProvider.preference;

  IconData currentIcon;
  String currentLabel;
  switch (pref) {
    case AppThemePreference.system:
      currentIcon = Icons.brightness_auto_outlined;
      currentLabel = '기기 설정 따라감';
      break;
    case AppThemePreference.light:
      currentIcon = Icons.light_mode_outlined;
      currentLabel = '항상 밝게';
      break;
    case AppThemePreference.dark:
      currentIcon = Icons.dark_mode_outlined;
      currentLabel = '항상 어둡게';
      break;
  }

  return Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Column(
      children: [
        ListTile(
          title: const Text('테마',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(currentLabel,
              style:
                  TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          leading: CircleAvatar(
            backgroundColor: AppColors.accent.withValues(alpha:0.1),
            child: Icon(currentIcon, color: AppColors.accent, size: 20),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          child: Row(
            children: [
              _buildThemeOption(
                context,
                themeProvider,
                AppThemePreference.system,
                Icons.brightness_auto_outlined,
                '시스템',
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildThemeOption(
                context,
                themeProvider,
                AppThemePreference.light,
                Icons.light_mode_outlined,
                '밝게',
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildThemeOption(
                context,
                themeProvider,
                AppThemePreference.dark,
                Icons.dark_mode_outlined,
                '어둡게',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildThemeOption(
  BuildContext context,
  ThemeProvider themeProvider,
  AppThemePreference target,
  IconData icon,
  String label,
) {
  final isSelected = themeProvider.preference == target;
  final cs = Theme.of(context).colorScheme;

  return Expanded(
    child: GestureDetector(
      onTap: () => themeProvider.setPreference(target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha:0.1)
              : cs.surfaceContainerLowest,
          border: Border.all(
            color: isSelected ? AppColors.accent : cs.outlineVariant,
            width: isSelected ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.accent : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? AppColors.accent : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
    _nameController = TextEditingController(
        text: context.read<SettingsProvider>().profileName);
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
        (errorMsg) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMsg))),
      );

     if (isSuccess && context.mounted) {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await settings.loadSettings();
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('정보가 성공적으로 수정되었습니다.')),
      );
    }
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('보호자 정보 수정',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // 미리보기 — 입력하는 동안 아바타 색이 살아남
            ListenableBuilder(
              listenable: _nameController,
              builder: (_, __) => Column(
                children: [
                  InitialAvatar(
                    name: _nameController.text.isEmpty
                        ? settings.profileName
                        : _nameController.text,
                    radius: 40,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: '이름 변경', border: OutlineInputBorder())),
            const SizedBox(height: AppSpacing.md),
            TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                    labelText: '새 비밀번호', border: OutlineInputBorder()),
                obscureText: true),
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
