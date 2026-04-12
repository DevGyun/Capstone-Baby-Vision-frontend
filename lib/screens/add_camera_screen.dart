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
  final TextEditingController _urlController = TextEditingController(); 
  bool _isSubmitting = false;

  void _submit() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 이름과 주소를 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<CameraProvider>();
    final success = await provider.addCamera(name, url);

    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        // 💡 [안내 문구 살짝 변경] 기기 연동을 강조
        const SnackBar(content: Text('카메라 등록 및 연동이 완료되었습니다.')),
      );
      Navigator.pop(context); 
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
              '모니터링할 장소의\n이름과 주소를 입력해주세요.',
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
            const SizedBox(height: 16),
            
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: '카메라 내부망 주소 (예: rtsp://192.168.0.55/stream)', // 💡 라벨 문구를 내부망임을 알 수 있게 조금 다듬음
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
                // 💡 [추가/수정된 부분] 통신 중일 때 로딩바 옆에 텍스트를 띄워서 체감 대기시간 완화
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20, height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          ),
                          SizedBox(width: 12),
                          Text('기기 연동 중...', style: TextStyle(fontSize: 16, color: Colors.white))
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