import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 앱 아이콘을 알림 아이콘으로 사용 (@mipmap/ic_launcher)
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

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // 임시 알림 발생 함수
  Future<void> showTestNotification({String? title, String? body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'baby_vision_channel', 
      'Baby Vision Alerts', 
      channelDescription: '카메라 이상 현상 감지 알림',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      0, 
      title ?? '🚨 이상 현상 감지 테스트',
      body ?? '카메라 화면에서 아기의 움직임이 감지되었습니다.',
      platformDetails,
    );
  }
}