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

  // 💡 [중요] 백엔드 MediaMTX 서버의 실제 RTSP 주소로 변경해야 합니다.
  // Bridge 설정 파일(config.py)에서 출력 스트림명이 'camera1'이므로 뒤에 /camera1이 붙습니다.
  // 로컬 테스트 시: rtsp://<서버의_로컬_IP>:8554/camera1
  // 외부 접속 시: ngrok tcp 8554 명령어로 생성된 tcp 주소를 사용하세요.
  final String streamUrl = 'rtsp://localhost:8554/camera1';

  @override
  void initState() {
    super.initState();
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
          VlcAdvancedOptions.networkCaching(150), // 지연 시간(Latency) 줄이기 (기본값보다 낮춤)
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoPlayerController.dispose(); // 화면 종료 시 스트림 리소스 해제
    super.dispose();
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
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    // 💡 RTSP 영상 플레이어 적용
                    child: VlcPlayer(
                      controller: _videoPlayerController,
                      aspectRatio: 16 / 9,
                      placeholder: const Center(
                        child: CircularProgressIndicator(color: Colors.blueAccent),
                      ),
                    ),
                  ),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.videocam, color: Colors.blueAccent),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('메인 게이트 카메라 01', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('스트리밍 연결 상태: 연결됨', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('종료'),
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
}