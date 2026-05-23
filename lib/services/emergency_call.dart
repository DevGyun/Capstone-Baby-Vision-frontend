import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// 119 등 긴급 번호로 전화 걸기.
///
/// 기기 기본 전화 앱을 열어 번호가 입력된 상태로 전환.
/// 전화 기능이 없는 기기(태블릿 등)에선 안내 SnackBar 표시.
class EmergencyCall {
  EmergencyCall._();

  static Future<void> dial(
    BuildContext context, {
    String number = '119',
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: number);

    try {
      final canCall = await canLaunchUrl(uri);
      if (!canCall) {
        _showError(messenger);
        return;
      }
      await launchUrl(uri);
    } catch (e) {
      debugPrint('긴급 전화 실패: $e');
      _showError(messenger);
    }
    /// 확인 다이얼로그를 거쳐 전화 걸기. 오발신 방지용.
  static Future<void> confirmAndDial(
    BuildContext context, {
    String number = '119',
  }) async {
    final confirmed = await showDialog<bool>(
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
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.phone_in_talk,
                        color: AppColors.danger, size: 28),
                  ),
                ),
                Text(
                  '$number에 전화할까요?',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '기기의 전화 앱이 열려요.\n실제로 전화가 연결됩니다.',
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
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text('$number 전화'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
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

    if (confirmed == true && context.mounted) {
      await dial(context, number: number);
    }
  }
  }

  static void _showError(ScaffoldMessengerState messenger) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.error_outline, color: AppColors.danger, size: 18),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('이 기기에서는 전화 기능을 지원하지 않아요'),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}