import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 클립보드 복사를 위해 추가
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 토큰 접근을 위해 추가
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Provider 구독
    final settings = context.watch<SettingsProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    void handleLogout() {
      settings.logout(() {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('안전하게 로그아웃 되었습니다.')));
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    }

    // 💡 [추가] 브릿지 연동용 토큰 클립보드 복사 함수
    void copyToken() async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('eyeCatchToken');
      
      if (token != null && token.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: token));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('브릿지 연동 토큰이 클립보드에 복사되었습니다.')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('토큰을 찾을 수 없습니다. 다시 로그인해주세요.')),
          );
        }
      }
    }

    void showPasswordCheckDialog() {
      // (기존 코드와 동일하므로 생략 없이 유지)
      final passwordController = TextEditingController();
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('비밀번호 확인'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('개인정보를 수정하려면 비밀번호를 다시 입력해주세요.', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
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
                  (errorMsg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)))
                );

                if (isSuccess && context.mounted) {
                  Navigator.pop(dialogContext);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileEditScreen()));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary),
              child: settings.isLoading 
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2))
                  : Text('확인', style: TextStyle(color: colorScheme.onPrimary)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.home, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text('Eye Catch', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 카드
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const CircleAvatar(radius: 50, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1596131398991-b94f928d85a1?auto=format&fit=crop&q=80')),
                  const SizedBox(height: 16),
                  Text('${settings.profileName} 보호자님', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('맘앤대디 안심 계정', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            const Text('계정 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildListTile(context, '보호자 정보 수정', settings.profileName, Icons.person, onTap: showPasswordCheckDialog),
            _buildListTile(context, '비상 연락처 (이메일)', settings.profileEmail, Icons.chevron_right),
            
            const SizedBox(height: 24),
            
            // 💡 [추가] 기기 연동 섹션 추가
            const Text('기기 연동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildListTile(context, '브릿지 연동 토큰 복사', '카메라 기기 최초 설정 시 필요합니다', Icons.copy, onTap: copyToken),

            const SizedBox(height: 24),
            const Text('아이 안심 환경 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
        trailing: Icon(icon, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildToggleTile(BuildContext context, String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    // 기존 코드 유지
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
        secondary: CircleAvatar(
          backgroundColor: value ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          child: Icon(icon, color: value ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 20),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }
}

// ProfileEditScreen 클래스는 기존 내용과 동일하게 유지하시면 됩니다.
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
    // 초기값으로 프로바이더의 이름을 가져옴
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
    final colorScheme = Theme.of(context).colorScheme;
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '이름 변경', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '새 비밀번호', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: settings.isLoading ? null : saveInfo,
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, minimumSize: const Size(double.infinity, 50)),
              child: settings.isLoading 
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2))
                  : const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}