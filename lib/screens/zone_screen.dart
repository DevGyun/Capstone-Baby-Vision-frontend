import 'package:flutter/material.dart';

class ZoneScreen extends StatelessWidget {
  const ZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('위험 구역 설정', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('아이가 접근하면 즉시 알림을 받을 위험 구역을 설정하세요.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            
            // 이미지 및 구역 그리기 영역 (Stack을 활용해 이미지 위에 오버레이 배치)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&q=80',
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                ),
                // 폴리곤 그리기 시뮬레이션용 (향후 CustomPaint로 교체 가능)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2), // 구역이 설정된 효과
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text('화면을 터치하여 구역을 설정하세요', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 활성 구역 리스트
            const Text('활성 구역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildZoneCard(title: '주방 인덕션 주변', subtitle: '높은 민감도', color: Colors.red),
            const SizedBox(height: 8),
            _buildZoneCard(title: '베란다 출입문', subtitle: '표준 알림', color: Colors.blue),
            
            const SizedBox(height: 24),
            
            // 탐지 정밀도 슬라이더 대체 UI
            const Text('전역 매개변수', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('탐지 정밀도', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            Slider(
              value: 0.7,
              onChanged: (val) {},
              activeColor: Colors.blue,
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('유연함', style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text('정밀함', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.save),
                label: const Text('설정 저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 구역 카드 위젯 분리
  Widget _buildZoneCard({required String title, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}