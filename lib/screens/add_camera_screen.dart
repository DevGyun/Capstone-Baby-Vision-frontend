import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/camera_provider.dart';
import '../services/ble_permission_helper.dart';
import '../services/bridge_ble_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/common.dart';

enum AddCameraStep {
  intro,
  permission,
  scanning,
  selectBridge,
  enterCredentials,
  provisioning,
  pairingWithServer,
  done,
  error,
}

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  AddCameraStep _step = AddCameraStep.intro;
  String _errorMessage = '';

  List<DiscoveredBridge> _bridges = [];
  DiscoveredBridge? _selectedBridge;

  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cameraNameController = TextEditingController();
  bool _obscurePassword = true;

  StreamSubscription? _scanSub;
  BlePairingPhase _pairingPhase = BlePairingPhase.idle;

  @override
  void dispose() {
    _scanSub?.cancel();
    BridgeBleService.instance.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    _cameraNameController.dispose();
    super.dispose();
  }

  void _go(AddCameraStep s) {
    if (!mounted) return;
    setState(() => _step = s);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _step = AddCameraStep.error;
      _errorMessage = message;
    });
  }

  Future<void> _requestPermissionAndScan() async {
    _go(AddCameraStep.permission);

    final result = await BlePermissionHelper.requestAll();
    if (!mounted) return;

    switch (result) {
      case BlePermissionResult.granted:
        await _startScan();
        break;
      case BlePermissionResult.denied:
        _fail('블루투스 권한이 필요해요. 권한을 허용한 뒤 다시 시도해 주세요');
        break;
      case BlePermissionResult.permanentlyDenied:
        _fail('블루투스 권한이 영구 거부되어 있어요.\n앱 설정 → 권한에서 직접 허용해 주세요');
        break;
      case BlePermissionResult.unsupported:
        _fail('이 기기에선 카메라 페어링을 사용할 수 없어요');
        break;
    }
  }

  Future<void> _startScan() async {
    _go(AddCameraStep.scanning);
    _bridges = [];

    await _scanSub?.cancel();
    _scanSub = BridgeBleService.instance.scan().listen(
      (results) {
        if (!mounted) return;
        setState(() => _bridges = results);
        if (results.isNotEmpty && _step == AddCameraStep.scanning) {
          _go(AddCameraStep.selectBridge);
        }
      },
      onError: (e) {
        _fail(e.toString().replaceFirst('Exception: ', ''));
      },
      onDone: () {
        if (!mounted) return;
        if (_bridges.isEmpty) {
          _fail('주변에서 카메라를 찾지 못했어요.\n카메라가 켜져 있고 페어링 모드인지 확인해 주세요');
        }
      },
    );
  }

  void _selectBridge(DiscoveredBridge b) {
    _scanSub?.cancel();
    BridgeBleService.instance.stopScan();
    setState(() {
      _selectedBridge = b;
      _step = AddCameraStep.enterCredentials;
    });
  }

  Future<void> _submitCredentials() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;
    final cameraName = _cameraNameController.text.trim();

    // Wi-Fi 정보는 비워도 OK (브릿지가 이미 연결돼 있는 경우 대응)
    // 카메라 이름만 필수
    if (cameraName.isEmpty) {
      _showSnack('카메라 이름을 입력해 주세요');
      return;
    }
    if (_selectedBridge == null) {
      _fail('선택된 카메라 정보가 없어요. 처음부터 다시 시도해 주세요');
      return;
    }

    _go(AddCameraStep.provisioning);

    final result = await BridgeBleService.instance.provisionAndAwaitCode(
      bridge: _selectedBridge!,
      ssid: ssid,
      password: password,
      cameraName: cameraName,
      onPhase: (phase) {
        if (!mounted) return;
        setState(() => _pairingPhase = phase);
      },
    );

    if (!mounted) return;

    if (!result.success) {
      _fail(result.errorMessage ?? '카메라 등록에 실패했어요');
      return;
    }

    _go(AddCameraStep.pairingWithServer);

    final provider = context.read<CameraProvider>();
    final ok = await provider.pairCamera(
      pairingCode: result.pairingCode!,
      name: cameraName,
    );

    if (!mounted) return;
    if (ok) {
      _go(AddCameraStep.done);
    } else {
      _fail(provider.lastErrorMessage ?? '서버 등록에 실패했어요');
    }
  }

  void _retryFromError() {
    setState(() {
      _step = AddCameraStep.intro;
      _errorMessage = '';
      _bridges = [];
      _selectedBridge = null;
      _pairingPhase = BlePairingPhase.idle;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('카메라 추가', style: TextStyle(color: cs.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case AddCameraStep.intro:
        return _buildIntroStep();
      case AddCameraStep.permission:
        return _buildLoading('블루투스 권한을 확인하고 있어요...');
      case AddCameraStep.scanning:
        return _buildScanningStep();
      case AddCameraStep.selectBridge:
        return _buildSelectStep();
      case AddCameraStep.enterCredentials:
        return _buildCredentialsStep();
      case AddCameraStep.provisioning:
        return _buildProvisioningStep();
      case AddCameraStep.pairingWithServer:
        return _buildLoading('서버에 카메라를 등록하는 중이에요...');
      case AddCameraStep.done:
        return _buildDoneStep();
      case AddCameraStep.error:
        return _buildErrorStep();
    }
  }

  Widget _buildIntroStep() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_searching,
              size: 80, color: AppColors.accent),
          const SizedBox(height: 24),
          Text(
            '카메라를 페어링 모드로 켜주세요',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '카메라가 처음 켜지면 자동으로\n블루투스 페어링 모드로 들어가요.\n앱이 주변에서 자동으로 찾아드려요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: SoftButton(
              label: '카메라 찾기',
              icon: Icons.search,
              onPressed: _requestPermissionAndScan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningStep() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_searching,
              size: 80, color: AppColors.accent),
          const SizedBox(height: 24),
          Text(
            '주변 카메라를 찾는 중...',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '카메라가 처음 켜진 상태여야 발견돼요.\n이미 등록된 카메라는 나타나지 않아요.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: cs.onSurfaceVariant, height: 1.5, fontSize: 13),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: AppColors.accent),
        ],
      ),
    );
  }

  Widget _buildSelectStep() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '발견된 카메라',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_bridges.length}대 발견 · 신호가 강한 순서로 표시',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: _bridges.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final b = _bridges[i];
              return _BridgeTile(
                bridge: b,
                onTap: () => _selectBridge(b),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: _startScan,
          icon: const Icon(Icons.refresh, color: AppColors.accent, size: 16),
          label: const Text(
            '다시 검색',
            style: TextStyle(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialsStep() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi, size: 56, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(
            'Wi-Fi 정보를 알려주세요',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '카메라(${_selectedBridge?.name ?? "-"})가 이 Wi-Fi에 연결돼서\n인터넷을 통해 영상을 보내게 돼요.',
            style: TextStyle(
                color: cs.onSurfaceVariant, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),

          // Wi-Fi 선택 안내 배너
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '카메라가 이미 Wi-Fi에 연결되어 있다면\nWi-Fi 정보는 비워두셔도 돼요',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const FieldLabel('Wi-Fi 이름 (SSID) · 선택'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _ssidController,
            decoration: const InputDecoration(
              hintText: '예: MyHomeWiFi (비워둬도 돼요)',
              prefixIcon: Icon(Icons.wifi, size: 20),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const FieldLabel('Wi-Fi 비밀번호 · 선택'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: '비밀번호 (비워둬도 돼요)',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const FieldLabel('카메라 이름 · 필수'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _cameraNameController,
            maxLength: 30,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitCredentials(),
            decoration: const InputDecoration(
              hintText: '예: 거실, 아기방',
              prefixIcon: Icon(Icons.videocam_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock, size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Wi-Fi 비밀번호는 카메라에만 전달되고 저장되지 않아요',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: SoftButton(
              label: '카메라 등록하기',
              icon: Icons.bluetooth_connected,
              onPressed: _submitCredentials,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvisioningStep() {
    final cs = Theme.of(context).colorScheme;
    final phaseLabel = switch (_pairingPhase) {
      BlePairingPhase.connecting => '카메라에 연결하는 중...',
      BlePairingPhase.sendingCredentials => 'Wi-Fi 정보를 전달하는 중...',
      BlePairingPhase.waitingWifi => '카메라가 Wi-Fi에 연결하는 중...',
      BlePairingPhase.waitingPairingCode => '서버에서 페어링 코드를 받는 중...',
      _ => '준비 중...',
    };

    final phaseDesc = switch (_pairingPhase) {
      BlePairingPhase.waitingWifi =>
        '카메라 근처에서 잠시 기다려 주세요. Wi-Fi 신호가 약하면 시간이 더 걸릴 수 있어요',
      BlePairingPhase.waitingPairingCode => '거의 다 됐어요!',
      _ => '잠시만 기다려 주세요',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 24),
          Text(
            phaseLabel,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            phaseDesc,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDoneStep() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 24),
          Text(
            '카메라가 등록되었어요!',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '메인 화면에서 영상을 확인하실 수 있어요',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 40),
          SoftButton(
            label: '메인으로 돌아가기',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStep() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: AppColors.danger),
          const SizedBox(height: 24),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface, height: 1.5),
          ),
          const SizedBox(height: 40),
          SoftButton(
            label: '다시 시도',
            icon: Icons.refresh,
            onPressed: _retryFromError,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(String message) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   서브 위젯들
// ────────────────────────────────────────────────────────────────

class _BridgeTile extends StatelessWidget {
  final DiscoveredBridge bridge;
  final VoidCallback onTap;

  const _BridgeTile({required this.bridge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outlineVariant, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.videocam_outlined,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bridge.name,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bridge.distanceHint,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _SignalIcon(rssi: bridge.rssi),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalIcon extends StatelessWidget {
  final int rssi;
  const _SignalIcon({required this.rssi});

  int get _bars {
    if (rssi > -50) return 4;
    if (rssi > -65) return 3;
    if (rssi > -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bars = _bars;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < bars;
        return Container(
          width: 4,
          height: 6.0 + i * 3,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : cs.outlineVariant,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}