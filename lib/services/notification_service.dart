/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 앱이 백그라운드나 종료 상태일 때 메시지를 처리하는 최상단 함수
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("백그라운드 메시지 수신: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // 글로벌 네비게이터 키 (알림 클릭 시 화면 이동을 위해 main.dart와 공유)
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    // 1. Firebase 초기화 및 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. 안드로이드 채널 세팅 (알림 아이콘은 실제 안드로이드 mipmap에 맞춰 수정)
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: DarwinInitializationSettings());

    await _localNotifications.initialize(
      initSettings,
      // 알림창의 버튼(Action)을 클릭했을 때의 동작 처리
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationAction(response.actionId, response.payload);
      },
    );

    // 3. 알림 채널 생성 (색상 및 중요도 분리)
    await _createNotificationChannels();

    // 4. 포그라운드 메시지 수신 리스너
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  Future<void> _createNotificationChannels() async {
    // [채널 1] 위험 구역 접근 (빨간색 테마, 헤드업 알림, 최대 중요도)
    const AndroidNotificationChannel dangerChannel = AndroidNotificationChannel(
      'danger_zone_channel',
      '위험 구역 접근 알림',
      description: '아이가 위험 구역에 접근했을 때 발생하는 긴급 알림입니다.',
      importance: Importance.max,
      ledColor: Colors.red, // LED 색상 빨강
    );

    // [채널 2] 일반 움직임 감지 (파란색 테마, 기본 중요도)
    const AndroidNotificationChannel normalChannel = AndroidNotificationChannel(
      'normal_movement_channel',
      '일반 움직임 감지',
      description: '아이의 일반적인 움직임을 감지한 알림입니다.',
      importance: Importance.high,
      ledColor: Colors.blue, // LED 색상 파랑
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(dangerChannel);
        
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(normalChannel);
  }

  // 포그라운드 수신 시 로컬 알림 띄우기
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final bool isDanger = message.data['type'] == 'danger';
    
    // 알림에 추가될 대화형 액션 버튼들
    final List<AndroidNotificationAction> actions = [
      const AndroidNotificationAction(
        'action_live_view', '실시간 보기',
        showsUserInterface: true,
      ),
      if (isDanger) // 위험 상황일 때만 경보음 버튼 추가
        const AndroidNotificationAction(
          'action_sound_alarm', '경보음 울리기',
          showsUserInterface: true,
          cancelNotification: false, // 버튼 눌러도 알림창 유지
        ),
    ];

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isDanger ? 'danger_zone_channel' : 'normal_movement_channel',
      isDanger ? '위험 구역 접근 알림' : '일반 움직임 감지',
      importance: isDanger ? Importance.max : Importance.high,
      priority: isDanger ? Priority.high : Priority.defaultPriority,
      color: isDanger ? Colors.redAccent : Colors.blueAccent, // 알림 아이콘/배경 색상 분리
      colorized: true,
      actions: actions,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? (isDanger ? '🚨 위험 감지!' : 'ℹ️ 움직임 감지'),
      message.notification?.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  // 액션 버튼 클릭 및 알림 탭 처리 로직
  void _handleNotificationAction(String? actionId, String? payload) {
    if (actionId == 'action_live_view') {
      // '실시간 보기' 버튼 클릭 시 CCTV 화면으로 라우팅
      debugPrint("실시간 보기 액션 실행");
      navigatorKey.currentState?.pushNamed('/live-stream');
    } else if (actionId == 'action_sound_alarm') {
      // '경보음 울리기' 로직 (API 호출 등)
      debugPrint("경보음 울리기 API 호출!");
      // TODO: 백엔드로 경보음 울리기 API POST 요청
    } else {
      // 일반 알림창 클릭 시 (히스토리나 메인 화면으로 이동)
      navigatorKey.currentState?.pushNamed('/main');
    }
  }

  // 알림 권한 요청 (앱 최초 실행 시)
  Future<void> requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }
}*/