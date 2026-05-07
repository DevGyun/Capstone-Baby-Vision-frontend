import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../providers/camera_provider.dart';
import '../widgets/polygon_painter.dart';

/// 백엔드 위험구역 모델.
/// GET /danger-zones/{camera_id} 응답: [{id, camera_id, label, zone_points}]
class ZoneModel {
  final int id;
  final String label;
  final List<Offset> zonePoints; // 정규화 좌표 (0~1)

  ZoneModel({
    required this.id,
    required this.label,
    required this.zonePoints,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    final raw = json['zone_points'] as List<dynamic>? ?? [];
    final points = raw.map<Offset>((p) {
      final list = p as List<dynamic>;
      return Offset(
        (list[0] as num).toDouble(),
        (list[1] as num).toDouble(),
      );
    }).toList();
    return ZoneModel(
      id: json['id'],
      label: json['label'] ?? '',
      zonePoints: points,
    );
  }
}

/// 편집 가능한 다각형. 화면에서 사용자가 추가/이동/삭제할 수 있는 단위.
/// 서버에 저장된 zone은 [serverId]가 있고, 새로 그린 zone은 null.
class _EditableZone {
  int? serverId; // 서버 저장된 zone의 id, 새 zone은 null
  String label;
  List<Offset> points; // 정규화 좌표 (0~1)

  _EditableZone({
    this.serverId,
    required this.label,
    required this.points,
  });

  bool get isCompleted => points.length >= 3;

  /// 백엔드 전송용 [[x,y], ...] 배열로 변환.
  List<List<double>> toZonePoints() {
    return points.map((p) => [p.dx, p.dy]).toList();
  }
}

class ZoneScreen extends StatefulWidget {
  const ZoneScreen({super.key});

  @override
  State<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends State<ZoneScreen> {
  // 카메라
  int _selectedCameraIndex = 0;
  int? _currentLoadedCameraId;

  // 캔버스 크기 (스냅샷 영역 픽셀)
  Size? _canvasSize;

  // 모든 다각형 (서버에서 로드한 것 + 새로 그린 것 모두)
  final List<_EditableZone> _zones = [];

  // 현재 그리는 중인 다각형의 인덱스 (null이면 그리는 중 아님 = 편집 모드)
  int? _activeZoneIndex;

  // 핸들 드래그 상태 (어느 zone의 어느 점을 드래그 중인지)
  int? _draggingZoneIndex;
  int? _draggingPointIndex;

  // 통신 상태
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isRefreshing = false;

  // 핸들 터치 인식 반경 (픽셀)
  static const double _handleHitRadius = 24;

  // ─────────────────────────────────────────────────────
  // 인증 헤더 (기존 zone_screen / camera_provider 컨벤션과 동일)
  // ─────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────
  // 좌표 변환
  // ─────────────────────────────────────────────────────
  Offset? _toNormalized(Offset local) {
    final size = _canvasSize;
    if (size == null) return null;
    final x = local.dx / size.width;
    final y = local.dy / size.height;
    if (x < 0 || x > 1 || y < 0 || y > 1) return null;
    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  /// 탭 위치 근처에 있는 핸들 찾기. {zoneIndex, pointIndex} 또는 null.
  ({int zoneIdx, int pointIdx})? _findHandleAt(Offset local) {
    final size = _canvasSize;
    if (size == null) return null;
    for (var z = 0; z < _zones.length; z++) {
      final pts = _zones[z].points;
      for (var p = 0; p < pts.length; p++) {
        final px = pts[p].dx * size.width;
        final py = pts[p].dy * size.height;
        if ((Offset(px, py) - local).distance <= _handleHitRadius) {
          return (zoneIdx: z, pointIdx: p);
        }
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────
  // 서버 통신 — 위험구역 로드
  // ─────────────────────────────────────────────────────
  Future<void> _loadZones(int cameraId) async {
    if (_canvasSize == null) return;
    setState(() {
      _isLoading = true;
      _zones.clear();
      _activeZoneIndex = null;
    });

    try {
      final headers = await _authHeaders();
      if (headers == null) {
        setState(() => _isLoading = false);
        return;
      }
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/danger-zones/$cameraId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final loaded = data
            .map((e) => ZoneModel.fromJson(e as Map<String, dynamic>))
            .map((m) => _EditableZone(
                  serverId: m.id,
                  label: m.label,
                  points: m.zonePoints,
                ))
            .toList();
        setState(() {
          _zones.addAll(loaded);
          _currentLoadedCameraId = cameraId;
          _isLoading = false;
        });
      } else {
        print('구역 로드 실패: ${response.statusCode} ${response.body}');
        setState(() => _isLoading = false);
        _showSnackBar('위험구역을 불러오지 못했어요. (${response.statusCode})',
            isError: true);
      }
    } catch (e) {
      print('구역 로드 에러: $e');
      setState(() => _isLoading = false);
      _showSnackBar('네트워크 오류로 구역을 불러오지 못했어요.', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────
  // 서버 통신 — 저장
  // 안전 순서: 새 zone POST → 모두 성공 시 기존 zone DELETE
  // (DELETE 먼저 하면 네트워크 끊길 때 데이터 손실)
  // ─────────────────────────────────────────────────────
  Future<void> _saveZones(int cameraId) async {
    if (_isSaving) return;

    // 완성 안 된 다각형 검사
    final incomplete = _zones.where((z) => !z.isCompleted).toList();
    if (incomplete.isNotEmpty) {
      _showSnackBar('점이 3개 미만인 미완성 구역이 있어요. 완성하거나 삭제해 주세요.',
          isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final headers = await _authHeaders();
      if (headers == null) {
        setState(() => _isSaving = false);
        return;
      }

      // 기존 서버 zones (저장 후 삭제 대상)
      final oldServerIds =
          _zones.where((z) => z.serverId != null).map((z) => z.serverId!).toList();

      // Phase 1: 모든 현재 zone들을 새로 POST (기존 ID 무시하고 새로 만듦)
      // 이렇게 하면 중간 실패 시 사용자 데이터는 그대로 남음.
      final List<int> newServerIds = [];
      bool postFailed = false;
      String? failReason;

      for (var i = 0; i < _zones.length; i++) {
        final zone = _zones[i];
        try {
          final response = await http.post(
            Uri.parse('${AppConfig.baseUrl}/danger-zones'),
            headers: headers,
            body: jsonEncode({
              'camera_id': cameraId,
              'label': zone.label.isEmpty ? 'Zone ${i + 1}' : zone.label,
              'zone_points': zone.toZonePoints(),
            }),
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            final created = jsonDecode(response.body);
            newServerIds.add(created['id']);
          } else {
            postFailed = true;
            failReason = _extractDetail(response) ??
                '저장 실패 (${response.statusCode})';
            break;
          }
        } catch (e) {
          postFailed = true;
          failReason = '네트워크 오류';
          print('zone POST 에러: $e');
          break;
        }
      }

      // Phase 1 실패: 새로 만든 것 롤백 (best effort)
      if (postFailed) {
        for (final id in newServerIds) {
          try {
            await http.delete(
              Uri.parse('${AppConfig.baseUrl}/danger-zones/$id'),
              headers: headers,
            );
          } catch (_) {/* best effort */}
        }
        setState(() => _isSaving = false);
        _showSnackBar(failReason ?? '저장에 실패했어요.', isError: true);
        return;
      }

      // Phase 2: 기존 server zones DELETE
      for (final id in oldServerIds) {
        try {
          await http.delete(
            Uri.parse('${AppConfig.baseUrl}/danger-zones/$id'),
            headers: headers,
          );
        } catch (e) {
          print('기존 zone DELETE 에러: $e');
          // 실패해도 무시 — 새 zone은 이미 등록됨. 다음 로드 때 정리됨.
        }
      }

      // 로컬 상태에 새 ID들 반영
      setState(() {
        for (var i = 0; i < _zones.length && i < newServerIds.length; i++) {
          _zones[i].serverId = newServerIds[i];
        }
        _isSaving = false;
        _activeZoneIndex = null;
      });

      _showSnackBar('위험 구역이 안전하게 저장되었습니다.', isError: false);
    } catch (e) {
      print('구역 저장 에러: $e');
      setState(() => _isSaving = false);
      _showSnackBar('저장에 실패했어요.', isError: true);
    }
  }

  /// FastAPI {"detail": "..."} 또는 {"detail": [{...}]} 파싱
  String? _extractDetail(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) {
            return first['msg'] as String;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────
  // 다각형 편집 동작
  // ─────────────────────────────────────────────────────
  void _startNewZone() {
    setState(() {
      _zones.add(_EditableZone(
        label: 'Zone ${_zones.length + 1}',
        points: [],
      ));
      _activeZoneIndex = _zones.length - 1;
    });
  }

  void _finishCurrentZone() {
    final idx = _activeZoneIndex;
    if (idx == null) return;
    final zone = _zones[idx];
    if (!zone.isCompleted) return;
    setState(() {
      // serverId를 null로 둬서 "변경됨"으로 마크
      // (이미 null이거나, 기존이라도 변경됐을 수 있으니 safe)
      _zones[idx].serverId = null;
      _activeZoneIndex = null;
    });
  }

  void _undoLastPoint() {
    final idx = _activeZoneIndex;
    if (idx == null) return;
    final pts = _zones[idx].points;
    if (pts.isEmpty) {
      // 점 0개에서 undo → 다각형 자체 제거
      setState(() {
        _zones.removeAt(idx);
        _activeZoneIndex = null;
      });
      return;
    }
    setState(() {
      _zones[idx].points.removeLast();
    });
  }

  void _removeZone(int index) {
    setState(() {
      _zones.removeAt(index);
      if (_activeZoneIndex == index) {
        _activeZoneIndex = null;
      } else if (_activeZoneIndex != null && _activeZoneIndex! > index) {
        _activeZoneIndex = _activeZoneIndex! - 1;
      }
    });
  }

  void _editZone(int index) {
    setState(() {
      // 기존 zone을 편집 모드로 전환 → serverId는 그대로 두되, 저장 시 새로 POST됨
      _activeZoneIndex = index;
    });
  }

  void _clearAll() {
    setState(() {
      _zones.clear();
      _activeZoneIndex = null;
    });
  }

  // ─────────────────────────────────────────────────────
  // 스냅샷 새로고침 (백엔드 연동 전 UX 시뮬레이션 — 기존 zone_screen 그대로)
  // ─────────────────────────────────────────────────────
  Future<void> _refreshSnapshot() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isRefreshing = false);
      _showSnackBar('카메라의 최신 화면을 불러왔습니다.', isError: false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // 빌드
  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cameras = context.watch<CameraProvider>().cameras;

    // 카메라가 있고 아직 로드 안 했으면 첫 카메라의 구역 자동 로드
    if (cameras.isNotEmpty &&
        _canvasSize != null &&
        _currentLoadedCameraId == null &&
        !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLoadedCameraId == null && !_isLoading) {
          final safeIdx = _selectedCameraIndex.clamp(0, cameras.length - 1);
          _loadZones(cameras[safeIdx].id);
        }
      });
    }

    final isActive = _activeZoneIndex != null;
    final activeZone = isActive ? _zones[_activeZoneIndex!] : null;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 (기존 디자인 유지) ──
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '위험 구역 설정',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isActive
                      ? '화면을 탭해 점을 추가하세요. 점을 드래그하면 위치를 옮길 수 있어요.'
                      : '+ 버튼으로 새 위험 구역을 추가하거나, 기존 구역을 탭해 편집하세요.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ── 카메라 선택 탭 (기존 그대로) ──
          if (cameras.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(cameras.length, (index) {
                  final isSelected = _selectedCameraIndex == index;
                  return GestureDetector(
                    onTap: () {
                      if (_selectedCameraIndex == index) return;
                      setState(() {
                        _selectedCameraIndex = index;
                        _currentLoadedCameraId = null;
                      });
                      _loadZones(cameras[index].id);
                      _refreshSnapshot();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cameras[index].name,
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

          const SizedBox(height: 20),

          // ── 스냅샷 + 그리기 영역 ──
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
                    final newSize = Size(
                        constraints.maxWidth, constraints.maxHeight);
                    // 무한 setState 방지: 실제로 다를 때만 갱신
                    if (_canvasSize != newSize) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _canvasSize != newSize) {
                          setState(() => _canvasSize = newSize);
                        }
                      });
                    }
                    return _buildCanvas(newSize, cameras.isNotEmpty);
                  },
                ),
              ),
            ),
          ),

          // ── 하단 컨트롤 ──
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildBottomControls(cameras),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCanvas(Size size, bool hasCameras) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 스냅샷 이미지 + 어둡게 오버레이
        Image.asset('assets/images/1babyscreen.png', fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.3)),

        // 그리기 + 제스처 레이어
        GestureDetector(
          onTapDown: _isRefreshing || _isSaving || _isLoading
              ? null
              : (details) => _handleTap(details.localPosition),
          onPanStart: _isRefreshing || _isSaving || _isLoading
              ? null
              : (details) => _handlePanStart(details.localPosition),
          onPanUpdate: _isRefreshing || _isSaving || _isLoading
              ? null
              : (details) => _handlePanUpdate(details.localPosition),
          onPanEnd: (_) {
            if (_draggingPointIndex != null) {
              setState(() {
                _draggingZoneIndex = null;
                _draggingPointIndex = null;
              });
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 모든 다각형을 각각 CustomPaint로 (탭 식별 위해 분리)
              for (var i = 0; i < _zones.length; i++)
                CustomPaint(
                  size: size,
                  painter: PolygonEditorPainter(
                    normalizedPoints: _zones[i].points,
                    selectedIndex: (_draggingZoneIndex == i)
                        ? _draggingPointIndex
                        : null,
                    isCompleted: _zones[i].isCompleted &&
                        _activeZoneIndex != i,
                    label: _zones[i].label,
                  ),
                ),
            ],
          ),
        ),

        // 우상단 — "최신 화면" 버튼 (기존 디자인 유지)
        if (!_isRefreshing && !_isSaving && !_isLoading && hasCameras)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _refreshSnapshot,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      Text('최신 화면',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 좌상단 — 그리는 중일 때 점 개수 표시
        if (_activeZoneIndex != null && !_isLoading)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orangeAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '점 ${_zones[_activeZoneIndex!].points.length}개'
                '${_zones[_activeZoneIndex!].points.length >= 3 ? ' • 완성 가능' : ' (3개 이상)'}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // 카메라 없을 때 안내
        if (!hasCameras && !_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '연결된 카메라가 없어요.\n먼저 카메라를 등록해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ),

        // 로딩 / 저장 / 새로고침 오버레이
        if (_isRefreshing || _isSaving || _isLoading)
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
                        : _isLoading
                            ? '저장된 위험 구역을 불러오는 중입니다...'
                            : '카메라에서 최신 스냅샷을\n불러오는 중입니다...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomControls(List<dynamic> cameras) {
    final isActive = _activeZoneIndex != null;
    final canFinish = isActive && _zones[_activeZoneIndex!].isCompleted;

    if (isActive) {
      // 그리는 중 — 되돌리기 + 완성하기 버튼
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _undoLastPoint,
              icon: const Icon(Icons.undo),
              label: const Text('되돌리기'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: canFinish ? _finishCurrentZone : null,
              icon: const Icon(Icons.check),
              label: const Text('이 구역 완성'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      );
    }

    // 편집 모드 — 초기화 + 추가 + 저장
    return Column(
      children: [
        // 등록된 구역 칩 (있을 때만)
        if (_zones.isNotEmpty) _buildZoneChips(),
        if (_zones.isNotEmpty) const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving || _zones.isEmpty ? null : _clearAll,
                icon: const Icon(Icons.delete_outline),
                label: const Text('초기화'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving || cameras.isEmpty ? null : _startNewZone,
                icon: const Icon(Icons.add),
                label: const Text('구역 추가'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: (_isSaving || cameras.isEmpty)
                    ? null
                    : () {
                        final safeIdx =
                            _selectedCameraIndex.clamp(0, cameras.length - 1);
                        _saveZones(cameras[safeIdx].id);
                      },
                icon: const Icon(Icons.save),
                label: const Text('저장'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildZoneChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_zones.length, (i) {
        final z = _zones[i];
        return InputChip(
          avatar: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            size: 18,
          ),
          label: Text('${z.label} (${z.points.length}점)'),
          onPressed: () => _editZone(i),
          onDeleted: () => _removeZone(i),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────
  // 제스처 핸들러
  // ─────────────────────────────────────────────────────
  void _handleTap(Offset local) {
    // 1. 핸들을 탭한 경우 → 드래그로 처리될 거라 무시
    final hit = _findHandleAt(local);
    if (hit != null) return;

    // 2. 그리는 중인 다각형이 있으면 → 점 추가
    if (_activeZoneIndex != null) {
      final n = _toNormalized(local);
      if (n == null) return;
      setState(() {
        _zones[_activeZoneIndex!].points.add(n);
      });
      return;
    }

    // 3. 그리는 중 아닌데 빈 영역 탭 → 무시 (실수 방지)
    //    "여기에서 새 다각형 시작"은 명시적 + 버튼으로만.
  }

  void _handlePanStart(Offset local) {
    final hit = _findHandleAt(local);
    if (hit != null) {
      setState(() {
        _draggingZoneIndex = hit.zoneIdx;
        _draggingPointIndex = hit.pointIdx;
      });
    }
  }

  void _handlePanUpdate(Offset local) {
    if (_draggingZoneIndex == null || _draggingPointIndex == null) return;
    final n = _toNormalized(local);
    if (n == null) return;
    setState(() {
      _zones[_draggingZoneIndex!].points[_draggingPointIndex!] = n;
    });
  }
}
