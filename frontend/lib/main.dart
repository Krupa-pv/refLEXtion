import 'package:flutter/material.dart';
import 'package:frontend/camera.dart';
import 'package:frontend/test.dart';
import 'avatarcustomizationpage.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'refLEXion Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'refLEXion'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
  
}

class _MyHomePageState extends State<MyHomePage> {
  final SpeechServices _speechServices = SpeechServices();
  int _counter = 0;

  Future <void> _incrementCounter() async {
    await _speechServices.CheckConnection();
    setState(() {
      _counter++;
    });
  }

  @override
  void initState() {
    super.initState();

    // Delay to ensure the widget tree is built before showing dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeDialog();
    });
  }

  @override
  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.deepPurple[50],
    appBar: AppBar(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.deepPurple[50],
      title: Text(
        widget.title,
        style: const TextStyle(
          fontSize: 28,          // increase size
          fontWeight: FontWeight.w900, // make it chunky/bolder
        ),
      ),
    ),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, // hugs content tightly
        children: [
          // Logo on top
          Image.asset(
            'assets/logo.png',
            width: 300,
            height: 300,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              debugPrint("avatar creation!");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AvatarCustomizationPage(
                    onAvatarCreated: (url) {
                      print("Avatar URL: $url");
                      // save to backend / user profile
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.deepPurple[50]
            ),
            child: const Text("Create your refLEXion!"),
          ),
           // spacing between logo and button
          const SizedBox(height: 20), 
          // Main button
          ElevatedButton(
            onPressed: () {
              debugPrint("Let's Reflect button pressed!");
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.deepPurple[50]
            ),
            child: const Text("Let's refLEX!"),
          ),
        ],
      ),
    ),
  );
}


  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // user must press button
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png', // replace with your logo path
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 8),
              const Text('Welcome to refLEXion'), // replace with your company name
            ],
          ),
          content: const Text('We’re excited to see you again!'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // close the dialog
              },
            ),
          ],
        );
      },
    );
  }

}