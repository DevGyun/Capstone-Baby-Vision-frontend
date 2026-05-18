import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../providers/camera_provider.dart';
import '../services/api_client.dart';
import '../services/camera_snapshot_storage.dart';
import '../services/zone_settings_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/common/common.dart';
import '../widgets/hls_player.dart';
import '../widgets/polygon_painter.dart';

/// 백엔드 위험구역 모델.
class ZoneModel {
  final int id;
  final String label;
  final List<Offset> zonePoints;

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

class _EditableZone {
  int? serverId;
  String label;
  List<Offset> points;

  int dangerLevel;
  bool objectDetectionEnabled;

  String? _originalLabel;
  List<Offset>? _originalPoints;

  _EditableZone({
    this.serverId,
    required this.label,
    required this.points,
    this.dangerLevel = 2,
    this.objectDetectionEnabled = true,
  });

  bool get isCompleted => points.length >= 3;

  List<List<double>> toZonePoints() {
    return points.map((p) => [p.dx, p.dy]).toList();
  }

  void markAsClean() {
    _originalLabel = label;
    _originalPoints = List<Offset>.from(points);
  }

  bool get isDirty {
    if (serverId == null) return false;
    if (_originalLabel == null) return true;
    if (_originalLabel != label) return true;
    if (_originalPoints == null) return true;
    if (_originalPoints!.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (_originalPoints![i] != points[i]) return true;
    }
    return false;
  }
}

/// 배경 모드
/// - cached: 저장된 스냅샷 이미지 사용
/// - liveCapturing: 라이브 영상 띄우고 캡처 대기
/// - placeholder: 스냅샷 없음 + 라이브도 못 띄움
enum _BackgroundMode { cached, liveCapturing, placeholder }

class ZoneScreen extends StatefulWidget {
  const ZoneScreen({super.key});

  @override
  State<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends State<ZoneScreen> with WidgetsBindingObserver {
  int _selectedCameraIndex = 0;
  int? _currentLoadedCameraId;
  Size? _canvasSize;
  final List<_EditableZone> _zones = [];
  final List<int> _pendingDeleteIds = [];
  final TextEditingController _labelController = TextEditingController();
  int? _activeZoneIndex;
  int? _draggingZoneIndex;
  int? _draggingPointIndex;
  bool _isLoading = false;
  bool _isSaving = false;

  // ── 배경 캡처 관련 ────────────────────────────────────
  File? _cachedSnapshot; // 캐시된 정적 이미지
  _BackgroundMode _bgMode = _BackgroundMode.placeholder;
  bool _captureScheduled = false; // 라이브 연결 후 자동 캡처 예약 여부
  final GlobalKey _liveCaptureKey = GlobalKey(); // 라이브 영상 캡처용

  bool get _hasUnsavedChanges {
    if (_pendingDeleteIds.isNotEmpty) return true;
    for (final z in _zones) {
      if (z.serverId == null) return true;
      if (z.isDirty) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _labelController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      final cameras = context.read<CameraProvider>().cameras;
      if (cameras.isNotEmpty && _currentLoadedCameraId != null) {
        final safeIdx = _selectedCameraIndex.clamp(0, cameras.length - 1);
        _loadZones(cameras[safeIdx].id);
      }
    }
  }

  static const double _handleHitRadius = 24;

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

  // ─────────────────────────────────────────────
  //   스냅샷 캐시 + 위험구역 로드
  // ─────────────────────────────────────────────
  Future<void> _loadZones(int cameraId) async {
    if (_canvasSize == null) return;
    setState(() {
      _isLoading = true;
      _zones.clear();
      _pendingDeleteIds.clear();
      _activeZoneIndex = null;
      _cachedSnapshot = null;
      _captureScheduled = false;
    });

    try {
      // 1) 캐시된 배경 스냅샷 확인
      final cached = await CameraSnapshotStorage.load(cameraId);

      // 2) 위험구역 + 로컬 설정
      final localSettings = await ZoneSettingsStorage.loadAll();
      final response =
          await ApiClient.request('GET', '/danger-zones/$cameraId');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final loaded = data
            .map((e) => ZoneModel.fromJson(e as Map<String, dynamic>))
            .map((m) {
          final local = localSettings[m.id] ?? const ZoneLocalSettings();
          final z = _EditableZone(
            serverId: m.id,
            label: m.label,
            points: m.zonePoints,
            dangerLevel: local.dangerLevel,
            objectDetectionEnabled: local.objectDetection,
          );
          z.markAsClean();
          return z;
        }).toList();

        setState(() {
          _zones.addAll(loaded);
          _currentLoadedCameraId = cameraId;
          _isLoading = false;
          _cachedSnapshot = cached;
          // 캐시 있으면 정적 배경, 없으면 라이브 띄워서 캡처 모드
          _bgMode = cached != null
              ? _BackgroundMode.cached
              : _BackgroundMode.liveCapturing;
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

  // ─────────────────────────────────────────────
  //   배경 캡처 (라이브 영상 → 정적 이미지)
  // ─────────────────────────────────────────────

  /// 라이브 영상이 연결되면 자동으로 한 프레임 캡처.
  /// HlsPlayer의 onConnected 콜백에서 호출됨.
  void _onLiveConnected() {
    if (_captureScheduled || _bgMode != _BackgroundMode.liveCapturing) return;
    _captureScheduled = true;

    // 영상이 안정적으로 디코딩될 때까지 살짝 대기 후 캡처
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      await _captureLiveFrameToCache();
    });
  }

  /// 라이브 영상을 캡처해 캐시 폴더에 저장
  Future<void> _captureLiveFrameToCache() async {
    final cameras = context.read<CameraProvider>().cameras;
    if (cameras.isEmpty || _currentLoadedCameraId == null) return;

    try {
      final boundary = _liveCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final dpr = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: dpr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      await CameraSnapshotStorage.save(_currentLoadedCameraId!, pngBytes);

      // 캐시 모드로 전환
      final cached = await CameraSnapshotStorage.load(_currentLoadedCameraId!);
      if (!mounted) return;
      setState(() {
        _cachedSnapshot = cached;
        _bgMode = _BackgroundMode.cached;
        _captureScheduled = false;
      });
    } catch (e) {
      debugPrint('배경 캡처 실패: $e');
      if (mounted) {
        setState(() {
          _bgMode = _BackgroundMode.placeholder;
          _captureScheduled = false;
        });
      }
    }
  }

  /// 사용자가 "배경 새로고침" 누르면 라이브 영상 다시 띄움
  void _refreshBackground() {
    if (_currentLoadedCameraId == null) return;
    setState(() {
      _cachedSnapshot = null;
      _bgMode = _BackgroundMode.liveCapturing;
      _captureScheduled = false;
    });
  }

  // ─────────────────────────────────────────────
  //   저장 (기존과 동일)
  // ─────────────────────────────────────────────
  Future<void> _saveZones(int cameraId) async {
    if (_isSaving) return;

    final incomplete = _zones.where((z) => !z.isCompleted).toList();
    if (incomplete.isNotEmpty) {
      _showSnack('점이 3개 미만인 미완성 구역이 있어요', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      bool anyFailed = false;
      String? failReason;

      for (final id in _pendingDeleteIds) {
        try {
          final r = await ApiClient.request('DELETE', '/danger-zones/$id');
          if (r.statusCode != 200 && r.statusCode != 204) {
            anyFailed = true;
            failReason = '구역 삭제 실패 (${r.statusCode})';
          }
        } catch (e) {
          anyFailed = true;
          failReason = '구역 삭제 중 네트워크 오류';
        }
      }

      for (var i = 0; i < _zones.length; i++) {
        final zone = _zones[i];
        final labelToSave =
            zone.label.isEmpty ? '위험 구역 ${i + 1}' : zone.label;

        try {
          if (zone.serverId == null) {
            final r = await ApiClient.request(
              'POST',
              '/danger-zones',
              body: {
                'camera_id': cameraId,
                'label': labelToSave,
                'zone_points': zone.toZonePoints(),
              },
            );
            if (r.statusCode == 200 || r.statusCode == 201) {
              final newId = jsonDecode(r.body)['id'] as int;
              zone.serverId = newId;
              zone.label = labelToSave;
              zone.markAsClean();
              await ZoneSettingsStorage.save(
                newId,
                ZoneLocalSettings(
                  dangerLevel: zone.dangerLevel,
                  objectDetection: zone.objectDetectionEnabled,
                ),
              );
            } else {
              anyFailed = true;
              failReason = '구역 생성 실패 (${r.statusCode})';
            }
          } else if (zone.isDirty) {
            final r = await ApiClient.request(
              'PUT',
              '/danger-zones/${zone.serverId}',
              body: {
                'label': labelToSave,
                'zone_points': zone.toZonePoints(),
              },
            );
            if (r.statusCode == 200) {
              zone.label = labelToSave;
              zone.markAsClean();
            } else {
              anyFailed = true;
              failReason = '구역 수정 실패 (${r.statusCode})';
            }
          }

          if (zone.serverId != null) {
            await ZoneSettingsStorage.save(
              zone.serverId!,
              ZoneLocalSettings(
                dangerLevel: zone.dangerLevel,
                objectDetection: zone.objectDetectionEnabled,
              ),
            );
          }
        } catch (e) {
          anyFailed = true;
          failReason = '저장 중 네트워크 오류';
        }
      }

      setState(() {
        _pendingDeleteIds.clear();
        _isSaving = false;
        _activeZoneIndex = null;
      });

      if (anyFailed) {
        _showSnack(failReason ?? '일부 저장에 실패했어요', isError: true);
      } else {
        _showSnack('위험구역이 안전하게 저장되었어요', isError: false);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnack('저장에 실패했어요', isError: true);
    }
  }

  // ─────────────────────────────────────────────
  //   편집 동작 (기존과 동일)
  // ─────────────────────────────────────────────
  void _startNewZone() {
    setState(() {
      _zones.add(
          _EditableZone(label: '위험 구역 ${_zones.length + 1}', points: []));
      _activeZoneIndex = _zones.length - 1;
      _labelController.text = _zones[_activeZoneIndex!].label;
    });
  }

  void _editZone(int index) {
    setState(() {
      _activeZoneIndex = index;
      _labelController.text = _zones[index].label;
    });
  }

  void _finishCurrentZone() {
    final idx = _activeZoneIndex;
    if (idx == null) return;
    if (!_zones[idx].isCompleted) {
      _showSnack('구역을 완성하려면 최소 3개의 점이 필요합니다.', isError: true);
      return;
    }
    setState(() => _activeZoneIndex = null);
  }

  void _undoLastPoint() {
    final idx = _activeZoneIndex;
    if (idx == null) return;
    if (_zones[idx].points.isEmpty) {
      setState(() {
        _zones.removeAt(idx);
        _activeZoneIndex = null;
      });
      return;
    }
    setState(() => _zones[idx].points.removeLast());
  }

  void _removeZone(int index) {
    setState(() {
      final removed = _zones.removeAt(index);
      if (removed.serverId != null) {
        _pendingDeleteIds.add(removed.serverId!);
        ZoneSettingsStorage.remove(removed.serverId!);
      }
      if (_activeZoneIndex == index) {
        _activeZoneIndex = null;
      } else if (_activeZoneIndex != null && _activeZoneIndex! > index) {
        _activeZoneIndex = _activeZoneIndex! - 1;
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final z in _zones) {
        if (z.serverId != null) {
          _pendingDeleteIds.add(z.serverId!);
          ZoneSettingsStorage.remove(z.serverId!);
        }
      }
      _zones.clear();
      _activeZoneIndex = null;
    });
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppColors.danger : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    ));
  }

  // ─────────────────────────────────────────────
  //   build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cameras = context.watch<CameraProvider>().cameras;

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
        children: [
          if (cameras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
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
                    final newSize =
                        Size(constraints.maxWidth, constraints.maxHeight);
                    if (_canvasSize != newSize) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _canvasSize = newSize);
                      });
                    }
                    final activeCam = cameras.isNotEmpty
                        ? cameras[_selectedCameraIndex.clamp(
                            0, cameras.length - 1)]
                        : null;
                    return _buildCanvas(newSize, cameras.isNotEmpty, activeCam);
                  },
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: _buildBottomControls(cameras),
          ),
          SizedBox(height: 60 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildCanvas(Size size, bool hasCameras, CameraModel? activeCamera) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 배경 ──
        _buildBackground(activeCamera),

        // 어두운 오버레이 — 위험구역 색이 더 잘 보이게
        Container(color: Colors.black.withValues(alpha:0.35)),

        // ── 위험구역 그리기 영역 ──
        GestureDetector(
          onTapDown: _isSaving || _isLoading
              ? null
              : (details) => _handleTap(details.localPosition),
          onPanStart: _isSaving || _isLoading
              ? null
              : (details) => _handlePanStart(details.localPosition),
          onPanUpdate: _isSaving || _isLoading
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
                    selectedIndex: (_draggingZoneIndex == i)
                        ? _draggingPointIndex
                        : null,
                    isCompleted:
                        _zones[i].isCompleted && _activeZoneIndex != i,
                    label: _zones[i].label,
                  ),
                ),
            ],
          ),
        ),

        // ── 상단 우측 배경 새로고침 버튼 ──
        if (!_isSaving &&
            !_isLoading &&
            hasCameras &&
            _bgMode == _BackgroundMode.cached)
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: _OverlayButton(
              icon: Icons.refresh,
              label: '배경 새로고침',
              onTap: _refreshBackground,
            ),
          ),

        // ── 라이브 캡처 중 배너 ──
        if (_bgMode == _BackgroundMode.liveCapturing &&
            hasCameras &&
            !_isLoading)
          Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: _CapturingBanner(),
          ),

        // ── 점 개수 표시 ──
        if (_activeZoneIndex != null && !_isLoading)
          Positioned(
            top: AppSpacing.md + 56,
            left: AppSpacing.md,
            child: _ActivePointsChip(
                count: _zones[_activeZoneIndex!].points.length),
          ),

        // ── 카메라 없음 ──
        if (!hasCameras && !_isLoading)
          const Center(
            child: EmptyStateView(
              icon: Icons.videocam_off_outlined,
              title: '연결된 카메라가 없어요',
              subtitle: '먼저 카메라를 등록해 주세요.',
              iconSize: 44,
            ),
          ),

        // ── 로딩/저장 오버레이 ──
        if (_isSaving || _isLoading)
          _BlurOverlay(message: _isSaving ? '저장 중...' : '불러오는 중...'),
      ],
    );
  }

  /// 배경 모드별 위젯 분기
  Widget _buildBackground(CameraModel? activeCamera) {
    switch (_bgMode) {
      case _BackgroundMode.cached:
        if (_cachedSnapshot != null) {
          return Image.file(
            _cachedSnapshot!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
        return Container(color: Colors.black);

      case _BackgroundMode.liveCapturing:
        if (activeCamera == null || activeCamera.hlsUrl.isEmpty) {
          return Container(color: Colors.black);
        }
        return RepaintBoundary(
          key: _liveCaptureKey,
          child: HlsPlayer(
            key: ValueKey('zone-live-${activeCamera.id}'),
            streamUrl: activeCamera.hlsUrl,
            onConnected: _onLiveConnected,
          ),
        );

      case _BackgroundMode.placeholder:
        return Container(color: Colors.black);
    }
  }

  Widget _buildBottomControls(List<dynamic> cameras) {
    final cs = Theme.of(context).colorScheme;
    final isActive = _activeZoneIndex != null;

    if (isActive) {
      final activeZone = _zones[_activeZoneIndex!];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '구역 이름',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _labelController,
                onChanged: (val) {
                  activeZone.label = val;
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: '예: 주방 가스레인지, 베란다',
                  filled: true,
                  fillColor: cs.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '위험 수위',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.surfaceContainerHigh,
                      radius: 18,
                      child: const Icon(Icons.view_in_ar, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const Text('객체 감지',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                Switch(
                  value: activeZone.objectDetectionEnabled,
                  onChanged: (val) async {
                    setState(() => activeZone.objectDetectionEnabled = val);
                    if (activeZone.serverId != null) {
                      await ZoneSettingsStorage.save(
                        activeZone.serverId!,
                        ZoneLocalSettings(
                          dangerLevel: activeZone.dangerLevel,
                          objectDetection: activeZone.objectDetectionEnabled,
                        ),
                      );
                    }
                  },
                  activeThumbColor: AppColors.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('점 지우기'),
                  onPressed: _undoLastPoint,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('이 구역 완성'),
                  onPressed:
                      activeZone.isCompleted ? _finishCurrentZone : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_zones.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('전체 지우기'),
              onPressed: _isSaving ? null : _clearAll,
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List.generate(
              _zones.length,
              (i) => _ZoneEditChip(
                label: _zones[i].label,
                pointCount: _zones[i].points.length,
                onTap: () => _editZone(i),
                onDelete: () => _removeZone(i),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('구역 추가'),
                onPressed: _isSaving || cameras.isEmpty ? null : _startNewZone,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('서버에 저장'),
                onPressed: (_isSaving ||
                        cameras.isEmpty ||
                        !_hasUnsavedChanges)
                    ? null
                    : () => _saveZones(cameras[_selectedCameraIndex].id),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelBtn(
      int level, String text, Color color, _EditableZone zone) {
    final isSelected = zone.dangerLevel == level;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() => zone.dangerLevel = level);
          if (zone.serverId != null) {
            await ZoneSettingsStorage.save(
              zone.serverId!,
              ZoneLocalSettings(
                dangerLevel: zone.dangerLevel,
                objectDetection: zone.objectDetectionEnabled,
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha:0.1)
                : Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border.all(
              color: isSelected
                  ? color
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 4, backgroundColor: color),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
    if (n != null) {
      setState(() =>
          _zones[_draggingZoneIndex!].points[_draggingPointIndex!] = n);
    }
  }
}

// ════════════════════════════════════════════════════════════════
//   서브 위젯
// ════════════════════════════════════════════════════════════════

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
          color: isSelected ? AppColors.accent : cs.surfaceContainerLow,
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
            color: Colors.black.withValues(alpha:0.5),
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

/// 라이브 캡처 중 안내 배너
class _CapturingBanner extends StatelessWidget {
  const _CapturingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: AppColors.accent.withValues(alpha:0.5), width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '카메라 화면을 가져오는 중이에요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '잠시 후 이 화면 위에 위험구역을 그릴 수 있어요',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: AppColors.warning.withValues(alpha:isDark ? 0.16 : 0.10),
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
                      color: AppColors.warning.withValues(alpha:0.7),
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
      color: Colors.black.withValues(alpha:0.7),
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