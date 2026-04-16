import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // 💡 추가된 비디오 플레이어 임포트
import '../config.dart';

class LiveStreamScreen extends StatefulWidget {
  final String cameraId;
  final String cameraName;
  final String streamUrl; // 💡 HLS 주소를 받기 위해 추가된 변수

  const LiveStreamScreen({
    super.key, 
    required this.cameraId, 
    required this.cameraName,
    required this.streamUrl, // 필수 파라미터로 설정
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isRecording = false;
  
  // 💡 비디오 플레이어 컨트롤러 선언
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // 💡 전달받은 URL로 비디오 컨트롤러 초기화 및 자동 재생
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl))
      ..initialize().then((_) {
        setState(() {}); // 준비가 완료되면 화면 갱신
        _videoController?.play();
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose(); // 💡 메모리 누수를 막기 위해 컨트롤러 해제
    super.dispose();
  }

  // ── 액션 핸들러 (기존 유지) ──
  void _takeSnapshot() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('화면이 갤러리에 안전하게 저장되었습니다.'), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isRecording ? '녹화를 시작합니다.' : '녹화가 완료되었습니다.'),
        backgroundColor: _isRecording ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── 비디오 영역 (WebRTC로 완벽 통일!) ──
  // 💡 WebRtcPlayer 대신 VideoPlayer를 반환하도록 수정
  Widget _buildVideoArea() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    } else {
      // 영상을 불러오는 동안 보여줄 로딩 화면
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 16),
            Text('HLS 영상 스트림을 불러오는 중...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
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
          // LIVE 깜빡임 애니메이션 (기존 유지)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _animationController,
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 4),
                const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // ── 영상 출력부 ──
              Expanded(
                child: Stack(
                  children: [
                    // 1. 실제 영상 렌더러
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _isRecording ? Colors.redAccent : Colors.grey[800]!, width: _isRecording ? 2 : 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildVideoArea(),
                      ),
                    ),
                    
                    // 2. REC 아이콘 오버레이
                    if (_isRecording)
                      Positioned(
                        top: 16, right: 16,
                        child: FadeTransition(
                          opacity: _animationController,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
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

                    // 💡 3. 메인에서 옮겨온 DANGER ZONE 오버레이
                    Positioned(
                      top: 40, left: 60,
                      child: Container(
                        width: 150, height: 200, // 구역 크기 임의 지정
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.orangeAccent, width: 2), 
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4), 
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), 
                            color: Colors.orangeAccent,
                            child: const Text('DANGER ZONE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 하단 컨트롤 패널 ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.videocam, color: Colors.blueAccent),
                            const SizedBox(width: 12),
                            // 💡 전달받은 카메라 이름 출력
                            Text(widget.cameraName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(color: Colors.grey, height: 1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionBtn(icon: Icons.camera_alt_outlined, label: '화면 캡처', color: Colors.white, onTap: _takeSnapshot),
                        _buildActionBtn(icon: _isRecording ? Icons.stop_circle : Icons.fiber_manual_record, label: _isRecording ? '녹화 중지' : '영상 녹화', color: _isRecording ? Colors.redAccent : Colors.white, onTap: _toggleRecording),
                        _buildActionBtn(icon: Icons.exit_to_app, label: '종료', color: Colors.grey[400]!, onTap: () => Navigator.pop(context)),
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

  Widget _buildActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
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