import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../providers/camera_provider.dart';

class ZoneScreen extends StatefulWidget {
  const ZoneScreen({super.key});

  @override
  State<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends State<ZoneScreen> {
  int _selectedCameraIndex = 0;
  List<Rect> _dangerZones = [];
  List<int> _loadedZoneIds = []; // 서버에서 가져온 기존 구역 ID들 (저장 시 삭제용)
  Offset? _startPoint;
  Offset? _currentPoint;

  bool _isRefreshing = false;
  bool _isSaving = false;
  Size? _containerSize;
  int? _currentLoadedCameraId; // 마지막으로 zones를 로드한 카메라 ID

  // ── 헬퍼 ────────────────────────────────────────
  Future<Map<String, String>?> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('eyeCatchToken');
    if (token == null) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': '69420',
    };
  }

  // Rect (픽셀) → 4점 다각형 (정규화 0~1)
  List<List<double>> _rectToPoints(Rect r, Size s) {
    double clamp(double v) => v.clamp(0.0, 1.0);
    return [
      [clamp(r.left  / s.width), clamp(r.top    / s.height)],
      [clamp(r.right / s.width), clamp(r.top    / s.height)],
      [clamp(r.right / s.width), clamp(r.bottom / s.height)],
      [clamp(r.left  / s.width), clamp(r.bottom / s.height)],
    ];
  }

  // 정규화 다각형 → Rect (bounding box)
  Rect _pointsToRect(List<dynamic> points, Size s) {
    double minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    for (final p in points) {
      final x = (p[0] as num).toDouble();
      final y = (p[1] as num).toDouble();
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return Rect.fromLTRB(
      minX * s.width, minY * s.height,
      maxX * s.width, maxY * s.height,
    );
  }

  // ── 구역 로드 ── GET /danger-zones/{camera_id}
  Future<void> _loadZones(int cameraId) async {
    if (_containerSize == null) return;

    setState(() {
      _dangerZones = [];
      _loadedZoneIds = [];
    });

    try {
      final headers = await _authHeaders();
      if (headers == null) return;

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/danger-zones/$cameraId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<Rect> rects = [];
        final List<int> ids = [];
        for (final zone in data) {
          ids.add(zone['id']);
          final points = zone['zone_points'] as List<dynamic>;
          rects.add(_pointsToRect(points, _containerSize!));
        }
        setState(() {
          _dangerZones = rects;
          _loadedZoneIds = ids;
          _currentLoadedCameraId = cameraId;
        });
      }
    } catch (e) {
      print('구역 로드 에러: $e');
    }
  }

  // ── 구역 저장 ── 기존 DELETE 후 새로 POST
  Future<void> _saveZones(int cameraId) async {
    if (_containerSize == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final headers = await _authHeaders();
      if (headers == null) {
        setState(() => _isSaving = false);
        return;
      }

      // 1. 기존 구역 모두 삭제
      for (final id in _loadedZoneIds) {
        await http.delete(
          Uri.parse('${AppConfig.baseUrl}/danger-zones/$id'),
          headers: headers,
        );
      }

      // 2. 현재 그려진 구역들을 새로 등록
      final List<int> newIds = [];
      for (int i = 0; i < _dangerZones.length; i++) {
        final rect = _dangerZones[i];
        final points = _rectToPoints(rect, _containerSize!);
        final response = await http.post(
          Uri.parse('${AppConfig.baseUrl}/danger-zones'),
          headers: headers,
          body: jsonEncode({
            'camera_id': cameraId,
            'label': 'Zone ${i + 1}',
            'zone_points': points,
          }),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          final created = jsonDecode(response.body);
          newIds.add(created['id']);
        }
      }

      setState(() {
        _loadedZoneIds = newIds;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('위험 구역이 안전하게 저장되었습니다.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('구역 저장 에러: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장에 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── 스냅샷 새로고침 (백엔드 연동 전 UX 시뮬레이션) ──
  Future<void> _refreshSnapshot() async {
    setState(() => _isRefreshing = true);
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

    // 카메라가 있고 아직 로드 안 했으면 첫 카메라의 구역 자동 로드
    if (cameras.isNotEmpty && _containerSize != null && _currentLoadedCameraId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLoadedCameraId == null) {
          final safeIdx = _selectedCameraIndex.clamp(0, cameras.length - 1);
          _loadZones(cameras[safeIdx].id);
        }
      });
    }

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
                        _dangerZones.clear();
                      });
                      _loadZones(cameras[index].id);
                      _refreshSnapshot();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cameras[index].name,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final newSize = Size(constraints.maxWidth, constraints.maxHeight);
                    if (_containerSize != newSize) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _containerSize = newSize);
                      });
                    }

                    return Stack(
                      children: [
                        GestureDetector(
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
                              final newRect = Rect.fromPoints(_startPoint!, _currentPoint!);
                              // 너무 작은 영역은 무시 (실수 방지)
                              if (newRect.width > 20 && newRect.height > 20) {
                                setState(() {
                                  _dangerZones.add(newRect);
                                });
                              }
                              setState(() {
                                _startPoint = null;
                                _currentPoint = null;
                              });
                            }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset('assets/images/1babyscreen.png', fit: BoxFit.cover),
                              Container(color: Colors.black.withOpacity(0.3)),
                              ..._dangerZones.map((rect) => _buildZoneBox(rect)),
                              if (_startPoint != null && _currentPoint != null)
                                _buildZoneBox(Rect.fromPoints(_startPoint!, _currentPoint!), isDrawing: true),
                            ],
                          ),
                        ),

                        if (!_isRefreshing && !_isSaving)
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
                                    border: Border.all(color: Colors.white24),
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

                        if (_isRefreshing || _isSaving)
                          Container(
                            color: Colors.black87,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(color: Colors.blueAccent),
                                  const SizedBox(height: 16),
                                  Text(
                                    _isSaving
                                        ? '서버에 위험 구역을 저장 중입니다...'
                                        : '카메라에서 최신 스냅샷을\n불러오는 중입니다...',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
                    onPressed: _isSaving ? null : () => setState(() => _dangerZones.clear()),
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
                    onPressed: (_isSaving || cameras.isEmpty) ? null : () {
                      final safeIdx = _selectedCameraIndex.clamp(0, cameras.length - 1);
                      _saveZones(cameras[safeIdx].id);
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
