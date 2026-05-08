import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/common/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 온보딩 완료 시 호출되는 함수 (기존 로직 유지)
  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 건너뛰기 버튼 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _finishOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                      textStyle: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    child: const Text('건너뛰기'),
                  ),
                ],
              ),
            ),
            
            // 메인 콘텐츠 영역 (PageView)
            Expanded(
              child: PageView(
                controller: _pageController,
                scrollBehavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.trackpad},
                ),
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [
                  _buildPage(
                    title: '아이의 안전을\n실시간으로 확인하세요',
                    subtitle: 'AI가 아이의 움직임을 분석하여\n항상 안전하게 지켜줍니다.',
                    imagePath: 'assets/images/onboarding1.png',
                    fallbackIcon: Icons.child_care_rounded,
                    blobColor: AppColors.accent,
                  ),
                  _buildPage(
                    title: '위험 구역을\n직접 설정하세요',
                    subtitle: '주방, 베란다 등 사고가 우려되는 곳을\n드로잉으로 지정하고 관리하세요.',
                    imagePath: 'assets/images/onboarding2.png',
                    fallbackIcon: Icons.draw_rounded,
                    blobColor: AppColors.accent,
                  ),
                  _buildPage(
                    title: '위험 상황을 즉시\n알려드립니다',
                    subtitle: '아이가 위험 구역에 진입하면\n즉각적인 알림과 경고 음성을 송출합니다.',
                    imagePath: 'assets/images/onboarding3.png',
                    fallbackIcon: Icons.notifications_active_rounded,
                    blobColor: AppColors.danger,
                  ),
                ],
              ),
            ),

            // 하단 인디케이터 및 버튼 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
              child: Column(
                children: [
                  // Progress Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 32 : 8, // 활성화된 점은 길어집니다.
                      decoration: BoxDecoration(
                        color: _currentPage == index ? AppColors.accent : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    )),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Primary Action Button (기존 SoftButton 활용)
                  SoftButton(
                    label: _currentPage == 2 ? '시작하기' : '다음',
                    onPressed: _nextPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 각 페이지를 그려주는 공통 빌더 위젯
  Widget _buildPage({
    required String title,
    required String subtitle,
    required String imagePath,
    required IconData fallbackIcon,
    required Color blobColor,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          // 1. 일러스트 및 배경 빛(Blob) 효과 영역
          Expanded(
            flex: 5,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 배경에 은은하게 퍼지는 빛 효과 (HTML의 blur-3xl 구현)
                  Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: blobColor.withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: blobColor.withOpacity(0.2),
                          blurRadius: 60,
                          spreadRadius: 20,
                        )
                      ],
                    ),
                  ),
                  
                  // 중앙 메인 이미지 (이미지가 없을 경우 아이콘 표시)
                  Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    height: 280,
                    errorBuilder: (context, error, stackTrace) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(fallbackIcon, size: 100, color: blobColor.withOpacity(0.7)),
                        const SizedBox(height: AppSpacing.md),
                        Text('이미지 파일 필요\n($imagePath)', textAlign: TextAlign.center, style: TextStyle(color: cs.outline, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 2. 텍스트 영역
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}