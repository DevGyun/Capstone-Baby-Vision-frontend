import 'dart:io';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/log_provider.dart';
import '../services/emergency_call.dart';   // ← 추가
import '../theme/app_theme.dart';    
import '../widgets/snapshot_image.dart';

class IncidentDetailsScreen extends StatefulWidget {
  final IncidentLog log;

  const IncidentDetailsScreen({super.key, required this.log});

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  bool _isSaving = false;
  bool _isSharing = false;

  /// 스냅샷을 인증 붙여 임시 파일로 받음. 저장·공유가 같이 재사용.
  /// 이미 받아둔 게 있으면 그대로 반환.
  String? _cachedPath;
  Future<String?> _ensureSnapshotFile() async {
    if (_cachedPath != null && File(_cachedPath!).existsSync()) {
      return _cachedPath;
    }
    final url = widget.log.snapshotUrl;
    if (url == null) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('eyeCatchToken') ?? '';
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': '69420',
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/eyecatch_alert_${widget.log.id}.jpg');
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      _cachedPath = file.path;
      return file.path;
    } catch (e) {
      debugPrint('스냅샷 다운로드 실패: $e');
      return null;
    }
  }

  String get _fileLabel {
    final dt = widget.log.detectedAt ?? widget.log.sentAt;
    final zone = widget.log.zoneName ?? '감지';
    return 'EyeCatch_${zone}_'
        '${dt.year}${dt.month.toString().padLeft(2, "0")}${dt.day.toString().padLeft(2, "0")}_'
        '${dt.hour.toString().padLeft(2, "0")}${dt.minute.toString().padLeft(2, "0")}';
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final path = await _ensureSnapshotFile();
      if (path == null) {
        _snack('저장할 사진을 불러오지 못했어요', isError: true);
        return;
      }

      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          _snack('갤러리 권한이 없어요. 설정에서 사진 권한을 허용해 주세요', isError: true);
          return;
        }
      }

      await Gal.putImage(path, album: 'EyeCatch');
      _snack('갤러리에 저장됐어요 · EyeCatch 앨범', isError: false);
    } on GalException catch (e) {
      _snack('저장 실패: ${e.type.message}', isError: true);
    } catch (e) {
      _snack('저장 중 오류가 발생했어요', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareSnapshot() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final path = await _ensureSnapshotFile();
      if (path == null) {
        _snack('공유할 사진을 불러오지 못했어요', isError: true);
        return;
      }
      final zone = widget.log.zoneName ?? '카메라';
      await Share.shareXFiles(
        [XFile(path, name: '$_fileLabel.jpg', mimeType: 'image/jpeg')],
        text: '[Eye Catch] $zone에서 위험이 감지됐어요 · ${widget.log.time}',
      );
    } catch (e) {
      _snack('공유 중 오류가 발생했어요', isError: true);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
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
            Expanded(child: Text(msg)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    // 상세 페이지 진입 시 자동으로 읽음 처리
    if (!widget.log.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<LogProvider>().markAsRead(widget.log.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Eye Catch 상세 보고서', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
  borderRadius: BorderRadius.circular(24),
  child: SnapshotImage(
    snapshotUrl: log.snapshotUrl,
    width: double.infinity,
    height: 220,
    fit: BoxFit.cover,
    color: Colors.black.withValues(alpha: 0.2),
    colorBlendMode: BlendMode.darken,
  ),
),
                if (log.isAlert)
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: log.iconColor, width: 4)),
                    child: Center(child: Icon(log.icon, color: log.iconColor, size: 40)),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha:0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: log.iconColor.withValues(alpha:0.1), borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      log.isAlert ? '알림: 주의 필요' : '일반 시스템 기록',
                      style: TextStyle(color: log.iconColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(log.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '감지 시간: ${log.time}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  const Text('상세 내용', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    log.description,
                    style: TextStyle(height: 1.5, color: colorScheme.onSurface),
                  ),

                  // 추가 정보 (백엔드에서 받은 정확도, 정확한 시각)
                  if (log.confidence != null || log.detectedAt != null) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text('추가 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (log.confidence != null)
                      _buildInfoRow(
                        context,
                        Icons.psychology,
                        'AI 분석 정확도',
                        '${(log.confidence! * 100).toStringAsFixed(1)}%',
                      ),
                    if (log.detectedAt != null)
                      _buildInfoRow(
                        context,
                        Icons.access_time,
                        '정확 감지 시각',
                        _formatDateTime(log.detectedAt!),
                      ),
                    if (log.zoneName != null)
                      _buildInfoRow(
                        context,
                        Icons.location_on,
                        '감지 구역',
                        log.zoneName!,
                      ),
                  ],
                ],
              ),
            ),
             const SizedBox(height: 24),
                         if (log.snapshotUrl != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _saveToGallery,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(_isSaving ? '저장 중...' : '사진 저장'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSharing ? null : _shareSnapshot,
                      icon: _isSharing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share_outlined, size: 20),
                      label: Text(_isSharing ? '공유 중...' : '공유'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => EmergencyCall.confirmAndDial(context),
                icon: const Icon(Icons.phone_in_talk, size: 20),
                label: const Text(
                  '119 긴급 전화',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '위급 상황 시 즉시 119로 연결됩니다',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
