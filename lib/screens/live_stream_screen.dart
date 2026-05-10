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

  /// 미구현 기능 안내 — 거짓말하지 않고 정직하게.
  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.construction, color: Colors.white, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('$featureName 기능은 준비 중이에요')),
          ],
        ),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, 100),
        duration: const Duration(seconds: 2),
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
                  if (mounted) setState(() => _retryCount++);
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
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            widget.cameraName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
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
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. 연결 중 안내 배너
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
                        _buildComingSoonBtn(
                          icon: Icons.camera_alt_outlined,
                          label: '캡처',
                          onTap: () => _showComingSoon('캡처'),
                        ),
                        _buildComingSoonBtn(
                          icon: Icons.fiber_manual_record,
                          label: '녹화',
                          onTap: () => _showComingSoon('녹화'),
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

  /// 준비 중 표시가 명확한 버튼.
  /// 시각적으로 비활성 상태처럼 보이지만 탭하면 안내가 떠요.
  Widget _buildComingSoonBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.5), size: 28),
                // 우측 상단에 "soon" 점 표시
                Positioned(
                  top: -2,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'soon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
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