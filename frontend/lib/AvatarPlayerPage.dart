import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'avatarvideoservice.dart';

class AvatarPlayerPage extends StatefulWidget {
  const AvatarPlayerPage({super.key});

  @override
  State<AvatarPlayerPage> createState() => _AvatarPlayerPageState();
}

class _AvatarPlayerPageState extends State<AvatarPlayerPage> {
  late WebViewController controller;
  final service = AvatarVideoService();

  @override
  void initState() {
    super.initState();
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ConsoleLog',
        onMessageReceived: (message) {
          print("JS LOG: ${message.message}"); // Flutter debug console
        },
      )
      ..loadFlutterAsset('assets/avatar_player.html');
  }


  Future<void> _onPressed() async {
    final data = await service.generateAvatarData(
      glbUrl: "https://models.readyplayer.me/68fdd258dc534bad0f8219fa.glb",
      text: "æ",
    );

    if (data != null) {
      controller.runJavaScript(
        'window.postMessage(${jsonEncode(data)})',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avatar Player')),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _onPressed,
                child: const Text("Play Avatar"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
