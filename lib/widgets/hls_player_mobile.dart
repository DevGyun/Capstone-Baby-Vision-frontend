import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// hls_player.dart 에서 호출할 약속된 함수
Widget getPlatformPlayer(String streamId) {
  return MobileHlsPlayer(streamId: streamId);
}

class MobileHlsPlayer extends StatefulWidget {
  final String streamId;
  const MobileHlsPlayer({super.key, required this.streamId});

  @override
  State<MobileHlsPlayer> createState() => _MobileHlsPlayerState();
}

class _MobileHlsPlayerState extends State<MobileHlsPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // 💡 [핵심] 모바일 HLS 플레이어는 MediaMTX 서버 규칙에 따라 끝에 '/index.m3u8'이 반드시 붙어야 합니다!
    final fullHlsUrl = 'http://211.243.47.179:8888/${widget.streamId}/index.m3u8';

    _controller = VideoPlayerController.networkUrl(Uri.parse(fullHlsUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _hasError = false;
          });
          _controller.play(); // 영상 자동 재생
        }
      }).catchError((error) {
        debugPrint('모바일 비디오 에러: $error');
        if (mounted) {
          setState(() => _hasError = true);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('영상 스트림을 불러올 수 없습니다.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}