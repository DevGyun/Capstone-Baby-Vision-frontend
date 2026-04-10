import 'package:flutter/material.dart';

class IncidentDetailsScreen extends StatelessWidget {
  const IncidentDetailsScreen({super.key});

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
                  child: Image.network(
                    'https://images.unsplash.com/photo-1519689680058-324335c77eba?w=800&auto=format&fit=crop&q=80',
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.2), // 어두운 오버레이
                    colorBlendMode: BlendMode.darken,
                  ),
                ),
                // 위험 경고 아이콘 (웹의 애니메이션 효과 대체)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 4),
                  ),
                  child: const Center(
                    child: Icon(Icons.warning, color: Colors.redAccent, size: 40),
                  ),
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
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16)),
                    child: Text('알림: 주의 필요', style: TextStyle(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  const Text('계단 위험 구역 접근', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('감지 시간: 오후 5:45:12', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  const Text('상세 내용', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    '설정된 위험 구역(계단 주변)에서 아이의 움직임이 감지되었습니다. 혹시 모를 안전사고를 예방하기 위해 보호자님의 실시간 확인이 필요합니다.',
                    style: TextStyle(height: 1.5, color: Colors.black87),
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