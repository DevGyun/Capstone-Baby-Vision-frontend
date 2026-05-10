import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/hls_player.dart';

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

class _LiveStreamScreenState extends State<LiveStreamScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isRecording = false;

  /// 스트림 실제 연결 상태.
  bool _isStreamConnected = false;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
            vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. 영상 플레이어
            Positioned.fill(
              child: HlsPlayer(
                streamUrl: widget.streamUrl,
                onConnected: () {
                  if (mounted && !_isStreamConnected) {
                    setState(() {
                      _isStreamConnected = true;
                      _retryCount = 0;
                    });
                  }
                },
                onRetry: () {
                  if (mounted) {
                    setState(() => _retryCount++);
                  }
                },
              ),
            ),

            // 2. 상단 바 (글래스모피즘)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration:
                        BoxDecoration(color: Colors.black.withOpacity(0.4)),
                    child: Row(
                      children: [
                        IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context)),
                        Expanded(
                            child: Text(widget.cameraName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                        if (_isRecording)
                          FadeTransition(
                            opacity: _animationController,
                            child: const Row(
                              children: [
                                Icon(Icons.fiber_manual_record,
                                    color: AppColors.danger, size: 14),
                                SizedBox(width: 4),
                                Text('REC',
                                    style: TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        const SizedBox(width: AppSpacing.md),
                        // LIVE 인디케이터 — 연결 상태에 따라 색/문구 다르게
                        Row(
                          children: [
                            FadeTransition(
                              opacity: _animationController,
                              child: Icon(
                                Icons.circle,
                                color: _isStreamConnected
                                    ? AppColors.danger
                                    : AppColors.warning,
                                size: 10,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isStreamConnected ? 'LIVE' : '연결 중',
                              style: TextStyle(
                                color: _isStreamConnected
                                    ? AppColors.danger
                                    : AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. 연결 중 안내 배너 (스트림 미연결 시만 노출)
            if (!_isStreamConnected)
              Positioned(
                top: 70,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _buildConnectingBanner(),
              ),

            // 4. 하단 컨트롤 패널
            Positioned(
              bottom: AppSpacing.xl,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration:
                        BoxDecoration(color: Colors.black.withOpacity(0.5)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionBtn(
                            icon: Icons.camera_alt_outlined,
                            label: '캡처',
                            color: Colors.white,
                            enabled: _isStreamConnected,
                            onTap: () => _showSnack('화면이 갤러리에 저장되었습니다.')),
                        _buildActionBtn(
                          icon: _isRecording
                              ? Icons.stop_circle
                              : Icons.fiber_manual_record,
                          label: _isRecording ? '녹화 중지' : '영상 녹화',
                          color: _isRecording ? AppColors.danger : Colors.white,
                          enabled: _isStreamConnected,
                          onTap: () {
                            setState(() => _isRecording = !_isRecording);
                            _showSnack(_isRecording
                                ? '녹화를 시작합니다.'
                                : '녹화가 완료되었습니다.');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 스트림 연결 안내 배너.
  /// 페어링 직후엔 MediaMTX에 스트림이 올라오기까지 시간이 걸려요.
  Widget _buildConnectingBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: AppColors.warning.withOpacity(0.5), width: 0.5),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.warning),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _retryCount == 0
                          ? '카메라 영상을 불러오고 있어요'
                          : '카메라가 깨어나길 기다리는 중...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _retryCount > 2
                          ? '방금 카메라를 등록한 경우 최대 1분 정도 걸려요'
                          : '잠시만 기다려 주세요',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
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
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? color : color.withOpacity(0.4), size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? color : color.withOpacity(0.4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}