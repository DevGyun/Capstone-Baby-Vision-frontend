import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/log_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/empty_state_view.dart';
import 'incident_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  /// 선택 모드 켜졌는지
  bool _selectionMode = false;

  /// 선택된 알림 ID들
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LogProvider>().fetchAlerts();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

void _toggleSelection(int id) {
  setState(() {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    if (_selectedIds.isEmpty) _selectionMode = false;
  });
}

  void _enterSelectionMode(int initialId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<IncidentLog> logs) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(logs.map((l) => l.id));
    });
  }

Future<void> _deleteSelected() async {
  final count = _selectedIds.length;
  final confirmed = await _showConfirmDialog(
    title: '선택한 $count개 삭제',
    message: '선택하신 알림이 영구 삭제돼요.\n복구할 수 없어요.',
    confirmLabel: '삭제',
  );
  if (!confirmed || !mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final ids = _selectedIds.toList();

  // ▼ 수정: API 호출 전에 미리 선택 모드 종료.
  //   - 사용자 입장에선 즉시 반응 (낙관적 UI와 결이 맞음)
  //   - await 중 rebuild로 카운트가 어긋나는 문제 차단
  setState(() {
    _selectionMode = false;
    _selectedIds.clear();
  });

  final deleted = await context.read<LogProvider>().deleteAlerts(ids);

  if (!mounted) return;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        deleted > 0
            ? '$deleted개의 알림이 삭제됐어요'
            : '삭제에 실패했어요. 다시 시도해 주세요',
      ),
    ),
  );
}

  Future<void> _deleteAll() async {
    final confirmed = await _showConfirmDialog(
      title: '모든 알림 삭제',
      message: '저장된 모든 알림 기록이 영구 삭제돼요.\n복구할 수 없어요.',
      confirmLabel: '전체 삭제',
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<LogProvider>().clearAllAlerts();

    if (!mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? '모든 알림이 삭제됐어요' : '삭제에 실패했어요. 다시 시도해 주세요',
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
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
                      color: AppColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                      size: 26,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(confirmLabel),
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
    return result ?? false;
  }

  @override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final logProvider = context.watch<LogProvider>();
  final logs = logProvider.logs;
  final isLoading = logProvider.isLoading;

  // ▼ 추가: _selectedIds를 항상 현재 보이는 logs와 동기화.
  // 유령 ID(이미 삭제됐거나 폴링으로 사라진 ID)를 자동 정리해
  // "N개 선택됨" 카운트가 실제 화면과 어긋나지 않게 함.
  if (_selectedIds.isNotEmpty) {
    final visibleIds = logs.map((l) => l.id).toSet();
    final hadGhosts = _selectedIds.any((id) => !visibleIds.contains(id));
    if (hadGhosts) {
      _selectedIds.removeWhere((id) => !visibleIds.contains(id));
      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    }
  }

  final allSelected =
      logs.isNotEmpty && _selectedIds.length == logs.length;
  // ... (이하 동일)

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
                tooltip: '선택 취소',
              )
            : null,
        title: Text(
          _selectionMode
              ? '${_selectedIds.length}개 선택됨'
              : '사건 로그 내역',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: _selectionMode
            ? [
                IconButton(
                  icon: Icon(
                    allSelected ? Icons.deselect : Icons.select_all,
                  ),
                  onPressed: () {
                    if (allSelected) {
                      setState(() => _selectedIds.clear());
                    } else {
                      _selectAll(logs);
                    }
                  },
                  tooltip: allSelected ? '전체 해제' : '전체 선택',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                  onPressed:
                      _selectedIds.isEmpty ? null : _deleteSelected,
                  tooltip: '선택 삭제',
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: isLoading
                      ? null
                      : () => context.read<LogProvider>().fetchAlerts(),
                ),
                if (logs.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'select') {
                        setState(() {
                          _selectionMode = true;
                        });
                      } else if (value == 'clear_all') {
                        _deleteAll();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'select',
                        child: Row(
                          children: [
                            Icon(Icons.checklist, size: 18),
                            SizedBox(width: 12),
                            Text('선택'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'clear_all',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep_outlined,
                                size: 18, color: AppColors.danger),
                            SizedBox(width: 12),
                            Text('전체 삭제',
                                style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => context.read<LogProvider>().fetchAlerts(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: 120 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_selectionMode) ...[
                Text(
                  '우리 아이 안심 로그',
                  style: Theme.of(context).textTheme.displayLarge ??
                      const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (isLoading && logs.isEmpty)
                Column(
                  children: List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildSkeletonCard(),
                    ),
                  ),
                )
              else if (logs.isEmpty)
                const SizedBox(
                  width: double.infinity,
                  child: EmptyStateView(
                    icon: Icons.history_rounded,
                    title: '아직 감지된 이벤트가 없어요',
                    subtitle: '안전하게 모니터링 중입니다.',
                  ),
                )
              else
                Column(
                  children: logs
                      .map((log) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _buildLogCard(context, log),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + (_pulseController.value * 0.5),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(height: 14, width: 80, color: baseColor),
                const SizedBox(height: AppSpacing.sm),
                Container(height: 20, width: 200, color: baseColor),
                const SizedBox(height: AppSpacing.sm),
                Container(height: 14, width: 150, color: baseColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogCard(BuildContext context, IncidentLog log) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedIds.contains(log.id);

    return GestureDetector(
      onTap: () {
        if (_selectionMode) {
          _toggleSelection(log.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncidentDetailsScreen(log: log),
            ),
          );
        }
      },
      onLongPress: () {
        if (!_selectionMode) {
          _enterSelectionMode(log.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: AppShadows.card(context),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.asset(
                    log.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: log.iconColor,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(log.icon, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          log.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!log.isRead && !_selectionMode)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // 선택 모드 체크박스
                if (_selectionMode)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              log.title,
              style: TextStyle(
                  color: log.iconColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              log.description,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              log.time,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
