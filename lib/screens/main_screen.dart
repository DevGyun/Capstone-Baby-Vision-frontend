import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:flutter/foundation.dart';
import 'add_camera_screen.dart';
import '../providers/camera_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/log_provider.dart';
import 'zone_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'live_stream_screen.dart';
import '../widgets/webrtc_player.dart'; //

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

  // 컨트롤러 해제 로직 (메모리 누수 방지)
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
    final cameras = context.watch<CameraProvider>().cameras;

    if (cameras.isEmpty) {
      return Container(
        width: double.infinity, height: 200,
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text('등록된 카메라가 없습니다.\n+ 버튼을 눌러 추가해주세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))),
      );
    }

    int safeIndex = _selectedCameraIndex;
    if (safeIndex >= cameras.length) {
      safeIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedCameraIndex = 0);
      });
    }

    final currentCam = cameras[safeIndex];
    final String camName = currentCam['name'] ?? '알 수 없는 카메라';
    final String streamUrl = currentCam['stream_url'] ?? '';
    
    // 💡 백엔드에서 받아온 카메라 고유 ID를 추출합니다. (키값은 백엔드 응답에 맞게 수정하세요)
    final String cameraId = currentCam['id']?.toString() ?? 'cam_0${safeIndex + 1}'; 

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
                // 💡 핵심 변경 부분: 환경에 따라 플레이어 분기
                kIsWeb 
                  ? WebRtcPlayer(
                      cameraId: cameraId, 
                      clientId: 'web_client_user', // 추후 AuthProvider에서 유저 ID를 가져와 넣을 수 있습니다.
                    )
                  : SafeVlcPlayer(streamUrl: streamUrl),

                // --- 상단 위험 구역 표시 (DANGER ZONE) ---
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

                // --- 하단 카메라 정보 표시 ---
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
                                Text('CAM 0${safeIndex + 1} - $camName', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
    // 💡 백엔드에서 받아온 데이터 사용
    final cameras = context.watch<CameraProvider>().cameras;

    return Row(
      children: [
        // 실제 카메라 리스트 렌더링
        for (int i = 0; i < cameras.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCameraIndex = i),
              child: _buildThumbnail('..assets/images/1babyscreen.png', isActive: _selectedCameraIndex == i),
            ),
          ),
          const SizedBox(width: 12),
        ],
        // 💡 여분 카메라 추가 버튼 (클릭 시 AddCameraScreen으로 이동)
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddCameraScreen()),
              );
            },
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
class SafeVlcPlayer extends StatefulWidget {
  final String streamUrl;
  const SafeVlcPlayer({super.key, required this.streamUrl});

  @override
  State<SafeVlcPlayer> createState() => _SafeVlcPlayerState();
}

class _SafeVlcPlayerState extends State<SafeVlcPlayer> {
  VlcPlayerController? _vlcController;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant SafeVlcPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _disposeController();
      _initialize();
    }
  }

  void _initialize() {
    // 💡 1. 웹 환경에서는 VLC 컨트롤러를 초기화하지 않고 바로 리턴합니다.
    if (kIsWeb) return; 
    
    if (widget.streamUrl.isEmpty) return;
    
    _vlcController = VlcPlayerController.network(
      widget.streamUrl,
      hwAcc: HwAcc.auto, 
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
  }

  Future<void> _disposeController() async {
    // 웹 환경이어서 컨트롤러가 null이면 아무것도 하지 않습니다.
    if (_vlcController == null) return; 
    
    final oldController = _vlcController;
    _vlcController = null;
    if (oldController != null) {
      try {
        await oldController.stopRendererScanning();
        await oldController.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 💡 2. 웹 환경일 때 보여줄 대체 UI 설정
    if (kIsWeb) {
      return const Center(
        child: Text(
          '웹 환경(Chrome)에서는\nVLC 플레이어를 지원하지 않습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (widget.streamUrl.isEmpty || _vlcController == null) {
      return const Center(
        child: Text('스트리밍 연결 대기 중...', style: TextStyle(color: Colors.white)),
      );
    }

    return VlcPlayer(
      key: ValueKey(_vlcController.hashCode),
      controller: _vlcController!,
      aspectRatio: 16 / 9,
      placeholder: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}