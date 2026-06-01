import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget getPlatformPlayer(
  String hlsUrl, {
  VoidCallback? onConnected,
  VoidCallback? onRetry,
  bool seekToLiveOnConnect = false,
}) {
  return MobileHlsPlayer(
    hlsUrl: hlsUrl,
    onConnected: onConnected,
    onRetry: onRetry,
  );
}

class MobileHlsPlayer extends StatefulWidget {
  final String hlsUrl;
  final VoidCallback? onConnected;
  final VoidCallback? onRetry;

  const MobileHlsPlayer({
    super.key,
    required this.hlsUrl,
    this.onConnected,
    this.onRetry,
  });

  @override
  State<MobileHlsPlayer> createState() => MobileHlsPlayerState();
}

class MobileHlsPlayerState extends State<MobileHlsPlayer> {
  VideoPlayerController? _controller;
  bool _connectedNotified = false;
  bool _hasGivenUp = false;
  int _retryCount = 0;

  static const int _maxRetries = 30;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.hlsUrl),
      httpHeaders: const {'ngrok-skip-browser-warning': '69420'},
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      await controller.play();
      await controller.setLooping(false);

      if (!_connectedNotified) {
        _connectedNotified = true;
        _retryCount = 0;
        widget.onConnected?.call();
      }
      setState(() {});
    } catch (e) {
      _handleError();
    }
  }

  void _handleError() {
    if (!mounted || _hasGivenUp) return;
    _retryCount++;
    widget.onRetry?.call();

    if (_retryCount >= _maxRetries) {
      setState(() => _hasGivenUp = true);
      return;
    }

    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted || _hasGivenUp) return;
      await _controller?.dispose();
      _controller = null;
      _connectedNotified = false;
      await _setup();
    });
  }

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// PiP 제거됨 — 호환용 빈 메서드 (live_stream_screen에서 호출 제거 권장)
  Future<void> enterPip() async {
    throw Exception('PiP는 더 이상 지원하지 않아요');
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasGivenUp) return _buildGaveUp();

    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return _buildLoading('카메라에 연결 중...');
    }

    // 에러 상태 감지
    if (c.value.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleError());
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      ),
    );
  }

  Widget _buildLoading(String msg) => Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _retryCount == 0
                    ? msg
                    : '연결을 기다리는 중... (${_retryCount + 1}회 시도)',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _buildGaveUp() => Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text('영상 스트림에 연결할 수 없어요',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasGivenUp = false;
                    _retryCount = 0;
                    _connectedNotified = false;
                  });
                  _setup();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
}
