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
import '../services/api_client.dart';

/// 백엔드 위험구역 모델.
class ZoneModel {
  final int id;
  final String label;
  final List<Offset> zonePoints;
  // TODO: 백엔드 스키마 업데이트 시 아래 필드들을 활용하세요.
  // final int dangerLevel; 
  // final bool objectDetection; 

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

/// 편집 가능한 다각형
class _EditableZone {
  int? serverId;
  String label;
  List<Offset> points;
  
  // ✅ 새로 추가된 UI 상태 값들
  int dangerLevel; // 0: 낮음, 1: 중간, 2: 높음
  bool objectDetectionEnabled;

  _EditableZone({
    this.serverId,
    required this.label,
    required this.points,
    this.dangerLevel = 2, // 기본값 높음
    this.objectDetectionEnabled = true, // 기본값 켜짐
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
  int _selectedCameraIndex = 0;
  int? _currentLoadedCameraId;
  Size? _canvasSize;
  final List<_EditableZone> _zones = [];
  int? _activeZoneIndex;
  int? _draggingZoneIndex;
  int? _draggingPointIndex;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isRefreshing = false;

  static const double _handleHitRadius = 24;

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

  Future<void> _loadZones(int cameraId) async {
  if (_canvasSize == null) return;
  setState(() {
    _isLoading = true;
    _zones.clear();
    _activeZoneIndex = null;
  });

  try {
    final response = await ApiClient.request('GET', '/danger-zones/$cameraId');

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
      setState(() => _isLoading = false);
      _showSnack('위험구역을 불러오지 못했어요', isError: true);
    }
  } catch (e) {
    setState(() => _isLoading = false);
    _showSnack('네트워크 오류로 구역을 불러오지 못했어요', isError: true);
  }
}

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

      final oldServerIds = _zones.where((z) => z.serverId != null).map((z) => z.serverId!).toList();
      final List<int> newServerIds = [];
      bool postFailed = false;

      for (var i = 0; i < _zones.length; i++) {
  final zone = _zones[i];
  try {
    final response = await ApiClient.request(
      'POST', '/danger-zones',
      body: {
        'camera_id': cameraId,
        'label': zone.label.isEmpty ? '위험 구역 ${i + 1}' : zone.label,
        'zone_points': zone.toZonePoints(),
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      newServerIds.add(jsonDecode(response.body)['id']);
    } else {
      postFailed = true; break;
    }
  } catch (e) {
    postFailed = true; break;
  }
}

      if (postFailed) {
        setState(() => _isSaving = false);
        _showSnack('저장에 실패했어요', isError: true);
        return;
      }

      for (final id in oldServerIds) {
  try {
    await ApiClient.request('DELETE', '/danger-zones/$id');
  } catch (_) {}
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
      setState(() => _isSaving = false);
      _showSnack('저장에 실패했어요', isError: true);
    }
  }

  void _startNewZone() {
    setState(() {
      _zones.add(_EditableZone(label: '위험 구역 ${_zones.length + 1}', points: []));
      _activeZoneIndex = _zones.length - 1;
    });
  }

  void _finishCurrentZone() {
    final idx = _activeZoneIndex;
    if (idx == null) return;
    if (!_zones[idx].isCompleted) {
      _showSnack('구역을 완성하려면 최소 3개의 점이 필요합니다.', isError: true);
      return;
    }
    setState(() {
      _zones[idx].serverId = null;
      _activeZoneIndex = null;
    });
  }

  void _undoLastPoint() {
    final idx = _activeZoneIndex;
    if (idx == null) return;
    if (_zones[idx].points.isEmpty) {
      setState(() { _zones.removeAt(idx); _activeZoneIndex = null; });
      return;
    }
    setState(() => _zones[idx].points.removeLast());
  }

  void _removeZone(int index) {
    setState(() {
      _zones.removeAt(index);
      if (_activeZoneIndex == index) _activeZoneIndex = null;
      else if (_activeZoneIndex != null && _activeZoneIndex! > index) _activeZoneIndex = _activeZoneIndex! - 1;
    });
  }

  void _editZone(int index) {
    setState(() => _activeZoneIndex = index);
  }

  void _clearAll() {
    setState(() { _zones.clear(); _activeZoneIndex = null; });
  }

  Future<void> _refreshSnapshot() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isRefreshing = false);
      _showSnack('최신 화면을 불러왔어요', isError: false);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? AppColors.danger : AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cameras = context.watch<CameraProvider>().cameras;

    if (cameras.isNotEmpty && _canvasSize != null && _currentLoadedCameraId == null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLoadedCameraId == null && !_isLoading) {
          final safeIdx = _selectedCameraIndex.clamp(0, cameras.length - 1);
          _loadZones(cameras[safeIdx].id);
        }
      });
    }

    return SafeArea(
      child: Column(
        children: [
          if (cameras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
                          setState(() { _selectedCameraIndex = index; _currentLoadedCameraId = null; });
                          _loadZones(cameras[index].id);
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final newSize = Size(constraints.maxWidth, constraints.maxHeight);
                    if (_canvasSize != newSize) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _canvasSize = newSize);
                      });
                    }
                    return _buildCanvas(newSize, cameras.isNotEmpty);
                  },
                ),
              ),
            ),
          ),

          // 하단 세부 컨트롤 (새 디자인 적용)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: _buildBottomControls(cameras),
          ),
          const SizedBox(height: 60), 
        ],
      ),
    );
  }

  Widget _buildCanvas(Size size, bool hasCameras) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/1babyscreen.png', fit: BoxFit.cover),
        Container(color: Colors.black.withOpacity(0.35)),

        GestureDetector(
          onTapDown: _isRefreshing || _isSaving || _isLoading ? null : (details) => _handleTap(details.localPosition),
          onPanStart: _isRefreshing || _isSaving || _isLoading ? null : (details) => _handlePanStart(details.localPosition),
          onPanUpdate: _isRefreshing || _isSaving || _isLoading ? null : (details) => _handlePanUpdate(details.localPosition),
          onPanEnd: (_) {
            if (_draggingPointIndex != null) setState(() { _draggingZoneIndex = null; _draggingPointIndex = null; });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < _zones.length; i++)
                CustomPaint(
                  size: size,
                  painter: PolygonEditorPainter(
                    normalizedPoints: _zones[i].points,
                    selectedIndex: (_draggingZoneIndex == i) ? _draggingPointIndex : null,
                    isCompleted: _zones[i].isCompleted && _activeZoneIndex != i,
                    label: _zones[i].label,
                  ),
                ),
            ],
          ),
        ),

        if (!_isRefreshing && !_isSaving && !_isLoading && hasCameras)
          Positioned(top: AppSpacing.md, right: AppSpacing.md, child: _OverlayButton(icon: Icons.refresh, label: '최신 화면', onTap: _refreshSnapshot)),

        if (_activeZoneIndex != null && !_isLoading)
          Positioned(top: AppSpacing.md, left: AppSpacing.md, child: _ActivePointsChip(count: _zones[_activeZoneIndex!].points.length)),

        if (!hasCameras && !_isLoading)
          const Center(child: EmptyStateView(icon: Icons.videocam_off_outlined, title: '연결된 카메라가 없어요', subtitle: '먼저 카메라를 등록해 주세요.', iconSize: 44)),

        if (_isRefreshing || _isSaving || _isLoading)
          _BlurOverlay(message: _isSaving ? '저장 중...' : _isLoading ? '불러오는 중...' : '새로고침 중...'),
      ],
    );
  }

  // ✅ HTML 기획안을 바탕으로 한 새로운 하단 컨트롤 패널
  Widget _buildBottomControls(List<dynamic> cameras) {
    final cs = Theme.of(context).colorScheme;
    final isActive = _activeZoneIndex != null;

    if (isActive) {
      final activeZone = _zones[_activeZoneIndex!];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 구역 이름 입력
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('구역 이름', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                onChanged: (val) => setState(() => activeZone.label = val),
                decoration: InputDecoration(
                  hintText: '예: 주방 가스레인지, 베란다',
                  filled: true,
                  fillColor: cs.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                ),
                controller: TextEditingController(text: activeZone.label)..selection = TextSelection.fromPosition(TextPosition(offset: activeZone.label.length)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. 위험 수위 버튼 (낮음, 중간, 높음)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('위험 수위', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _buildLevelBtn(0, '낮음', Colors.green, activeZone),
                  const SizedBox(width: AppSpacing.sm),
                  _buildLevelBtn(1, '중간', Colors.orange, activeZone),
                  const SizedBox(width: AppSpacing.sm),
                  _buildLevelBtn(2, '높음', AppColors.danger, activeZone),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. 토글 버튼들 (그리기 완료/되돌리기, 객체 감지)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(color: cs.surfaceContainerLowest, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(backgroundColor: cs.surfaceContainerHigh, radius: 18, child: const Icon(Icons.view_in_ar, size: 18)),
                    const SizedBox(width: AppSpacing.md),
                    const Text('객체 감지', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                Switch(
                  value: activeZone.objectDetectionEnabled,
                  onChanged: (val) => setState(() => activeZone.objectDetectionEnabled = val),
                  activeColor: AppColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 4. 액션 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('점 지우기'),
                  onPressed: _undoLastPoint,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('이 구역 완성'),
                  onPressed: activeZone.isCompleted ? _finishCurrentZone : null,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 기본 리스트 모드
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_zones.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm, runSpacing: AppSpacing.sm,
            children: List.generate(_zones.length, (i) => _ZoneEditChip(
              label: _zones[i].label, pointCount: _zones[i].points.length,
              onTap: () => _editZone(i), onDelete: () => _removeZone(i),
            )),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add), label: const Text('구역 추가'),
                onPressed: _isSaving || cameras.isEmpty ? null : _startNewZone,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                icon: const Icon(Icons.save), label: const Text('서버에 저장'),
                onPressed: (_isSaving || cameras.isEmpty) ? null : () => _saveZones(cameras[_selectedCameraIndex].id),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 위험 수위 선택 버튼 위젯
  Widget _buildLevelBtn(int level, String text, Color color, _EditableZone zone) {
    final isSelected = zone.dangerLevel == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => zone.dangerLevel = level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border.all(color: isSelected ? color : Theme.of(context).colorScheme.outlineVariant, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 4, backgroundColor: color),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(Offset local) {
    final hit = _findHandleAt(local);
    if (hit != null) return;
    if (_activeZoneIndex != null) {
      final n = _toNormalized(local);
      if (n != null) setState(() => _zones[_activeZoneIndex!].points.add(n));
    }
  }

  void _handlePanStart(Offset local) {
    final hit = _findHandleAt(local);
    if (hit != null) setState(() { _draggingZoneIndex = hit.zoneIdx; _draggingPointIndex = hit.pointIdx; });
  }

  void _handlePanUpdate(Offset local) {
    if (_draggingZoneIndex == null || _draggingPointIndex == null) return;
    final n = _toNormalized(local);
    if (n != null) setState(() => _zones[_draggingZoneIndex!].points[_draggingPointIndex!] = n);
  }
}

// (이하 _CameraTab, _OverlayButton, _ActivePointsChip, _ZoneEditChip, _BlurOverlay 위젯은 이전 코드와 완벽히 동일하므로 생략 없이 기존 코드 하단에 그대로 유지하시면 됩니다.)
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