import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class RecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<void> dispose() => _recorder.dispose();


  Future<void> ensureMicPermission() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      print("Microphone permission already granted");
      return;
    }

    // Request permission
    final result = await Permission.microphone.request();

    if (result.isGranted) {
      print("Microphone permission granted after request");
      return;
    } else if (result.isPermanentlyDenied) {
      print("Microphone permission permanently denied. Open app settings.");
      throw MicPermissionException(
      'Microphone permission permanently denied. Please enable it in System Settings.',
    );
    } else {
      print("Microphone permission denied.");
      throw MicPermissionException('Microphone permission denied.');
    }
  } else {
    print("Microphone permission not required on this platform.");
  }
    
  }

  /// Returns the absolute file path it will record to, so the UI can store or upload it later.
  Future<String> start() async {
    print("get mic permission");
    //await ensureMicPermission();
    
    final dir = await getTemporaryDirectory();
    final filePath =
        p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');

    final cfg = const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 16000 * 16,  
    );


    await _recorder.start(cfg, path: filePath);
    print('Recording to $filePath');
    return filePath;
  }

  //helper method to hear recording on my computer
  Future<void> exportRecordingToDownloads(File recordedFile) async {
    final filename = recordedFile.uri.pathSegments.last;
    final newPath = "/sdcard/Download/$filename";
    final newFile = await recordedFile.copy(newPath);
    print("Recording exported to $newPath");
  }


  Future<File?> stop() async {
    final path = await _recorder.stop();
    return path != null ? File(path) : null;
  }

  Future<void> cancel() => _recorder.cancel();
}

class MicPermissionException implements Exception{
  final String message;
  MicPermissionException(this.message);

  @override
  String toString() => "MicPermissionException: $message";
}

