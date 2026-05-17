// 1. Dart & Flutter Core
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

// 2. Third-party
import 'package:provider/provider.dart';

// 3. Providers
import '../providers/camera_provider.dart';
import '../providers/log_provider.dart';
import '../providers/settings_provider.dart';

// 4. Services
import '../services/notification_service.dart';

// 5. Screens
import 'add_camera_screen.dart';
import 'history_screen.dart';
import 'incident_details_screen.dart';
import 'live_stream_screen.dart';
import 'settings_screen.dart';
import 'zone_screen.dart';

// 6. Theme & widgets
import '../theme/app_theme.dart';
import '../widgets/common/common.dart';
import '../widgets/common/initial_avatar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _selectedCameraIndex = 0;

  /// 자동 폴링 (30초마다 알림 + 카메라 연결 상태).
  Timer? _pollingTimer;

@override
void initState() {
  super.initState();

  // 라이프사이클 감지 등록
  WidgetsBinding.instance.addObserver(this);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    context.read<CameraProvider>().fetchCameras();
    context.read<LogProvider>().fetchAlerts();
  });

  _startPolling();
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _stopPolling();
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);

  switch (state) {
    case AppLifecycleState.resumed:
      // 포그라운드 복귀 — 한 번 즉시 갱신 + 폴링 재개
      if (mounted) {
        context.read<CameraProvider>().fetchCameras();
        context.read<LogProvider>().fetchAlerts();
      }
      _startPolling();
      break;
    case AppLifecycleState.paused:
    case AppLifecycleState.inactive:
    case AppLifecycleState.detached:
    case AppLifecycleState.hidden:
      // 백그라운드 / 화면 꺼짐 — 폴링 중단해서 데이터 절약
      _stopPolling();
      break;
  }
}

void _startPolling() {
  _pollingTimer?.cancel();

  // 폴링 시작 시점에 푸시 활성화 상태 동기화
  _syncPushEnabled();

  _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    if (!mounted) return;
    _syncPushEnabled(); // 매 폴링마다 최신 설정 반영
    context.read<LogProvider>().fetchAlerts();
    context.read<CameraProvider>().fetchCameras();
  });
}

/// SettingsProvider의 isAlertOn을 LogProvider에 전달
void _syncPushEnabled() {
  if (!mounted) return;
  final alertOn = context.read<SettingsProvider>().isAlertOn;
  context.read<LogProvider>().pushEnabled = alertOn;
}

void _stopPolling() {
  _pollingTimer?.cancel();
  _pollingTimer = null;
}

void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  /// 페어링 직후 환영 SnackBar — Provider의 justPairedCameraName 감지.
  void _maybeShowJustPairedSnack() {
    final cameraProvider = context.read<CameraProvider>();
    final justPaired = cameraProvider.justPairedCameraName;
    if (justPaired == null) return;

    cameraProvider.consumeJustPairedCameraName();

    // 새로 등록한 카메라를 자동으로 선택해서 보여주기
    final newIdx =
        cameraProvider.cameras.indexWhere((c) => c.name == justPaired);
    if (newIdx != -1 && mounted) {
      setState(() => _selectedCameraIndex = newIdx);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '"$justPaired" 카메라가 연결되었어요',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //   카메라 삭제 확인 다이얼로그
  // ─────────────────────────────────────────────────────────────
  void _showDeleteConfirmation(
      BuildContext context, int cameraId, String cameraName) {
    showDialog(
      context: context,
      builder: (childContext) {
        final cs = Theme.of(childContext).colorScheme;
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 26,
                    ),
                  ),
                ),
                Text(
                  '카메라 제거',
                  style: Theme.of(childContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '"$cameraName" 카메라를 제거하면 연결된\n위험구역과 알림 설정이 모두 사라져요.',
                  style: Theme.of(childContext).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: SoftButton(
                        label: '취소',
                        variant: SoftButtonVariant.tonal,
                        onPressed: () => Navigator.pop(childContext),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: SoftButton(
                        label: '제거',
                        icon: Icons.delete_outline,
                        variant: SoftButtonVariant.danger,
                        onPressed: () async {
                          Navigator.pop(childContext);
                          final success = await context
                              .read<CameraProvider>()
                              .removeCamera(cameraId);
                          if (!mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('카메라가 제거되었어요'),
                              ),
                            );
                            setState(() => _selectedCameraIndex = 0);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('제거에 실패했어요. 다시 시도해 주세요'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  //   루트 빌드
  // ─────────────────────────────────────────────────────────────
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  // 시스템 네비게이션 바 영역 (Android 제스처/3버튼)
  final bottomInset = MediaQuery.of(context).padding.bottom;

  final justPaired = context.watch<CameraProvider>().justPairedCameraName;
  if (justPaired != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeShowJustPairedSnack();
    });
  }

  return Scaffold(
    backgroundColor: Colors.black,
    // ✨ resizeToAvoidBottomInset: 키보드 올라올 때 자동 스크롤
    resizeToAvoidBottomInset: true,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          color: cs.surface,
          child: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildMonitoringView(),
                  const ZoneScreen(),
                  const HistoryScreen(),
                  const SettingsScreen(),
                ],
              ),
              // 테스트 알림 FAB — 시스템 네비를 피해서 위로 올림
              Positioned(
                bottom: 110 + bottomInset,
                right: AppSpacing.lg,
                child: _buildTestNotificationFab(),
              ),
              // 플로팅 네비 — 시스템 네비를 피해서 위로 올림
              Positioned(
                bottom: AppSpacing.lg + bottomInset,
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                child: _buildFloatingNavBar(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  Widget _buildMonitoringView() {
    final cameras = context.watch<CameraProvider>().cameras;

    if (cameras.isEmpty) {
      return _buildNoCameraDashboard();
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          await context.read<CameraProvider>().fetchCameras();
          await context.read<LogProvider>().fetchAlerts();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.sm,
  AppSpacing.lg,
  120 + MediaQuery.of(context).padding.bottom,
),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(),
              const SizedBox(height: AppSpacing.lg),
              _buildLiveSection(),
              const SizedBox(height: AppSpacing.md - 4),
              _buildThumbnailsRow(),
              const SizedBox(height: AppSpacing.lg),
              _buildStatsCards(),
              const SizedBox(height: AppSpacing.md),
              _buildRecentLogsPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoCameraDashboard() {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.sm,
  AppSpacing.lg,
  120 + MediaQuery.of(context).padding.bottom,
),
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.06),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.videocam_off_outlined,
                          size: 64,
                          color: cs.outlineVariant,
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.dangerSoft(context),
                                  blurRadius: 10,
                                  spreadRadius: 5)
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: -16,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft(context),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.accentSoft(context),
                                  blurRadius: 8,
                                  spreadRadius: 4)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    '연결된 카메라가 없어요',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '아이의 안전을 실시간으로 확인하려면\n먼저 카메라를 등록해 주세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('가이드를 준비 중입니다.')),
                    );
                  },
                  icon: Icon(Icons.help_outline, size: 18, color: cs.outline),
                  label: Text(
                    '가이드 보기',
                    style: TextStyle(
                        color: cs.outline, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SoftButton(
                  label: '카메라 추가하기',
                  icon: Icons.add_circle,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddCameraScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final cs = Theme.of(context).colorScheme;
    final unreadCount =
        context.watch<LogProvider>().logs.where((l) => !l.isRead).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentSoft(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.visibility_rounded,
                color: AppColors.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Text(
              'Eye Catch',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedIndex = 2),
              behavior: HitTestBehavior.opaque,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: cs.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            GestureDetector(
  onTap: () => setState(() => _selectedIndex = 3),
  child: Selector<SettingsProvider, String>(
    selector: (_, s) => s.profileName,
    builder: (_, name, __) => InitialAvatar(name: name, radius: 16),
  ),
),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE SYSTEM',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '실시간 모니터링',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: SoftChip(
                label: 'REC LIVE',
                tone: SoftChipTone.dark,
                leadingDot: true,
                pulseDot: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildMainVideoCard(),
      ],
    );
  }

  Widget _buildMainVideoCard() {
    final cs = Theme.of(context).colorScheme;
    final cameras = context.watch<CameraProvider>().cameras;

    final safeIndex = _selectedCameraIndex.clamp(0, cameras.length - 1);
    final cam = cameras[safeIndex];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveStreamScreen(
            cameraId: cam.id.toString(),
            cameraName: cam.name,
            streamUrl: cam.hlsUrl,
          ),
        ),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: Colors.black,
            border: Border.all(color: cs.outlineVariant, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg - 0.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm + 2),
                      const Text(
                        '라이브 화면 보기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: cam.isActive
                      ? const SoftChip(
                          label: '위험구역 감지 켜짐',
                          tone: SoftChipTone.warning,
                          icon: Icons.warning_amber_rounded,
                        )
                      : const SoftChip(
                          label: '모니터링 일시중지',
                          tone: SoftChipTone.neutral,
                          icon: Icons.pause_circle_outline,
                        ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusDot(
                          kind: cam.isConnected
                              ? StatusDotKind.online
                              : StatusDotKind.offline,
                          size: 6,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cam.isConnected ? '온라인' : '오프라인',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 16, 6, 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cam.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 모니터링 토글
                        InkWell(
                          onTap: () async {
                            final newState = !cam.isActive;
                            final ok = await context
                                .read<CameraProvider>()
                                .setCameraActive(cam.id, newState);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? (newState ? '모니터링이 켜졌어요' : '모니터링이 꺼졌어요')
                                    : '변경에 실패했어요. 다시 시도해 주세요'),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              cam.isActive
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: cam.isActive
                                  ? Colors.white.withOpacity(0.85)
                                  : AppColors.warning,
                              size: 18,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showDeleteConfirmation(
                              context, cam.id, cam.name),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white.withOpacity(0.85),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailsRow() {
    final cameras = context.watch<CameraProvider>().cameras;

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          for (int i = 0; i < cameras.length; i++) ...[
            _buildThumbnailTile(
              cameras[i],
              isActive: _selectedCameraIndex == i,
              onTap: () => setState(() => _selectedCameraIndex = i),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
          ],
          _buildAddCameraTile(),
        ],
      ),
    );
  }

  Widget _buildThumbnailTile(
    CameraModel cam, {
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md - 2),
          border: Border.all(
            color: isActive ? AppColors.accent : cs.outlineVariant,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md - 4),
              child: Container(
                foregroundDecoration: BoxDecoration(
                  color: isActive
                      ? Colors.transparent
                      : Colors.black.withOpacity(0.45),
                ),
                child: Image.asset(
                  'assets/images/1babyscreen.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Text(
                cam.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: StatusDot(
                kind: cam.isConnected
                    ? StatusDotKind.online
                    : StatusDotKind.offline,
                size: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCameraTile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddCameraScreen()),
      ),
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: AppColors.accentSoft(context),
          borderRadius: BorderRadius.circular(AppRadius.md - 2),
          border: Border.all(
            color: AppColors.accent.withOpacity(0.4),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_rounded,
              color: AppColors.accent,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              '추가',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final cameras = context.watch<CameraProvider>().cameras;
    final logs = context.watch<LogProvider>().logs;

    final connected = cameras.where((c) => c.isConnected).length;
    final total = cameras.length;
    final unread = logs.where((l) => !l.isRead).length;
    final totalLogs = logs.length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.videocam_outlined,
            label: '연결된 카메라',
            value: total == 0 ? '0' : '$connected/$total',
            unit: '대',
            accentColor: AppColors.success,
            progress: total == 0 ? 0 : connected / total,
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: _StatCard(
            icon: Icons.notifications_none_rounded,
            label: '안 읽은 알림',
            value: '$unread',
            unit: '건',
            accentColor: AppColors.accent,
            progress:
                totalLogs == 0 ? 0 : (unread / totalLogs).clamp(0.0, 1.0),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentLogsPanel() {
    final cs = Theme.of(context).colorScheme;
    final logs = context.watch<LogProvider>().logs;
    final displayLogs = logs.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, 8, AppSpacing.sm + 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 알림',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (logs.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _selectedIndex = 2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '전체보기',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (displayLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 4, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      '아직 감지된 사건이 없어요',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...displayLogs.map((log) => _buildLogItem(log)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildLogItem(IncidentLog log) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => IncidentDetailsScreen(log: log)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: log.iconColor.withOpacity(isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(log.icon, color: log.iconColor, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: log.iconColor,
                              letterSpacing: -0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          log.time,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      log.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.8),
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!log.isRead) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg + 6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainer.withOpacity(0.85)
                : cs.surfaceContainerLow.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppRadius.lg + 6),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.5),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.videocam_outlined, '모니터링'),
              _buildNavItem(1, Icons.shield_outlined, '구역'),
              _buildNavItem(2, Icons.history_rounded, '내역'),
              _buildNavItem(3, Icons.settings_outlined, '설정'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? AppSpacing.md : AppSpacing.sm + 2,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentSoft(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.accent : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.accent : cs.onSurfaceVariant,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestNotificationFab() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await NotificationService().showTestNotification();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.notifications_active_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color accentColor;
  final double progress;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}