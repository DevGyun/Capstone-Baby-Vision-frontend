import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/hls_player.dart';

class LiveStreamScreen extends StatefulWidget {
  final String cameraId;
  final String cameraName;
  final String streamUrl;

  const LiveStreamScreen({super.key, required this.cameraId, required this.cameraName, required this.streamUrl});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
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
      backgroundColor: Colors.black, // 스트리밍 화면은 몰입감을 위해 Black 고정
      body: SafeArea(
        child: Stack(
          children: [
            // 1. 영상 플레이어
            Positioned.fill(
              child: HlsPlayer(streamUrl: widget.streamUrl),
            ),
            
            // 2. 상단 바 (글래스모피즘)
            Positioned(
              top: AppSpacing.sm, left: AppSpacing.sm, right: AppSpacing.sm,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                        Expanded(child: Text(widget.cameraName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                        if (_isRecording)
                          FadeTransition(
                            opacity: _animationController,
                            child: const Row(
                              children: [
                                Icon(Icons.fiber_manual_record, color: AppColors.danger, size: 14),
                                SizedBox(width: 4),
                                Text('REC', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        const SizedBox(width: AppSpacing.md),
                        Row(
                          children: [
                            FadeTransition(
                              opacity: _animationController,
                              child: const Icon(Icons.circle, color: AppColors.danger, size: 10),
                            ),
                            const SizedBox(width: 4),
                            const Text('LIVE', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. 하단 컨트롤 패널
            Positioned(
              bottom: AppSpacing.xl, left: AppSpacing.lg, right: AppSpacing.lg,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionBtn(icon: Icons.camera_alt_outlined, label: '캡처', color: Colors.white, onTap: () => _showSnack('화면이 갤러리에 저장되었습니다.')),
                        _buildActionBtn(icon: _isRecording ? Icons.stop_circle : Icons.fiber_manual_record, label: _isRecording ? '녹화 중지' : '영상 녹화', color: _isRecording ? AppColors.danger : Colors.white, onTap: () {
                          setState(() => _isRecording = !_isRecording);
                          _showSnack(_isRecording ? '녹화를 시작합니다.' : '녹화가 완료되었습니다.');
                        }),
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

  Widget _buildActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}