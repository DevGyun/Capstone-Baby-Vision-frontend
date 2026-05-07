import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'soft_button.dart';

/// 빈 상태 (카메라 0대, 알림 0건 등) 화면.
/// 시스템 메시지 톤이 아닌, 친근한 카피와 CTA 버튼.
///
/// 사용 예:
/// ```dart
/// EmptyStateView(
///   icon: Icons.videocam_off_outlined,
///   title: '아직 카메라가 없어요',
///   subtitle: '첫 카메라를 등록하고 아기를 지켜봐 주세요.',
///   actionLabel: '카메라 등록하기',
///   onAction: () => Navigator.push(...),
/// )
/// ```
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 패딩 조정. 작은 카드 안의 빈 상태인지, 화면 전체 빈 상태인지에 따라 다름.
  final EdgeInsetsGeometry padding;

  /// 아이콘 크기. 화면 전체이면 64+, 카드 안이면 36 정도.
  final double iconSize;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 아이콘 — 큰 원형 박스 안에 (테라코타 살짝 톤다운)
          Container(
            width: iconSize + AppSpacing.lg,
            height: iconSize + AppSpacing.lg,
            decoration: BoxDecoration(
              color: AppColors.accentSoft(context),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: iconSize * 0.55,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SoftButton(
              label: actionLabel!,
              icon: Icons.add,
              onPressed: onAction,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}
