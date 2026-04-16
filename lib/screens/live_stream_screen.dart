import 'package:flutter/material.dart';
import '../widgets/hls_player.dart'; // 💡 새로 만든 HLS 위젯 임포트

class LiveStreamScreen extends StatefulWidget {
  final String cameraId;
  final String cameraName;
  final String streamUrl; 

  const LiveStreamScreen({
    super.key, 
    required this.cameraId, 
    required this.cameraName,
    required this.streamUrl, 
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
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

  // ── 액션 핸들러 ──
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.8),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('실시간 CCTV 모니터링', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // LIVE 깜빡임 애니메이션
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
                    // 1. 실제 영상 렌더러 (HLS)
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
                        child: HlsPlayer(streamUrl: widget.streamUrl), // 💡 HLS 위젯 적용
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

                    // 3. DANGER ZONE 오버레이
                    Positioned(
                      top: 40, left: 60,
                      child: Container(
                        width: 150, height: 200,
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
  children: [
    Icon(Icons.videocam),
    Expanded( // 💡 공간이 부족하면 자동으로 줄여주는 위젯으로 감싸기
      child: Text(
        '카메라 이름이 너무 깁니다', 
        overflow: TextOverflow.ellipsis, // 글자가 넘치면 '...'으로 표시
      ),
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