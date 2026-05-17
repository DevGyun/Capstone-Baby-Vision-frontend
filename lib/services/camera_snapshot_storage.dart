import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 카메라별 라이브 영상 한 프레임을 기기에 캐시.
///
/// ZoneScreen 배경으로 사용 — 매번 라이브 영상 띄우지 않고
/// 한 번 캡처해둔 이미지 위에 위험구역을 그릴 수 있게 함.
///
/// 백엔드 스키마 변경 없이 시연용으로 동작.
/// 추후 백엔드에 GET /cameras/{id}/snapshot API가 생기면
/// 이 클래스를 제거하고 서버로 옮기면 됨.
///
/// 저장 위치: <앱 문서 디렉토리>/snapshots/camera_<id>.png
class CameraSnapshotStorage {
  static const String _folder = 'snapshots';

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _fileFor(int cameraId) async {
    final dir = await _dir();
    return File('${dir.path}/camera_$cameraId.png');
  }

  /// 카메라 스냅샷 저장
  static Future<void> save(int cameraId, Uint8List pngBytes) async {
    final f = await _fileFor(cameraId);
    await f.writeAsBytes(pngBytes, flush: true);
  }

  /// 저장된 스냅샷 파일 가져오기 — 없으면 null
  static Future<File?> load(int cameraId) async {
    final f = await _fileFor(cameraId);
    if (await f.exists()) return f;
    return null;
  }

  /// 카메라가 삭제되면 함께 정리
  static Future<void> remove(int cameraId) async {
    try {
      final f = await _fileFor(cameraId);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}