import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget getPlatformPlayer(String hlsUrl) {
  return MobileHlsPlayer(hlsUrl: hlsUrl);
}

class MobileHlsPlayer extends StatefulWidget {
  // 전체 HLS URL을 그대로 받음 (백엔드 hls_url 필드)
  final String hlsUrl;

  const MobileHlsPlayer({super.key, required this.hlsUrl});

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
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.hlsUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _hasError = false;
          });
          _controller.play();
        }
      }).catchError((error) {
        debugPrint('모바일 HLS 비디오 에러: $error');
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
