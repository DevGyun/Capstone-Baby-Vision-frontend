import 'dart:ui';
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

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.visibility, color: AppColors.accent),
                      SizedBox(width: AppSpacing.sm),
                      Text('Eye Catch', style: TextStyle(
                        color: AppColors.accent, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 20
                      )),
                    ],
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text('건너뛰기', style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                scrollBehavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch, PointerDeviceKind.trackpad},
                ),
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [
                  _buildPage1(cs),
                  _buildPage2(cs),
                  _buildPage3(cs),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? AppColors.accent : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    )),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  SoftButton(
                    label: _currentPage == 2 ? '시작하기' : '다음 단계로',
                    icon: _currentPage < 2 ? Icons.arrow_forward : null,
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

  Widget _buildPage1(ColorScheme cs) {
    return _buildPageTemplate(
      cs,
      title: '실시간 아이 안심 모니터링',
      description: '회사에서도 집안에 있는 아이의 모습을\n24시간 실시간으로 확인하세요.',
      imageWidget: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.asset(
              'assets/images/1babyscreen.png', 
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: 60, left: 60,
                    child: Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white54, width: 2), left: BorderSide(color: Colors.white54, width: 2)),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.lg)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80, right: 60,
                    child: Container(
                      width: 80, height: 80,
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white54, width: 2), right: BorderSide(color: Colors.white54, width: 2)),
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(AppRadius.lg)),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 1)),
                      child: Center(
                        child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.md, left: AppSpacing.md,
            child: _buildGlassCard(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.danger, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(_pulseController.value * 0.5), blurRadius: 10, spreadRadius: 4)]
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('LIVE', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: AppSpacing.md, right: AppSpacing.md,
            child: _buildGlassCard(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.child_care, color: AppColors.accent, size: 16),
                  SizedBox(width: 6),
                  Text('Safe Zone Detection', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2(ColorScheme cs) {
    return _buildPageTemplate(
      cs,
      title: 'AI가 알아서 지키는 위험 구역',
      description: '주방, 베란다 등 위험한 곳을 설정하면\nAI가 아이의 접근을 즉시 감지합니다.',
      imageWidget: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Image.network(
              'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&q=80',
              fit: BoxFit.cover, width: double.infinity, height: double.infinity,
              errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
            ),
          ),
          Container(decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(AppRadius.lg))),
          Positioned(
            top: 60, bottom: 80, left: 40, right: 40,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.warning, width: 3),
                color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Text('DANGER ZONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, backgroundColor: AppColors.warning)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3(ColorScheme cs) {
    return _buildPageTemplate(
      cs,
      title: '놓치지 않는 즉각 알림',
      description: '위험 상황 발생 시 스마트폰으로\n즉시 알림과 영상을 보내드립니다.',
      imageWidget: Stack(
        alignment: Alignment.center,
        children: [
          Container(decoration: BoxDecoration(color: AppColors.accentSoft(context), borderRadius: BorderRadius.circular(AppRadius.lg))),
          Container(
            width: 220, height: 380,
            decoration: BoxDecoration(
              color: cs.surface, borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.surfaceContainerHighest, width: 6),
              boxShadow: AppShadows.card(context),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1519689680058-324335c77eba?auto=format&fit=crop&q=80',
                    fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => _buildFallbackImage(),
                  ),
                ),
                Positioned(
                  top: AppSpacing.lg, left: AppSpacing.sm, right: AppSpacing.sm,
                  child: _buildGlassCard(
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: AppColors.danger, size: 16),
                            SizedBox(width: 4),
                            Text('Eye Catch 알림', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text('위험 구역 진입 감지!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('아이가 주방 구역에 접근했습니다.', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTemplate(ColorScheme cs, {required String title, required String description, required Widget imageWidget}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Expanded(flex: 6, child: Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg), child: imageWidget)),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                Text(description, style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant, height: 1.5), textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, color: Colors.grey, size: 48),
          SizedBox(height: 8),
          Text('이미지를 여기에 넣어주세요\n(assets/images/1babyscreen.png)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12))
        ],
      )),
    );
  }
}