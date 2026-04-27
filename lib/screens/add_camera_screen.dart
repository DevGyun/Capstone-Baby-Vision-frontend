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
  int? _selectedBridgeId; // 선택된 브릿지 ID 저장
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 화면 초기화 시 미등록 브릿지 목록 로드
    Future.microtask(() =>
        context.read<CameraProvider>().fetchPendingBridges());
  }

  void _submit() async {
    final name = _nameController.text.trim();

    if (_selectedBridgeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록할 기기를 선택해주세요.')),
      );
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 이름을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<CameraProvider>();
    // 선택된 브릿지 ID와 함께 이름 전달
    final resultMessage = await provider.addCamera(name, _selectedBridgeId!);

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
    final cameraProvider = context.watch<CameraProvider>();
    final pendingBridges = cameraProvider.pendingBridges;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('새 카메라 추가', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => cameraProvider.fetchPendingBridges(),
            tooltip: '기기 목록 새로고침',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '새로운 기기를\n등록합니다.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.3),
            ),
            const SizedBox(height: 32),
            
            // 1. 브릿지 선택 UI
            const Text('1. 연결할 기기 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (pendingBridges.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '연결 대기 중인 기기가 없습니다.\n브릿지 프로그램이 실행 중인지 확인해주세요.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<int>(
                value: _selectedBridgeId,
                hint: const Text('기기를 선택하세요'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.router_outlined),
                ),
                items: pendingBridges.map<DropdownMenuItem<int>>((bridge) {
                  return DropdownMenuItem<int>(
                    value: bridge['id'],
                    child: Text('기기 ID: ${bridge['id']} (${bridge['token'].toString().substring(0, 5)}...)'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedBridgeId = value);
                },
              ),

            const SizedBox(height: 32),

            // 2. 카메라 이름 입력 UI
            const Text('2. 카메라 이름 설정', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '예: 거실, 아이방',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.videocam_outlined),
              ),
            ),
            
            const SizedBox(height: 40),

            // 3. 등록 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                // 기기가 없거나 제출 중이면 버튼 비활성화
                onPressed: (_isSubmitting || pendingBridges.isEmpty) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: colorScheme.surfaceVariant,
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