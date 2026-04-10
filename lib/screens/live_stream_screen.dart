import 'package:flutter/foundation.dart'; // kIsWeb, defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../config.dart';

// 웹 전용 HLS 플레이어 (조건부 import)
// 웹에서만 dart:html을 사용하므로 별도 파일로 분리하지 않고
// kIsWeb 분기 내 HtmlElementView로 처리합니다.
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web if (dart.library.io) 'stub_ui_web.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html if (dart.library.io) 'stub_html.dart';

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // 앱 전용 VLC 컨트롤러 (nullable — 웹에서는 null)
  VlcPlayerController? _vlcController;

  bool _isRecording = false;
  late String _streamUrl;

  // 웹에서 <video> 엘리먼트를 Flutter 뷰에 연결하는 ID
  static const String _htmlViewId = 'hls-video-player';

  @override
  void initState() {
    super.initState();
    _streamUrl = '${AppConfig.rtspUrl}/camera1';

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    if (kIsWeb) {
      _initWebPlayer();
    } else {
      _initVlcPlayer();
    }
  }

  // ── 웹: HLS 플레이어 초기화 ──────────────────────────────────
  void _initWebPlayer() {
    // dart:html의 VideoElement을 생성해 HLS 스트림 연결
    final videoElement = html.VideoElement()
      ..src = _streamUrl
      ..autoplay = true
      ..controls = false // 커스텀 컨트롤 사용
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.background = 'black';

    // Flutter Web 렌더러에 HTML 엘리먼트 등록
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _htmlViewId,
      (int viewId) => videoElement,
    );
  }

  // ── 앱: VLC RTSP 플레이어 초기화 ─────────────────────────────
  void _initVlcPlayer() {
    _vlcController = VlcPlayerController.network(
      _streamUrl,
      hwAcc: HwAcc.disabled, // 에뮬레이터 프리징 방지
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(300),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _vlcController?.dispose();
    super.dispose();
  }

  // ── 액션 핸들러 ──────────────────────────────────────────────
  void _takeSnapshot() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          Icon(Icons.camera_alt, color: Colors.white),
          SizedBox(width: 8),
          Text('화면이 갤러리에 안전하게 저장되었습니다.'),
        ]),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            _isRecording ? Icons.fiber_manual_record : Icons.save_alt,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(_isRecording ? '아이의 모습을 녹화하기 시작합니다.' : '녹화가 완료되어 갤러리에 저장되었습니다.'),
        ]),
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

  // ── 비디오 영역 위젯 ─────────────────────────────────────────
  Widget _buildVideoArea() {
    if (kIsWeb) {
      // 웹: HtmlElementView로 <video> 태그 렌더링
      return HtmlElementView(viewType: _htmlViewId);
    }

    // 앱: VLC 플레이어
    return VlcPlayer(
      controller: _vlcController!,
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
    );
  }

  // ── 빌드 ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.8),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '실시간 CCTV 모니터링',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!kIsWeb)
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
                    decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
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
              // ── 비디오 영역 ──
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
                          width: _isRecording ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildVideoArea(),
                      ),
                    ),
                    // REC 표시
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
                    // 웹 안내 배지
                    if (kIsWeb)
                      Positioned(
                        bottom: 12, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HLS 스트림 (웹)',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 컨트롤 패널 ──
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
                            Text(
                              '메인 게이트 카메라 01',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('상태: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Icon(Icons.network_wifi, color: Colors.green[400], size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '연결 대기',
                              style: TextStyle(color: Colors.green[400], fontSize: 12, fontWeight: FontWeight.bold),
                            ),
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