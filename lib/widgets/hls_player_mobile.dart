import 'dart:async';
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
    seekToLiveOnConnect: seekToLiveOnConnect,
  );
}

class MobileHlsPlayer extends StatefulWidget {
  final String hlsUrl;
  final VoidCallback? onConnected;
  final VoidCallback? onRetry;
  final bool seekToLiveOnConnect;

  const MobileHlsPlayer({
    super.key,
    required this.hlsUrl,
    this.onConnected,
    this.onRetry,
    this.seekToLiveOnConnect = false,
  });

  @override
  State<MobileHlsPlayer> createState() => _MobileHlsPlayerState();
}

class _MobileHlsPlayerState extends State<MobileHlsPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasGivenUp = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  /// 페어링 직후 MediaMTX에 스트림이 올라올 때까지 약 6~8초 정도 걸림.
  /// 여유있게 최대 30번 재시도 (5초 간격 = 약 2분 30초).
  static const int _maxRetries = 30;
  static const Duration _retryInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_hasGivenUp) return;

    // 기존 컨트롤러 정리
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.hlsUrl));

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
  _controller = controller;
  _isInitialized = true;
  _retryCount = 0;
});
controller.play();

// ▼ 추가: 라이브 엣지로 점프 (HLS 지연 보정)
if (widget.seekToLiveOnConnect) {
  final duration = controller.value.duration;
  if (duration > Duration.zero) {
    await controller.seekTo(duration);
  }
}

widget.onConnected?.call();
    } catch (error) {
      debugPrint('HLS 연결 실패 (시도 ${_retryCount + 1}/$_maxRetries): $error');
      await controller.dispose();

      if (!mounted) return;

      _retryCount++;
      widget.onRetry?.call();

      if (_retryCount >= _maxRetries) {
        setState(() => _hasGivenUp = true);
        return;
      }

      // 일정 간격 후 재시도
      _retryTimer = Timer(_retryInterval, () {
        if (mounted && !_isInitialized) _connect();
      });
    }
  }

  /// 사용자가 수동으로 재시도하고 싶을 때 호출.
  void _manualRetry() {
    _retryTimer?.cancel();
    setState(() {
      _hasGivenUp = false;
      _retryCount = 0;
      _isInitialized = false;
    });
    _connect();
  }

  @override
  Widget build(BuildContext context) {
    // 1. 영구 실패 — 사용자에게 다시 시도 버튼 노출
    if (_hasGivenUp) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text(
                '영상 스트림에 연결할 수 없어요',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '카메라가 켜져 있는지 확인해 주세요',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _manualRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    // 2. 연결 중 (재시도 횟수 표시)
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _retryCount == 0
                    ? '카메라에 연결 중...'
                    : '연결을 기다리는 중... (${_retryCount + 1}회 시도)',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              if (_retryCount > 2) ...[
                const SizedBox(height: 8),
                const Text(
                  '카메라가 막 켜진 경우 잠시 시간이 걸려요',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 3. 정상 재생
    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}
