import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/log_provider.dart';
import '../services/emergency_call.dart';   // ← 추가
import '../theme/app_theme.dart';    

class IncidentDetailsScreen extends StatefulWidget {
  final IncidentLog log;

  const IncidentDetailsScreen({super.key, required this.log});

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
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
                  child: Image.asset(
                    log.imageUrl,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha:0.2),
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
