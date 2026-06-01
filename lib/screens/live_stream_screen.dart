import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart'; // 추가된 임포트
import '../theme/app_theme.dart';
import '../widgets/hls_player.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import '../widgets/hls_player_mobile.dart';

class LiveStreamScreen extends StatefulWidget {
  final String cameraId;
  final String cameraName;
  final String streamUrl;
  final bool isConnected;          // ← 추가

  const LiveStreamScreen({
    super.key,
    required this.cameraId,
    required this.cameraName,
    required this.streamUrl,
    this.isConnected = true,       // ← 추가
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}
class _CameraOfflineView extends StatelessWidget {
  const _CameraOfflineView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined,
                color: Colors.white.withValues(alpha: 0.5), size: 56),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '카메라가 꺼져 있어요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '카메라 전원과 인터넷 연결을 확인해 주세요',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _LiveStreamScreenState extends State<LiveStreamScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  bool _isStreamConnected = false;
  int _retryCount = 0;
  bool _isCapturing = false;
  final GlobalKey _captureKey = GlobalKey();

  // ▼ PiP 제어용 — 영상 플레이어 State에 접근
  final GlobalKey<MobileHlsPlayerState> _playerKey =
      GlobalKey<MobileHlsPlayerState>();

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
/// PiP 모드 진입. 영상 플레이어 State의 enterPip() 호출.
Future<void> _enterPip() async {
  if (!_isStreamConnected) {
    _showSnack('영상이 연결된 뒤에 사용할 수 있어요', isError: true);
    return;
  }
  try {
    await _playerKey.currentState?.enterPip();
  } catch (e) {
    debugPrint('PiP 실패: $e');
    _showSnack('이 기기에서는 PiP 기능을 지원하지 않아요', isError: true);
  }
}

Future<void> _captureFrame() async {
  if (_isCapturing) return;
  if (!_isStreamConnected) {
    _showSnack('영상이 연결된 뒤에 캡처할 수 있어요', isError: true);
    return;
  }

  setState(() => _isCapturing = true);

  try {
    // 1) 갤러리 접근 권한 확인
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        if (mounted) {
          _showSnack(
            '갤러리 권한이 없어요. 앱 설정에서 사진 권한을 허용해 주세요',
            isError: true,
          );
        }
        return;
      }
    }

    // 2) 영상 영역만 이미지로 추출
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      _showSnack('캡처를 준비하지 못했어요. 잠시 후 다시 시도해 주세요', isError: true);
      return;
    }
    
    if (!mounted) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: dpr);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      _showSnack('이미지 변환에 실패했어요', isError: true);
      return;
    }
    final pngBytes = byteData.buffer.asUint8List();

    // 3) 갤러리에 저장
    final now = DateTime.now();
    final fileName =
        'EyeCatch_${widget.cameraName.replaceAll(RegExp(r"\s+"), "_")}_'
        '${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}_'
        '${now.hour.toString().padLeft(2, "0")}${now.minute.toString().padLeft(2, "0")}${now.second.toString().padLeft(2, "0")}';

    await Gal.putImageBytes(
      pngBytes,
      album: 'EyeCatch',
      name: fileName,
    );

    if (mounted) {
      _showSnack('갤러리에 저장됐어요 · EyeCatch 앨범', isError: false);
    }
  } on GalException catch (e) {
    if (mounted) {
      _showSnack('저장 실패: ${e.type.message}', isError: true);
    }
  } catch (e) {
    if (mounted) {
      _showSnack('캡처 중 오류가 발생했어요', isError: true);
    }
  } finally {
    if (mounted) setState(() => _isCapturing = false);
  }
}

/// 성공/실패 메시지를 일관된 모양으로 표시
void _showSnack(String message, {required bool isError}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppColors.danger : AppColors.success,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
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
            // 1. 영상 플레이어 (캡처를 위해 RepaintBoundary로 감싸기)
Positioned.fill(
  child: widget.isConnected
      ? RepaintBoundary(
          key: _captureKey,
          child: MobileHlsPlayer(
            key: _playerKey,
            hlsUrl: widget.streamUrl,
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
        )
      : const _CameraOfflineView(),   // ← 오프라인이면 영상 대신 안내
),

            // 2. 상단 바 (글래스모피즘) - PointerInterceptor 적용
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              child: PointerInterceptor(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      decoration:
                          BoxDecoration(color: Colors.black.withValues(alpha:0.4)),
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
            ),

            // 3. 연결 중 안내 배너
            if (!_isStreamConnected)
              Positioned(
                top: 70,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _buildConnectingBanner(),
              ),

            // 4. 하단 컨트롤 패널 - PointerInterceptor 적용
            Positioned(
              bottom: AppSpacing.xl,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: PointerInterceptor(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      decoration:
                          BoxDecoration(color: Colors.black.withValues(alpha:0.5)),
                      child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    // 캡처 — 활성화됨!
    _buildActiveControlBtn(
      icon: _isCapturing
          ? Icons.hourglass_top
          : Icons.camera_alt_outlined,
      label: _isCapturing ? '저장 중...' : '캡처',
      onTap: _isCapturing ? null : _captureFrame,
      isProcessing: _isCapturing,
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
            color: Colors.black.withValues(alpha:0.55),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: AppColors.warning.withValues(alpha:0.5), width: 0.5),
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
                        color: Colors.white.withValues(alpha:0.7),
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
/// 활성화된 컨트롤 버튼.
/// 캡처처럼 실제로 동작하는 기능에 사용.
Widget _buildActiveControlBtn({
  required IconData icon,
  required String label,
  required VoidCallback? onTap,
  bool isProcessing = false,
}) {
  final enabled = onTap != null;

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isProcessing)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          else
            Icon(
              icon,
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha:0.4),
              size: 28,
            ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: enabled
                  ? Colors.white
                  : Colors.white.withValues(alpha:0.4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
                Icon(icon, color: Colors.white.withValues(alpha:0.5), size: 28),
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
                color: Colors.white.withValues(alpha:0.5),
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
