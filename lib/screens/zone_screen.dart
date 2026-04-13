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
  List<Rect> _dangerZones = [];
  Offset? _startPoint;
  Offset? _currentPoint;
  
  // 💡 로딩 상태를 관리할 변수 추가
  bool _isRefreshing = false; 

  // 💡 스냅샷 새로고침 액션 메서드
  Future<void> _refreshSnapshot() async {
    setState(() => _isRefreshing = true);
    
    // TODO: 백엔드 API 연동 시 이곳에 최신 이미지(URL)를 받아오는 로직을 넣습니다.
    // 현재는 UX 시뮬레이션을 위해 1.2초 대기합니다.
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카메라의 최신 화면을 불러왔습니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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

          // ── 카메라 선택 탭 ──
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
                      _refreshSnapshot(); // 💡 탭 변경 시 자동으로 최신 화면을 불러옵니다.
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

          // ── 스냅샷 이미지 및 그리기 영역 ──
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
                child: Stack(
                  children: [
                    // 1. 제스처 드래그 & 배경 이미지
                    GestureDetector(
                      // 💡 로딩 중일 때는 드래그를 막습니다.
                      onPanStart: _isRefreshing ? null : (details) {
                        setState(() {
                          _startPoint = details.localPosition;
                          _currentPoint = details.localPosition;
                        });
                      },
                      onPanUpdate: _isRefreshing ? null : (details) {
                        setState(() => _currentPoint = details.localPosition);
                      },
                      onPanEnd: _isRefreshing ? null : (details) {
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
                          Image.asset('assets/images/1babyscreen.png', fit: BoxFit.cover),
                          Container(color: Colors.black.withOpacity(0.3)), // 어두운 오버레이
                          ..._dangerZones.map((rect) => _buildZoneBox(rect)), // 저장된 구역
                          if (_startPoint != null && _currentPoint != null)
                            _buildZoneBox(Rect.fromPoints(_startPoint!, _currentPoint!), isDrawing: true), // 그리는 중인 구역
                        ],
                      ),
                    ),

                    // 💡 2. 최신 화면 새로고침 버튼 (우측 상단)
                    if (!_isRefreshing)
                      Positioned(
                        top: 12, right: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _refreshSnapshot,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24)
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text('최신 화면', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 💡 3. 로딩 중 오버레이 화면
                    if (_isRefreshing)
                      Container(
                        color: Colors.black87,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.blueAccent),
                              SizedBox(height: 16),
                              Text('카메라에서 최신 스냅샷을\n불러오는 중입니다...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── 하단 컨트롤 버튼 ──
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _dangerZones.clear()),
                    icon: const Icon(Icons.delete_outline),
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildZoneBox(Rect rect, {bool isDrawing = false}) {
    return Positioned(
      left: rect.left, top: rect.top, width: rect.width, height: rect.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withOpacity(0.3),
          border: Border.all(color: isDrawing ? Colors.white : Colors.orangeAccent, width: 2),
        ),
        child: isDrawing ? null : const Align(
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