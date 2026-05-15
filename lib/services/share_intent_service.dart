import 'package:flutter/services.dart';

class ShareIntentService {
  static final ShareIntentService _instance = ShareIntentService._internal();
  factory ShareIntentService() => _instance;
  ShareIntentService._internal();

  static const MethodChannel _channel = MethodChannel('com.example.myailangtutor/share');

  String? _sharedText;
  String? _sharedTitle;
  String? _sharedSubject;
  Map<String, dynamic>? _sharedData;

  String? get sharedText => _sharedText;
  String? get sharedTitle => _sharedTitle;
  String? get sharedSubject => _sharedSubject;
  Map<String, dynamic>? get sharedData => _sharedData;

  Future<void> init() async {
    try {
      final Map<dynamic, dynamic>? data = await _channel.invokeMethod('getSharedData');
      if (data != null) {
        _sharedText = data['text'] as String?;
        _sharedTitle = data['title'] as String?;
        _sharedSubject = data['subject'] as String?;
        
        _sharedData = {
          'type': 'text/plain',
          'text': _sharedText,
          'title': _sharedTitle,
          'subject': _sharedSubject,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } on PlatformException catch (e) {
      print('Share Intent Error: ${e.message}');
    } catch (e) {
      print('Share Intent Error: $e');
    }
  }

  Future<bool> hasSharedData() async {
    try {
      final bool? result = await _channel.invokeMethod('hasSharedData');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    clearSharedData();
  }

  String getSharedDataAsString() {
    if (_sharedData != null) {
      return _sharedData.toString();
    }
    return '';
  }

  void clearSharedData() {
    try {
      _channel.invokeMethod('clearSharedData');
    } catch (e) {
      print('Clear Share Intent Error: $e');
    }
    _sharedText = null;
    _sharedTitle = null;
    _sharedSubject = null;
    _sharedData = null;
  }

  void setSharedData(String text, {String? title, String? subject}) {
    _sharedText = text;
    _sharedTitle = title;
    _sharedSubject = subject;
    _sharedData = {
      'type': 'text/plain',
      'text': text,
      'title': title,
      'subject': subject,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
