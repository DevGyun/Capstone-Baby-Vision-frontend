import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  @override
  void initState() {
    super.initState();
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    await _localRenderer.initialize();

    // 💡 FastAPI 서버 IP 또는 도메인으로 변경해야 합니다.
    final wsUrl = Uri.parse('ws://서버주소/ws/signaling/${widget.clientId}');
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
      color: Colors.black,
      child: RTCVideoView(
        _localRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}