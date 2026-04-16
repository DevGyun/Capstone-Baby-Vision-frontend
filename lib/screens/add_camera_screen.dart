import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSubmitting = false;

  void _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 이름을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<CameraProvider>();
    // URL 매개변수 제거 및 이름만 전달
    final resultMessage = await provider.addCamera(name);

    setState(() => _isSubmitting = false);

    if (resultMessage == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 등록이 완료되었습니다.')),
      );
      Navigator.pop(context); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('새 카메라 추가', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '모니터링할 장소의\n이름을 입력해주세요.', // 텍스트 수정
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.3),
            ),
            const SizedBox(height: 32),
            
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '카메라 이름 (예: 거실, 아이방)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.videocam_outlined),
              ),
            ),
            // URL 입력 TextField 제거됨
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20, height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          ),
                          SizedBox(width: 12),
                          Text('서버 등록 중...', style: TextStyle(fontSize: 16, color: Colors.white))
                        ],
                      )
                    : const Text('카메라 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}