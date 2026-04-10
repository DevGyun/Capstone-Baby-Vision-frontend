import 'package:flutter/material.dart';

// 로그 데이터 구조체
class IncidentLog {
  final String title;
  final String time;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool isAlert;
  final String imageUrl;

  IncidentLog({
    required this.title,
    required this.time,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.isAlert = false,
    required this.imageUrl,
  });
}

// 상태 관리 프로바이더
class LogProvider extends ChangeNotifier {
  // 실제 서버 대신 임시로 들고 있을 로그 데이터들
  final List<IncidentLog> _logs = [
    IncidentLog(
      title: '위험 감지',
      time: '방금 전',
      description: '제 1구역 아이방 베란다 접근 감지',
      icon: Icons.warning,
      iconColor: Colors.redAccent,
      isAlert: true,
      imageUrl: 'assets/images/1babyscreen.png',
    ),
    IncidentLog(
      title: '일반 알림',
      time: '15분 전',
      description: '침대 위 일반적인 움직임 감지',
      icon: Icons.info_outline,
      iconColor: Colors.blueAccent,
      imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&q=80',
    ),
    IncidentLog(
      title: '시스템 알림',
      time: '1시간 전',
      description: '카메라 01 펌웨어 업데이트 완료',
      icon: Icons.settings,
      iconColor: Colors.grey,
      imageUrl: 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&q=80',
    ),
  ];

  List<IncidentLog> get logs => _logs;

  // 새로운 알람이 오면 맨 위에 추가하고 화면 갱신
  void addLog(IncidentLog newLog) {
    _logs.insert(0, newLog);
    notifyListeners();
  }
}