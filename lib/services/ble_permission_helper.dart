import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// BLE 사용 전 필요한 권한을 한 번에 요청.
///
/// - Android 12+ (SDK 31+): bluetoothScan, bluetoothConnect
/// - Android 11 이하: bluetooth, bluetoothAdmin, locationWhenInUse
/// - iOS: bluetooth (첫 사용 시 자동 팝업)
class BlePermissionHelper {
  /// 모든 BLE 관련 권한을 요청.
  /// 반환값:
  ///   - granted: 모두 허용됨
  ///   - denied: 일부 거부됨 (사용자가 다시 허용 가능)
  ///   - permanentlyDenied: 영구 거부됨 (앱 설정으로 가야 함)
  static Future<BlePermissionResult> requestAll() async {
    if (Platform.isAndroid) {
      return _requestAndroid();
    } else if (Platform.isIOS) {
      return _requestIOS();
    }
    // 데스크탑/웹은 BLE 미지원으로 처리
    return BlePermissionResult.unsupported;
  }

  static Future<BlePermissionResult> _requestAndroid() async {
    // Android는 SDK 버전을 정확히 알기 어려우니 모두 요청 — permission_handler가
    // 이미 부여된/지원 안 되는 권한은 알아서 처리해줌.
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Android 11 이하 호환 — 12+에선 시스템이 자동 무시
      Permission.locationWhenInUse,
    ].request();

    final critical = [
      statuses[Permission.bluetoothScan],
      statuses[Permission.bluetoothConnect],
    ];

    // bluetoothScan/Connect 중 하나라도 영구 거부면 사용자가 직접 설정에서 풀어줘야 함
    if (critical.any((s) => s == PermissionStatus.permanentlyDenied)) {
      return BlePermissionResult.permanentlyDenied;
    }
    if (critical.every((s) => s == PermissionStatus.granted)) {
      return BlePermissionResult.granted;
    }
    return BlePermissionResult.denied;
  }

  static Future<BlePermissionResult> _requestIOS() async {
    final status = await Permission.bluetooth.request();
    switch (status) {
      case PermissionStatus.granted:
        return BlePermissionResult.granted;
      case PermissionStatus.permanentlyDenied:
        return BlePermissionResult.permanentlyDenied;
      default:
        return BlePermissionResult.denied;
    }
  }
}

enum BlePermissionResult {
  granted,
  denied,
  permanentlyDenied,
  unsupported,
}