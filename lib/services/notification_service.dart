import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

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

    // ✅ v21+ 최신 버전 문법 (settings 명명 인자)
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  // ✅ 앱 최초 실행 시 알림 권한 팝업 강제 요청
  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showTestNotification({String? title, String? body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'baby_vision_channel',
      'Baby Vision Alerts',
      channelDescription: '카메라 이상 현상 감지 알림',
      importance: Importance.max,
      priority: Priority.high,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title ?? '🚨 이상 현상 감지 테스트',
      body: body ?? '카메라 화면에서 아기의 움직임이 감지되었습니다.',
      notificationDetails: platformDetails,
    );
  }

  Future<void> showUrgentNotification({String? title, String? body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'urgent_alert_channel',
      '긴급 위험 알림',
      channelDescription: '위험 구역 침입 등 긴급 상황 발생 시 화면을 깨우고 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // ✅ 화면 잠금을 뚫고 전화처럼 팝업을 띄우는 핵심 옵션
      enableVibration: true,
      playSound: true,
      color: Colors.red,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );

    // ✅ 오류 2, 3 해결: id, title, body 모두 명명 인자(이름표) 붙임
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond, // 알림이 겹치지 않게 고유 ID 부여
      title: title ?? '🚨 위험 구역 침입 감지!',
      body: body ?? '아이가 주방 가스레인지 구역에 접근했습니다. 즉시 확인하세요.',
      notificationDetails: platformDetails,
    );
  }
}