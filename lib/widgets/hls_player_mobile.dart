import 'package:better_player_enhanced/better_player.dart';
import 'package:flutter/material.dart';

Widget getPlatformPlayer(
  String hlsUrl, {
  VoidCallback? onConnected,
  VoidCallback? onRetry,
  bool seekToLiveOnConnect = false,   // 인터페이스 호환용 (better_player는 자체 처리)
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

// PiP 제어를 위해 외부에서 접근 가능하게 State를 public으로
class MobileHlsPlayerState extends State<MobileHlsPlayer> {
  BetterPlayerController? _controller;
  final GlobalKey _betterPlayerKey = GlobalKey();
  bool _connectedNotified = false;
  bool _hasGivenUp = false;
  int _retryCount = 0;

  static const int _maxRetries = 30;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.hlsUrl,
      liveStream: true,                 // ★ 라이브 스트림 — 항상 엣지 재생
      videoFormat: BetterPlayerVideoFormat.hls,
      headers: const {
        'ngrok-skip-browser-warning': '69420',
      },
    );

    final config = BetterPlayerConfiguration(
      autoPlay: true,
      looping: false,
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      handleLifecycle: false,           // 우리가 직접 라이프사이클 관리
      // ★ PiP 활성화
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        enablePip: true,
        showControls: false,            // 자체 컨트롤 숨김 (우리 UI 사용)
      ),
      errorBuilder: (context, errorMessage) => _buildError(),
    );

    final controller = BetterPlayerController(config);
    controller.setupDataSource(dataSource);

    controller.addEventsListener((event) {
      switch (event.betterPlayerEventType) {
        case BetterPlayerEventType.initialized:
        case BetterPlayerEventType.play:
          if (!_connectedNotified && mounted) {
            _connectedNotified = true;
            _retryCount = 0;
            widget.onConnected?.call();
          }
          break;
        case BetterPlayerEventType.exception:
          _handleError();
          break;
        default:
          break;
      }
    });

    setState(() => _controller = controller);
  }

  void _handleError() {
    if (!mounted || _hasGivenUp) return;
    _retryCount++;
    widget.onRetry?.call();

    if (_retryCount >= _maxRetries) {
      setState(() => _hasGivenUp = true);
      return;
    }

    // 5초 후 데이터소스 다시 시도
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _hasGivenUp) return;
      try {
        _controller?.retryDataSource();
      } catch (_) {}
    });
  }

Future<void> enterPip() async {
  final controller = _controller;
  if (controller == null) {
    throw Exception('플레이어가 아직 준비되지 않았어요');
  }
  await controller.enablePictureInPicture(_betterPlayerKey);
}

  bool get isInitialized => _controller?.isVideoInitialized() ?? false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasGivenUp) return _buildGaveUp();

    if (_controller == null) {
      return _buildLoading('카메라에 연결 중...');
    }

    return Container(
  color: Colors.black,
  child: BetterPlayer(
    key: _betterPlayerKey,        // ← 추가
    controller: _controller!,
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

  Widget _buildError() => Container(color: Colors.black);

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