import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../providers/camera_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common/soft_button.dart';

enum PairingStep {
  connectToBridgeWifi,     // 1. 브릿지 핫스팟 연결 대기
  fetchingCodeFromBridge,  // 2. 브릿지와 직접 통신하여 코드 발급
  reconnectToInternet,     // 3. 원래 인터넷으로 복귀 대기
  inputCameraName,         // 4. (추가) 카메라 이름 설정
  pairingWithServer,       // 5. 서버에 페어링 요청
  done,                    // 6. 성공
  error,                   // 오류 발생
}

class AddCameraScreen extends StatefulWidget {
  const AddCameraScreen({super.key});

  @override
  State<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  PairingStep _currentStep = PairingStep.connectToBridgeWifi;
  String _errorMessage = '';
  String _pairingCode = '';
  
  final TextEditingController _nameController = TextEditingController();
  
  Timer? _wifiCheckTimer;
  StreamSubscription? _connectivitySubscription;

  // 설정하신 핫스팟 이름 앞부분 및 로컬 IP
  final String _bridgeSSIDPrefix = 'EyeCatch-Setup-';
  final String _bridgeLocalIp = 'http://192.168.4.1'; 

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStart();
  }

  @override
  void dispose() {
    _wifiCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  /// 권한 요청 후 와이파이 체크 시작 (안드로이드 8 이상 필수)
  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      _startWifiCheckLoop();
    } else {
      setState(() {
        _currentStep = PairingStep.error;
        _errorMessage = '위치 권한을 허용해야 Wi-Fi 연결을 확인할 수 있습니다.';
      });
    }
  }

  /// 1. Wi-Fi 연결 감지 루프
  void _startWifiCheckLoop() {
    _wifiCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_currentStep != PairingStep.connectToBridgeWifi) {
        timer.cancel();
        return;
      }

      final info = NetworkInfo();
      String? ssid = await info.getWifiName();
      ssid = ssid?.replaceAll('"', ''); // 안드로이드 따옴표 제거

      if (ssid != null && ssid.startsWith(_bridgeSSIDPrefix)) {
        timer.cancel();
        _fetchCodeFromBridge();
      }
    });
  }

  /// 2. 브릿지에서 코드를 받아옵니다 (로컬 통신)
  Future<void> _fetchCodeFromBridge() async {
    setState(() {
      _currentStep = PairingStep.fetchingCodeFromBridge;
      _errorMessage = '';
    });

    try {
      final response = await http.get(Uri.parse('$_bridgeLocalIp/register'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _pairingCode = data['code'];
        _waitForInternetConnection();
      } else {
        throw Exception('브릿지 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentStep = PairingStep.error;
        _errorMessage = '카메라 정보를 받아오지 못했습니다.\n다시 시도해주세요.';
      });
    }
  }

  /// 3. 사용자망 복귀 감지
  void _waitForInternetConnection() {
    setState(() {
      _currentStep = PairingStep.reconnectToInternet;
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        if (results.contains(ConnectivityResult.mobile) || 
            results.contains(ConnectivityResult.wifi)) {
          
          final info = NetworkInfo();
          String? ssid = await info.getWifiName();
          ssid = ssid?.replaceAll('"', '');

          // 핫스팟과 연결이 끊겼다면 이름 입력 화면으로 전환
          if (ssid == null || !ssid.startsWith(_bridgeSSIDPrefix)) {
            _connectivitySubscription?.cancel();
            setState(() {
              _currentStep = PairingStep.inputCameraName;
            });
          }
        }
      },
    );
  }

  /// 4, 5. 작성하신 Provider를 활용하여 메인 서버로 페어링 요청
  Future<void> _pairWithServer() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() {
      _currentStep = PairingStep.pairingWithServer;
    });

    // camera_provider에 이미 구현된 로직 실행 (토큰, 헤더, 리스트 갱신 모두 자동)
    final provider = context.read<CameraProvider>();
    final success = await provider.pairCamera(
      pairingCode: _pairingCode,
      name: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() => _currentStep = PairingStep.done);
    } else {
      setState(() {
        _currentStep = PairingStep.error;
        // provider 내부에서 에러 메시지를 세팅해두었으므로 이를 그대로 활용
        _errorMessage = provider.lastErrorMessage ?? '서버 등록에 실패했습니다.';
      });
    }
  }

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
      body: Center(
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
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.wifi_find, size: 80, color: AppColors.accent),
            SizedBox(height: 24),
            Text('카메라 핫스팟에 연결해주세요', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('스마트폰 Wi-Fi 설정에서\n"EyeCatch-Setup-XXXX"를 선택해주세요.', 
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            SizedBox(height: 40),
            CircularProgressIndicator(),
          ],
        );
      
      case PairingStep.fetchingCodeFromBridge:
        return _buildLoadingState('카메라 정보를 불러오고 있습니다...');

      case PairingStep.reconnectToInternet:
         return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.wifi_off, size: 80, color: AppColors.warning),
            SizedBox(height: 24),
            Text('원래 인터넷으로 돌아와주세요', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('카메라 핫스팟 연결을 끊고\n평소에 쓰시는 Wi-Fi나 데이터로 변경해주세요.', 
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        );
      
      case PairingStep.inputCameraName:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit, size: 80, color: AppColors.accent),
            const SizedBox(height: 24),
            const Text('카메라 이름을 정해주세요', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: '예: 거실 카메라, 아기방',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: SoftButton(
                label: '이 이름으로 등록하기',
                onPressed: _pairWithServer,
              ),
            ),
          ],
        );

      case PairingStep.pairingWithServer:
        return _buildLoadingState('서버에 카메라를 등록하는 중입니다...');

      case PairingStep.done:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: AppColors.success),
            const SizedBox(height: 24),
            const Text('연결 완료!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            SoftButton(
              label: '메인으로 돌아가기',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );

      case PairingStep.error:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppColors.danger),
            const SizedBox(height: 24),
            Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 40),
            SoftButton(
              label: '다시 시도',
              onPressed: () {
                _requestPermissionAndStart();
                setState(() => _currentStep = PairingStep.connectToBridgeWifi);
              },
            ),
          ],
        );
    }
  }

  Widget _buildLoadingState(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(message, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
