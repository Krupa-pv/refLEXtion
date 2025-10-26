import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'tts.dart';


class AvatarCustomizationPage extends StatefulWidget {
  final Function(String avatarUrl) onAvatarCreated;

  const AvatarCustomizationPage({Key? key, required this.onAvatarCreated}) : super(key: key);

  @override
  State<AvatarCustomizationPage> createState() => _AvatarCustomizationPageState();
}

class _AvatarCustomizationPageState extends State<AvatarCustomizationPage> {
  final tts = TTSService();
  late WebViewController _controller;

  final String rpmUrl = "https://refLEXtion.readyplayer.me/avatar?frameApi";

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'RPMChannel',
        onMessageReceived: (message) {
          debugPrint("yes atleast it receives a message!");
          try {
            final data = jsonDecode(message.message);
          } catch (_) {
            // ignore
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _controller.runJavaScript("""
              window.addEventListener('message', function(event) {
                try {
                  const data = JSON.parse(event.data);
                  if (data.eventName === 'v1.avatar.exported' && data.data.url) {
                    RPMChannel.postMessage(JSON.stringify({ url: data.data.url }));
                  }
                } catch(e) {}
              });
            """);
          },
        ),
      )
      ..loadRequest(Uri.parse(rpmUrl));
  }

  void _onDone() async{

    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null){
      debugPrint(data.text);
      Navigator.pop(context);
    }
    else{
      tts.speak("Make sure to complete your avatar and copy the link before pressing done!");
      _onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Customize Your Avatar")),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Positioned(
            top: 50,
            right: 2,
            child: SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: _onDone,
                child: Text("Done"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.deepPurple[50],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
