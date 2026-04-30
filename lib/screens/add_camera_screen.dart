import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';

class AddCameraScreen extends StatefulWidget {
  @override
  _AddCameraScreenState createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends State<AddCameraScreen> {
  bool _isScanning = false;
  String? _bridgeId;
  final TextEditingController _nameController = TextEditingController();

  // TODO: 차훈님과 협의하여 브릿지(C++) 측에 설정된 실제 UUID로 변경해야 합니다.
  final String SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0";
  final String CHARACTERISTIC_UUID = "abcdef01-1234-5678-1234-56789abcdef0";

  @override
  void initState() {
    super.initState();
    _startBleScan();
  }

  Future<void> _startBleScan() async {
    // 1. 권한 요청
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isDenied ||
        statuses[Permission.location]!.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('블루투스 및 위치 권한이 필요합니다.')));
      }
      return;
    }

    setState(() {
      _isScanning = true;
    });

    // 2. BLE 스캔 시작
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        // 브릿지의 Bluetooth Advertising 이름 필터링 (예: "BabyVision")
        if (r.device.platformName.startsWith("BabyVision")) {
          await FlutterBluePlus.stopScan();
          _connectToDevice(r.device);
          break;
        }
      }
    });

    // 스캔 상태 감지하여 UI 업데이트
    FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning && mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      // 3. 기기 연결
      await device.connect();
      
      // 4. 서비스 및 특성(Characteristic) 탐색
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid.toString() == CHARACTERISTIC_UUID) {
              // 5. 브릿지 아이디 읽어오기
              List<int> value = await c.read();
              String bridgeId = String.fromCharCodes(value);
              
              if (mounted) {
                setState(() {
                  _bridgeId = bridgeId;
                });
              }
              
              // 정보 획득 후 즉시 연결 해제 (배터리 및 리소스 절약)
              await device.disconnect();
              return;
            }
          }
        }
      }
      await device.disconnect();
    } catch (e) {
      print("BLE 연결 에러: $e");
    }
  }

  void _registerCamera() async {
    if (_nameController.text.isEmpty || _bridgeId == null) return;

    // 6. 획득한 정보로 서버에 POST 요청
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    bool success = await cameraProvider.registerCamera(_nameController.text, _bridgeId!);

    if (success && mounted) {
      // 등록 성공 시 라이브 스트리밍 화면으로 이동
      Navigator.pushReplacementNamed(context, '/live_stream'); 
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카메라 등록에 실패했습니다. 서버 상태를 확인해주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('브릿지 카메라 등록')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 앱 내 로컬 에셋 이미지 활용
            Image.asset('assets/images/1babyscreen.png', height: 150),
            const SizedBox(height: 30),
            
            if (_bridgeId == null) ...[
              if (_isScanning) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 20),
                const Text(
                  '주변의 Baby Vision 브릿지를 찾고 있습니다...\n스마트폰을 브릿지 가까이 가져가 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ] else ...[
                const Text(
                  '브릿지를 찾을 수 없습니다.\n기기 전원과 블루투스 상태를 확인해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _startBleScan,
                  child: const Text('다시 스캔하기'),
                ),
              ]
            ] else ...[
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              const Text(
                '브릿지가 성공적으로 연결되었습니다!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Bridge ID: $_bridgeId',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '카메라 이름 (예: 거실, 아기방)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.videocam),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _registerCamera,
                child: const Text('서버에 카메라 등록하기', style: TextStyle(fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}