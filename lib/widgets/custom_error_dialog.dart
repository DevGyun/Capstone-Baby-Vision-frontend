import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common/common.dart';

/// 에러 다이얼로그. login 등에서 사용.
/// 다시 시도 버튼이 있으면 표시되고, 누르면 [onRetry] 실행.
class CustomErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const CustomErrorDialog({
    super.key,
    this.title = '문제가 생겼어요',
    required this.message,
    this.onRetry,
  });

  /// 어디서든 쉽게 호출 가능한 static 메서드.
  static void show(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
    String title = '문제가 생겼어요',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomErrorDialog(
        title: title,
        message: message,
        onRetry: onRetry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
            // 상단 위험 아이콘
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
            // 타이틀
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            // 메시지
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            // 버튼
            if (onRetry == null)
              SoftButton(
                label: '확인',
                variant: SoftButtonVariant.tonal,
                onPressed: () => Navigator.pop(context),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SoftButton(
                      label: '닫기',
                      variant: SoftButtonVariant.tonal,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: SoftButton(
                      label: '다시 시도',
                      icon: Icons.refresh,
                      onPressed: () {
                        Navigator.pop(context);
                        onRetry!();
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}