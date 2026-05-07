import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/common.dart';

/// 카메라 등록 화면 (페어링 코드 방식).
///
/// 흐름:
/// 1. 라즈베리파이 부팅 시 백엔드가 6자리 코드 발급 (10분 유효)
/// 2. 카메라가 코드 표시
/// 3. 사용자: 이름 + 6자리 코드 입력 → POST /bridges/pair
class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // 코드 입력 변화 시 재빌드 (6자리 채워졌나 표시용)
    _codeController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    return name.isNotEmpty && code.length == 6;
  }

  String? _validate() {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty) return '카메라 이름을 입력해 주세요.';
    if (name.length > 100) return '카메라 이름은 100자 이내로 입력해 주세요.';
    if (code.isEmpty) return '페어링 코드를 입력해 주세요.';
    if (code.length != 6) return '페어링 코드는 6자리 숫자예요.';
    return null;
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    final error = _validate();
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }

    final provider = context.read<CameraProvider>();
    final success = await provider.pairCamera(
      pairingCode: _codeController.text.trim(),
      name: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      _showSnack('"${_nameController.text.trim()}" 카메라가 연결되었어요',
          isError: false);
      Navigator.pop(context);
    } else {
      _showSnack(provider.lastErrorMessage ?? '연결에 실패했어요', isError: true);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 20,
              color: isError ? AppColors.danger : AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = context.watch<CameraProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('카메라 연결'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),

              // ── 헤드라인 ──
              Text(
                '새 카메라를\n연결해 보세요',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                '카메라 화면에 표시된 6자리 코드를 입력하면 내 계정에 연결돼요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── 안내 카드 (3단계) ──
              _GuideCard(),

              const SizedBox(height: AppSpacing.xl),

              // ── 카메라 이름 ──
              _FieldLabel(text: '카메라 이름'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nameController,
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                onSubmitted: (_) => _codeFocus.requestFocus(),
                decoration: const InputDecoration(
                  hintText: '예: 아기방, 거실, 베란다',
                  prefixIcon: Icon(Icons.videocam_outlined, size: 20),
                  counterText: '',
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── 페어링 코드 ──
              Row(
                children: [
                  _FieldLabel(text: '페어링 코드'),
                  const Spacer(),
                  // 6자리 입력 진행 표시 (5/6, 6/6 등)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _codeController.text.isEmpty
                        ? const SizedBox.shrink()
                        : Text(
                            '${_codeController.text.length}/6',
                            key: ValueKey(_codeController.text.length),
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: _codeController.text.length == 6
                                          ? AppColors.accent
                                          : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _PairingCodeField(
                controller: _codeController,
                focusNode: _codeFocus,
                onComplete: _onSubmit,
              ),

              const SizedBox(height: AppSpacing.md - 2),

              // 만료 안내 - 작게
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '코드는 발급 후 10분간 유효해요',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── 등록 버튼 ──
              SoftButton(
                label: isLoading ? '연결 중...' : '카메라 연결하기',
                icon: isLoading ? null : Icons.link_rounded,
                isLoading: isLoading,
                onPressed: _canSubmit ? _onSubmit : null,
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// 라벨 (필드 위 텍스트)
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

/// 1, 2, 3 단계 페어링 안내 카드
class _GuideCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SoftCard(
      color: AppColors.accentSoft(context),
      bordered: false,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '연결 전에 확인해 주세요',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 4),
          _GuideStep(num: 1, text: '카메라(라즈베리파이)의 전원이 켜져 있어요'),
          const SizedBox(height: AppSpacing.sm + 2),
          _GuideStep(num: 2, text: '카메라 화면에 6자리 코드가 표시돼요'),
          const SizedBox(height: AppSpacing.sm + 2),
          _GuideStep(num: 3, text: '아래에 이름과 코드를 입력하면 끝이에요'),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int num;
  final String text;
  const _GuideStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1, right: AppSpacing.sm + 2),
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$num',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

/// 6자리 페어링 코드 입력 필드.
/// 6개 박스로 시각적으로 분리해서 OTP 입력처럼 보이게 함.
class _PairingCodeField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onComplete;

  const _PairingCodeField({
    required this.controller,
    required this.focusNode,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = controller.text;

    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 시각적인 6개 박스
          Row(
            children: List.generate(6, (i) {
              final hasChar = i < text.length;
              final isActiveCursor = i == text.length && focusNode.hasFocus;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 5 ? 0 : AppSpacing.sm),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isActiveCursor
                            ? AppColors.accent
                            : (hasChar
                                ? cs.outline
                                : cs.outlineVariant),
                        width: isActiveCursor ? 1.5 : 0.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: hasChar
                        ? Text(
                            text[i],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          )
                        : (isActiveCursor
                            ? _BlinkingCursor()
                            : const SizedBox.shrink()),
                  ),
                ),
              );
            }),
          ),
          // 실제 입력 받는 투명 TextField (위 박스들 위에 겹쳐짐)
          Positioned.fill(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              maxLength: 6,
              showCursor: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (v) {
                if (v.length == 6) {
                  // 6자리 완성 시 키보드만 닫음 (자동 제출은 안 함 — 사용자 의도 존중)
                  FocusScope.of(context).unfocus();
                }
              },
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 1,
                height: 1,
              ),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 깜빡이는 커서 (현재 활성 박스 표시)
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}