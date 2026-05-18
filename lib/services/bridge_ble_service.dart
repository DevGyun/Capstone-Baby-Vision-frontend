import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// ─────────────────────────────────────────────────────────────────
///   BLE 컨트랙트 (브릿지 담당자와 합의 필요)
///
///   브릿지가 Wi-Fi 미연결 상태일 때 ble_server.py가
///   "EyeCatch-XXXX" 이름으로 BLE 광고를 시작한다고 가정.
///
///   Service UUID는 브릿지 코드와 정확히 같아야 함.
///   현재 ble_surver.py(오타 그대로)가 비어있어서 임시값을 사용함.
///   브릿지 측에서 UUID를 정한 뒤 아래 상수를 수정해 주세요.
/// ─────────────────────────────────────────────────────────────────

class BleContract {
  BleContract._();

  /// 메인 서비스 UUID
  static const String serviceUuid =
      '0000ebec-0000-1000-8000-00805f9b34fb';

  /// 앱→브릿지: Wi-Fi 정보 + 카메라 이름 전달 (JSON Write)
  /// 페이로드: {"ssid": "...", "password": "...", "camera_name": "..."}
  static const String provisioningCharUuid =
      '0000ec01-0000-1000-8000-00805f9b34fb';

  /// 브릿지→앱: 상태 알림 (Notify, plain text)
  ///   "wifi_connecting" | "wifi_ok" | "wifi_failed"
  ///   "registering" | "error:<reason>"
  static const String statusCharUuid =
      '0000ec02-0000-1000-8000-00805f9b34fb';

  /// 브릿지→앱: 서버에서 받은 6자리 페어링 코드 (Notify, plain text)
  ///   "123456"
  static const String pairingCodeCharUuid =
      '0000ec03-0000-1000-8000-00805f9b34fb';

  /// BLE 광고 이름 prefix — 발견된 기기 중 우리 브릿지만 골라내기 위함
  static const String advertisingNamePrefix = 'EyeCatch-';
}

/// 스캔으로 발견된 브릿지 정보
class DiscoveredBridge {
  final String name;
  final String deviceId; // 플랫폼 고유 ID (remoteId)
  final int rssi; // 신호 강도 (0에 가까울수록 가까움)
  final BluetoothDevice device;

  DiscoveredBridge({
    required this.name,
    required this.deviceId,
    required this.rssi,
    required this.device,
  });

  /// 신호 강도 → 사람 친화적 거리 힌트
  String get distanceHint {
    if (rssi > -50) return '바로 옆';
    if (rssi > -65) return '가까움';
    if (rssi > -80) return '같은 방';
    return '먼 거리';
  }
}

/// 페어링 진행 상태 (BLE 흐름 전용)
enum BlePairingPhase {
  idle,
  scanning,
  connecting,
  sendingCredentials,
  waitingWifi,
  waitingPairingCode,
  done,
  failed,
}

/// 페어링 결과
class BlePairingResult {
  final bool success;
  final String? pairingCode; // 성공 시 서버에 전달할 6자리
  final String? errorMessage;

  BlePairingResult.success(this.pairingCode)
      : success = true,
        errorMessage = null;

  BlePairingResult.failure(this.errorMessage)
      : success = false,
        pairingCode = null;
}

/// BLE 통신 전반을 다루는 싱글톤 서비스.
class BridgeBleService {
  BridgeBleService._();
  static final BridgeBleService instance = BridgeBleService._();

  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothDevice? _connectedDevice;

  // ───────── 스캔 ─────────

  /// 주변 브릿지를 스캔. 결과는 스트림으로 점진적으로 흘려보냄.
  /// 같은 기기가 여러 번 잡혀도 RSSI는 최신 값으로 갱신.
  Stream<List<DiscoveredBridge>> scan({
    Duration timeout = const Duration(seconds: 15),
  }) {
    final controller = StreamController<List<DiscoveredBridge>>.broadcast();
    final Map<String, DiscoveredBridge> found = {};

    () async {
      try {
        // Bluetooth 자체가 꺼져있으면 스캔 안 됨 — 호출측에서 처리
        if (await FlutterBluePlus.isSupported == false) {
          controller.addError(Exception('이 기기는 BLE를 지원하지 않아요'));
          return;
        }
        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState != BluetoothAdapterState.on) {
          controller.addError(
            Exception('블루투스가 꺼져 있어요. 켜고 다시 시도해 주세요'),
          );
          return;
        }

        _scanSub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            // platformName은 페어링 후 캐시된 이름이 잡힐 수도 있으니
// advertisementData.advName을 우선 사용 (없으면 platformName 폴백)
String n = r.advertisementData.advName;
if (n.isEmpty) n = r.device.platformName;

final prefixLower = BleContract.advertisingNamePrefix.toLowerCase();
if (n.toLowerCase().startsWith(prefixLower)) {
  found[r.device.remoteId.str] = DiscoveredBridge(
    name: n,
    deviceId: r.device.remoteId.str,
    rssi: r.rssi,
    device: r.device,
  );
}
          }
          final list = found.values.toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi)); // 가까운 순
          if (!controller.isClosed) controller.add(list);
        });

        // Service UUID 필터로 스캔 시도. 광고에 UUID가 없으면 위의
        // 이름 필터가 잡아내므로 둘 다 작동시킴.
        await FlutterBluePlus.startScan(
          withServices: [Guid(BleContract.serviceUuid)],
          timeout: timeout,
        );

        // 스캔 종료 대기
        await Future.delayed(timeout);
        if (!controller.isClosed) {
          // 종료 시점에 최종 결과 한 번 더 보내기
          final list = found.values.toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
          controller.add(list);
          await controller.close();
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }();

    controller.onCancel = () async {
      await stopScan();
    };
    return controller.stream;
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // ───────── 연결 + 프로비저닝 ─────────

  /// 핵심 메서드: 발견된 브릿지에 연결하고, 와이파이 정보를 넘기고,
  /// 브릿지가 받은 페어링 코드를 다시 받아 반환.
  ///
  /// 진행 상황은 [onPhase] 콜백으로 UI에 통지.
  /// 호출 후엔 자동으로 BLE 연결을 끊음.
  Future<BlePairingResult> provisionAndAwaitCode({
    required DiscoveredBridge bridge,
    required String ssid,
    required String password,
    required String cameraName,
    Duration totalTimeout = const Duration(seconds: 90),
    void Function(BlePairingPhase)? onPhase,
  }) async {
    onPhase?.call(BlePairingPhase.connecting);

    final device = bridge.device;
    final completer = Completer<BlePairingResult>();
    StreamSubscription? statusSub;
    StreamSubscription? codeSub;
    Timer? timeoutTimer;

    Future<void> cleanup() async {
      await statusSub?.cancel();
      await codeSub?.cancel();
      timeoutTimer?.cancel();
      try {
        await device.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }

    void finish(BlePairingResult r) {
      if (!completer.isCompleted) {
        completer.complete(r);
      }
    }

    try {
      // 1) 연결
      await device.connect(
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );
      _connectedDevice = device;

      // 🌟 [추가] 연결 직후 안드로이드 블루투스 스택 안정을 위해 1초 대기
      await Future.delayed(const Duration(seconds: 1));

      // 2) MTU 확장 시도 (Android 전용 — iOS는 자동)
      // JSON 페이로드가 길어질 수 있으므로 최대한 늘려둠
      try {
        await device.requestMtu(247);
        
        // 🌟 [추가] MTU 확장 및 안드로이드 시스템의 bonding(임시 페어링) 절차가 
        // 완료되거나 안정화될 때까지 3초간 충분히 기다려 줍니다.
        // 이 딜레이가 있어야 로그의 'bonding' 단계 충돌로 인한 튕김을 막을 수 있습니다.
        await Future.delayed(const Duration(seconds: 3));
      } catch (_) {}
      if (!device.isConnected){
        throw Exception('disconnected');
      }
      // 3) 서비스/특성 검색
      // 이제 시스템이 안정된 상태이므로 에러 없이 정상적으로 서비스를 찾아냅니다!
      final services = await device.discoverServices();
      BluetoothService? svc;
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() ==
            BleContract.serviceUuid.toLowerCase()) {
          svc = s;
          break;
        }
      }
      if (svc == null) {
        await cleanup();
        return BlePairingResult.failure(
          '카메라에서 EyeCatch 서비스를 찾지 못했어요',
        );
      }

      final provisioningChar = _findChar(svc, BleContract.provisioningCharUuid);
      final statusChar = _findChar(svc, BleContract.statusCharUuid);
      final codeChar = _findChar(svc, BleContract.pairingCodeCharUuid);

      if (provisioningChar == null ||
          statusChar == null ||
          codeChar == null) {
        await cleanup();
        return BlePairingResult.failure(
          '카메라의 BLE 구성이 예상과 달라요. 카메라 펌웨어를 확인해 주세요',
        );
      }

      // 4) 상태/코드 Notify 구독을 먼저 켜두기 — write 후 즉시 응답이 올 수 있음
      await statusChar.setNotifyValue(true);
      await codeChar.setNotifyValue(true);

      statusSub = statusChar.lastValueStream.listen((bytes) {
        if (bytes.isEmpty) return;
        final msg = utf8.decode(bytes, allowMalformed: true).trim();
        // 상태 메시지 매핑
        if (msg == 'wifi_connecting') {
          onPhase?.call(BlePairingPhase.waitingWifi);
        } else if (msg == 'wifi_ok') {
          onPhase?.call(BlePairingPhase.waitingPairingCode);
        } else if (msg == 'wifi_failed') {
          finish(BlePairingResult.failure(
            '카메라가 Wi-Fi에 연결하지 못했어요. 비밀번호를 다시 확인해 주세요',
          ));
        } else if (msg.startsWith('error:')) {
          finish(BlePairingResult.failure(
            msg.substring('error:'.length).trim().isEmpty
                ? '카메라 등록 중 오류가 발생했어요'
                : '오류: ${msg.substring('error:'.length).trim()}',
          ));
        }
      });

      codeSub = codeChar.lastValueStream.listen((bytes) {
        if (bytes.isEmpty) return;
        final code = utf8.decode(bytes, allowMalformed: true).trim();
        // 6자리 숫자인지 검증
        final clean = code.replaceAll(RegExp(r'[^0-9]'), '');
        if (clean.length == 6) {
          onPhase?.call(BlePairingPhase.done);
          finish(BlePairingResult.success(clean));
        }
      });

      // 5) 프로비저닝 페이로드 전송
      onPhase?.call(BlePairingPhase.sendingCredentials);
      final payload = jsonEncode({
        'ssid': ssid,
        'password': password,
        'camera_name': cameraName,
      });
      final bytes = utf8.encode(payload);

      // writeWithoutResponse는 빠르지만 응답 보장 X
      // 페어링 같은 1회성 중요 작업은 응답 받는 write 사용
      await provisioningChar.write(bytes, withoutResponse: true);

      // 6) 전체 타임아웃 — 브릿지가 wifi 연결 + 서버 register까지 마칠 시간
      timeoutTimer = Timer(totalTimeout, () {
  finish(BlePairingResult.failure(
    '카메라 응답이 너무 늦어요.\n\n'
    '• Wi-Fi 비밀번호가 맞는지 확인해 주세요\n'
    '• 카메라가 공유기 가까이 있는지 확인해 주세요\n'
    '• 카메라를 다시 켠 뒤 처음부터 시도해 주세요',
  ));
});
      final result = await completer.future;
      await cleanup();
      return result;
    } catch (e) {
      await cleanup();
      onPhase?.call(BlePairingPhase.failed);
      return BlePairingResult.failure(_humanizeBleError(e));
    }
  }

  BluetoothCharacteristic? _findChar(
    BluetoothService service,
    String uuid,
  ) {
    for (final c in service.characteristics) {
      if (c.uuid.toString().toLowerCase() == uuid.toLowerCase()) return c;
    }
    return null;
  }

  /// 외부에서 BLE 연결을 강제 종료하고 싶을 때 (사용자가 취소 누름 등)
  Future<void> cancel() async {
    await stopScan();
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
  }

  String _humanizeBleError(Object e) {
    final s = e.toString();
    if (s.contains('timeout')) return '카메라 연결 시간이 초과됐어요';
    if (s.contains('disconnected')) return '카메라와의 연결이 끊겼어요';
    if (s.contains('not supported')) return '이 기기는 BLE를 지원하지 않아요';
    if (s.contains('permission')) {
      return '블루투스 권한이 없어요. 설정에서 허용해 주세요';
    }
    return '블루투스 통신 중 오류가 발생했어요';
  }
}
