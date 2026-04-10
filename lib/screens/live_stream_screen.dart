import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late VlcPlayerController _videoPlayerController;
  
  //녹화 상태를 추적하는 변수
  bool _isRecording = false;

  late String streamUrl;
  
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      streamUrl = 'rtsp://localhost:8554/camera1';
    } else if (Platform.isAndroid) {
      streamUrl = 'rtsp://10.0.2.2:8554/camera1';
    } else {
      streamUrl = 'rtsp://localhost:8554/camera1';
    }
    // LIVE 깜빡임 효과를 위한 애니메이션 컨트롤러
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // VLC 플레이어 컨트롤러 초기화 (RTSP 네트워크 스트림 연결)
    _videoPlayerController = VlcPlayerController.network(
      streamUrl,
      hwAcc: HwAcc.full, // 하드웨어 가속 사용 (성능 최적화)
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(150), // 지연 시간(Latency) 줄이기
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoPlayerController.dispose(); 
    super.dispose();
  }

  // 📸 1. 화면 캡처(Snapshot) 모의 기능
  void _takeSnapshot() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.white),
            SizedBox(width: 8),
            Text('화면이 갤러리에 안전하게 저장되었습니다.'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 🎥 2. 영상 녹화 모의 기능
  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_isRecording ? Icons.fiber_manual_record : Icons.save_alt, color: Colors.white),
            SizedBox(width: 8),
            Text(_isRecording ? '아이의 모습을 녹화하기 시작합니다.' : '녹화가 완료되어 갤러리에 저장되었습니다.'),
          ],
        ),
        backgroundColor: _isRecording ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _enterPIPMode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIP 모드로 전환합니다. (네이티브 연동 필요)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.8),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('실시간 CCTV 모니터링', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt),
            tooltip: '백그라운드에서 보기 (PIP)',
            onPressed: _enterPIPMode,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _animationController,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isRecording ? Colors.redAccent : Colors.grey[800]!,
                          width: _isRecording ? 2 : 1
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        // 💡 수정 2: Image.network를 지우고 VlcPlayer를 연결했습니다.
                        child: VlcPlayer(
                          controller: _videoPlayerController,
                          aspectRatio: 16 / 9, // CCTV 기본 비율
                          placeholder: const Center(
                            child: CircularProgressIndicator(color: Colors.blueAccent),
                          ),
                        ),
                      ),
                    ),
                    if (_isRecording)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: FadeTransition(
                          opacity: _animationController,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                                SizedBox(width: 4),
                                Text('REC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.videocam, color: Colors.blueAccent),
                            SizedBox(width: 12),
                            Text('메인 게이트 카메라 01', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('상태: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Icon(Icons.network_wifi, color: Colors.green[400], size: 18),
                            const SizedBox(width: 4),
                            Text('최상', style: TextStyle(color: Colors.green[400], fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(color: Colors.grey, height: 1),
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionBtn(
                          icon: Icons.camera_alt_outlined,
                          label: '화면 캡처',
                          color: Colors.white,
                          onTap: _takeSnapshot,
                        ),
                        _buildActionBtn(
                          icon: _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                          label: _isRecording ? '녹화 중지' : '영상 녹화',
                          color: _isRecording ? Colors.redAccent : Colors.white,
                          onTap: _toggleRecording,
                        ),
                        _buildActionBtn(
                          icon: Icons.exit_to_app,
                          label: '종료',
                          color: Colors.grey[400]!,
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}