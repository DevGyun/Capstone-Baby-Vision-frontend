import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';

/// 카메라 등록 화면 (페어링 코드 방식).
///
/// 흐름:
/// 1. 라즈베리파이(브릿지) 부팅 → 백엔드가 6자리 코드 발급 (10분 유효)
/// 2. 카메라가 화면에 코드 표시
/// 3. 사용자가 카메라 이름 + 6자리 코드 입력 → POST /bridges/pair
class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (name.isEmpty) return '카메라 이름을 입력해 주세요.';
    if (name.length > 100) return '카메라 이름은 100자 이내로 입력해 주세요.';
    if (code.isEmpty) return '페어링 코드를 입력해 주세요.';
    if (code.length != 6) return '페어링 코드는 6자리 숫자예요.';
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return '숫자만 입력할 수 있어요.';
    return null;
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();

    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final cameraProvider = context.read<CameraProvider>();
    final success = await cameraProvider.pairCamera(
      pairingCode: _codeController.text.trim(),
      name: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${_nameController.text.trim()}" 카메라가 연결되었어요.'),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cameraProvider.lastErrorMessage ?? '페어링에 실패했어요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = context.watch<CameraProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('카메라 등록',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // 페어링 안내 카드 (1babyscreen 이미지 대체)
              _buildGuideCard(colorScheme),
              const SizedBox(height: 28),

              const Text('카메라 페어링',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '카메라(브릿지)에 표시된 6자리 코드를 입력하면 내 계정에 연결돼요.\n코드는 발급 후 10분간 유효해요.',
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 28),

              // 카메라 이름
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                onSubmitted: (_) => _codeFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: '카메라 이름',
                  hintText: '예: 거실, 아기방, 베란다',
                  prefixIcon: const Icon(Icons.videocam),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),

              // 페어링 코드 (6자리 숫자, 큰 글자 + letterSpacing)
              TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                onSubmitted: (_) => _onSubmit(),
                decoration: InputDecoration(
                  labelText: '페어링 코드',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    fontSize: 22,
                    letterSpacing: 8,
                  ),
                  prefixIcon: const Icon(Icons.password_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    isLoading ? '연결 중...' : '카메라 연결하기',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2, color: colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              const Text(
                '카메라 연결 방법',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _stepRow(colorScheme, 1, '카메라(라즈베리파이)의 전원을 켜 주세요.'),
          _stepRow(colorScheme, 2, '카메라 화면에 6자리 코드가 표시될 때까지 기다려요.'),
          _stepRow(colorScheme, 3, '아래에 이름과 코드를 입력하면 연결돼요.'),
        ],
      ),
    );
  }

  Widget _stepRow(ColorScheme colorScheme, int num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1, right: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$num',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
