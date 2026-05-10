import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

Widget getPlatformPlayer(
  String hlsUrl, {
  VoidCallback? onConnected,
  VoidCallback? onRetry,
}) {
  return WebHlsPlayer(hlsUrl: hlsUrl);
}

class WebHlsPlayer extends StatefulWidget {
  final String hlsUrl;

  const WebHlsPlayer({super.key, required this.hlsUrl});

  @override
  State<WebHlsPlayer> createState() => _WebHlsPlayerState();
}

class _WebHlsPlayerState extends State<WebHlsPlayer> {
  late String viewId;
  late String iframeUrl;

  @override
  void initState() {
    super.initState();

    iframeUrl = widget.hlsUrl.endsWith('/index.m3u8')
        ? widget.hlsUrl.substring(0, widget.hlsUrl.length - 'index.m3u8'.length)
        : widget.hlsUrl;

    viewId = 'iframe-video-player-${widget.hlsUrl.hashCode}';

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final iframe = html.IFrameElement()
        ..src = iframeUrl
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