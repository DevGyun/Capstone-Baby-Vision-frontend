import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../config.dart';
import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/soft_button.dart';

/// ──────────────────────────────────────────────────────────────────
///  카메라 등록 플로우
///
///  1. 사용자가 폰을 브릿지의 핫스팟(EyeCatch-Setup-XXXX)에 연결
///  2. 앱이 브릿지 로컬 IP(192.168.4.1)로 코드 발급 요청
///       → 브릿지가 내부적으로 서버에 POST /bridges/register
///       → 6자리 코드를 받아서 앱에 응답
///  3. 사용자가 일반 Wi-Fi / LTE 로 복귀
///  4. 카메라 이름 입력
///  5. 앱이 서버에 POST /bridges/pair (Bearer + 코드 + 이름)
///  6. 완료
///
///  브릿지 로컬 HTTP 컨트랙트 (브릿지 담당자와 합의 필요):
///    GET http://192.168.4.1/pair/start
///    Response 200:
///      {
///        "pairing_code": "123456",
///        "expires_at": "2026-05-11T12:34:56Z",
///        "poll_interval_seconds": 5
///      }
/// ──────────────────────────────────────────────────────────────────

enum PairingStep {
  connectToBridgeWifi,    // 1. 브릿지 핫스팟 연결 대기
  fetchingCodeFromBridge, // 2. 브릿지에 코드 요청 (LAN 안에서)
  reconnectToInternet,    // 3. 일반 인터넷으로 복귀 대기
  verifyingServer,        // 4. 서버 도달 가능한지 검증
  inputCameraName,        // 5. 카메라 이름 입력
  pairingWithServer,      // 6. 서버에 페어링 요청
  manualCodeEntry,        // (폴백) 사용자가 직접 코드 입력
  done,                   // 7. 성공
  error,                  // 오류
}

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  // ── 브릿지 컨트랙트 ────────────────────────────────────────────
  static const String _bridgeSSIDPrefix = 'EyeCatch-Setup-';
  static const String _bridgeLocalUrl = 'http://192.168.4.1';
  static const String _bridgePairEndpoint = '/pair/start';
  static const Duration _bridgeFetchTimeout = Duration(seconds: 30);

  // ── 상태 ──────────────────────────────────────────────────────
  PairingStep _currentStep = PairingStep.connectToBridgeWifi;
  String _errorMessage = '';
  String _pairingCode = '';
  DateTime? _codeExpiresAt;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _manualCodeController = TextEditingController();

  Timer? _wifiCheckTimer;
  Timer? _expiryTickTimer;
  StreamSubscription? _connectivitySubscription;
  int _wifiCheckElapsedSec = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStart();
  }

  @override
  void dispose() {
    _wifiCheckTimer?.cancel();
    _expiryTickTimer?.cancel();
    _connectivitySubscription?.cancel();
    _nameController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // 권한 → 핫스팟 감지 루프 시작
  // ─────────────────────────────────────────────────────────────
  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;

    if (status.isGranted) {
      _startWifiCheckLoop();
    } else {
      setState(() {
        _currentStep = PairingStep.error;
        _errorMessage =
            '위치 권한이 필요해요.\nWi-Fi 이름을 확인하려면 Android가 위치 권한을 요구합니다.';
      });
    }
  }

  /// 2초마다 SSID 확인. 10초 넘게 못 찾으면 "수동 입력" 폴백 노출.
  void _startWifiCheckLoop() {
    _wifiCheckElapsedSec = 0;
    _wifiCheckTimer?.cancel();
    _wifiCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted ||
          _currentStep != PairingStep.connectToBridgeWifi) {
        timer.cancel();
        return;
      }

      _wifiCheckElapsedSec += 2;

      final info = NetworkInfo();
      String? ssid;
      try {
        ssid = await info.getWifiName();
      } catch (e) {
        debugPrint('SSID 조회 실패: $e');
      }
      ssid = ssid?.replaceAll('"', '').trim();

      if (ssid != null && ssid.startsWith(_bridgeSSIDPrefix)) {
        timer.cancel();
        await _fetchCodeFromBridge();
        return;
      }

      // UI 갱신용 (안내문/폴백 버튼 노출)
      if (mounted) setState(() {});
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 브릿지에 코드 요청 (LAN)
  // ─────────────────────────────────────────────────────────────
  Future<void> _fetchCodeFromBridge() async {
    setState(() {
      _currentStep = PairingStep.fetchingCodeFromBridge;
      _errorMessage = '';
    });

    try {
      final response = await http
          .get(Uri.parse('$_bridgeLocalUrl$_bridgePairEndpoint'))
          .timeout(_bridgeFetchTimeout);

      if (response.statusCode != 200) {
        throw Exception('브릿지 응답 코드: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // 브릿지는 서버의 BridgeRegisterResponse를 그대로 프록시한다고 가정.
      // 구버전 호환을 위해 'code'도 fallback으로 받음.
      final code = (data['pairing_code'] ?? data['code']) as String?;
      if (code == null || code.isEmpty) {
        throw Exception('응답에 pairing_code가 없어요');
      }

      _pairingCode = code;
      final expiresStr = data['expires_at'] as String?;
      _codeExpiresAt = expiresStr != null ? DateTime.tryParse(expiresStr) : null;

      _waitForInternetConnection();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _currentStep = PairingStep.error;
        _errorMessage =
            '브릿지가 응답하지 않아요.\n핫스팟에 잘 연결되어 있는지 확인해 주세요.';
      });
    } catch (e) {
      debugPrint('브릿지 코드 발급 에러: $e');
      if (!mounted) return;
      setState(() {
        _currentStep = PairingStep.error;
        _errorMessage = '카메라 정보를 받아오지 못했어요.\n다시 시도하거나 코드를 직접 입력할 수 있어요.';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 인터넷 복귀 감지
  // ─────────────────────────────────────────────────────────────
  void _waitForInternetConnection() {
    setState(() => _currentStep = PairingStep.reconnectToInternet);
    _startCodeExpiryTicker();

    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      if (!mounted) return;

      final hasData = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);
      if (!hasData) return;

      // 핫스팟에서 빠져나왔는지 확인
      final info = NetworkInfo();
      String? ssid;
      try {
        ssid = await info.getWifiName();
      } catch (_) {}
      ssid = ssid?.replaceAll('"', '').trim();

      final stillOnBridge =
          ssid != null && ssid.startsWith(_bridgeSSIDPrefix);
      if (stillOnBridge) return;

      _connectivitySubscription?.cancel();
      await _verifyServerReachable();
    });
  }

  /// 코드 만료 시각이 가까워질 때 안내문이 자동으로 갱신되도록 1초 틱.
  void _startCodeExpiryTicker() {
    _expiryTickTimer?.cancel();
    if (_codeExpiresAt == null) return;
    _expiryTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _expiryTickTimer?.cancel();
        return;
      }
      setState(() {});
    });
  }

  // ─────────────────────────────────────────────────────────────
  // 서버 도달 가능 여부 검증 (/health)
  // ─────────────────────────────────────────────────────────────
  Future<void> _verifyServerReachable() async {
    setState(() => _currentStep = PairingStep.verifyingServer);

    try {
      final r = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/health'),
            headers: {'ngrok-skip-browser-warning': '69420'},
          )
          .timeout(const Duration(seconds: 5));

      if (r.statusCode == 200) {
        if (!mounted) return;
        setState(() => _currentStep = PairingStep.inputCameraName);
        return;
      }
      throw Exception('서버 응답 코드: ${r.statusCode}');
    } catch (e) {
      debugPrint('서버 도달 검증 실패: $e');
      if (!mounted) return;
      setState(() {
        _currentStep = PairingStep.error;
        _errorMessage =
            '인터넷 연결을 확인 후 다시 시도해 주세요.\n서버와 통신할 수 없어요.';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 메인 서버에 페어링 요청
  // ─────────────────────────────────────────────────────────────
  Future<void> _pairWithServer() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카메라 이름을 입력해 주세요')),
      );
      return;
    }
    if (_pairingCode.isEmpty) {
      setState(() {
        _currentStep = PairingStep.error;
        _errorMessage = '페어링 코드가 없어요. 처음부터 다시 시도해 주세요.';
      });
      return;
    }

    setState(() => _currentStep = PairingStep.pairingWithServer);

    final provider = context.read<CameraProvider>();
    final success = await provider.pairCamera(
      pairingCode: _pairingCode,
      name: name,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _currentStep = PairingStep.done);
    } else {
      setState(() {
        _currentStep = PairingStep.error;
        _errorMessage = provider.lastErrorMessage ?? '서버 등록에 실패했어요.';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 수동 코드 입력 (폴백)
  // ─────────────────────────────────────────────────────────────
  void _enterManualMode() {
    _wifiCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    setState(() {
      _currentStep = PairingStep.manualCodeEntry;
      _errorMessage = '';
    });
  }

  Future<void> _submitManualCode() async {
    final code = _manualCodeController.text.trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6자리 숫자 코드를 입력해 주세요')),
      );
      return;
    }
    _pairingCode = code;
    await _verifyServerReachable();
  }

  // ─────────────────────────────────────────────────────────────
  // 재시도
  // ─────────────────────────────────────────────────────────────
  void _retryFromError() {
    if (_pairingCode.isNotEmpty && !_isCodeExpired()) {
      _waitForInternetConnection();
    } else {
      _pairingCode = '';
      _codeExpiresAt = null;
      setState(() => _currentStep = PairingStep.connectToBridgeWifi);
      _startWifiCheckLoop();
    }
  }

  bool _isCodeExpired() {
    if (_codeExpiresAt == null) return false;
    return DateTime.now().isAfter(_codeExpiresAt!);
  }

  String? _remainingTimeText() {
    if (_codeExpiresAt == null) return null;
    final diff = _codeExpiresAt!.difference(DateTime.now());
    if (diff.isNegative) return '만료됨';
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m}분 ${s.toString().padLeft(2, '0')}초 후 만료';
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('카메라 추가', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
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
    switch (_currentStep) {
      case PairingStep.connectToBridgeWifi:
        return _buildConnectToWifiStep();

      case PairingStep.fetchingCodeFromBridge:
        return _buildLoadingState('카메라 정보를 불러오는 중이에요...');

      case PairingStep.reconnectToInternet:
        return _buildReconnectStep();

      case PairingStep.verifyingServer:
        return _buildLoadingState('서버 연결을 확인하는 중이에요...');

      case PairingStep.inputCameraName:
        return _buildInputNameStep();

      case PairingStep.pairingWithServer:
        return _buildLoadingState('서버에 카메라를 등록하는 중이에요...');

      case PairingStep.manualCodeEntry:
        return _buildManualCodeStep();

      case PairingStep.done:
        return _buildDoneStep();

      case PairingStep.error:
        return _buildErrorStep();
    }
  }

  // ─── 각 스텝 UI ───────────────────────────────────────────────

  Widget _buildConnectToWifiStep() {
    final showFallback = _wifiCheckElapsedSec >= 10;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_find, size: 80, color: AppColors.accent),
          const SizedBox(height: 24),
          const Text(
            '카메라 핫스팟에 연결해 주세요',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '스마트폰 Wi-Fi 설정에서\n"EyeCatch-Setup-XXXX"를 선택해 주세요.\n비밀번호는 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 40),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '핫스팟 연결 확인 중... (${_wifiCheckElapsedSec}s)',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if (showFallback) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: _enterManualMode,
              child: const Text(
                '카메라 화면의 코드를 직접 입력하기',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReconnectStep() {
    final remaining = _remainingTimeText();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 80, color: AppColors.warning),
          const SizedBox(height: 24),
          const Text(
            '원래 인터넷으로 돌아와 주세요',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '카메라 핫스팟 연결을 끊고\n평소 쓰시는 Wi-Fi나 데이터로 변경해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          if (remaining != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    remaining,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildInputNameStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.edit, size: 80, color: AppColors.accent),
        const SizedBox(height: 24),
        const Text(
          '카메라 이름을 정해주세요',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '나중에 메인 화면에서 이 이름으로 보여요',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          autofocus: true,
          maxLength: 100,
          style: const TextStyle(color: Colors.black),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _pairWithServer(),
          decoration: InputDecoration(
            hintText: '예: 거실 카메라, 아기방',
            filled: true,
            fillColor: Colors.white,
            counterStyle: const TextStyle(color: Colors.white38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SoftButton(
            label: '이 이름으로 등록하기',
            onPressed: _pairWithServer,
          ),
        ),
      ],
    );
  }

  Widget _buildManualCodeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.dialpad, size: 80, color: AppColors.accent),
        const SizedBox(height: 24),
        const Text(
          '6자리 페어링 코드를 입력해 주세요',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '카메라 화면에 표시된 숫자를 입력하세요',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _manualCodeController,
          autofocus: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: Colors.black,
            fontSize: 28,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitManualCode(),
          decoration: InputDecoration(
            hintText: '000000',
            counterStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SoftButton(
            label: '다음',
            onPressed: _submitManualCode,
          ),
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 24),
          const Text(
            '연결 완료!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '메인 화면에서 영상을 확인하실 수 있어요',
            style: TextStyle(color: Colors.grey, fontSize: 13),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: AppColors.danger),
          const SizedBox(height: 24),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 40),
          SoftButton(
            label: '다시 시도',
            onPressed: _retryFromError,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _enterManualMode,
            child: const Text(
              '코드를 직접 입력하기',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
