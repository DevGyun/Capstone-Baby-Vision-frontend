import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/common.dart';
import '../widgets/polygon_painter.dart';

/// 백엔드 위험구역 모델.
/// GET /danger-zones/{camera_id}: [{id, camera_id, label, zone_points}]
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

/// 편집 가능한 다각형. id가 null이면 아직 서버 저장 안 된 새 zone.
class _EditableZone {
  int? serverId;
  String label;
  List<Offset> points;

  _EditableZone({
    this.serverId,
    required this.label,
    required this.points,
  });

  bool get isCompleted => points.length >= 3;

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

  // 캔버스 (스냅샷 영역) 픽셀 크기
  Size? _canvasSize;

  // 모든 다각형
  final List<_EditableZone> _zones = [];

  // 그리는 중인 다각형의 인덱스 (null이면 편집 모드)
  int? _activeZoneIndex;

  // 핸들 드래그 중인 zone/point
  int? _draggingZoneIndex;
  int? _draggingPointIndex;

  // 통신 상태
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isRefreshing = false;

  static const double _handleHitRadius = 24;

  // ─── 인증 ───
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

  // ─── 좌표 변환 ───
  Offset? _toNormalized(Offset local) {
    final size = _canvasSize;
    if (size == null) return null;
    final x = local.dx / size.width;
    final y = local.dy / size.height;
    if (x < 0 || x > 1 || y < 0 || y > 1) return null;
    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

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

  // ─── 서버 통신 — 위험구역 로드 ───
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
        _showSnack('위험구역을 불러오지 못했어요', isError: true);
      }
    } catch (e) {
      print('구역 로드 에러: $e');
      setState(() => _isLoading = false);
      _showSnack('네트워크 오류로 구역을 불러오지 못했어요', isError: true);
    }
  }

  // ─── 서버 통신 — 저장 ───
  // 안전 순서: 새 zone POST → 모두 성공 시 기존 zone DELETE
  Future<void> _saveZones(int cameraId) async {
    if (_isSaving) return;

    final incomplete = _zones.where((z) => !z.isCompleted).toList();
    if (incomplete.isNotEmpty) {
      _showSnack('점이 3개 미만인 미완성 구역이 있어요', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final headers = await _authHeaders();
      if (headers == null) {
        setState(() => _isSaving = false);
        return;
      }

      final oldServerIds = _zones
          .where((z) => z.serverId != null)
          .map((z) => z.serverId!)
          .toList();

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
              'label': zone.label.isEmpty ? '구역 ${i + 1}' : zone.label,
              'zone_points': zone.toZonePoints(),
            }),
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            final created = jsonDecode(response.body);
            newServerIds.add(created['id']);
          } else {
            postFailed = true;
            failReason = _extractDetail(response) ?? '저장에 실패했어요';
            break;
          }
        } catch (e) {
          postFailed = true;
          failReason = '네트워크 오류로 저장하지 못했어요';
          print('zone POST 에러: $e');
          break;
        }
      }

      // 실패 시 새로 만든 것 롤백
      if (postFailed) {
        for (final id in newServerIds) {
          try {
            await http.delete(
              Uri.parse('${AppConfig.baseUrl}/danger-zones/$id'),
              headers: headers,
            );
          } catch (_) {}
        }
        setState(() => _isSaving = false);
        _showSnack(failReason ?? '저장에 실패했어요', isError: true);
        return;
      }

      // 기존 zone들 DELETE (best effort)
      for (final id in oldServerIds) {
        try {
          await http.delete(
            Uri.parse('${AppConfig.baseUrl}/danger-zones/$id'),
            headers: headers,
          );
        } catch (e) {
          print('기존 zone DELETE 에러: $e');
        }
      }

      setState(() {
        for (var i = 0; i < _zones.length && i < newServerIds.length; i++) {
          _zones[i].serverId = newServerIds[i];
        }
        _isSaving = false;
        _activeZoneIndex = null;
      });

      _showSnack('위험구역이 안전하게 저장되었어요', isError: false);
    } catch (e) {
      print('구역 저장 에러: $e');
      setState(() => _isSaving = false);
      _showSnack('저장에 실패했어요', isError: true);
    }
  }

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

  // ─── 다각형 편집 ───
  void _startNewZone() {
    setState(() {
      _zones.add(_EditableZone(
        label: '구역 ${_zones.length + 1}',
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
      _zones[idx].serverId = null;
      _activeZoneIndex = null;
    });
  }

  void _undoLastPoint() {
    final idx = _activeZoneIndex;
    if (idx == null) return;
    final pts = _zones[idx].points;
    if (pts.isEmpty) {
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
    setState(() => _activeZoneIndex = index);
  }

  void _clearAll() {
    setState(() {
      _zones.clear();
      _activeZoneIndex = null;
    });
  }

  // ─── 스냅샷 새로고침 (UX 시뮬레이션) ───
  Future<void> _refreshSnapshot() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isRefreshing = false);
      _showSnack('카메라의 최신 화면을 불러왔어요', isError: false);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 20,
              color: isError ? AppColors.danger : AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 빌드 ───
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cameras = context.watch<CameraProvider>().cameras;

    // 카메라가 있고 아직 로드 안 했으면 첫 카메라 zones 자동 로드
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

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '아이가 다가가면 안 되는\n공간을 알려주세요',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                Text(
                  _activeZoneIndex != null
                      ? '화면을 탭해 점을 추가하세요. 점을 드래그하면 위치를 옮길 수 있어요.'
                      : '+ 버튼으로 새 구역을 추가하거나, 등록된 구역을 탭해 편집할 수 있어요.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),

          // ── 카메라 선택 칩 ──
          if (cameras.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: List.generate(cameras.length, (index) {
                  final isSelected = _selectedCameraIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: _CameraTab(
                      name: cameras[index].name,
                      isSelected: isSelected,
                      onTap: () {
                        if (_selectedCameraIndex == index) return;
                        setState(() {
                          _selectedCameraIndex = index;
                          _currentLoadedCameraId = null;
                        });
                        _loadZones(cameras[index].id);
                      },
                    ),
                  );
                }),
              ),
            ),

          const SizedBox(height: AppSpacing.md),

          // ── 스냅샷 + 그리기 영역 ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: cs.outlineVariant, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final newSize =
                        Size(constraints.maxWidth, constraints.maxHeight);
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildBottomControls(cameras),
          ),
          const SizedBox(height: 80), // 플로팅 네비 회피
        ],
      ),
    );
  }

  Widget _buildCanvas(Size size, bool hasCameras) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 스냅샷 이미지 + 어둡게 오버레이
        Image.asset('assets/images/1babyscreen.png', fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.35)),

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
              for (var i = 0; i < _zones.length; i++)
                CustomPaint(
                  size: size,
                  painter: PolygonEditorPainter(
                    normalizedPoints: _zones[i].points,
                    selectedIndex:
                        (_draggingZoneIndex == i) ? _draggingPointIndex : null,
                    isCompleted:
                        _zones[i].isCompleted && _activeZoneIndex != i,
                    label: _zones[i].label,
                  ),
                ),
            ],
          ),
        ),

        // 우상단: 최신 화면 새로고침
        if (!_isRefreshing && !_isSaving && !_isLoading && hasCameras)
          Positioned(
            top: AppSpacing.md - 2,
            right: AppSpacing.md - 2,
            child: _OverlayButton(
              icon: Icons.refresh,
              label: '최신 화면',
              onTap: _refreshSnapshot,
            ),
          ),

        // 좌상단: 그리는 중 점 개수 칩
        if (_activeZoneIndex != null && !_isLoading)
          Positioned(
            top: AppSpacing.md - 2,
            left: AppSpacing.md - 2,
            child: _ActivePointsChip(
              count: _zones[_activeZoneIndex!].points.length,
            ),
          ),

        // 카메라 없을 때
        if (!hasCameras && !_isLoading)
          Center(
            child: EmptyStateView(
              icon: Icons.videocam_off_outlined,
              title: '연결된 카메라가 없어요',
              subtitle: '먼저 카메라를 등록해 주세요.',
              padding: const EdgeInsets.all(AppSpacing.xl),
              iconSize: 44,
            ),
          ),

        // 로딩 / 저장 / 새로고침 오버레이
        if (_isRefreshing || _isSaving || _isLoading)
          _BlurOverlay(
            message: _isSaving
                ? '서버에 위험구역을 저장하고 있어요'
                : _isLoading
                    ? '저장된 위험구역을 불러오고 있어요'
                    : '카메라의 최신 모습을 가져오고 있어요',
          ),
      ],
    );
  }

  Widget _buildBottomControls(List<dynamic> cameras) {
    final isActive = _activeZoneIndex != null;
    final canFinish = isActive && _zones[_activeZoneIndex!].isCompleted;

    if (isActive) {
      // 그리는 중 — 되돌리기 + 완성하기
      return Row(
        children: [
          Expanded(
            child: SoftButton(
              label: '되돌리기',
              icon: Icons.undo_rounded,
              variant: SoftButtonVariant.tonal,
              onPressed: _isSaving ? null : _undoLastPoint,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            flex: 2,
            child: SoftButton(
              label: '이 구역 완성',
              icon: Icons.check_rounded,
              onPressed: canFinish ? _finishCurrentZone : null,
            ),
          ),
        ],
      );
    }

    // 편집 모드
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 등록된 구역 칩 (있을 때)
        if (_zones.isNotEmpty) ...[
          _buildZoneChips(),
          const SizedBox(height: AppSpacing.md - 4),
        ],
        Row(
          children: [
            Expanded(
              child: SoftButton(
                label: '초기화',
                icon: Icons.delete_outline,
                variant: SoftButtonVariant.tonal,
                onPressed: _isSaving || _zones.isEmpty ? null : _clearAll,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: SoftButton(
                label: '구역 추가',
                icon: Icons.add_rounded,
                variant: SoftButtonVariant.tonal,
                onPressed: _isSaving || cameras.isEmpty ? null : _startNewZone,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              flex: 2,
              child: SoftButton(
                label: '저장',
                icon: Icons.shield_outlined,
                onPressed: (_isSaving || cameras.isEmpty)
                    ? null
                    : () {
                        final safeIdx =
                            _selectedCameraIndex.clamp(0, cameras.length - 1);
                        _saveZones(cameras[safeIdx].id);
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildZoneChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: List.generate(_zones.length, (i) {
        final z = _zones[i];
        return _ZoneEditChip(
          label: z.label,
          pointCount: z.points.length,
          onTap: () => _editZone(i),
          onDelete: () => _removeZone(i),
        );
      }),
    );
  }

  // ─── 제스처 ───
  void _handleTap(Offset local) {
    final hit = _findHandleAt(local);
    if (hit != null) return;

    if (_activeZoneIndex != null) {
      final n = _toNormalized(local);
      if (n == null) return;
      setState(() => _zones[_activeZoneIndex!].points.add(n));
    }
    // 비활성 모드에서 빈 영역 탭은 무시 (실수 방지)
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
    setState(() =>
        _zones[_draggingZoneIndex!].points[_draggingPointIndex!] = n);
  }
}

// ════════════════════════════════════════════════════════════════
//   서브 위젯들
// ════════════════════════════════════════════════════════════════

/// 카메라 선택 칩 (선택 시 테라코타 강조)
class _CameraTab extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _CameraTab({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.sm + 4),
          border: Border.all(
            color: isSelected ? AppColors.accent : cs.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 14,
              color: isSelected ? Colors.white : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 영상 위 오버레이 버튼 (최신 화면 등)
class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: Colors.white24, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 13),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 그리는 중 점 개수 칩 (좌상단)
class _ActivePointsChip extends StatelessWidget {
  final int count;
  const _ActivePointsChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final ready = count >= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle_outline : Icons.touch_app_outlined,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            ready ? '점 $count개 · 완성 가능' : '점 $count개 (3개 이상)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 등록된 구역 편집 칩 (탭하면 편집, X로 삭제)
class _ZoneEditChip extends StatelessWidget {
  final String label;
  final int pointCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ZoneEditChip({
    required this.label,
    required this.pointCount,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.sm + 2),
              bottomLeft: Radius.circular(AppRadius.sm + 2),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '· $pointCount점',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(AppRadius.sm + 2),
              bottomRight: Radius.circular(AppRadius.sm + 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 영상 위 블러 오버레이 (로딩 / 저장 중)
class _BlurOverlay extends StatelessWidget {
  final String message;
  const _BlurOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}