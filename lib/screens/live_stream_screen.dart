import 'package:flutter/material.dart';

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isRecording = false; // 영상 녹화 상태 관리

  // 실제 스트리밍 서버 주소 (웹의 VITE_API_BASE_URL 역할)
  final String streamUrl = 'https://새로-발급받은-ngrok-주소.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    // LIVE 깜빡임 효과를 위한 애니메이션 컨트롤러
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 📸 1. 화면 캡처(Snapshot) 모의 기능
  // 실제 구현 시 image_gallery_saver, path_provider 패키지 활용
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

  // 📺 3. PIP (Picture-in-Picture) 모드 모의 기능
  // 실제 구현 시 simple_pip_mode 또는 floating 패키지 활용 필요
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
      backgroundColor: const Color(0xFF0F172A), // Tailwind slate-900
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.8),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('실시간 CCTV 모니터링', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // PIP 버튼 추가
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
                        // 녹화 중일 때 빨간색 테두리로 강조
                        border: Border.all(
                          color: _isRecording ? Colors.redAccent : Colors.grey[800]!,
                          width: _isRecording ? 2 : 1
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        // 향후 RTSP나 특수 포맷인 경우 flutter_vlc_player 패키지로 교체
                        child: Image.network(
                          streamUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(child: Text('스트리밍을 연결할 수 없습니다.', style: TextStyle(color: Colors.white)));
                          },
                        ),
                      ),
                    ),
                    // 녹화 중 표시 인디케이터 (우측 상단)
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
              
              // 하단 컨트롤러 안내 영역
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // slate-800
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 상단: 카메라 정보 및 세분화된 네트워크 상태
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
                        // Wi-Fi 신호 상태 시각화
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
                    
                    // 하단: 비디오 플레이어 컨트롤 버튼들
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

  // 컨트롤러 버튼 위젯을 생성하는 헬퍼 메서드
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