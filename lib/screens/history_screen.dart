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

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logProvider = context.watch<LogProvider>();
    final logs = logProvider.logs;
    final isLoading = logProvider.isLoading;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('사건 로그 내역', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : () => context.read<LogProvider>().fetchAlerts(),
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
              Text('우리 아이 안심 로그', style: Theme.of(context).textTheme.displayLarge ?? const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.lg),

              if (isLoading && logs.isEmpty)
                Column(
                  children: List.generate(3, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _buildSkeletonCard(),
                  )),
                )
              else if (logs.isEmpty)
                // ✅ 이 부분을 수정했습니다: SizedBox로 감싸 가로 전체 공간을 확보합니다.
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
                  children: logs.map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _buildLogCard(context, log),
                  )).toList(),
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
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(AppRadius.lg)),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 160, width: double.infinity, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(AppRadius.md))),
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => IncidentDetailsScreen(log: log)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
                  child: Image.asset(log.imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: AppSpacing.sm, left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: log.iconColor, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Row(
                      children: [
                        Icon(log.icon, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(log.title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                if (!log.isRead)
                  Positioned(
                    top: AppSpacing.sm, right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(log.title, style: TextStyle(color: log.iconColor, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(log.description, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(log.time, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}