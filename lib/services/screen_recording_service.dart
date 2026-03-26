import 'package:flutter/services.dart';
import 'dart:io';

class ScreenRecordingService {
  static const MethodChannel _channel = MethodChannel('com.playsphere/screen_recording');

  /// Prevents screen recording on Android
  /// Note: This also prevents screenshots due to Android limitations
  static Future<void> preventScreenRecording() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('preventScreenRecording');
      } on PlatformException catch (e) {
      }
    }
  }

  /// Allows screen recording on Android
  static Future<void> allowScreenRecording() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('allowScreenRecording');
      } on PlatformException catch (e) {
      }
    }
  }
}
