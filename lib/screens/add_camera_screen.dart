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
  // 💡 1. RTSP 주소를 입력받을 컨트롤러 추가
  final TextEditingController _urlController = TextEditingController(); 
  bool _isSubmitting = false;

  void _submit() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    // 💡 2. 이름과 주소를 모두 입력했는지 검사하도록 수정
    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 이름과 주소를 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<CameraProvider>();
    // 💡 3. Provider로 name과 url을 같이 넘겨주도록 수정
    final success = await provider.addCamera(name, url);

    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라가 성공적으로 추가되었습니다.')),
      );
      Navigator.pop(context); // 추가 성공 후 메인 화면으로 창 닫기
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 추가에 실패했습니다. 다시 시도해주세요.')),
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
              '모니터링할 장소의\n이름과 주소를 입력해주세요.', // 💡 문구 수정
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.3),
            ),
            const SizedBox(height: 32),
            
            // 이름 입력 필드
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '카메라 이름 (예: 거실, 아이방)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.videocam_outlined),
              ),
            ),
            const SizedBox(height: 16),
            
            // 💡 4. RTSP 주소 입력 필드 UI 추가
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: '카메라 RTSP 주소 (예: rtsp://192.168.0.55/stream)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            
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
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('카메라 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}