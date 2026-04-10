import 'package:flutter/material.dart';

class CustomErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const CustomErrorDialog({
    super.key,
    this.title = '오류 발생',
    required this.message,
    this.onRetry,
  });

  // 어디서든 쉽게 호출할 수 있는 static 메서드
  static void show(BuildContext context, String message, {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥을 눌러서 닫히지 않게 (명시적 선택 유도)
      builder: (context) => CustomErrorDialog(message: message, onRetry: onRetry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: Text(message, style: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기', style: TextStyle(color: Colors.grey)),
        ),
        if (onRetry != null)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // 알림창 닫기
              onRetry!(); // 전달받은 재시도 함수 실행
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('다시 시도', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
      ],
    );
  }
}