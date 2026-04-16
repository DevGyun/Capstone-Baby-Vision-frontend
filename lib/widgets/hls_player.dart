import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HlsPlayer extends StatefulWidget {
  final String streamUrl;

  const HlsPlayer({
    super.key,
    required this.streamUrl,
  });

  @override
  State<HlsPlayer> createState() => _HlsPlayerState();
}

class _HlsPlayerState extends State<HlsPlayer> {
  VideoPlayerController? _videoController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
      await _videoController!.initialize();
      _videoController!.play();
      setState(() {});
    } catch (e) {
      debugPrint("HLS Player Error: $e");
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text('영상 스트림을 불러올 수 없습니다.', style: TextStyle(color: Colors.redAccent)),
        ),
      );
    }

    if (_videoController != null && _videoController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
      );
    }

    // 영상 로딩 중 화면
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 16),
            Text('안전한 HLS 스트림 연결 중...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}