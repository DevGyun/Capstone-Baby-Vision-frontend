import 'package:flutter/material.dart';
import '../providers/log_provider.dart'; // 💡 데이터 구조체 임포트

class IncidentDetailsScreen extends StatelessWidget {
  final IncidentLog log; // 💡 선택된 로그 데이터를 받아올 변수

  const IncidentDetailsScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Eye Catch 상세 보고서', style: TextStyle(color: Color(0xFF003d9b), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 비디오/이미지 영역
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  // 💡 [수정] http와 로컬 assets 이미지를 모두 렌더링할 수 있도록 분기 처리
                  child: log.imageUrl.startsWith('http')
                    ? Image.network(
                        log.imageUrl,
                        width: double.infinity, height: 220, fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.2), colorBlendMode: BlendMode.darken,
                      )
                    : Image.asset(
                        log.imageUrl,
                        width: double.infinity, height: 220, fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.2), colorBlendMode: BlendMode.darken,
                      ),
                ),
                // 위험 경고 아이콘 (Alert 상태일 때만 표시)
                if (log.isAlert)
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: log.iconColor, width: 4)),
                    child: Center(child: Icon(log.icon, color: log.iconColor, size: 40)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 상세 텍스트 영역
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: log.iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                    // 💡 [수정] 실제 로그의 데이터 바인딩
                    child: Text(
                      log.isAlert ? '알림: 주의 필요' : '일반 시스템 기록', 
                      style: TextStyle(color: log.iconColor, fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(log.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('감지 시간: ${log.time}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  const Text('상세 내용', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    log.description,
                    style: const TextStyle(height: 1.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}