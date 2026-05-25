import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // appNavigatorKey

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// 앱이 종료된 상태에서 알림 탭으로 시작된 경우 받는 페이로드.
  String? _launchPayload;
  String? get launchPayload => _launchPayload;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final launchDetails = await flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _launchPayload = launchDetails?.notificationResponse?.payload;
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    _navigateFromNotification(response.payload);
  }

  void _navigateFromNotification(String? payload) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil('/main', (_) => false);
  }

  void handleLaunchPayload() {
    if (_launchPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromNotification(_launchPayload);
        _launchPayload = null;
      });
    }
  }

  Future<void> requestPermissions() async {
    final androidImpl =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

  Future<void> showTestNotification({String? title, String? body}) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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
      payload: 'alerts',
    );
  }

/// 긴급 위험 알림. imagePath가 있으면 감지 사진을 펼쳐 보여줌.
/// 긴급 위험 알림. imagePath가 있으면 감지 사진을 펼쳐 보여줌.
Future<void> showUrgentNotification({
  String? title,
  String? body,
  String? imagePath,
}) async {
  final hasImage = imagePath != null && File(imagePath).existsSync();

  // 안드로이드: 펼쳤을 때 큰 사진
  final StyleInformation? styleInformation = hasImage
      ? BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          contentTitle: title,
          summaryText: body,
          hideExpandedLargeIcon: true, // 펼치면 우측 작은 썸네일 숨김 (중복 방지)
        )
      : null;

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'urgent_alert_channel',
    '긴급 위험 알림',
    channelDescription: '위험 구역 침입 등 긴급 상황 발생 시 화면을 깨우고 알림을 보냅니다.',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
    enableVibration: true,
    playSound: true,
    color: Colors.red,
    styleInformation: styleInformation,
    // 접힌 상태에서도 우측에 작은 썸네일
    largeIcon: hasImage ? FilePathAndroidBitmap(imagePath) : null,
  );

  final NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      attachments: hasImage
          ? [DarwinNotificationAttachment(imagePath)]
          : null,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    id: DateTime.now().millisecond,
    title: title ?? '🚨 위험 구역 침입 감지!',
    body: body ?? '아이가 주방 가스레인지 구역에 접근했습니다. 즉시 확인하세요.',
    notificationDetails: platformDetails,
    payload: 'alerts',
  );
}}