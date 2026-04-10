import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../config.dart'; // RTSP 주소를 가져오기 위한 config

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  // 💡 수정 1: 웹 환경을 대비해 컨트롤러를 nullable(?)로 변경
  VlcPlayerController? _videoPlayerController;
  
  bool _isRecording = false;
  late String streamUrl;
  
  @override
  void initState() {
    super.initState();
    
    // config.dart에 추가한 rtspUrl 사용
    streamUrl = '${AppConfig.rtspUrl}/camera1';

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // 💡 수정 2: 웹이 아닐 때(안드로이드/iOS)만 VLC 플레이어 초기화
    if (!kIsWeb) {
      _videoPlayerController = VlcPlayerController.network(
        streamUrl,
        // 💡 수정 3: 에뮬레이터 프리징 방지를 위해 하드웨어 가속 비활성화
        hwAcc: HwAcc.disabled, 
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(300), // 연결 안정성을 위해 캐싱 시간 약간 증가
          ]),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // 💡 수정 4: 컨트롤러가 초기화되었을 때만 안전하게 해제
    _videoPlayerController?.dispose(); 
    super.dispose();
  }

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
                    width: 8, height: 8,
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
                        // 💡 수정 5: 웹 환경일 때와 모바일일 때 화면을 다르게 보여줌
                        child: kIsWeb 
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.videocam_off, color: Colors.grey, size: 48),
                                    SizedBox(height: 16),
                                    Text('웹 브라우저에서는 영상을 지원하지 않습니다.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 8),
                                    Text('안드로이드 에뮬레이터나 실기기를 이용해주세요.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              )
                            : VlcPlayer(
                                controller: _videoPlayerController!,
                                aspectRatio: 16 / 9,
                                placeholder: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: Colors.blueAccent),
                                      SizedBox(height: 16),
                                      Text('카메라 신호 대기 중...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (_isRecording)
                      Positioned(
                        top: 16, right: 16,
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
                            Text('연결 대기', style: TextStyle(color: Colors.green[400], fontSize: 12, fontWeight: FontWeight.bold)),
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