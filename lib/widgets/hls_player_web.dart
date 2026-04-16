import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

// hls_player.dart 에서 호출할 약속된 함수
Widget getPlatformPlayer(String streamId) {
  return WebHlsPlayer(streamId: streamId);
}

class WebHlsPlayer extends StatefulWidget {
  final String streamId;
  const WebHlsPlayer({super.key, required this.streamId});

  @override
  State<WebHlsPlayer> createState() => _WebHlsPlayerState();
}

class _WebHlsPlayerState extends State<WebHlsPlayer> {
  late String fullUrl;
  late String viewId;

  @override
  void initState() {
    super.initState();
    fullUrl = 'http://211.243.47.179:8888/${widget.streamId}/';
    viewId = 'iframe-video-player-${widget.streamId}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final iframe = html.IFrameElement()
        ..src = fullUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..allow = 'autoplay; fullscreen; camera; microphone';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: HtmlElementView(viewType: viewId),
      ),
    );
  }
}