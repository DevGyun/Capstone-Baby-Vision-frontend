import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';

class ZoneScreen extends StatefulWidget {
  const ZoneScreen({super.key});

  @override
  State<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends State<ZoneScreen> {
  int _selectedCameraIndex = 0;
  
  // 💡 사용자가 그린 위험 구역(Rect)들을 저장하는 리스트
  List<Rect> _dangerZones = [];
  Offset? _startPoint;
  Offset? _currentPoint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cameras = context.watch<CameraProvider>().cameras;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Danger Zone', style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                const Text('위험 구역 설정', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('화면을 드래그하여 아이가 접근하면 안 되는 위험 구역을 지정하세요.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),

          // 카메라 선택 탭
          if (cameras.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(cameras.length, (index) {
                  final isSelected = _selectedCameraIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCameraIndex = index;
                        _dangerZones.clear(); // 카메라 변경 시 구역 초기화
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cameras[index]['name'] ?? 'CAM 0${index + 1}',
                        style: TextStyle(
                          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          
          const SizedBox(height: 20),

          // 💡 스냅샷 이미지 위에서 구역 그리기
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _startPoint = details.localPosition;
                      _currentPoint = details.localPosition;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _currentPoint = details.localPosition;
                    });
                  },
                  onPanEnd: (details) {
                    if (_startPoint != null && _currentPoint != null) {
                      setState(() {
                        _dangerZones.add(Rect.fromPoints(_startPoint!, _currentPoint!));
                        _startPoint = null;
                        _currentPoint = null;
                      });
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. 카메라 스냅샷 이미지 (라이브 스트림 대신 정지 이미지 사용)
                      Image.asset(
                        'assets/images/1babyscreen.png', 
                        fit: BoxFit.cover,
                      ),
                      
                      // 2. 어두운 오버레이 (구역이 더 잘 보이도록)
                      Container(color: Colors.black.withOpacity(0.3)),

                      // 3. 확정된 위험 구역들 렌더링
                      ..._dangerZones.map((rect) => _buildZoneBox(rect)),

                      // 4. 현재 드래그 중인 구역 렌더링
                      if (_startPoint != null && _currentPoint != null)
                        _buildZoneBox(Rect.fromPoints(_startPoint!, _currentPoint!), isDrawing: true),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 하단 컨트롤 버튼
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _dangerZones.clear()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('초기화'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      // TODO: FastAPI 백엔드로 좌표(_dangerZones) 전송 로직 구현
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('위험 구역이 안전하게 저장되었습니다.'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('구역 저장하기'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80), // 하단 네비게이션 바 공간 확보
        ],
      ),
    );
  }

  // 그려지는 네모 박스 UI
  Widget _buildZoneBox(Rect rect, {bool isDrawing = false}) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.3),
          border: Border.all(
            color: isDrawing ? Colors.white : Colors.orangeAccent,
            width: 2,
            style: isDrawing ? BorderStyle.solid : BorderStyle.solid, // 드래그 중일 땐 흰색 선
          ),
        ),
        child: isDrawing 
            ? null 
            : const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('DANGER', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
      ),
    );
  }
}