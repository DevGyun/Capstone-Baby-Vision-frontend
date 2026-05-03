import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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

    // ✅ v21: settings 명명 인자 필수
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<void> showTestNotification({String? title, String? body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'baby_vision_channel',
      'Baby Vision Alerts',
      channelDescription: '카메라 이상 현상 감지 알림',
      importance: Importance.max,
      priority: Priority.high,
    );

    // DarwinNotificationDetails는 v21에서 const 생성자가 아니므로 final 사용
    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    // ✅ v21: id, title, body, notificationDetails 모두 명명 인자
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title ?? '🚨 이상 현상 감지 테스트',
      body: body ?? '카메라 화면에서 아기의 움직임이 감지되었습니다.',
      notificationDetails: platformDetails,
    );
  }
}