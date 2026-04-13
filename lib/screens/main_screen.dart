import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'add_camera_screen.dart';
import '../providers/camera_provider.dart';
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
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().fetchCameras();
    });
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
      backgroundColor: Colors.black87, // PC 환경에서 바깥 배경을 어둡게
      // 💡 [웹 비율 고정 기능] 화면 가운데에 모바일 크기(최대 너비 480)로 앱을 띄웁니다.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            color: colorScheme.surface, // 실제 모바일 앱의 배경색
            child: Stack(
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
          ),
        ),
      ),
      // 경보 버튼 역시 PC 웹화면 중앙 정렬에 맞춰 이동시킴
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
            
            // 재생 대기 화면이 렌더링 됩니다. (크래시 방지용)
            _buildMainVideoCard(colorScheme),
            const SizedBox(height: 16),
            
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

  // 💡 메인 스크린에서는 영상을 렌더링하지 않고 대기 화면만 보여줍니다.
  Widget _buildMainVideoCard(ColorScheme colorScheme) {
    final cameras = context.watch<CameraProvider>().cameras;

    if (cameras.isEmpty) {
      return Container(
        width: double.infinity, height: 200,
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text('등록된 카메라가 없습니다.\n+ 버튼을 눌러 추가해주세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))),
      );
    }

    int safeIndex = _selectedCameraIndex;
    if (safeIndex >= cameras.length) safeIndex = 0;

    final currentCam = cameras[safeIndex];
    final String camName = currentCam['name'] ?? '알 수 없는 카메라';
    final String cameraId = currentCam['id']?.toString() ?? 'cam_0${safeIndex + 1}'; 

    return GestureDetector(
      // 💡 여기서 라이브 스크린으로 카메라 ID를 넘깁니다.
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveStreamScreen(cameraId: cameraId, cameraName: camName))),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [BoxShadow(color: colorScheme.shadow.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- 대기 화면 (재생 버튼) ---
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 4)]
                      ),
                      child: Icon(Icons.play_arrow_rounded, size: 40, color: colorScheme.onPrimary),
                    ),
                    const SizedBox(height: 12),
                    Text('라이브 화면 보기', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              // --- 상단 위험 구역 표시 ---
              Positioned(
                top: 16, left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 14),
                      SizedBox(width: 4),
                      Text('위험 구역 감지 켜짐', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              // --- 하단 카메라 정보 표시 ---
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.videocam, color: colorScheme.onSurfaceVariant, size: 16),
                          const SizedBox(width: 6),
                          Text('CAM 0${safeIndex + 1} - $camName', style: TextStyle(color: colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Icon(Icons.open_in_new, color: colorScheme.primary, size: 16)
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailsRow(ColorScheme colorScheme) {
    final cameras = context.watch<CameraProvider>().cameras;

    return Row(
      children: [
        for (int i = 0; i < cameras.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCameraIndex = i),
              // 💡 파일 경로 오타 (..assets -> assets) 수정 완료
              child: _buildThumbnail('assets/images/1babyscreen.png', isActive: _selectedCameraIndex == i),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCameraScreen())),
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
          ...displayLogs.map((log) => _buildLogItem(colorScheme, log)),
          InkWell(
            onTap: () => setState(() => _selectedIndex = 2),
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

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}