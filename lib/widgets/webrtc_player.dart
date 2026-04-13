import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';

class WebRtcPlayer extends StatefulWidget {
  final String cameraId;
  final String clientId;

  const WebRtcPlayer({
    super.key, 
    required this.cameraId, 
    required this.clientId,
  });

  @override
  State<WebRtcPlayer> createState() => _WebRtcPlayerState();
}

class _WebRtcPlayerState extends State<WebRtcPlayer> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _channel;
  
  // 💡 비디오 트랙 수신 여부를 확인하는 상태 변수 추가
  bool _isVideoReady = false; 

  @override
  void initState() {
    super.initState();
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    await _localRenderer.initialize();

    final wsUrl = Uri.parse('${AppConfig.wsUrl}/ws/signaling/${widget.clientId}');
    _channel = WebSocketChannel.connect(wsUrl);

    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        setState(() {
          _localRenderer.srcObject = event.streams[0];
          // 💡 영상 트랙이 들어오면 준비 완료 상태로 변경!
          _isVideoReady = true; 
        });
      }
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _sendMessage({
        'type': 'candidate',
        'target_id': widget.cameraId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    _channel?.stream.listen((message) async {
      var data = jsonDecode(message);
      
      if (data['type'] == 'answer') {
        var answer = RTCSessionDescription(data['sdp'], data['type']);
        await _peerConnection?.setRemoteDescription(answer);
      } 
      else if (data['type'] == 'candidate') {
        var candidate = RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex']);
        await _peerConnection?.addCandidate(candidate);
      }
    });

    _createOffer();
  }

  Future<void> _createOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    _sendMessage({
      'type': 'offer',
      'target_id': widget.cameraId,
      'sdp': offer.sdp,
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _localRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // 배경을 항상 까맣게 유지
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 실제 영상 렌더러 (항상 렌더링은 하되 데이터가 없으면 투명하게 대기)
          RTCVideoView(
            _localRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),

          // 2. 💡 영상이 아직 안 들어왔을 때 보여줄 로딩 오버레이 UI
          if (!_isVideoReady)
            Container(
              color: Colors.black87, // 영상 렌더러 위를 살짝 덮음
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.blueAccent,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '안전한 P2P 연결을 생성 중입니다...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '카메라 모듈과 통신 중',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}