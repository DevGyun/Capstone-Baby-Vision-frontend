import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/log_provider.dart';
import 'zone_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'live_stream_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _pulseController;

  // 💡 선택된 카메라 인덱스와 영상 URL 리스트
  int _selectedCameraIndex = 0;
  final List<Map<String, String>> _cameras = [
    {'name': '아이방', 'url': 'assets/images/1babyscreen.png'}, 
    {'name': '주방', 'url': 'https://images.unsplash.com/...'}, 
    {'name': '거실', 'url': 'https://images.unsplash.com/...'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildMonitoringView(colorScheme),
              const ZoneScreen(),
              const HistoryScreen(),
              const SettingsScreen(),
            ],
          ),
          Positioned(
            bottom: 24, left: 24, right: 24,
            child: _buildFloatingNavBar(colorScheme),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 
        ? Padding(
            padding: const EdgeInsets.only(bottom: 80.0),
            child: FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수동 경보가 작동되었습니다.'), backgroundColor: Colors.redAccent));
              },
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.add_alert),
            ),
          )
        : null,
    );
  }

  Widget _buildMonitoringView(ColorScheme colorScheme) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopHeader(colorScheme),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live System', style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    const Text('실시간 모니터링', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) => Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: Colors.redAccent, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(_pulseController.value * 0.5), blurRadius: 8, spreadRadius: 2)]
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('REC: LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 💡 선택된 카메라가 메인 영상에 나오도록 변경
            _buildMainVideoCard(colorScheme),
            const SizedBox(height: 16),
            
            // 💡 서브 썸네일 클릭 시 메인 영상 전환되도록 변경
            _buildThumbnailsRow(colorScheme),
            const SizedBox(height: 24),
            _buildAiStatusCard(colorScheme),
            const SizedBox(height: 16),
            _buildLiveLogsPanel(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.visibility, color: colorScheme.primary, size: 28),
            const SizedBox(width: 8),
            Text('Eye Catch', style: TextStyle(color: colorScheme.primary, fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
        Row(
          children: [
            Icon(Icons.notifications_outlined, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            CircleAvatar(radius: 16, backgroundColor: colorScheme.primaryContainer, child: Icon(Icons.person, size: 20, color: colorScheme.onPrimaryContainer)),
          ],
        )
      ],
    );
  }

  Widget _buildMainVideoCard(ColorScheme colorScheme) {
    final currentCam = _cameras[_selectedCameraIndex];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveStreamScreen())),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.black,
            boxShadow: [BoxShadow(color: colorScheme.shadow.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // AnimatedSwitcher를 넣어서 부드러운 전환 효과 추가
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: currentCam['url']!.startsWith('http')
                      ? Image.network(
                          currentCam['url']!,
                          key: ValueKey<String>(currentCam['url']!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : Image.asset(
                          currentCam['url']!,
                          key: ValueKey<String>(currentCam['url']!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                ),
                Positioned(
                  top: 40, left: 60,
                  child: Container(
                    width: 100, height: 140,
                    decoration: BoxDecoration(border: Border.all(color: Colors.orangeAccent, width: 2), borderRadius: BorderRadius.circular(8)),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), color: Colors.orangeAccent,
                        child: const Text('DANGER ZONE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12, left: 12, right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: Colors.black.withOpacity(0.4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.videocam, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text('CAM 0${_selectedCameraIndex + 1} - ${currentCam['name']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Icon(Icons.fullscreen, color: Colors.white.withOpacity(0.8), size: 20)
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
      ),
    );
  }

  Widget _buildThumbnailsRow(ColorScheme colorScheme) {
    return Row(
      children: [
        // 카메라 리스트를 순회하며 썸네일 생성
        for (int i = 0; i < _cameras.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCameraIndex = i),
              child: _buildThumbnail(_cameras[i]['url']!, isActive: _selectedCameraIndex == i),
            ),
          ),
          const SizedBox(width: 12),
        ],
        // 여분 카메라 추가 버튼
        Expanded(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant, style: BorderStyle.solid),
              ),
              child: Icon(Icons.add, color: colorScheme.outline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(String url, {bool isActive = false}) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isActive ? 9 : 12),
          // 💡 해결 방법: URL이 http로 시작하면 network로, 아니면 asset으로 띄웁니다!
          child: url.startsWith('http')
              ? Image.network(url, fit: BoxFit.cover, color: isActive ? null : Colors.black.withOpacity(0.5), colorBlendMode: BlendMode.darken)
              : Image.asset(url, fit: BoxFit.cover, color: isActive ? null : Colors.black.withOpacity(0.5), colorBlendMode: BlendMode.darken),
        ),
      ),
    );
  }

  Widget _buildAiStatusCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(24), border: Border.all(color: colorScheme.surfaceContainerHighest)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text('AI 인텔리전스 현황', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('분석 정확도', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              Text('98.2%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: 0.982, backgroundColor: colorScheme.surfaceContainerHigh, valueColor: AlwaysStoppedAnimation(colorScheme.primary), minHeight: 6),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('활성화된 감지 구역', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
                const Text('3 개', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLiveLogsPanel(ColorScheme colorScheme) {
    // 💡 Provider에서 로그 데이터를 가져옵니다 (최대 2개만 보여줌)
    final logs = context.watch<LogProvider>().logs;
    final displayLogs = logs.take(2).toList(); 

    return Container(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(24), border: Border.all(color: colorScheme.surfaceContainerHighest)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('실시간 감지 로그', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Text('UPDATE NOW', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          
          // 💡 공통 로그 데이터를 UI로 변환하여 출력
          ...displayLogs.map((log) => _buildLogItem(colorScheme, log)),

          InkWell(
            onTap: () => setState(() => _selectedIndex = 2), // 위험 로그 탭으로 이동
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: colorScheme.surfaceContainerHigh))),
              child: Text('모든 로그 보기', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLogItem(ColorScheme colorScheme, IncidentLog log) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: log.isAlert ? log.iconColor.withOpacity(0.05) : colorScheme.surfaceContainerLow,
        border: log.isAlert ? Border(left: BorderSide(color: log.iconColor, width: 4)) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: log.iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(log.icon, color: log.iconColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(log.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: log.iconColor)),
                  Text(log.time, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                ]),
                const SizedBox(height: 4),
                Text(log.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.videocam, '모니터링'),
              _buildNavItem(1, Icons.grid_view, '구역 설정'),
              _buildNavItem(2, Icons.history, '사건 내역'),
              _buildNavItem(3, Icons.settings, '설정'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? colorScheme.primaryContainer : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}