import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // 싱글톤 패턴
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 안드로이드 아이콘 설정 (기본 아이콘 사용)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 권한 설정
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // 나중에 카메라에서 호출할 때 메시지를 동적으로 바꿀 수 있도록 파라미터화
  Future<void> showTestNotification({String? title, String? body}) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'baby_vision_channel', // 채널 ID
      'Baby Vision Alerts', // 채널 이름
      channelDescription: '카메라 이상 현상 감지 알림',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // 알림 발생!
    await flutterLocalNotificationsPlugin.show(
      0, // 알림 ID (고유값)
      title ?? '이상 현상 감지 테스트',
      body ?? '카메라 화면에서 아기의 움직임이 감지되었습니다.',
      platformDetails,
    );
  }
}